// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payway_partner_get_mc_info_merchant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaywayPartnerGetMcInfoMerchant _$PaywayPartnerGetMcInfoMerchantFromJson(
  Map<String, dynamic> json,
) => PaywayPartnerGetMcInfoMerchant(
  merchantKey: json['merchant_key'] as String,
  currency: json['currency'] as String,
  publicKey: json['public_key'] as String,
  rsaPublicKey: json['rsa_public_key'] as String?,
);

Map<String, dynamic> _$PaywayPartnerGetMcInfoMerchantToJson(
  PaywayPartnerGetMcInfoMerchant instance,
) => <String, dynamic>{
  'merchant_key': instance.merchantKey,
  'currency': instance.currency,
  'public_key': instance.publicKey,
  'rsa_public_key': ?instance.rsaPublicKey,
};
