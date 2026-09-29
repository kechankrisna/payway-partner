// Runs the shared conformance vectors in ../spec/test-vectors, which every
// SDK in this repository must pass.
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:payway_partner/payway_partner.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

Map<String, dynamic> vectors(String name) =>
    json.decode(io.File('../spec/test-vectors/$name').readAsStringSync())
        as Map<String, dynamic>;

String fixture(String name) =>
    io.File('../spec/fixtures/$name').readAsStringSync();

List<Map<String, dynamic>> cases(
  Map<String, dynamic> file, [
  String key = 'cases',
]) => (file[key] as List<dynamic>).cast<Map<String, dynamic>>();

class _Reply implements HttpClientAdapter {
  _Reply(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(body, statusCode);

  @override
  void close({bool force = false}) {}
}

void main() {
  final partnerVector = vectors('partner.json');
  final partner = PaywayPartner(
    partnerName: 'Test Partner',
    partnerID: partnerVector['partner_id'] as String,
    partnerKey: partnerVector['partner_key'] as String,
    partnerPrivateKey: fixture(partnerVector['private_key'] as String),
    partnerPublicKey: fixture(partnerVector['public_key'] as String),
    partnerReferer: partnerVector['referer'] as String,
    baseApiUrl: partnerVector['base_url'] as String,
  );
  const crypto = PaywayPartnerCrypto();

  group('request_time', () {
    for (final c in cases(vectors('request_time.json'))) {
      test(c['utc'], () {
        expect(
          PaywayPartnerRequestBuilder.formatRequestTime(
            DateTime.parse(c['utc'] as String),
          ),
          c['expected'],
        );
      });
    }
  });

  group('hmac', () {
    for (final c in cases(vectors('hmac.json'))) {
      test('${c['algorithm']} ${c['message']}', () {
        final message = c['message'] as String;
        final key = c['key'] as String;
        expect(
          c['algorithm'] == 'sha256'
              ? crypto.hmacSha256(message, key)
              : crypto.hmacSha512(message, key),
          c['expected'],
        );
      });
    }
  });

  group('signing', () {
    for (final c in cases(vectors('signing.json'))) {
      test(c['request_data'], () {
        final builder = PaywayPartnerRequestBuilder(
          partner: partner.copyWith(
            partnerID: c['partner_id'] as String,
            partnerKey: c['partner_key'] as String,
          ),
        );
        expect(
          builder.hash(
            requestData: c['request_data'] as String,
            requestTime: c['request_time'] as String,
          ),
          c['expected_hash'],
        );
      });
    }
  });

  group('requests', () {
    final file = vectors('requests.json');
    final requestTime = file['request_time'] as String;
    final builder = PaywayPartnerRequestBuilder(partner: partner);

    for (final c in cases(file)) {
      test(c['name'], () {
        final input = c['input'] as Map<String, dynamic>;
        final body = switch (c['name'] as String) {
          'register_merchant_minimal' ||
          'register_merchant_full' => builder.registerMerchant(
            PaywayPartnerRegisterMerchant.fromJson(input),
            requestTime: requestTime,
          ),
          'check_merchant' => builder.checkMerchant(
            PaywayPartnerCheckMerchant.fromJson(input),
            requestTime: requestTime,
          ),
          'get_mc_info' => builder.getMcInfo(
            PaywayPartnerGetMcInfoMerchant(
              merchantKey: input['merchant_key'] as String,
              currency: input['currency'] as String,
              publicKey: input['public_key'] as String,
              rsaPublicKey: fixture(input['rsa_public_key'] as String),
            ),
            requestTime: requestTime,
          ),
          final name => throw StateError('unknown case $name'),
        };

        expect(body.keys.toList(), c['body_keys']);
        expect(body['request_time'], requestTime);
        expect(body['partner_id'], partner.partnerID);
        (c['expected_extra'] as Map<String, dynamic>).forEach(
          (key, value) => expect(body[key], value),
        );
        expect(
          body['hash'],
          crypto.hmacSha256(
            '${partner.partnerID}${body['request_data']}$requestTime',
            partner.partnerKey,
          ),
        );

        final payload = crypto.decryptJson(
          body['request_data'] as String,
          partner.partnerPrivateKey,
        );
        final rsaHash = payload.remove('rsa_public_key_hash_encrypt');
        expect(payload, c['expected_payload']);
        if (c['expected_rsa_public_key_hash'] != null) {
          expect(
            crypto.decryptString(
              rsaHash as String,
              fixture('rsa_2048_private.pem'),
            ),
            c['expected_rsa_public_key_hash'],
          );
        }
      });
    }
  });

  group('decryption', () {
    final file = vectors('decryption.json');
    for (final c in cases(file)) {
      test(c['name'], () {
        expect(
          crypto.decryptJson(
            c['ciphertext'] as String,
            fixture(c['private_key'] as String),
          ),
          c['expected'],
        );
      });
    }
    for (final c in cases(file, 'pushback')) {
      test('pushback ${c['name']}', () {
        final service = PaywayPartnerService(
          partner: partner.copyWith(
            partnerPrivateKey: fixture(c['private_key'] as String),
          ),
        );
        final body = c['body'] as String;
        if (c['expected_error'] != null) {
          expect(
            () => service.decryptPushback(body),
            throwsA(
              isA<PaywayPartnerException>().having(
                (e) => e.type.name,
                'type',
                c['expected_error'],
              ),
            ),
          );
        } else {
          expect(service.decryptPushback(body).toJson(), c['expected']);
        }
      });
    }
  });

  group('responses', () {
    for (final c in cases(vectors('responses.json'))) {
      test(c['name'], () async {
        final raw = c['raw_body'] as String? ?? json.encode(c['body']);
        final service = PaywayPartnerService(
          partner: partner,
          dio: Dio()..httpClientAdapter = _Reply(c['http_status'] as int, raw),
        );
        Future<Object> call() => switch (c['endpoint'] as String) {
          'register_merchant' => service.registerMerchant(
            merchant: const PaywayPartnerRegisterMerchant(
              pushbackUrl: 'p',
              redirectUrl: 'r',
              registerRef: 'x',
              currency: 'USD',
            ),
          ),
          'check_merchant' => service.checkMerchant(
            merchant: const PaywayPartnerCheckMerchant(registerRef: 'x'),
          ),
          'get_mc_info' => service.getMcInfo(
            merchant: const PaywayPartnerGetMcInfoMerchant(
              merchantKey: 'k',
              currency: 'USD',
              publicKey: 'p',
            ),
          ),
          final name => throw StateError('unknown endpoint $name'),
        };

        final error = c['expected_error'] as Map<String, dynamic>?;
        if (error != null) {
          await expectLater(
            call(),
            throwsA(
              isA<PaywayPartnerException>()
                  .having((e) => e.type.name, 'type', error['type'])
                  .having(
                    (e) => e.statusCode,
                    'statusCode',
                    error['status_code'],
                  )
                  .having(
                    (e) => e.isRetryable,
                    'isRetryable',
                    error['retryable'],
                  ),
            ),
          );
          return;
        }

        final expected = c['expected'] as Map<String, dynamic>;
        final response = await call();
        final (actual, isSuccess) = switch (response) {
          PaywayPartnerRegisterMerchantResponse r => (r.toJson(), r.isSuccess),
          PaywayPartnerInquiryResponse r => (r.toJson(), r.isSuccess),
          _ => throw StateError('unexpected $response'),
        };
        expect(isSuccess, expected['is_success']);
        expect(actual, {...expected}..remove('is_success'));
      });
    }
  });

  group('merchant_info', () {
    for (final c in cases(vectors('merchant_info.json'))) {
      test(c['name'], () {
        final info = PaywayPartnerMerchantInfo.fromJson(
          c['data'] as Map<String, dynamic>,
        );
        final expected = c['expected'] as Map<String, dynamic>;
        expect(
          info.availablePaymentMethods,
          expected['available_payment_methods'],
        );
        expect(info.enabledPaymentMethods, expected['enabled_payment_methods']);
        expect(info.pendingPaymentMethods, expected['pending_payment_methods']);
      });
    }
  });

  test('status codes', () {
    final codes = vectors('status_codes.json')['codes'] as Map<String, dynamic>;
    expect(codes['merchantNotFound'], PaywayPartnerStatusCode.merchantNotFound);
    expect(codes['wrongHash'], PaywayPartnerStatusCode.wrongHash);
    expect(codes, hasLength(14));
  });
}
