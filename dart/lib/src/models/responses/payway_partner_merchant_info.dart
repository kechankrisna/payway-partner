import 'package:json_annotation/json_annotation.dart';

import '../json_converters.dart';

part 'payway_partner_merchant_info.g.dart';

/// Decrypted merchant info returned by the inquiry via public key.
///
/// Payment method maps are `code: label`, e.g. `{"abapay_khqr": "ABA Pay KHQR"}`.
@JsonSerializable(fieldRename: FieldRename.snake)
class PaywayPartnerMerchantInfo {
  /// outlet (merchant) name
  @JsonKey(fromJson: stringFromJson)
  final String outletName;

  /// ABA account receiving KHR payments, empty when none
  @JsonKey(fromJson: stringFromJson)
  final String abaAccountKhr;

  /// ABA account receiving USD payments, empty when none
  @JsonKey(fromJson: stringFromJson)
  final String abaAccountUsd;

  /// payment methods the merchant can apply for
  @JsonKey(fromJson: paymentMethodsFromJson)
  final Map<String, String> availablePaymentMethods;

  /// payment methods the merchant can accept now
  @JsonKey(fromJson: paymentMethodsFromJson)
  final Map<String, String> enabledPaymentMethods;

  /// payment methods awaiting approval
  @JsonKey(fromJson: paymentMethodsFromJson)
  final Map<String, String> pendingPaymentMethods;

  /// Creates a [PaywayPartnerMerchantInfo].
  const PaywayPartnerMerchantInfo({
    required this.outletName,
    required this.abaAccountKhr,
    required this.abaAccountUsd,
    this.availablePaymentMethods = const {},
    this.enabledPaymentMethods = const {},
    this.pendingPaymentMethods = const {},
  });

  /// Parses PayWay JSON (snake_case keys).
  factory PaywayPartnerMerchantInfo.fromJson(Map<String, dynamic> json) =>
      _$PaywayPartnerMerchantInfoFromJson(json);

  /// with PayWay's field names
  Map<String, dynamic> toJson() => _$PaywayPartnerMerchantInfoToJson(this);

  @override
  String toString() =>
      'PaywayPartnerMerchantInfo(outletName: $outletName, abaAccountKhr: $abaAccountKhr, abaAccountUsd: $abaAccountUsd, availablePaymentMethods: $availablePaymentMethods, enabledPaymentMethods: $enabledPaymentMethods, pendingPaymentMethods: $pendingPaymentMethods)';
}
