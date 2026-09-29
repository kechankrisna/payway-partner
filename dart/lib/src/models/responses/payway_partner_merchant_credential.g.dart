// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payway_partner_merchant_credential.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaywayPartnerMerchantCredential _$PaywayPartnerMerchantCredentialFromJson(
  Map<String, dynamic> json,
) => PaywayPartnerMerchantCredential(
  partnerName: stringFromJson(json['partner_name']),
  merchantName: stringFromJson(json['merchant_name']),
  mid: stringFromJson(json['mid']),
  merchantKey: stringFromJson(json['merchant_key']),
  publicKey: stringFromJson(json['public_key']),
  registerRef: stringFromJson(json['register_ref']),
  currency: stringFromJson(json['currency']),
  rsaPublicKey: stringFromJson(json['rsa_public_key']),
);

Map<String, dynamic> _$PaywayPartnerMerchantCredentialToJson(
  PaywayPartnerMerchantCredential instance,
) => <String, dynamic>{
  'partner_name': instance.partnerName,
  'merchant_name': instance.merchantName,
  'mid': instance.mid,
  'merchant_key': instance.merchantKey,
  'public_key': instance.publicKey,
  'register_ref': instance.registerRef,
  'currency': instance.currency,
  'rsa_public_key': instance.rsaPublicKey,
};
