/// What went wrong in a [PaywayPartnerException].
enum PaywayPartnerErrorType {
  /// PayWay could not be reached (DNS, refused connection, offline, ...)
  connection,

  /// connecting, sending or receiving took longer than the configured timeout
  timeout,

  /// the call was cancelled with its `CancelToken`
  cancelled,

  /// PayWay's TLS certificate was rejected
  badCertificate,

  /// PayWay answered without a PayWay `status` (e.g. an HTML error page)
  unexpectedResponse,

  /// PayWay data could not be decrypted with the partner private key
  decryption,

  /// a pushback body is not `{"return_params": "..."}`
  invalidPushback,

  /// any other failure; see [PaywayPartnerException.cause]
  unknown,
}

/// Thrown when PayWay could not be reached, did not answer with a PayWay
/// status, or its data could not be decrypted. Branch on [type].
///
/// Business errors such as `PTL02 Wrong Hash` or `PTL46 Merchant not found`
/// are not thrown: they are returned in the response `status`.
class PaywayPartnerException implements Exception {
  /// what went wrong
  final PaywayPartnerErrorType type;

  /// human readable description, for logs
  final String message;

  /// HTTP status code, when a response was received
  final int? statusCode;

  /// the underlying error, e.g. a `DioException` or `FormatException`
  final Object? cause;

  /// Creates an exception of [type] described by [message].
  const PaywayPartnerException(
    this.type,
    this.message, {
    this.statusCode,
    this.cause,
  });

  /// whether retrying the same call later may succeed
  bool get isRetryable =>
      type == PaywayPartnerErrorType.connection ||
      type == PaywayPartnerErrorType.timeout ||
      (type == PaywayPartnerErrorType.unexpectedResponse &&
          (statusCode ?? 0) >= 500);

  @override
  String toString() => statusCode == null
      ? 'PaywayPartnerException(${type.name}): $message'
      : 'PaywayPartnerException(${type.name}): $message (HTTP $statusCode)';
}
