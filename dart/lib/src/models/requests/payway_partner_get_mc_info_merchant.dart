import 'package:json_annotation/json_annotation.dart';

part 'payway_partner_get_mc_info_merchant.g.dart';

/// Request of `get-mc-info` (inquiry merchant info via merchant public key).
///
/// The keys come from the merchant credentials (see
/// `PaywayPartnerMerchantCredential.toGetMcInfoMerchant`). They are never sent
/// to PayWay as is: they key the hashes PayWay uses to verify the request.
/// [toJson] is for storing these values yourself; it contains the keys.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class PaywayPartnerGetMcInfoMerchant {
  /// merchant key provided by ABA
  final String merchantKey;

  /// `USD` or `KHR`
  final String currency;

  /// merchant public key, keys `public_key_hash_encrypt` (HMAC-SHA512)
  final String publicKey;

  /// merchant RSA public key, encrypts `rsa_public_key_hash_encrypt` (optional)
  final String? rsaPublicKey;

  /// Creates a [PaywayPartnerGetMcInfoMerchant].
  const PaywayPartnerGetMcInfoMerchant({
    required this.merchantKey,
    required this.currency,
    required this.publicKey,
    this.rsaPublicKey,
  });

  /// Parses PayWay JSON (snake_case keys).
  factory PaywayPartnerGetMcInfoMerchant.fromJson(Map<String, dynamic> json) =>
      _$PaywayPartnerGetMcInfoMerchantFromJson(json);

  /// JSON with PayWay's field names, for storing; contains the keys.
  Map<String, dynamic> toJson() => _$PaywayPartnerGetMcInfoMerchantToJson(this);

  /// Returns a copy with the given fields replaced.
  PaywayPartnerGetMcInfoMerchant copyWith({
    String? merchantKey,
    String? currency,
    String? publicKey,
    String? rsaPublicKey,
  }) {
    return PaywayPartnerGetMcInfoMerchant(
      merchantKey: merchantKey ?? this.merchantKey,
      currency: currency ?? this.currency,
      publicKey: publicKey ?? this.publicKey,
      rsaPublicKey: rsaPublicKey ?? this.rsaPublicKey,
    );
  }

  /// keys are left out on purpose so they don't end up in logs
  @override
  String toString() =>
      'PaywayPartnerGetMcInfoMerchant(merchantKey: $merchantKey, currency: $currency)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywayPartnerGetMcInfoMerchant &&
          other.merchantKey == merchantKey &&
          other.currency == currency &&
          other.publicKey == publicKey &&
          other.rsaPublicKey == rsaPublicKey;

  @override
  int get hashCode =>
      Object.hash(merchantKey, currency, publicKey, rsaPublicKey);
}
