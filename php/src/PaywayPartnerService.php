<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner;

use Kechankrisna\PaywayPartner\Crypto\OpenSslCrypto;
use Kechankrisna\PaywayPartner\Crypto\PaywayPartnerCrypto;
use Kechankrisna\PaywayPartner\Exception\ErrorType;
use Kechankrisna\PaywayPartner\Exception\PaywayPartnerException;
use Kechankrisna\PaywayPartner\Http\CurlHttpClient;
use Kechankrisna\PaywayPartner\Http\HttpClient;
use Kechankrisna\PaywayPartner\Model\CheckMerchantRequest;
use Kechankrisna\PaywayPartner\Model\GetMcInfoRequest;
use Kechankrisna\PaywayPartner\Model\InquiryResponse;
use Kechankrisna\PaywayPartner\Model\MerchantCredential;
use Kechankrisna\PaywayPartner\Model\MerchantInfo;
use Kechankrisna\PaywayPartner\Model\RegisterMerchantRequest;
use Kechankrisna\PaywayPartner\Model\RegisterMerchantResponse;
use Psr\Clock\ClockInterface;
use Psr\Log\LoggerInterface;

/**
 * ABA PayWay partner API client.
 *
 * PayWay business errors (`PTL02 Wrong Hash`, `PTL46 Merchant not found`, ...)
 * are returned in `status`. A {@see PaywayPartnerException} is thrown only
 * when PayWay could not be reached, did not answer with a status, or data
 * could not be decrypted.
 *
 * Run this on your server: the partner key and private key are secrets.
 */
final class PaywayPartnerService
{
    /** endpoint of {@see registerMerchant()} */
    public const string REGISTER_MERCHANT_PATH = '/api/merchant-portal/online-self-activation/new-merchant';

    /** endpoint of {@see checkMerchant()} */
    public const string CHECK_MERCHANT_PATH = '/api/merchant-portal/online-self-activation/get-mc-credential-info';

    /** endpoint of {@see getMcInfo()} */
    public const string GET_MC_INFO_PATH = '/api/merchant-portal/online-self-activation/get-mc-info';

    /** builds the signed request bodies; exposed to support new endpoints */
    public readonly RequestBuilder $requestBuilder;

    private readonly PaywayPartnerCrypto $crypto;

    private ?HttpClient $http;

    /**
     * Every dependency except `$partner` is optional and injectable.
     *
     * @param PaywayPartner $partner partner credentials used to sign and decrypt
     * @param ?HttpClient $httpClient HTTP stack (default: {@see CurlHttpClient})
     * @param ?ClockInterface $clock PSR-20 source of `request_time` (default: now)
     * @param ?PaywayPartnerCrypto $crypto RSA/HMAC implementation (default: ext-openssl)
     * @param ?LoggerInterface $logger PSR-3 logger for request/response logs (debug level)
     */
    public function __construct(
        public readonly PaywayPartner $partner,
        ?HttpClient $httpClient = null,
        ?ClockInterface $clock = null,
        ?PaywayPartnerCrypto $crypto = null,
        private readonly ?LoggerInterface $logger = null,
    ) {
        $this->crypto = $crypto ?? new OpenSslCrypto();
        $this->requestBuilder = new RequestBuilder($partner, $clock, $this->crypto);
        // created on first use, so decrypting a pushback needs no ext-curl
        $this->http = $httpClient;
    }

    /**
     * Registers a merchant; redirect the merchant to the returned `url`, then
     * wait for the pushback (see {@see decryptPushback()}).
     *
     * @throws PaywayPartnerException
     */
    public function registerMerchant(RegisterMerchantRequest $request): RegisterMerchantResponse
    {
        return RegisterMerchantResponse::fromArray(
            $this->post(self::REGISTER_MERCHANT_PATH, $this->requestBuilder->registerMerchant($request)),
        );
    }

    /**
     * Inquiry merchant info via register ref; decrypt the result with
     * {@see decryptMerchantCredential()}.
     *
     * @throws PaywayPartnerException
     */
    public function checkMerchant(CheckMerchantRequest $request): InquiryResponse
    {
        return InquiryResponse::fromArray(
            $this->post(self::CHECK_MERCHANT_PATH, $this->requestBuilder->checkMerchant($request)),
        );
    }

