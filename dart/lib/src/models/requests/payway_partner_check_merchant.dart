import 'package:json_annotation/json_annotation.dart';

part 'payway_partner_check_merchant.g.dart';

/// Request of `get-mc-credential-info` (inquiry merchant info via register ref).
///
/// [toJson] is the `request_data` payload, with PayWay's field names.
@JsonSerializable(fieldRename: FieldRename.snake)
class PaywayPartnerCheckMerchant {
  /// the `registerRef` used when registering the merchant
  final String registerRef;

  /// Creates a [PaywayPartnerCheckMerchant].
  const PaywayPartnerCheckMerchant({required this.registerRef});

  /// Parses PayWay JSON (snake_case keys).
  factory PaywayPartnerCheckMerchant.fromJson(Map<String, dynamic> json) =>
      _$PaywayPartnerCheckMerchantFromJson(json);

  /// The `request_data` payload, with PayWay's field names.
  Map<String, dynamic> toJson() => _$PaywayPartnerCheckMerchantToJson(this);

  @override
  String toString() => 'PaywayPartnerCheckMerchant(registerRef: $registerRef)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywayPartnerCheckMerchant && other.registerRef == registerRef;

  @override
  int get hashCode => registerRef.hashCode;
}
