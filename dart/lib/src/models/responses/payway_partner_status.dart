import 'package:json_annotation/json_annotation.dart';

import '../json_converters.dart';

part 'payway_partner_status.g.dart';

/// Status codes documented for the PayWay partner API, for comparing with
/// [PaywayPartnerStatus.code]:
///
/// ```dart
/// if (response.status.code == PaywayPartnerStatusCode.merchantNotFound) ...
/// ```
abstract final class PaywayPartnerStatusCode {
  /// `00` Success!
  static const String success = '00';

  /// `PTL02` Wrong Hash
  static const String wrongHash = 'PTL02';

  /// `PTL04` Parameter Validation Required
  static const String parameterValidationRequired = 'PTL04';

  /// `PTL06` The Request is Expired
  static const String requestExpired = 'PTL06';

  /// `PTL46` Merchant not found
  static const String merchantNotFound = 'PTL46';

  /// `PTL137` Partner id not found
  static const String partnerIdNotFound = 'PTL137';

  /// `PTL141` The redirect url can not empty
  static const String redirectUrlEmpty = 'PTL141';

  /// `PTL142` The pushback url can not empty
  static const String pushbackUrlEmpty = 'PTL142';

  /// `PTL164` The register ref is already exist
  static const String registerRefAlreadyExists = 'PTL164';

  /// `PTL165` The register ref can not empty
  static const String registerRefEmpty = 'PTL165';

  /// `PTL166` The register ref is invalid format
  /// (letters and numbers with `_` or `-` only)
  static const String registerRefInvalidFormat = 'PTL166';

  /// `PTL170` Your profile is deactivated
  static const String profileDeactivated = 'PTL170';

  /// `PTL171` Invalid request data: check the key and the encryption method
  static const String invalidRequestData = 'PTL171';

  /// `PTL175` Requested Domain is not in whitelist
  static const String domainNotWhitelisted = 'PTL175';
}

/// The `status` object of every PayWay partner response.
/// See [PaywayPartnerStatusCode] for the documented codes.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class PaywayPartnerStatus {
  /// status code, `00` on success; see [PaywayPartnerStatusCode]
  @JsonKey(fromJson: stringFromJson)
  final String code;

  /// human readable status message from PayWay
  @JsonKey(fromJson: stringFromJson)
  final String message;

  /// transaction id (register and inquiry via register ref)
  @JsonKey(fromJson: nullableStringFromJson)
  final String? tranId;

  /// PayWay log id for debugging (inquiry via public key)
  @JsonKey(fromJson: nullableStringFromJson)
  final String? traceId;

  /// PayWay correlation id for debugging (inquiry via public key)
  @JsonKey(fromJson: nullableStringFromJson)
  final String? correlationId;

  /// Creates a [PaywayPartnerStatus].
  const PaywayPartnerStatus({
    required this.code,
    required this.message,
    this.tranId,
    this.traceId,
    this.correlationId,
  });

  /// Whether PayWay answered `00` (success).
  bool get isSuccess => code == PaywayPartnerStatusCode.success;

  /// Parses PayWay JSON (snake_case keys).
  factory PaywayPartnerStatus.fromJson(Map<String, dynamic> json) =>
      _$PaywayPartnerStatusFromJson(json);

  /// JSON with PayWay's field names; absent ids are left out.
  Map<String, dynamic> toJson() => _$PaywayPartnerStatusToJson(this);

  @override
  String toString() =>
      'PaywayPartnerStatus(code: $code, message: $message, tranId: $tranId, traceId: $traceId, correlationId: $correlationId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywayPartnerStatus &&
          other.code == code &&
          other.message == message &&
          other.tranId == tranId &&
          other.traceId == traceId &&
          other.correlationId == correlationId;

  @override
  int get hashCode =>
      Object.hash(code, message, tranId, traceId, correlationId);
}
