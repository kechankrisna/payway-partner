// Offline tests: no network, no ABA credentials. Keys in test/fixtures are
// throwaway keys generated for these tests only.
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:payway_partner/payway_partner.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

String fixture(String name) =>
    io.File('../spec/fixtures/$name').readAsStringSync();

/// answers every request with [handler] and records what was sent
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = requestStream == null
        ? <int>[]
        : await requestStream.expand((chunk) => chunk).toList();
    requests.add(options);
    bodies.add(json.decode(utf8.decode(bytes)) as Map<String, dynamic>);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, int statusCode) =>
    ResponseBody.fromString(
      json.encode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  final partner = PaywayPartner(
    partnerName: 'Test Partner',
    partnerID: 'test-partner-id',
    partnerKey: 'test-partner-key',
    partnerPrivateKey: fixture('rsa_1024_private.pem'),
    partnerPublicKey: fixture('rsa_1024_public.pem'),
    partnerReferer: 'https://partner.test',
    baseApiUrl: 'https://payway.test',
  );
  DateTime fixedClock() => DateTime.utc(2026, 1, 2, 3, 4, 5);
  const crypt = PaywayPartnerCrypto();

  PaywayPartnerService serviceWith(
    FakeAdapter adapter, {
    PaywayPartnerLogger? logger,
  }) => PaywayPartnerService(
    partner: partner,
    dio: Dio()..httpClientAdapter = adapter,
    clock: fixedClock,
    logger: logger,
  );

  const registerRequest = PaywayPartnerRegisterMerchant(
    pushbackUrl: 'https://partner.test/pushback',
    redirectUrl: 'https://partner.test',
    registerRef: 'ref-001',
    currency: 'USD',
  );
  const checkRequest = PaywayPartnerCheckMerchant(registerRef: 'ref-001');

  group('PaywayPartnerCrypto', () {
    for (final bits in [1024, 2048]) {
      test('round-trips long multi-byte text with a $bits bit key', () {
        final data = {'outlet_name': 'ហាងកាហ្វេ ' * 40, 'n': 1};
        final encrypted = crypt.encryptJson(
          data,
          fixture('rsa_${bits}_public.pem'),
        );

        expect(
          base64.decode(encrypted).length % (bits ~/ 8),
          0,
          reason: 'output is whole RSA blocks of the key size',
        );
        expect(
          crypt.decryptJson(encrypted, fixture('rsa_${bits}_private.pem')),
          data,
        );
      });
    }

    test('accepts a bare base64 public key', () {
      final bare = fixture(
        'rsa_1024_public.pem',
      ).split('\n').where((l) => l.isNotEmpty && !l.startsWith('-----')).join();
      final encrypted = crypt.encryptString('hello', bare);
      expect(
        crypt.decryptString(encrypted, partner.partnerPrivateKey),
        'hello',
      );
    });

    test('parses PKCS#8 private and PKCS#1 public keys', () {
      final encrypted = crypt.encryptString(
        'hello',
        fixture('rsa_1024_public_pkcs1.pem'),
      );
      expect(
        crypt.decryptString(encrypted, fixture('rsa_1024_private_pkcs8.pem')),
        'hello',
      );
    });

    test('rejects an invalid key', () {
      expect(
        () => crypt.encryptString('x', 'not a key'),
        throwsFormatException,
      );
      expect(() => crypt.decryptString('', 'not a key'), throwsFormatException);
    });

    test('rejects data that is not whole key-size blocks', () {
      expect(
        () => crypt.decryptString(
          base64.encode([1, 2, 3]),
          partner.partnerPrivateKey,
        ),
        throwsFormatException,
      );
    });

    test('HMAC matches PHP hash_hmac hex output', () {
      expect(
        crypt.hmacSha256('message', 'key'),
        crypto.Hmac(
          crypto.sha256,
          utf8.encode('key'),
        ).convert(utf8.encode('message')).toString(),
      );
    });
  });

  group('PaywayPartnerRequestBuilder', () {
    final builder = PaywayPartnerRequestBuilder(
      partner: partner,
      clock: fixedClock,
    );

    test('uses the injected clock in UTC YYYYMMDDHHmmss', () {
      expect(
        builder.checkMerchant(checkRequest)['request_time'],
        '20260102030405',
      );
    });

    test('formats local times as UTC', () {
      final local = DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal();
      expect(
        PaywayPartnerRequestBuilder.formatRequestTime(local),
        '20260102030405',
      );
    });

    test('register body is signed and carries reference_id', () {
      final body = builder.registerMerchant(registerRequest);

      expect(body.keys, [
        'request_time',
        'request_data',
        'partner_id',
        'reference_id',
        'hash',
      ]);
      expect(body['reference_id'], 'ref-001');
      expect(
        body['hash'],
        crypt.hmacSha256(
          'test-partner-id${body['request_data']}20260102030405',
          'test-partner-key',
        ),
      );
      expect(
        crypt.decryptJson(
          body['request_data'] as String,
          partner.partnerPrivateKey,
        ),
        {
          'pushback_url': 'https://partner.test/pushback',
          'redirect_url': 'https://partner.test',
          'type': 0,
          'register_ref': 'ref-001',
          'currency': 'USD',
        },
      );
    });

    test('get-mc-info payload follows the docs', () {
      final bareRsaKey = fixture(
        'rsa_2048_public.pem',
      ).split('\n').where((l) => l.isNotEmpty && !l.startsWith('-----')).join();
      final body = builder.getMcInfo(
        PaywayPartnerGetMcInfoMerchant(
          merchantKey: 'EC0002',
          currency: 'USD',
          publicKey: 'merchant-public-key',
          rsaPublicKey: bareRsaKey,
        ),
      );
      final payload = crypt.decryptJson(
        body['request_data'] as String,
        partner.partnerPrivateKey,
      );
      const hashEncryptString = 'test-partner-idEC000220260102030405';

      expect(payload['merchant_key'], 'EC0002');
      expect(payload['currency'], 'USD');
      expect(
        payload['public_key_hash_encrypt'],
        crypt.hmacSha512(hashEncryptString, 'merchant-public-key'),
      );
      expect(
        crypt.decryptString(
          payload['rsa_public_key_hash_encrypt'] as String,
          fixture('rsa_2048_private.pem'),
        ),
        hashEncryptString,
      );
    });

    test('rejects a malformed request time', () {
      expect(
        () => builder.checkMerchant(checkRequest, requestTime: '2026-01-02'),
        throwsArgumentError,
      );
    });
  });

  group('PaywayPartnerService with an injected Dio', () {
    test('posts JSON to the documented endpoint with headers', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'url': ' https://payway.test/self-register?partner-token=t',
          'token': 't',
          'status': {'code': '00', 'message': 'Success!', 'tran_id': 'x-1'},
        }, 200),
      );

      final response = await serviceWith(
        adapter,
      ).registerMerchant(merchant: registerRequest);

      expect(response.isSuccess, true);
      expect(response.status.tranId, 'x-1');
      expect(response.url, 'https://payway.test/self-register?partner-token=t');

      final request = adapter.requests.single;
      expect(
        request.uri.toString(),
        'https://payway.test${PaywayPartnerService.registerMerchantPath}',
      );
      expect(request.method, 'POST');
      expect(request.headers['Referer'], 'https://partner.test');
      expect(request.headers[Headers.contentTypeHeader], 'application/json');
      expect(
        request.headers['User-Agent'],
        'payway-partner-dart/${PaywayPartnerService.sdkVersion}',
      );
      expect(adapter.bodies.single['request_time'], '20260102030405');
    });

    test('a cancelled call throws PaywayPartnerException', () async {
      final adapter = FakeAdapter(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        ),
      );

      expect(
        serviceWith(
          adapter,
        ).checkMerchant(merchant: checkRequest, cancelToken: CancelToken()),
        throwsA(
          isA<PaywayPartnerException>()
              .having((e) => e.type, 'type', PaywayPartnerErrorType.cancelled)
              .having((e) => e.isRetryable, 'isRetryable', false),
        ),
      );
    });

    test('passes the cancel token to the HTTP client', () async {
      final token = CancelToken();
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'status': {'code': 'PTL46', 'message': 'x'},
        }, 403),
      );

      await serviceWith(
        adapter,
      ).checkMerchant(merchant: checkRequest, cancelToken: token);

      expect(adapter.requests.single.cancelToken, same(token));
    });

    test('data encrypted for another key throws PaywayPartnerException', () {
      final service = serviceWith(
        FakeAdapter((_) async => throw UnimplementedError()),
      );
      final foreign = crypt.encryptJson({
        'a': 1,
      }, fixture('rsa_2048_public.pem'));

      expect(
        () => service.decryptMerchantData(foreign),
        throwsA(
          isA<PaywayPartnerException>()
              .having((e) => e.type, 'type', PaywayPartnerErrorType.decryption)
              .having((e) => e.cause, 'cause', isNotNull),
        ),
      );
      expect(
        () => service.decryptMcInfo('%%%'),
        throwsA(isA<PaywayPartnerException>()),
      );
    });

    test('reuses the injected HTTP client across calls', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'status': {'code': 'PTL46', 'message': 'x'},
        }, 403),
      );
      final service = serviceWith(adapter);

      await service.checkMerchant(merchant: checkRequest);
      await service.checkMerchant(merchant: checkRequest);

      expect(adapter.requests, hasLength(2));
    });

    test('returns the PayWay status from a 403 error body', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'status': {'code': 'PTL02', 'message': 'Wrong Hash'},
        }, 403),
      );

      final response = await serviceWith(
        adapter,
      ).checkMerchant(merchant: checkRequest);

      expect(response.isSuccess, false);
      expect(response.status.code, 'PTL02');
      expect(response.status.message, 'Wrong Hash');
    });

    test('throws PaywayPartnerException on network failures', () async {
      final adapter = FakeAdapter(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        serviceWith(adapter).checkMerchant(merchant: checkRequest),
        throwsA(
          isA<PaywayPartnerException>()
              .having((e) => e.type, 'type', PaywayPartnerErrorType.connection)
              .having(
                (e) => e.message,
                'message',
                'Could not connect to PayWay',
              )
              .having((e) => e.isRetryable, 'isRetryable', true)
              .having((e) => e.cause, 'cause', isA<DioException>()),
        ),
      );
    });

    test('throws PaywayPartnerException on a body without status', () async {
      final adapter = FakeAdapter(
        (_) async => ResponseBody.fromString('<html>oops</html>', 502),
      );

      expect(
        serviceWith(adapter).checkMerchant(merchant: checkRequest),
        throwsA(
          isA<PaywayPartnerException>()
              .having(
                (e) => e.type,
                'type',
                PaywayPartnerErrorType.unexpectedResponse,
              )
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.isRetryable, 'isRetryable', true),
        ),
      );
    });

    test('sends logs to the injected logger only', () async {
      final lines = <String>[];
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'status': {'code': 'PTL46', 'message': 'x'},
        }, 403),
      );

      await serviceWith(
        adapter,
        logger: lines.add,
      ).checkMerchant(merchant: checkRequest);

      expect(lines, hasLength(2));
      expect(lines.first, contains('POST https://payway.test'));
      expect(lines.last, contains('403'));
    });

    test('decrypts a pushback sent with the partner public key', () {
      final service = serviceWith(
        FakeAdapter((_) async => throw UnimplementedError()),
      );
      final details = {
        'partner_name': 'Test Partner',
        'merchant_name': 'Test Outlet',
        'mid': '000000000000001',
        'merchant_key': 'mk-1',
        'public_key': 'pk-1',
        'register_ref': 'ref-001',
        'currency': 'USD',
        'rsa_public_key': 'rsa-1',
      };
      final body = json.encode({
        'return_params': crypt.encryptJson(details, partner.partnerPublicKey),
      });

      final credential = service.decryptPushback(body);
      expect(credential.toJson(), details);
      expect(credential.toGetMcInfoMerchant().merchantKey, 'mk-1');
      final invalidPushback = throwsA(
        isA<PaywayPartnerException>().having(
          (e) => e.type,
          'type',
          PaywayPartnerErrorType.invalidPushback,
        ),
      );
      expect(() => service.decryptPushback('{}'), invalidPushback);
      expect(() => service.decryptPushback('not json'), invalidPushback);
    });

    test('decrypts get-mc-info data, accepting [] for empty method lists', () {
      final service = serviceWith(
        FakeAdapter((_) async => throw UnimplementedError()),
      );
      final info = service.decryptMcInfo(
        crypt.encryptJson({
          'outlet_name': 'Test Outlet',
          'aba_account_khr': '',
          'aba_account_usd': '000000001',
          'available_payment_methods': {'alipay': 'Alipay'},
          'enabled_payment_methods': {'abapay_khqr': 'ABA Pay KHQR'},
          'pending_payment_methods': [],
        }, partner.partnerPublicKey),
      );

      expect(info.outletName, 'Test Outlet');
      expect(info.enabledPaymentMethods, {'abapay_khqr': 'ABA Pay KHQR'});
      expect(info.pendingPaymentMethods, isEmpty);
    });
  });

  group('JSON serialization', () {
    test('request models round-trip with PayWay field names', () {
      const register = PaywayPartnerRegisterMerchant(
        pushbackUrl: 'https://partner.test/pushback',
        redirectUrl: 'https://partner.test',
        registerRef: 'ref-001',
        currency: 'KHR',
        type: 1,
        merchantType: 0,
      );
      expect(register.toJson(), {
        'pushback_url': 'https://partner.test/pushback',
        'redirect_url': 'https://partner.test',
        'type': 1,
        'register_ref': 'ref-001',
        'merchant_type': 0,
        'currency': 'KHR',
      });
      expect(
        PaywayPartnerRegisterMerchant.fromJson(register.toJson()),
        register,
      );

      expect(checkRequest.toJson(), {'register_ref': 'ref-001'});
      expect(
        PaywayPartnerCheckMerchant.fromJson(checkRequest.toJson()),
        checkRequest,
      );

      const mcInfo = PaywayPartnerGetMcInfoMerchant(
        merchantKey: 'mk',
        currency: 'USD',
        publicKey: 'pk',
      );
      expect(mcInfo.toJson(), {
        'merchant_key': 'mk',
        'currency': 'USD',
        'public_key': 'pk',
      });
      expect(PaywayPartnerGetMcInfoMerchant.fromJson(mcInfo.toJson()), mcInfo);
    });

    test('register request omits merchant_type and defaults type', () {
      expect(registerRequest.toJson().containsKey('merchant_type'), false);
      expect(
        PaywayPartnerRegisterMerchant.fromJson({
          'pushback_url': 'p',
          'redirect_url': 'r',
          'register_ref': 'x',
          'currency': 'USD',
        }).type,
        0,
      );
    });

    test('status codes are named', () {
      final status = PaywayPartnerStatus.fromJson({
        'code': 'PTL46',
        'message': 'Merchant not found',
      });
      expect(status.code, PaywayPartnerStatusCode.merchantNotFound);
      expect(status.isSuccess, false);
      expect(
        PaywayPartnerStatus.fromJson({'code': '00', 'message': ''}).isSuccess,
        true,
      );
    });

    test('status reads non-string values and omits absent ids', () {
      final status = PaywayPartnerStatus.fromJson({
        'code': 0,
        'message': 'ok',
        'tran_id': 12345,
      });
      expect(status.code, '0');
      expect(status.tranId, '12345');
      expect(status.traceId, isNull);
      expect(status.toJson(), {
        'code': '0',
        'message': 'ok',
        'tran_id': '12345',
      });
    });

    test('responses parse PayWay samples and round-trip', () {
      final register = PaywayPartnerRegisterMerchantResponse.fromJson({
        'url': ' https://payway.test/self-register?partner-token=t',
        'token': 't',
        'status': {'code': '00', 'message': 'Success!', 'tran_id': 'x'},
      });
      expect(register.url, 'https://payway.test/self-register?partner-token=t');
      expect(
        PaywayPartnerRegisterMerchantResponse.fromJson(register.toJson()),
        register,
      );

      final error = PaywayPartnerInquiryResponse.fromJson({
        'status': {'code': 'PTL02', 'message': 'Wrong Hash'},
      });
      expect(error.data, isEmpty);
      expect(error.toJson(), {
        'data': '',
        'status': {'code': 'PTL02', 'message': 'Wrong Hash'},
      });
      expect(PaywayPartnerInquiryResponse.fromJson(error.toJson()), error);
    });

    test('merchant credential reads numbers as strings', () {
      final credential = PaywayPartnerMerchantCredential.fromJson({
        'partner_name': 'P',
        'merchant_name': 'M',
        'mid': 123456789012345,
        'merchant_key': 'mk',
        'public_key': 'pk',
        'register_ref': 'ref',
        'currency': 'USD',
      });
      expect(credential.mid, '123456789012345');
      expect(credential.rsaPublicKey, '');
      expect(
        PaywayPartnerMerchantCredential.fromJson(credential.toJson()),
        credential,
      );
    });

    test('partner config round-trips', () {
      expect(PaywayPartner.fromJson(partner.toJson()), partner);
      expect(partner.toJson().keys, contains('partnerID'));
    });
  });

  test('sdkVersion matches pubspec.yaml', () {
    final pubspec = io.File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: (\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(PaywayPartnerService.sdkVersion, version.group(1));
  });

  test('PaywayPartner.toString does not leak secrets', () {
    final text = partner.toString();
    expect(text, isNot(contains(partner.partnerKey)));
    expect(text, isNot(contains(partner.partnerPrivateKey)));
  });
}
