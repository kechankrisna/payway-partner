import 'package:json_annotation/json_annotation.dart';

part 'payway_partner_register_merchant.g.dart';

/// Request of `new-merchant` (register a merchant).
///
/// [toJson] is the `request_data` payload, with PayWay's field names.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class PaywayPartnerRegisterMerchant {
  /// PayWay POSTs the merchant details here once registration completes
  final String pushbackUrl;

  /// embedded in the button on PayWay's success screen.
  /// Native app ([type] 1): `{"ios_scheme":"...","android_scheme":"..."}`;
  /// web ([type] 0): `https://your-url.domain`
  final String redirectUrl;

  /// activation platform: `0` web (default), `1` native app
  final int type;

  /// your unique reference for this registration
  /// (letters, numbers, `_` and `-`)
  final String registerRef;

  /// `0` in-store merchant, `1` online merchant (ABA default when omitted)
  final int? merchantType;

  /// merchant currency to register: `KHR` or `USD`
  final String currency;

  /// Creates a [PaywayPartnerRegisterMerchant].
  const PaywayPartnerRegisterMerchant({
    required this.pushbackUrl,
    required this.redirectUrl,
    required this.registerRef,
    required this.currency,
    this.type = 0,
    this.merchantType,
  });

  /// Parses PayWay JSON (snake_case keys).
  factory PaywayPartnerRegisterMerchant.fromJson(Map<String, dynamic> json) =>
      _$PaywayPartnerRegisterMerchantFromJson(json);

  /// The `request_data` payload, with PayWay's field names.
  Map<String, dynamic> toJson() => _$PaywayPartnerRegisterMerchantToJson(this);

  /// Returns a copy with the given fields replaced.
  PaywayPartnerRegisterMerchant copyWith({
    String? pushbackUrl,
    String? redirectUrl,
    int? type,
    String? registerRef,
    String? currency,
    int? merchantType,
  }) {
    return PaywayPartnerRegisterMerchant(
      pushbackUrl: pushbackUrl ?? this.pushbackUrl,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      type: type ?? this.type,
      registerRef: registerRef ?? this.registerRef,
      currency: currency ?? this.currency,
      merchantType: merchantType ?? this.merchantType,
    );
  }

  @override
  String toString() =>
      'PaywayPartnerRegisterMerchant(pushbackUrl: $pushbackUrl, redirectUrl: $redirectUrl, type: $type, registerRef: $registerRef, currency: $currency, merchantType: $merchantType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywayPartnerRegisterMerchant &&
          other.pushbackUrl == pushbackUrl &&
          other.redirectUrl == redirectUrl &&
          other.type == type &&
          other.registerRef == registerRef &&
          other.currency == currency &&
          other.merchantType == merchantType;

  @override
  int get hashCode => Object.hash(
    pushbackUrl,
    redirectUrl,
    type,
    registerRef,
    currency,
    merchantType,
  );
}
