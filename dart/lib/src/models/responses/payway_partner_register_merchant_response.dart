import 'package:json_annotation/json_annotation.dart';

import '../json_converters.dart';
import 'payway_partner_status.dart';

part 'payway_partner_register_merchant_response.g.dart';

/// Response of `new-merchant`.
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class PaywayPartnerRegisterMerchantResponse {
  /// onboarding form: redirect the merchant here to complete registration.
  /// Trimmed, as the documented sample has a leading space.
  @JsonKey(fromJson: trimmedStringFromJson)
  final String url;

  /// unique token of this registration session
  @JsonKey(fromJson: stringFromJson)
  final String token;

  /// PayWay's `status` object
  final PaywayPartnerStatus status;

  /// Creates a [PaywayPartnerRegisterMerchantResponse].
  const PaywayPartnerRegisterMerchantResponse({
    required this.url,
    required this.token,
    required this.status,
  });

  /// Whether PayWay answered `00` (success).
  bool get isSuccess => status.isSuccess;

  /// Parses PayWay JSON (snake_case keys).
  factory PaywayPartnerRegisterMerchantResponse.fromJson(
    Map<String, dynamic> json,
  ) => _$PaywayPartnerRegisterMerchantResponseFromJson(json);

  /// JSON with PayWay's field names.
  Map<String, dynamic> toJson() =>
      _$PaywayPartnerRegisterMerchantResponseToJson(this);

  @override
  String toString() =>
      'PaywayPartnerRegisterMerchantResponse(url: $url, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywayPartnerRegisterMerchantResponse &&
          other.url == url &&
          other.token == token &&
          other.status == status;

  @override
  int get hashCode => Object.hash(url, token, status);
}
