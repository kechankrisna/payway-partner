<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Tests;

use Kechankrisna\PaywayPartner\Crypto\OpenSslCrypto;
use Kechankrisna\PaywayPartner\Exception\PaywayPartnerException;
use Kechankrisna\PaywayPartner\Http\HttpResponse;
use Kechankrisna\PaywayPartner\Model\CheckMerchantRequest;
use Kechankrisna\PaywayPartner\Model\GetMcInfoRequest;
use Kechankrisna\PaywayPartner\Model\MerchantInfo;
use Kechankrisna\PaywayPartner\Model\RegisterMerchantRequest;
use Kechankrisna\PaywayPartner\PaywayPartnerService;
use Kechankrisna\PaywayPartner\RequestBuilder;
use Kechankrisna\PaywayPartner\StatusCode;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/**
 * Runs the shared conformance vectors in spec/test-vectors, which every SDK
 * in this repository must pass.
 */
final class VectorsTest extends TestCase
{
    /** @return iterable<string, array{array<string, mixed>}> */
    private static function casesOf(string $file, string $key = 'cases', string $name = 'name'): iterable
    {
        foreach (Support::cases(Support::vectors($file)[$key]) as $case) {
            yield Support::str($case[$name]) => [$case];
        }
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function requestTimeCases(): iterable
    {
        return self::casesOf('request_time.json', name: 'utc');
    }

    /** @param array<string, mixed> $c */
    #[DataProvider('requestTimeCases')]
    public function testRequestTime(array $c): void
    {
        self::assertSame(
            $c['expected'],
            RequestBuilder::formatRequestTime(new \DateTimeImmutable(Support::str($c['utc']))),
        );
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function hmacCases(): iterable
    {
        foreach (Support::cases(Support::vectors('hmac.json')['cases']) as $i => $case) {
            yield "{$i} " . Support::str($case['algorithm']) => [$case];
        }
    }

    /** @param array<string, mixed> $c */
    #[DataProvider('hmacCases')]
    public function testHmac(array $c): void
    {
        $crypto = new OpenSslCrypto();
        $message = Support::str($c['message']);
        $key = Support::str($c['key']);
        $actual = $c['algorithm'] === 'sha256' ? $crypto->hmacSha256($message, $key) : $crypto->hmacSha512($message, $key);
        self::assertSame($c['expected'], $actual);
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function signingCases(): iterable
    {
        return self::casesOf('signing.json', name: 'request_data');
    }

    /** @param array<string, mixed> $c */
    #[DataProvider('signingCases')]
    public function testSigning(array $c): void
    {
        $partner = Support::partner()->with(
            partnerId: Support::str($c['partner_id']),
            partnerKey: Support::str($c['partner_key']),
        );
        self::assertSame(
            $c['expected_hash'],
            (new RequestBuilder($partner))->hash(Support::str($c['request_data']), Support::str($c['request_time'])),
        );
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function requestCases(): iterable
    {
        return self::casesOf('requests.json');
    }

    /** @param array<string, mixed> $c */
    #[DataProvider('requestCases')]
    public function testRequests(array $c): void
    {
        $partner = Support::partner();
        $crypto = new OpenSslCrypto();
        $builder = new RequestBuilder($partner);
        $time = Support::str(Support::vectors('requests.json')['request_time']);
        /** @var array<string, mixed> $i */
        $i = $c['input'];

        $body = match ($c['name']) {
            'register_merchant_minimal', 'register_merchant_full' => $builder->registerMerchant(new RegisterMerchantRequest(
                Support::str($i['pushback_url']),
                Support::str($i['redirect_url']),
                Support::str($i['register_ref']),
                $i['currency'] === 'KHR' ? 'KHR' : 'USD',
                ($i['type'] ?? 0) === 1 ? 1 : 0,
                match ($i['merchant_type'] ?? null) {
                    0 => 0,
                    1 => 1,
                    default => null,
                },
            ), $time),
            'check_merchant' => $builder->checkMerchant(new CheckMerchantRequest(Support::str($i['register_ref'])), $time),
            'get_mc_info' => $builder->getMcInfo(new GetMcInfoRequest(
                Support::str($i['merchant_key']),
                Support::str($i['currency']),
                Support::str($i['public_key']),
                Support::fixture(Support::str($i['rsa_public_key'])),
            ), $time),
            default => self::fail('unknown case'),
        };

        self::assertSame($c['body_keys'], array_keys($body));
        self::assertSame($time, $body['request_time']);
        self::assertSame($partner->partnerId, $body['partner_id']);
        \assert(\is_array($c['expected_extra']));
        foreach ($c['expected_extra'] as $key => $value) {
            self::assertSame($value, $body[$key]);
        }
        self::assertSame(
            $crypto->hmacSha256($partner->partnerId . $body['request_data'] . $time, $partner->partnerKey),
            $body['hash'],
        );

        $payload = $crypto->decryptJson($body['request_data'], $partner->partnerPrivateKey);
        $rsaHash = $payload['rsa_public_key_hash_encrypt'] ?? null;
        unset($payload['rsa_public_key_hash_encrypt']);
        self::assertSame($c['expected_payload'], $payload, 'payload and key order');
        if (isset($c['expected_rsa_public_key_hash'])) {
            self::assertSame(
                $c['expected_rsa_public_key_hash'],
                $crypto->decryptString(Support::str($rsaHash), Support::fixture('rsa_2048_private.pem')),
            );
        }
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function decryptionCases(): iterable
    {
        return self::casesOf('decryption.json');
    }

    /** @param array<string, mixed> $c */
    #[DataProvider('decryptionCases')]
    public function testDecryption(array $c): void
    {
        self::assertSame(
            $c['expected'],
            (new OpenSslCrypto())->decryptJson(Support::str($c['ciphertext']), Support::fixture(Support::str($c['private_key']))),
        );
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function pushbackCases(): iterable
    {
        return self::casesOf('decryption.json', 'pushback');
    }

    /** @param array<string, mixed> $c */
    #[DataProvider('pushbackCases')]
    public function testPushback(array $c): void
    {
        $service = new PaywayPartnerService(
            Support::partner()->with(partnerPrivateKey: Support::fixture(Support::str($c['private_key']))),
        );
        if (isset($c['expected_error'])) {
            try {
                $service->decryptPushback(Support::str($c['body']));
                self::fail('expected an exception');
            } catch (PaywayPartnerException $e) {
                self::assertSame($c['expected_error'], $e->type->value);
            }

            return;
        }
        self::assertSame($c['expected'], $service->decryptPushback(Support::str($c['body']))->toArray());
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function responseCases(): iterable
    {
        return self::casesOf('responses.json');
    }

    /** @param array<string, mixed> $c */
    #[DataProvider('responseCases')]
    public function testResponses(array $c): void
    {
        $raw = isset($c['raw_body']) ? Support::str($c['raw_body']) : json_encode($c['body'], JSON_THROW_ON_ERROR);
        \assert(\is_int($c['http_status']));
        $status = $c['http_status'];
        $service = new PaywayPartnerService(
            Support::partner(),
            Support::fakeHttp(static fn(): HttpResponse => new HttpResponse($status, $raw)),
        );
        $call = static fn() => match ($c['endpoint']) {
            'register_merchant' => $service->registerMerchant(new RegisterMerchantRequest('p', 'r', 'x', 'USD')),
            'check_merchant' => $service->checkMerchant(new CheckMerchantRequest('x')),
            'get_mc_info' => $service->getMcInfo(new GetMcInfoRequest('k', 'USD', 'p')),
            default => throw new \LogicException('unknown endpoint'),
        };

        if (isset($c['expected_error'])) {
            /** @var array{type: string, status_code: int, retryable: bool} $error */
            $error = $c['expected_error'];
            try {
                $call();
                self::fail('expected an exception');
            } catch (PaywayPartnerException $e) {
                self::assertSame($error['type'], $e->type->value);
                self::assertSame($error['status_code'], $e->statusCode);
                self::assertSame($error['retryable'], $e->isRetryable());
            }

            return;
        }

        /** @var array<string, mixed> $expected */
        $expected = $c['expected'];
        $response = $call();
        self::assertSame($expected['is_success'], $response->isSuccess());
        unset($expected['is_success']);
        self::assertEquals($expected, $response->toArray());
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function merchantInfoCases(): iterable
    {
        return self::casesOf('merchant_info.json');
    }

    /** @param array<string, mixed> $c */
    #[DataProvider('merchantInfoCases')]
    public function testMerchantInfo(array $c): void
    {
        \assert(\is_array($c['data']) && \is_array($c['expected']));
        $info = MerchantInfo::fromArray($c['data']);
        self::assertSame($c['expected']['available_payment_methods'], $info->availablePaymentMethods);
        self::assertSame($c['expected']['enabled_payment_methods'], $info->enabledPaymentMethods);
        self::assertEquals($c['expected']['pending_payment_methods'], $info->pendingPaymentMethods);
    }

    public function testStatusCodes(): void
    {
        $codes = Support::vectors('status_codes.json')['codes'];
        \assert(\is_array($codes));
        $constants = (new \ReflectionClass(StatusCode::class))->getConstants();
        $expected = [];
        foreach ($codes as $name => $code) {
            $constant = strtoupper((string) preg_replace('/[A-Z]/', '_$0', Support::str($name)));
            $expected[$constant] = $code;
        }
        self::assertSame($expected, $constants);
    }
}