    /**
     * Inquiry merchant info via merchant public key; decrypt the result with
     * {@see decryptMcInfo()}.
     *
     * @throws PaywayPartnerException
     */
    public function getMcInfo(GetMcInfoRequest $request): InquiryResponse
    {
        return InquiryResponse::fromArray(
            $this->post(self::GET_MC_INFO_PATH, $this->requestBuilder->getMcInfo($request)),
        );
    }

    /**
     * Decrypts encrypted PayWay `data` with the partner private key.
     *
     * @return array<string, mixed>
     *
     * @throws PaywayPartnerException `decryption` when it cannot be decrypted
     */
    public function decryptMerchantData(string $data): array
    {
        try {
            return $this->crypto->decryptJson($data, $this->partner->partnerPrivateKey);
        } catch (\Throwable $e) {
            throw new PaywayPartnerException(ErrorType::Decryption, 'Could not decrypt PayWay data', null, $e);
        }
    }

    /**
     * Decrypts the `data` of {@see checkMerchant()}.
     *
     * @throws PaywayPartnerException
     */
    public function decryptMerchantCredential(string $data): MerchantCredential
    {
        return MerchantCredential::fromArray($this->decryptMerchantData($data));
    }

    /**
     * Decrypts the `data` of {@see getMcInfo()}.
     *
     * @throws PaywayPartnerException
     */
    public function decryptMcInfo(string $data): MerchantInfo
    {
        return MerchantInfo::fromArray($this->decryptMerchantData($data));
    }

    /**
     * Decrypts the body PayWay POSTs (as `text/plain`) to your `pushback_url`:
     * `{"return_params": "<encrypted merchant details>"}`.
     *
     * ```php
     * $credential = $service->decryptPushback(file_get_contents('php://input'));
     * ```
     *
     * @throws PaywayPartnerException `invalidPushback` or `decryption`
     */
    public function decryptPushback(string $body): MerchantCredential
    {
        try {
            $decoded = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
        } catch (\JsonException $e) {
            throw new PaywayPartnerException(ErrorType::InvalidPushback, 'Pushback body is not JSON', null, $e);
        }
        if (!\is_array($decoded) || !\is_string($decoded['return_params'] ?? null)) {
            throw new PaywayPartnerException(ErrorType::InvalidPushback, 'Pushback body has no "return_params"');
        }

        return $this->decryptMerchantCredential($decoded['return_params']);
    }

    /**
     * POSTs `$body` to `$path` and returns PayWay's reply. PayWay answers
     * errors with a non-2xx status and a JSON body carrying the real status,
     * which is returned like a success.
     *
     * @param array<string, string> $body
     * @return array<array-key, mixed>
     */
    private function post(string $path, array $body): array
    {
        $url = rtrim($this->partner->baseApiUrl, '/') . $path;
        $payload = json_encode($body, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        $this->logger?->debug("[PayWay] POST {$url} {$payload}");

        try {
            $this->http ??= new CurlHttpClient();
            $response = $this->http->post($url, $this->headers(), $payload);
        } catch (PaywayPartnerException $e) {
            $this->logger?->debug("[PayWay] failed {$e->getMessage()}");
            throw $e;
        }

        $this->logger?->debug("[PayWay] {$response->statusCode} {$response->body}");
        $json = json_decode($response->body, true);
        if (\is_array($json) && \is_array($json['status'] ?? null)) {
            return $json;
        }

        throw new PaywayPartnerException(
            ErrorType::UnexpectedResponse,
            'Unexpected response from PayWay',
            $response->statusCode,
        );
    }

    /** @return array<string, string> */
    private function headers(): array
    {
        $headers = [
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'payway-partner-php/' . Version::SDK_VERSION,
        ];
        if ($this->partner->partnerReferer !== '') {
            $headers['Referer'] = $this->partner->partnerReferer;
        }

        return $headers;
    }
}
