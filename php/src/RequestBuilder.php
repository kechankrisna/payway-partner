<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner;

use Kechankrisna\PaywayPartner\Crypto\OpenSslCrypto;
use Kechankrisna\PaywayPartner\Crypto\PaywayPartnerCrypto;
use Kechankrisna\PaywayPartner\Model\CheckMerchantRequest;
use Kechankrisna\PaywayPartner\Model\GetMcInfoRequest;
use Kechankrisna\PaywayPartner\Model\RegisterMerchantRequest;
use Psr\Clock\ClockInterface;

/**
 * Builds the signed JSON bodies PayWay expects: `request_time`,
 * `request_data` (RSA-encrypted payload), `partner_id` and `hash`
 * (HMAC-SHA256 of partner_id + request_data + request_time).
 *
 * To support a new endpoint, build its body with {@see signedBody()}.
 */
final readonly class RequestBuilder
{
    private ClockInterface $clock;

    private PaywayPartnerCrypto $crypto;

    public function __construct(
        private PaywayPartner $partner,
        ?ClockInterface $clock = null,
        ?PaywayPartnerCrypto $crypto = null,
    ) {
        $this->clock = $clock ?? new SystemClock();
        $this->crypto = $crypto ?? new OpenSslCrypto();
    }

    /**
     * Body of `new-merchant`; `reference_id` mirrors `register_ref`.
     *
     * @return array<string, string>
     */
    public function registerMerchant(RegisterMerchantRequest $request, ?string $requestTime = null): array
    {
        return $this->signedBody($request->toArray(), $requestTime, ['reference_id' => $request->registerRef]);
    }

    /**
     * Body of `get-mc-credential-info`.
     *
     * @return array<string, string>
     */
    public function checkMerchant(CheckMerchantRequest $request, ?string $requestTime = null): array
    {
        return $this->signedBody($request->toArray(), $requestTime);
    }

    /**
     * Body of `get-mc-info`: `public_key_hash_encrypt` is the HMAC-SHA512 of
     * partner_id + merchant_key + request_time keyed with the merchant public
     * key; `rsa_public_key_hash_encrypt` is the same string RSA-encrypted.
     *
     * @return array<string, string>
     */
    public function getMcInfo(GetMcInfoRequest $request, ?string $requestTime = null): array
    {
        $time = $this->requestTime($requestTime);
        $hashEncryptString = $this->partner->partnerId . $request->merchantKey . $time;
        $payload = [
            'merchant_key' => $request->merchantKey,
            'currency' => $request->currency,
            'public_key_hash_encrypt' => $this->crypto->hmacSha512($hashEncryptString, $request->publicKey),
        ];
        if ($request->rsaPublicKey !== null) {
            $payload['rsa_public_key_hash_encrypt'] = $this->crypto->encryptString(
                $hashEncryptString,
                $request->rsaPublicKey,
            );
        }

        return $this->signedBody($payload, $time);
    }

    /**
     * Encrypts `$payload` as `request_data` and signs it; `$extra` is sent as is.
     *
     * @param array<string, mixed> $payload
     * @param array<string, string> $extra
     * @return array<string, string>
     */
    public function signedBody(array $payload, ?string $requestTime = null, array $extra = []): array
    {
        $time = $this->requestTime($requestTime);
        $requestData = $this->crypto->encryptJson($payload, $this->partner->partnerPublicKey);

        return [
            'request_time' => $time,
            'request_data' => $requestData,
            'partner_id' => $this->partner->partnerId,
            ...$extra,
            'hash' => $this->hash($requestData, $time),
        ];
    }

    /** HMAC-SHA256 of partner_id + request_data + request_time with the partner key. */
    public function hash(string $requestData, string $requestTime): string
    {
        return $this->crypto->hmacSha256(
            $this->partner->partnerId . $requestData . $requestTime,
            $this->partner->partnerKey,
        );
    }

    /** `YYYYMMDDHHmmss` in UTC, as PayWay requires. */
    public static function formatRequestTime(\DateTimeInterface $time): string
    {
        return \DateTimeImmutable::createFromInterface($time)
            ->setTimezone(new \DateTimeZone('UTC'))
            ->format('YmdHis');
    }

    private function requestTime(?string $requestTime): string
    {
        $time = $requestTime ?? self::formatRequestTime($this->clock->now());
        if (preg_match('/^\d{14}$/', $time) !== 1) {
            throw new \InvalidArgumentException("requestTime must be 14 digits YYYYMMDDHHmmss, got \"{$time}\"");
        }

        return $time;
    }
}
