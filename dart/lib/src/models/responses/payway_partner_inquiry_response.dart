import 'package:json_annotation/json_annotation.dart';

import '../json_converters.dart';
import 'payway_partner_status.dart';

part 'payway_partner_inquiry_response.g.dart';

/// Response of both merchant inquiries (`get-mc-credential-info` and
/// `get-mc-info`).
///
/// [data] is encrypted with the partner public key. Decrypt it with
/// `PaywayPartnerService.decryptMerchantCredential` (inquiry via register ref)
/// or `PaywayPartnerService.decryptMcInfo` (inquiry via public key).
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class PaywayPartnerInquiryResponse {
  /// encrypted merchant details, empty unless [isSuccess]
  @JsonKey(fromJson: stringFromJson)
  final String data;

  /// PayWay's `status` object
  final PaywayPartnerStatus status;

  /// Creates a [PaywayPartnerInquiryResponse].
  const PaywayPartnerInquiryResponse({
    required this.data,
    required this.status,
  });

  /// Whether PayWay answered `00` (success).
  bool get isSuccess => status.isSuccess;

  /// Parses PayWay JSON (snake_case keys).
  factory PaywayPartnerInquiryResponse.fromJson(Map<String, dynamic> json) =>
      _$PaywayPartnerInquiryResponseFromJson(json);

  /// JSON with PayWay's field names.
  Map<String, dynamic> toJson() => _$PaywayPartnerInquiryResponseToJson(this);

  @override
  String toString() =>
      'PaywayPartnerInquiryResponse(data: ${data.isEmpty ? '' : '<encrypted>'}, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywayPartnerInquiryResponse &&
          other.data == data &&
          other.status == status;

  @override
  int get hashCode => Object.hash(data, status);
}
