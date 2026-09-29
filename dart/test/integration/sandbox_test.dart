// Integration tests against the ABA PayWay sandbox. They need a `.env` with
// sandbox partner credentials at the repository root (see ../.env.example)
// and are skipped without one.
// Run only the offline tests with: dart test -x integration
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:payway_partner/payway_partner.dart';
import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';

void main() {
  final hasSandboxEnv = io.File('../.env').existsSync();

  group(
    'ABA PayWay sandbox',
    skip: hasSandboxEnv ? false : 'no .env with ABA sandbox credentials',
    () {
      late PaywayPartnerService service;

      setUpAll(() {
        io.HttpOverrides.global = null;
        final env = DotEnv(includePlatformEnvironment: true)..load(['../.env']);
        String pem(String key) => utf8.decode(base64.decode(env[key] ?? ''));

        service = PaywayPartnerService(
          partner: PaywayPartner(
            partnerName: env['ABA_PARTNER_NAME'] ?? '',
            partnerID: env['ABA_PARTNER_ID'] ?? '',
            partnerKey: env['ABA_PARTNER_KEY'] ?? '',
            partnerPrivateKey: pem('ABA_PARTNER_PRIVATE_KEY'),
            partnerPublicKey: pem('ABA_PARTNER_PUBLIC_KEY'),
            partnerReferer: env['ABA_PARTNER_REFERER_DOMAIN'] ?? '',
            baseApiUrl:
                env['ABA_PARTNER_API_URL'] ?? PaywayPartner.sandboxBaseUrl,
          ),
          logger: print,
        );
      });

      test('register a merchant returns the onboarding url', () async {
        final response = await service.registerMerchant(
          merchant: const PaywayPartnerRegisterMerchant(
            pushbackUrl:
                'https://www.mylekha.org/api/v1.0/integrate/payway/success?register_ref=mylekha003',
            redirectUrl: 'https://www.mylekha.org',
            type: 1,
            registerRef: 'mylekha003',
            merchantType: 1,
            currency: 'USD',
          ),
        );

        expect(response.isSuccess, true, reason: '${response.status}');
        expect(response.url, startsWith('https://'));
        expect(response.token, isNotEmpty);
        expect(response.status.tranId, isNotEmpty);
      });

      test('inquiry via register ref of an unfinished registration', () async {
        final response = await service.checkMerchant(
          merchant: const PaywayPartnerCheckMerchant(registerRef: 'mylekha003'),
        );

        expect(
          response.status.code,
          PaywayPartnerStatusCode.merchantNotFound,
          reason: 'the merchant has not completed registration yet',
        );
        expect(response.status.message, 'Merchant not found');
        expect(response.data, isEmpty);
      });

      test('inquiry via public key of an unknown merchant', () async {
        final response = await service.getMcInfo(
          merchant: const PaywayPartnerGetMcInfoMerchant(
            merchantKey: 'UNKNOWN000',
            currency: 'USD',
            publicKey: 'not-a-real-key',
          ),
        );

        expect(response.isSuccess, false);
        expect(response.status.code, isNotEmpty);
        expect(response.status.traceId, isNotEmpty);
      });

      test('a wrong partner key is reported as PTL02', () async {
        final wrongKey = PaywayPartnerService(
          partner: service.partner.copyWith(partnerKey: 'wrong-key'),
        );

        final response = await wrongKey.checkMerchant(
          merchant: const PaywayPartnerCheckMerchant(registerRef: 'mylekha003'),
        );

        expect(response.status.code, PaywayPartnerStatusCode.wrongHash);
      });
    },
  );
}
