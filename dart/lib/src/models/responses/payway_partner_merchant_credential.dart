import 'package:json_annotation/json_annotation.dart';

import '../json_converters.dart';
import '../requests/payway_partner_get_mc_info_merchant.dart';

part 'payway_partner_merchant_credential.g.dart';

/// Decrypted merchant details, sent by PayWay to your `pushback_url`
/// (as `return_params`) and returned by the inquiry via register ref.
///
/// Store these securely: they are required to initiate transactions.
@JsonSerializable(fieldRename: FieldRename.snake)
class PaywayPartnerMerchantCredential {
  /// your official partner name registered in PayWay
  @JsonKey(fromJson: stringFromJson)
  final String partnerName;

  /// outlet name
  @JsonKey(fromJson: stringFromJson)
  final String merchantName;

  /// MID representing the outlet
  @JsonKey(fromJson: stringFromJson)
  final String mid;

  /// `merchant_id` used for purchase, refund and other merchant APIs
  @JsonKey(fromJson: stringFromJson)
  final String merchantKey;

  /// merchant public key (secret)
  @JsonKey(fromJson: stringFromJson)
  final String publicKey;

  /// your register reference id
  @JsonKey(fromJson: stringFromJson)
  final String registerRef;

  /// merchant currency code: `USD`, `KHR` or both
  @JsonKey(fromJson: stringFromJson)
  final String currency;

  /// merchant RSA public key
  @JsonKey(fromJson: stringFromJson)
  final String rsaPublicKey;

  /// Creates a [PaywayPartnerMerchantCredential].
  const PaywayPartnerMerchantCredential({
    required this.partnerName,
    required this.merchantName,
    required this.mid,
    required this.merchantKey,
    required this.publicKey,
    required this.registerRef,
    required this.currency,
    required this.rsaPublicKey,
  });

  /// Parses PayWay JSON (snake_case keys).
  factory PaywayPartnerMerchantCredential.fromJson(Map<String, dynamic> json) =>
      _$PaywayPartnerMerchantCredentialFromJson(json);

  /// with PayWay's field names; contains the merchant keys
  Map<String, dynamic> toJson() =>
      _$PaywayPartnerMerchantCredentialToJson(this);

  /// build the request of the inquiry via public key from these credentials
  PaywayPartnerGetMcInfoMerchant toGetMcInfoMerchant({String? currency}) {
    return PaywayPartnerGetMcInfoMerchant(
      merchantKey: merchantKey,
      currency: currency ?? this.currency,
      publicKey: publicKey,
      rsaPublicKey: rsaPublicKey.isEmpty ? null : rsaPublicKey,
    );
  }

  /// keys are left out on purpose so they don't end up in logs
  @override
  String toString() =>
      'PaywayPartnerMerchantCredential(merchantName: $merchantName, mid: $mid, merchantKey: $merchantKey, registerRef: $registerRef, currency: $currency)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywayPartnerMerchantCredential &&
          other.partnerName == partnerName &&
          other.merchantName == merchantName &&
          other.mid == mid &&
          other.merchantKey == merchantKey &&
          other.publicKey == publicKey &&
          other.registerRef == registerRef &&
          other.currency == currency &&
          other.rsaPublicKey == rsaPublicKey;

  @override
  int get hashCode => Object.hash(
    partnerName,
    merchantName,
    mid,
    merchantKey,
    publicKey,
    registerRef,
    currency,
    rsaPublicKey,
  );
}
