import 'dart:convert';

import 'package:dio/dio.dart';

import '../exceptions.dart';
import '../models/payway_partner.dart';
import '../models/requests/payway_partner_check_merchant.dart';
import '../models/requests/payway_partner_get_mc_info_merchant.dart';
import '../models/requests/payway_partner_register_merchant.dart';
import '../models/responses/payway_partner_inquiry_response.dart';
import '../models/responses/payway_partner_merchant_credential.dart';
import '../models/responses/payway_partner_merchant_info.dart';
import '../models/responses/payway_partner_register_merchant_response.dart';
import 'payway_partner_crypto.dart';
import 'payway_partner_request_builder.dart';
import '../version.dart';

/// receives request/response log lines
typedef PaywayPartnerLogger = void Function(String message);

/// browsers do not allow setting `Referer` or `User-Agent`
const bool _kIsWeb =
    bool.fromEnvironment('dart.library.js_util') ||
    bool.fromEnvironment('dart.library.js_interop');

/// ABA PayWay partner API client.
///
/// ```dart
/// final service = PaywayPartnerService(partner: partner);
/// final response = await service.registerMerchant(merchant: request);
/// if (response.isSuccess) redirectTo(response.url);
/// ```
///
/// PayWay business errors (`PTL02 Wrong Hash`, `PTL46 Merchant not found`, ...)
/// are returned in `status`. A [PaywayPartnerException] is thrown only when
/// PayWay could not be reached, did not answer with a status, or data could
/// not be decrypted.
///
/// Run this on your server: [PaywayPartner.partnerKey] and
/// [PaywayPartner.partnerPrivateKey] are secrets, and browsers cannot send the
/// whitelisted `Referer` PayWay requires.
class PaywayPartnerService {
  /// version of this SDK, sent as `User-Agent: payway-partner-dart/<version>`
  static const String sdkVersion = packageVersion;

  /// endpoint of [registerMerchant]
  static const String registerMerchantPath =
      '/api/merchant-portal/online-self-activation/new-merchant';

  /// endpoint of [checkMerchant]
  static const String checkMerchantPath =
      '/api/merchant-portal/online-self-activation/get-mc-credential-info';

  /// endpoint of [getMcInfo]
  static const String getMcInfoPath =
      '/api/merchant-portal/online-self-activation/get-mc-info';

  /// partner credentials used to sign and decrypt
  final PaywayPartner partner;

  /// RSA/HMAC implementation
  final PaywayPartnerCrypto crypto;

  /// builds the signed request bodies; exposed to support new endpoints
  final PaywayPartnerRequestBuilder requestBuilder;
  final Dio _dio;
  final PaywayPartnerLogger? _logger;

  /// Creates a client for [partner].
  ///
  /// Every dependency except [partner] is optional and injectable:
  ///
  /// - `dio`: HTTP client, used as is (URLs and headers are set per request,
  ///   so it needs no base URL or interceptors) and reused for all calls
  /// - `clock`: source of `request_time` (default `DateTime.now`)
  /// - `crypto`: RSA/HMAC implementation
  /// - `logger`: receives request/response logs; nothing is logged without it
  PaywayPartnerService({
    required this.partner,
    Dio? dio,
    PaywayPartnerClock? clock,
    this.crypto = const PaywayPartnerCrypto(),
    PaywayPartnerLogger? logger,
  }) : requestBuilder = PaywayPartnerRequestBuilder(
         partner: partner,
         clock: clock,
         crypto: crypto,
       ),
       _dio = dio ?? createDio(),
       _logger = logger;

  /// default HTTP client: platform adapter with certificate validation
  static Dio createDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  /// ## [registerMerchant]
  ///
  /// register a merchant; redirect the merchant to the returned `url`, then
  /// wait for the pushback (see [decryptPushback])
  ///
  /// Every call accepts an optional [CancelToken] to abort it; a cancelled
  /// call throws [PaywayPartnerException].
  Future<PaywayPartnerRegisterMerchantResponse> registerMerchant({
    required PaywayPartnerRegisterMerchant merchant,
    CancelToken? cancelToken,
  }) {
    return _post(
      registerMerchantPath,
      requestBuilder.registerMerchant(merchant),
      PaywayPartnerRegisterMerchantResponse.fromJson,
      cancelToken,
    );
  }

  /// ## [checkMerchant]
  ///
  /// inquiry merchant info via register ref; decrypt the result with
  /// [decryptMerchantCredential]
  Future<PaywayPartnerInquiryResponse> checkMerchant({
    required PaywayPartnerCheckMerchant merchant,
    CancelToken? cancelToken,
  }) {
    return _post(
      checkMerchantPath,
      requestBuilder.checkMerchant(merchant),
      PaywayPartnerInquiryResponse.fromJson,
      cancelToken,
    );
  }

  /// ## [getMcInfo]
  ///
  /// inquiry merchant info via merchant public key; decrypt the result with
  /// [decryptMcInfo]
  Future<PaywayPartnerInquiryResponse> getMcInfo({
    required PaywayPartnerGetMcInfoMerchant merchant,
    CancelToken? cancelToken,
  }) {
    return _post(
      getMcInfoPath,
      requestBuilder.getMcInfo(merchant),
      PaywayPartnerInquiryResponse.fromJson,
      cancelToken,
    );
  }

