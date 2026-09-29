<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Tests;

use Kechankrisna\PaywayPartner\Model\CheckMerchantRequest;
use Kechankrisna\PaywayPartner\Model\GetMcInfoRequest;
use Kechankrisna\PaywayPartner\Model\RegisterMerchantRequest;
use Kechankrisna\PaywayPartner\PaywayPartner;
use Kechankrisna\PaywayPartner\PaywayPartnerService;
use Kechankrisna\PaywayPartner\StatusCode;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\TestCase;

/**
 * Integration tests against the ABA PayWay sandbox. They need the sandbox
 * credentials in the repository's .env (see .env.example) and are skipped
 * without it. Run only the offline tests with `composer test:unit`.
 */
#[Group('integration')]
final class IntegrationTest extends TestCase
{
    private const string ENV_FILE = __DIR__ . '/../../.env';

    private static function service(): PaywayPartnerService
    {
        if (!is_file(self::ENV_FILE)) {
            self::markTestSkipped('no .env with ABA sandbox credentials');
        }
        $env = parse_ini_file(self::ENV_FILE, false, INI_SCANNER_RAW) ?: [];
        $get = static fn (string $key): string => \is_string($env[$key] ?? null) ? $env[$key] : '';
        $pem = static fn (string $key): string => (string) base64_decode($get($key), true);

        return new PaywayPartnerService(new PaywayPartner(
            $get('ABA_PARTNER_NAME'),
            $get('ABA_PARTNER_ID'),
            $get('ABA_PARTNER_KEY'),
            $pem('ABA_PARTNER_PRIVATE_KEY'),
            $pem('ABA_PARTNER_PUBLIC_KEY'),
            $get('ABA_PARTNER_REFERER_DOMAIN'),
            $get('ABA_PARTNER_API_URL') ?: PaywayPartner::SANDBOX_URL,
        ));
    }

    public function testRegisterMerchantReturnsTheOnboardingUrl(): void
    {
        $response = self::service()->registerMerchant(new RegisterMerchantRequest(
            'https://www.mylekha.org/api/v1.0/integrate/payway/success?register_ref=mylekha003',
            'https://www.mylekha.org',
            'mylekha003',
            'USD',
            type: 1,
            merchantType: 1,
        ));

        self::assertTrue($response->isSuccess(), json_encode($response->status->toArray(), JSON_THROW_ON_ERROR));
        self::assertStringStartsWith('https://', $response->url);
        self::assertNotSame('', $response->token);
    }

    public function testInquiryViaRegisterRefOfAnUnfinishedRegistration(): void
    {
        $response = self::service()->checkMerchant(new CheckMerchantRequest('mylekha003'));

        self::assertSame(StatusCode::MERCHANT_NOT_FOUND, $response->status->code);
        self::assertSame('', $response->data);
    }

    public function testInquiryViaPublicKeyOfAnUnknownMerchant(): void
    {
        $response = self::service()->getMcInfo(new GetMcInfoRequest('UNKNOWN000', 'USD', 'not-a-real-key'));

        self::assertFalse($response->isSuccess());
        self::assertNotNull($response->status->traceId);
    }

    public function testAWrongPartnerKeyIsReportedAsWrongHash(): void
    {
        $service = self::service();
        $wrongKey = new PaywayPartnerService($service->partner->with(partnerKey: 'wrong-key'));

        $response = $wrongKey->checkMerchant(new CheckMerchantRequest('mylekha003'));

        self::assertSame(StatusCode::WRONG_HASH, $response->status->code);
    }
}
