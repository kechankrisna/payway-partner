<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Tests;

use Kechankrisna\PaywayPartner\Crypto\OpenSslCrypto;
use Kechankrisna\PaywayPartner\Exception\ErrorType;
use Kechankrisna\PaywayPartner\Exception\PaywayPartnerException;
use Kechankrisna\PaywayPartner\Http\HttpResponse;
use Kechankrisna\PaywayPartner\Http\Psr18HttpClient;
use Kechankrisna\PaywayPartner\Model\CheckMerchantRequest;
use Kechankrisna\PaywayPartner\Model\MerchantCredential;
use Kechankrisna\PaywayPartner\Model\RegisterMerchantRequest;
use Kechankrisna\PaywayPartner\PaywayPartnerService;
use Kechankrisna\PaywayPartner\Version;
use Nyholm\Psr7\Factory\Psr17Factory;
use Nyholm\Psr7\Response;
use PHPUnit\Framework\TestCase;
use Psr\Clock\ClockInterface;
use Psr\Http\Client\ClientInterface;
use Psr\Http\Client\NetworkExceptionInterface;
use Psr\Http\Message\RequestInterface;
use Psr\Http\Message\ResponseInterface;
use Psr\Log\AbstractLogger;

/** Offline tests of the PHP specifics: injected HTTP, clock, logger, errors. */
final class UnitTest extends TestCase
{
    private static function notFound(): HttpResponse
    {
        return new HttpResponse(403, '{"status":{"code":"PTL46","message":"Merchant not found"}}');
    }

    public function testPostsJsonWithHeadersAndTheInjectedClock(): void
    {
        $http = Support::fakeHttp(static fn (): HttpResponse => new HttpResponse(
            200,
            '{"url":"https://payway.test/self-register","token":"t","status":{"code":"00","message":"Success!"}}',
        ));
        $clock = new class () implements ClockInterface {
            public function now(): \DateTimeImmutable
            {
                return new \DateTimeImmutable('2026-01-02T03:04:05Z');
            }
        };
        $service = new PaywayPartnerService(Support::partner(), $http, $clock);

        $response = $service->registerMerchant(new RegisterMerchantRequest('p', 'r', 'ref-001', 'USD'));

        self::assertTrue($response->isSuccess());
        $request = $http->requests[0];
        self::assertSame('https://payway.test' . PaywayPartnerService::REGISTER_MERCHANT_PATH, $request['url']);
        self::assertSame('application/json', $request['headers']['Content-Type']);
        self::assertSame('https://partner.test', $request['headers']['Referer']);
        self::assertSame('payway-partner-php/' . Version::SDK_VERSION, $request['headers']['User-Agent']);
        self::assertSame('20260102030405', $request['body']['request_time']);
    }

    public function testLogsToTheInjectedLogger(): void
    {
        $logger = new class () extends AbstractLogger {
            /** @var list<string> */
            public array $lines = [];

            public function log($level, string|\Stringable $message, array $context = []): void
            {
                $this->lines[] = (string) $message;
            }
        };
        $service = new PaywayPartnerService(
            Support::partner(),
            Support::fakeHttp(static fn (): HttpResponse => self::notFound()),
            logger: $logger,
        );

        $service->checkMerchant(new CheckMerchantRequest('a'));

        self::assertCount(2, $logger->lines);
        self::assertStringContainsString('POST https://payway.test', $logger->lines[0]);
        self::assertStringContainsString('403', $logger->lines[1]);
    }

    public function testPsr18NetworkErrorsAreRetryableConnectionErrors(): void
    {
        $client = new class () implements ClientInterface {
            public function sendRequest(RequestInterface $request): ResponseInterface
            {
                throw new class ('offline') extends \RuntimeException implements NetworkExceptionInterface {
                    public function getRequest(): RequestInterface
                    {
                        throw new \LogicException();
                    }
                };
            }
        };
        $factory = new Psr17Factory();
        $service = new PaywayPartnerService(Support::partner(), new Psr18HttpClient($client, $factory, $factory));

        try {
            $service->checkMerchant(new CheckMerchantRequest('a'));
            self::fail('expected an exception');
        } catch (PaywayPartnerException $e) {
            self::assertSame(ErrorType::Connection, $e->type);
            self::assertTrue($e->isRetryable());
            self::assertInstanceOf(NetworkExceptionInterface::class, $e->getPrevious());
        }
    }

    public function testPsr18ClientSendsTheRequest(): void
    {
        $client = new class () implements ClientInterface {
            public ?RequestInterface $request = null;

            public function sendRequest(RequestInterface $request): ResponseInterface
            {
                $this->request = $request;

                return new Response(403, [], '{"status":{"code":"PTL46","message":"Merchant not found"}}');
            }
        };
        $factory = new Psr17Factory();
        $service = new PaywayPartnerService(Support::partner(), new Psr18HttpClient($client, $factory, $factory));

        $response = $service->checkMerchant(new CheckMerchantRequest('a'));

        self::assertSame('PTL46', $response->status->code);
        self::assertNotNull($client->request);
        self::assertSame('POST', $client->request->getMethod());
        self::assertSame('https://partner.test', $client->request->getHeaderLine('Referer'));
    }

    public function testDecryptionErrorsAreTyped(): void
    {
        $service = new PaywayPartnerService(Support::partner());
        $foreign = (new OpenSslCrypto())->encryptJson(['a' => 1], Support::fixture('rsa_2048_public.pem'));

        foreach ([$foreign, '%%%'] as $data) {
            try {
                $service->decryptMerchantData($data);
                self::fail('expected an exception');
            } catch (PaywayPartnerException $e) {
                self::assertSame(ErrorType::Decryption, $e->type);
                self::assertNotNull($e->getPrevious());
            }
        }
    }

    public function testCryptoAcceptsEveryKeyFormat(): void
    {
        $crypto = new OpenSslCrypto();
        $pkcs1 = $crypto->encryptString('hello', Support::fixture('rsa_1024_public_pkcs1.pem'));
        self::assertSame('hello', $crypto->decryptString($pkcs1, Support::fixture('rsa_1024_private_pkcs8.pem')));

        $lines = array_filter(
            explode("\n", Support::fixture('rsa_1024_public.pem')),
            static fn (string $l): bool => $l !== '' && !str_starts_with($l, '-----'),
        );
        $bare = implode('', $lines);
        self::assertSame('hi', $crypto->decryptString($crypto->encryptString('hi', $bare), Support::partner()->partnerPrivateKey));
    }

    public function testSecretsAreHiddenFromDebugOutput(): void
    {
        $partner = Support::partner();
        $dump = print_r($partner, true);
        self::assertStringNotContainsString($partner->partnerKey, $dump);
        self::assertStringNotContainsString('PRIVATE KEY', $dump);

        $credential = new MerchantCredential('P', 'M', '1', 'mk', 'secret-public-key', 'r', 'USD', '');
        self::assertStringNotContainsString('secret-public-key', print_r($credential, true));
        self::assertNull($credential->toGetMcInfoRequest()->rsaPublicKey);
    }

    public function testVersionIsSemver(): void
    {
        self::assertMatchesRegularExpression('/^\d+\.\d+\.\d+$/', Version::SDK_VERSION);
    }
}
