// Generates the shared conformance vectors in ../spec/test-vectors from the
// Dart reference implementation. Every SDK (Dart, Node, PHP) must pass them.
//
//   cd dart && dart run tool/generate_test_vectors.dart
//
// RSA PKCS#1 v1.5 encryption is randomized, so ciphertexts change on every
// run; only regenerate when a vector is added or changed, and commit the
// result.
import 'dart:convert';
import 'dart:io';

import 'package:payway_partner/payway_partner.dart';

const _fixtures = '../spec/fixtures';
const _out = '../spec/test-vectors';

String _fixture(String name) => File('$_fixtures/$name').readAsStringSync();

const _partnerId = 'test-partner-id';
const _partnerKey = 'test-partner-key';
const _requestTime = '20260102030405';

void main() {
  const crypto = PaywayPartnerCrypto();
  final partner = PaywayPartner(
    partnerName: 'Test Partner',
    partnerID: _partnerId,
    partnerKey: _partnerKey,
    partnerPrivateKey: _fixture('rsa_1024_private.pem'),
    partnerPublicKey: _fixture('rsa_1024_public.pem'),
    partnerReferer: 'https://partner.test',
    baseApiUrl: 'https://payway.test',
  );
  final builder = PaywayPartnerRequestBuilder(partner: partner);

  _write('partner.json', {
    'description': 'Partner used by the vectors; keys are in spec/fixtures.',
    'partner_id': _partnerId,
    'partner_key': _partnerKey,
    'public_key': 'rsa_1024_public.pem',
    'private_key': 'rsa_1024_private.pem',
    'referer': 'https://partner.test',
    'base_url': 'https://payway.test',
  });

  _write('request_time.json', {
    'description': 'request_time is the UTC time as YYYYMMDDHHmmss.',
    'cases': [
      for (final t in [
        DateTime.utc(2026, 1, 2, 3, 4, 5),
        DateTime.utc(2026, 12, 31, 23, 59, 59),
        DateTime.utc(2000, 2, 29, 0, 0, 0),
      ])
        {
          'utc': t.toIso8601String(),
          'expected': PaywayPartnerRequestBuilder.formatRequestTime(t),
        },
    ],
  });

  _write('hmac.json', {
    'description': 'Lowercase hex HMAC, like PHP hash_hmac().',
    'cases': [
      for (final (message, key) in [
        ('message', 'key'),
        ('test-partner-idabc20260102030405', _partnerKey),
        ('ហាងកាហ្វេ', 'ключ'),
      ]) ...[
        {
          'algorithm': 'sha256',
          'key': key,
          'message': message,
          'expected': crypto.hmacSha256(message, key),
        },
        {
          'algorithm': 'sha512',
          'key': key,
          'message': message,
          'expected': crypto.hmacSha512(message, key),
        },
      ],
    ],
  });

  _write('signing.json', {
    'description':
        'hash = hex HMAC-SHA256(partner_id + request_data + request_time, partner_key)',
    'cases': [
      for (final requestData in ['abc', 'Uyv+FcEc+QHD3UO/WYhBFH6l02Z0DVTN=='])
        {
          'partner_id': _partnerId,
          'partner_key': _partnerKey,
          'request_data': requestData,
          'request_time': _requestTime,
          'expected_hash': builder.hash(
            requestData: requestData,
            requestTime: _requestTime,
          ),
        },
    ],
  });

  const register = PaywayPartnerRegisterMerchant(
    pushbackUrl: 'https://partner.test/pushback',
    redirectUrl: 'https://partner.test',
    registerRef: 'ref-001',
    currency: 'USD',
  );
  const registerFull = PaywayPartnerRegisterMerchant(
    pushbackUrl: 'https://partner.test/pushback',
    redirectUrl: '{"ios_scheme":"app://done","android_scheme":"app://done"}',
    registerRef: 'ref_002',
    currency: 'KHR',
    type: 1,
    merchantType: 0,
  );
  final hashEncryptString = '${_partnerId}EC0002$_requestTime';
  _write('requests.json', {
    'description':
        'Signed request bodies. request_data is RSA-encrypted with a random '
        'padding, so decrypt it with the partner private key and compare '
        'with expected_payload. body_keys is the exact key order. For '
        'get_mc_info, decrypt rsa_public_key_hash_encrypt with '
        'rsa_2048_private.pem and compare with '
        'expected_rsa_public_key_hash.',
    'request_time': _requestTime,
    'cases': [
      {
        'name': 'register_merchant_minimal',
        'endpoint': PaywayPartnerService.registerMerchantPath,
        'input': {
          'pushback_url': register.pushbackUrl,
          'redirect_url': register.redirectUrl,
          'register_ref': register.registerRef,
          'currency': register.currency,
        },
        'body_keys': builder.registerMerchant(register).keys.toList(),
        'expected_extra': {'reference_id': 'ref-001'},
        'expected_payload': register.toJson(),
      },
      {
        'name': 'register_merchant_full',
        'endpoint': PaywayPartnerService.registerMerchantPath,
        'input': {
          'pushback_url': registerFull.pushbackUrl,
          'redirect_url': registerFull.redirectUrl,
          'register_ref': registerFull.registerRef,
          'currency': registerFull.currency,
          'type': registerFull.type,
          'merchant_type': registerFull.merchantType,
        },
        'body_keys': builder.registerMerchant(registerFull).keys.toList(),
        'expected_extra': {'reference_id': 'ref_002'},
        'expected_payload': registerFull.toJson(),
      },
      {
        'name': 'check_merchant',
        'endpoint': PaywayPartnerService.checkMerchantPath,
        'input': {'register_ref': 'ref-001'},
        'body_keys': builder
            .checkMerchant(const PaywayPartnerCheckMerchant(registerRef: 'x'))
            .keys
            .toList(),
        'expected_extra': <String, Object>{},
        'expected_payload': {'register_ref': 'ref-001'},
      },
      {
        'name': 'get_mc_info',
        'endpoint': PaywayPartnerService.getMcInfoPath,
        'input': {
          'merchant_key': 'EC0002',
          'currency': 'USD',
          'public_key': 'merchant-public-key',
          'rsa_public_key': 'rsa_2048_public.pem',
        },
        'body_keys': builder
            .getMcInfo(
              const PaywayPartnerGetMcInfoMerchant(
                merchantKey: 'EC0002',
                currency: 'USD',
                publicKey: 'p',
              ),
            )
            .keys
            .toList(),
        'expected_extra': <String, Object>{},
        'expected_payload': {
          'merchant_key': 'EC0002',
          'currency': 'USD',
          'public_key_hash_encrypt': crypto.hmacSha512(
            hashEncryptString,
            'merchant-public-key',
          ),
        },
        'expected_rsa_public_key_hash': hashEncryptString,
      },
    ],
  });

  final credential = {
    'partner_name': 'Test Partner',
    'merchant_name': 'Test Outlet',
    'mid': '000000000000001',
    'merchant_key': 'mk-1',
    'public_key': 'pk-1',
    'register_ref': 'ref-001',
    'currency': 'USD',
    'rsa_public_key': 'rsa-1',
  };
  final mcInfo = {
    'outlet_name': 'ហាងកាហ្វេ ' * 20,
    'aba_account_khr': '',
    'aba_account_usd': '000000001',
    'available_payment_methods': {'alipay': 'Alipay', 'wechat': 'WeChat Pay'},
    'enabled_payment_methods': {'abapay_khqr': 'ABA Pay KHQR'},
    'pending_payment_methods': <Object>[],
  };
  final pub1024 = _fixture('rsa_1024_public.pem');
  final pub2048 = _fixture('rsa_2048_public.pem');
  _write('decryption.json', {
    'description':
        'Decrypt ciphertext with private_key (from spec/fixtures); the result '
        'is the JSON in expected. pushback cases are full pushback bodies.',
    'cases': [
      {
        'name': 'merchant_credential',
        'private_key': 'rsa_1024_private.pem',
        'ciphertext': crypto.encryptJson(credential, pub1024),
        'expected': credential,
      },
      {
        'name': 'merchant_info_multi_block_khmer',
        'private_key': 'rsa_1024_private.pem',
        'ciphertext': crypto.encryptJson(mcInfo, pub1024),
        'expected': mcInfo,
      },
      {
        'name': 'key_2048',
        'private_key': 'rsa_2048_private.pem',
        'ciphertext': crypto.encryptJson(credential, pub2048),
        'expected': credential,
      },
      {
        'name': 'pkcs8_private_key',
        'private_key': 'rsa_1024_private_pkcs8.pem',
        'ciphertext': crypto.encryptJson(credential, pub1024),
        'expected': credential,
      },
    ],
    'pushback': [
      {
        'name': 'valid',
        'private_key': 'rsa_1024_private.pem',
        'body': json.encode({
          'return_params': crypto.encryptJson(credential, pub1024),
        }),
        'expected': credential,
      },
      {
        'name': 'missing_return_params',
        'private_key': 'rsa_1024_private.pem',
        'body': '{}',
        'expected_error': 'invalidPushback',
      },
      {
        'name': 'not_json',
        'private_key': 'rsa_1024_private.pem',
        'body': 'not json',
        'expected_error': 'invalidPushback',
      },
      {
        'name': 'wrong_key',
        'private_key': 'rsa_1024_private.pem',
        'body': json.encode({
          'return_params': crypto.encryptJson(credential, pub2048),
        }),
        'expected_error': 'decryption',
      },
    ],
  });

  _write('responses.json', {
    'description':
        'HTTP replies from PayWay and what the SDK returns. PayWay sends '
        'errors as non-2xx with a JSON status body, which is a normal '
        'response. expected.status uses PayWay field names; absent ids '
        'are omitted. Values documented as strings are read as strings.',
    'cases': [
      {
        'name': 'register_success',
        'endpoint': 'register_merchant',
        'http_status': 200,
        'body': {
          'url': ' https://payway.test/self-register?partner-token=t',
          'token': 't',
          'status': {'code': '00', 'message': 'Success!', 'tran_id': 'x-1'},
        },
        'expected': {
          'url': 'https://payway.test/self-register?partner-token=t',
          'token': 't',
          'is_success': true,
          'status': {'code': '00', 'message': 'Success!', 'tran_id': 'x-1'},
        },
      },
      {
        'name': 'inquiry_merchant_not_found_403',
        'endpoint': 'check_merchant',
        'http_status': 403,
        'body': {
          'status': {
            'code': 'PTL46',
            'message': 'Merchant not found',
            'tran_id': '1790695069292980',
          },
        },
        'expected': {
          'data': '',
          'is_success': false,
          'status': {
            'code': 'PTL46',
            'message': 'Merchant not found',
            'tran_id': '1790695069292980',
          },
        },
      },
      {
        'name': 'inquiry_wrong_hash_with_trace_ids',
        'endpoint': 'get_mc_info',
        'http_status': 403,
        'body': {
          'status': {
            'code': 'PTL02',
            'message': 'Wrong Hash',
            'trace_id': 't-1',
            'correlation_id': 'c-1',
          },
        },
        'expected': {
          'data': '',
          'is_success': false,
          'status': {
            'code': 'PTL02',
            'message': 'Wrong Hash',
            'trace_id': 't-1',
            'correlation_id': 'c-1',
          },
        },
      },
      {
        'name': 'numbers_read_as_strings',
        'endpoint': 'check_merchant',
        'http_status': 200,
        'body': {
          'data': 'abc',
          'status': {'code': 0, 'message': 'ok', 'tran_id': 12345},
        },
        'expected': {
          'data': 'abc',
          'is_success': false,
          'status': {'code': '0', 'message': 'ok', 'tran_id': '12345'},
        },
      },
      {
        'name': 'html_error_page_502',
        'endpoint': 'check_merchant',
        'http_status': 502,
        'raw_body': '<html>Bad Gateway</html>',
        'expected_error': {
          'type': 'unexpectedResponse',
          'status_code': 502,
          'retryable': true,
        },
      },
      {
        'name': 'json_without_status_200',
        'endpoint': 'check_merchant',
        'http_status': 200,
        'body': {'unexpected': true},
        'expected_error': {
          'type': 'unexpectedResponse',
          'status_code': 200,
          'retryable': false,
        },
      },
    ],
  });

  _write('merchant_info.json', {
    'description':
        'Decrypted get-mc-info data and the payment method maps the SDK '
        'returns. PHP encodes an empty map as [].',
    'cases': [
      {
        'name': 'empty_methods_as_list',
        'data': mcInfo,
        'expected': {
          'available_payment_methods': mcInfo['available_payment_methods'],
          'enabled_payment_methods': mcInfo['enabled_payment_methods'],
          'pending_payment_methods': <String, String>{},
        },
      },
    ],
  });

  _write('status_codes.json', {
    'description': 'Documented PayWay partner status codes.',
    'codes': {
      'success': PaywayPartnerStatusCode.success,
      'wrongHash': PaywayPartnerStatusCode.wrongHash,
      'parameterValidationRequired':
          PaywayPartnerStatusCode.parameterValidationRequired,
      'requestExpired': PaywayPartnerStatusCode.requestExpired,
      'merchantNotFound': PaywayPartnerStatusCode.merchantNotFound,
      'partnerIdNotFound': PaywayPartnerStatusCode.partnerIdNotFound,
      'redirectUrlEmpty': PaywayPartnerStatusCode.redirectUrlEmpty,
      'pushbackUrlEmpty': PaywayPartnerStatusCode.pushbackUrlEmpty,
      'registerRefAlreadyExists':
          PaywayPartnerStatusCode.registerRefAlreadyExists,
      'registerRefEmpty': PaywayPartnerStatusCode.registerRefEmpty,
      'registerRefInvalidFormat':
          PaywayPartnerStatusCode.registerRefInvalidFormat,
      'profileDeactivated': PaywayPartnerStatusCode.profileDeactivated,
      'invalidRequestData': PaywayPartnerStatusCode.invalidRequestData,
      'domainNotWhitelisted': PaywayPartnerStatusCode.domainNotWhitelisted,
    },
  });
}

void _write(String name, Map<String, Object?> content) {
  final file = File('$_out/$name')..createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(content)}\n',
  );
  stdout.writeln('wrote ${file.path}');
}
