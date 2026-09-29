// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payway_partner_register_merchant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaywayPartnerRegisterMerchant _$PaywayPartnerRegisterMerchantFromJson(
  Map<String, dynamic> json,
) => PaywayPartnerRegisterMerchant(
  pushbackUrl: json['pushback_url'] as String,
  redirectUrl: json['redirect_url'] as String,
  registerRef: json['register_ref'] as String,
  currency: json['currency'] as String,
  type: (json['type'] as num?)?.toInt() ?? 0,
  merchantType: (json['merchant_type'] as num?)?.toInt(),
);

Map<String, dynamic> _$PaywayPartnerRegisterMerchantToJson(
  PaywayPartnerRegisterMerchant instance,
) => <String, dynamic>{
  'pushback_url': instance.pushbackUrl,
  'redirect_url': instance.redirectUrl,
  'type': instance.type,
  'register_ref': instance.registerRef,
  'merchant_type': ?instance.merchantType,
  'currency': instance.currency,
};
