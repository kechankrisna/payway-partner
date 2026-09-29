// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payway_partner_merchant_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaywayPartnerMerchantInfo _$PaywayPartnerMerchantInfoFromJson(
  Map<String, dynamic> json,
) => PaywayPartnerMerchantInfo(
  outletName: stringFromJson(json['outlet_name']),
  abaAccountKhr: stringFromJson(json['aba_account_khr']),
  abaAccountUsd: stringFromJson(json['aba_account_usd']),
  availablePaymentMethods: json['available_payment_methods'] == null
      ? const {}
      : paymentMethodsFromJson(json['available_payment_methods']),
  enabledPaymentMethods: json['enabled_payment_methods'] == null
      ? const {}
      : paymentMethodsFromJson(json['enabled_payment_methods']),
  pendingPaymentMethods: json['pending_payment_methods'] == null
      ? const {}
      : paymentMethodsFromJson(json['pending_payment_methods']),
);

Map<String, dynamic> _$PaywayPartnerMerchantInfoToJson(
  PaywayPartnerMerchantInfo instance,
) => <String, dynamic>{
  'outlet_name': instance.outletName,
  'aba_account_khr': instance.abaAccountKhr,
  'aba_account_usd': instance.abaAccountUsd,
  'available_payment_methods': instance.availablePaymentMethods,
  'enabled_payment_methods': instance.enabledPaymentMethods,
  'pending_payment_methods': instance.pendingPaymentMethods,
};
