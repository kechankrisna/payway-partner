import '../models/payway_partner.dart';
import '../models/requests/payway_partner_check_merchant.dart';
import '../models/requests/payway_partner_get_mc_info_merchant.dart';
import '../models/requests/payway_partner_register_merchant.dart';
import 'payway_partner_crypto.dart';

/// returns the current time; injectable so `request_time` can be tested
typedef PaywayPartnerClock = DateTime Function();

/// Builds the signed JSON bodies PayWay expects:
/// `request_time`, `partner_id`, `request_data` (RSA-encrypted payload) and
/// `hash` (HMAC-SHA256 of partner_id + request_data + request_time).
///
/// To support a new endpoint, build its body with [signedBody].
class PaywayPartnerRequestBuilder {
  /// partner credentials used to encrypt and sign
  final PaywayPartner partner;

  /// source of `request_time`
  final PaywayPartnerClock clock;

  /// RSA/HMAC implementation
  final PaywayPartnerCrypto crypto;

  /// Creates a builder for [partner]; [clock] defaults to `DateTime.now`.
  PaywayPartnerRequestBuilder({
    required this.partner,
    PaywayPartnerClock? clock,
    this.crypto = const PaywayPartnerCrypto(),
  }) : clock = clock ?? DateTime.now;

  /// body of `new-merchant`; `reference_id` mirrors `register_ref`
  Map<String, dynamic> registerMerchant(
    PaywayPartnerRegisterMerchant request, {
    String? requestTime,
  }) {
    return signedBody(
      request.toJson(),
      requestTime: requestTime,
      extra: {'reference_id': request.registerRef},
    );
  }

  /// body of `get-mc-credential-info`
  Map<String, dynamic> checkMerchant(
    PaywayPartnerCheckMerchant request, {
    String? requestTime,
  }) {
    return signedBody(request.toJson(), requestTime: requestTime);
  }

  /// body of `get-mc-info`. The payload holds `merchant_key`, `currency`,
  /// `public_key_hash_encrypt` (HMAC-SHA512 of partner_id + merchant_key +
  /// request_time, keyed with the merchant public key) and, when an RSA key
  /// is given, `rsa_public_key_hash_encrypt` (the same string RSA-encrypted).
  Map<String, dynamic> getMcInfo(
    PaywayPartnerGetMcInfoMerchant request, {
    String? requestTime,
  }) {
    final time = _requestTime(requestTime);
    final hashEncryptString = partner.partnerID + request.merchantKey + time;

    return signedBody({
      'merchant_key': request.merchantKey,
      'currency': request.currency,
      'public_key_hash_encrypt': crypto.hmacSha512(
        hashEncryptString,
        request.publicKey,
      ),
      if (request.rsaPublicKey != null)
        'rsa_public_key_hash_encrypt': crypto.encryptString(
          hashEncryptString,
          request.rsaPublicKey!,
        ),
    }, requestTime: time);
  }

  /// encrypt [payload] as `request_data` and sign it; [extra] fields are
  /// sent as is next to it
  Map<String, dynamic> signedBody(
    Map<String, dynamic> payload, {
    String? requestTime,
    Map<String, dynamic> extra = const {},
  }) {
    final time = _requestTime(requestTime);
    final requestData = crypto.encryptJson(payload, partner.partnerPublicKey);
    return {
      'request_time': time,
      'request_data': requestData,
      'partner_id': partner.partnerID,
      ...extra,
      'hash': hash(requestData: requestData, requestTime: time),
    };
  }

  /// HMAC-SHA256 of partner_id + request_data + request_time with the partner key
  String hash({required String requestData, required String requestTime}) {
    return crypto.hmacSha256(
      partner.partnerID + requestData + requestTime,
      partner.partnerKey,
    );
  }

  /// `YYYYMMDDHHmmss` in UTC, as the docs require
  static String formatRequestTime(DateTime time) {
    final utc = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
        '${two(utc.day)}${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  }

  String _requestTime(String? requestTime) {
    final time = requestTime ?? formatRequestTime(clock());
    if (!RegExp(r'^\d{14}$').hasMatch(time)) {
      throw ArgumentError.value(
        time,
        'requestTime',
        'must be 14 digits: YYYYMMDDHHmmss',
      );
    }
    return time;
  }
}