  /// decrypt encrypted PayWay `data` with the partner private key.
  ///
  /// Throws [PaywayPartnerException] when [data] cannot be decrypted, e.g. it
  /// is corrupted or was encrypted for another partner key.
  Map<String, dynamic> decryptMerchantData(String data) {
    try {
      return crypto.decryptJson(data, partner.partnerPrivateKey);
    } on PaywayPartnerException {
      rethrow;
    } catch (error) {
      throw PaywayPartnerException(
        PaywayPartnerErrorType.decryption,
        'Could not decrypt PayWay data',
        cause: error,
      );
    }
  }

  /// decrypt the `data` of [checkMerchant]; see [decryptMerchantData]
  PaywayPartnerMerchantCredential decryptMerchantCredential(String data) {
    return PaywayPartnerMerchantCredential.fromJson(decryptMerchantData(data));
  }

  /// decrypt the `data` of [getMcInfo]; see [decryptMerchantData]
  PaywayPartnerMerchantInfo decryptMcInfo(String data) {
    return PaywayPartnerMerchantInfo.fromJson(decryptMerchantData(data));
  }

  /// ## [decryptPushback]
  ///
  /// decrypt the body PayWay POSTs (as `text/plain`) to your `pushback_url`
  /// once the merchant completes registration:
  /// `{"return_params": "<encrypted merchant details>"}`
  ///
  /// Throws [PaywayPartnerException] when the body is not a PayWay pushback
  /// or cannot be decrypted.
  ///
  /// ```dart
  /// final body = await utf8.decoder.bind(request).join();
  /// final credential = service.decryptPushback(body);
  /// // store credential.merchantKey, publicKey, rsaPublicKey securely
  /// ```
  PaywayPartnerMerchantCredential decryptPushback(String body) {
    Object? decoded;
    try {
      decoded = json.decode(body);
    } on FormatException catch (error) {
      throw PaywayPartnerException(
        PaywayPartnerErrorType.invalidPushback,
        'Pushback body is not JSON',
        cause: error,
      );
    }
    if (decoded is! Map || decoded['return_params'] is! String) {
      throw const PaywayPartnerException(
        PaywayPartnerErrorType.invalidPushback,
        'Pushback body has no "return_params"',
      );
    }
    return decryptMerchantCredential(decoded['return_params'] as String);
  }

  /// POST [body] to [path] and parse PayWay's reply.
  ///
  /// PayWay answers errors with a non-2xx status and a JSON body carrying the
  /// real status, which is parsed like a success.
  Future<T> _post<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic> map) parse,
    CancelToken? cancelToken,
  ) async {
    final uri = Uri.parse(partner.baseApiUrl).resolve(path);
    _logger?.call('[PayWay] POST $uri ${json.encode(body)}');

    Response<String> response;
    try {
      response = await _dio.postUri<String>(
        uri,
        data: json.encode(body),
        options: Options(headers: _headers, responseType: ResponseType.plain),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      final errorBody = error.response?.data;
      _logger?.call(
        '[PayWay] ${error.response?.statusCode ?? error.type.name} '
        '${errorBody ?? error.message}',
      );
      final map = _statusBody(errorBody);
      if (map != null) return parse(map);
      final (type, message) = _describe(error);
      throw PaywayPartnerException(
        type,
        message,
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }

    _logger?.call('[PayWay] ${response.statusCode} ${response.data}');
    final map = _statusBody(response.data);
    if (map != null) return parse(map);
    throw PaywayPartnerException(
      PaywayPartnerErrorType.unexpectedResponse,
      'Unexpected response from PayWay',
      statusCode: response.statusCode,
    );
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (!_kIsWeb) 'User-Agent': 'payway-partner-dart/$sdkVersion',
    if (!_kIsWeb && partner.partnerReferer.isNotEmpty)
      'Referer': partner.partnerReferer,
  };

  /// decode [body] when it is a JSON object with a PayWay `status`
  static Map<String, dynamic>? _statusBody(Object? body) {
    if (body is! String || body.isEmpty) return null;
    try {
      final map = json.decode(body);
      if (map is Map<String, dynamic> && map['status'] is Map) return map;
    } on FormatException {
      return null;
    }
    return null;
  }

  static (PaywayPartnerErrorType, String) _describe(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout => (
        PaywayPartnerErrorType.timeout,
        'Connection timeout with PayWay',
      ),
      DioExceptionType.sendTimeout => (
        PaywayPartnerErrorType.timeout,
        'Send timeout with PayWay',
      ),
      DioExceptionType.receiveTimeout => (
        PaywayPartnerErrorType.timeout,
        'Receive timeout with PayWay',
      ),
      DioExceptionType.badCertificate => (
        PaywayPartnerErrorType.badCertificate,
        'Bad certificate from PayWay',
      ),
      DioExceptionType.badResponse => (
        PaywayPartnerErrorType.unexpectedResponse,
        'Unexpected response from PayWay',
      ),
      DioExceptionType.cancel => (
        PaywayPartnerErrorType.cancelled,
        'Request to PayWay was cancelled',
      ),
      DioExceptionType.connectionError => (
        PaywayPartnerErrorType.connection,
        'Could not connect to PayWay',
      ),
      // unknown, and any type a newer dio adds
      _ => (
        PaywayPartnerErrorType.unknown,
        'Request to PayWay failed: ${error.message ?? error.error}',
      ),
    };
  }
}
