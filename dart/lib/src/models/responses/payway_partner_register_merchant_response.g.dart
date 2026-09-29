// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payway_partner_register_merchant_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaywayPartnerRegisterMerchantResponse
_$PaywayPartnerRegisterMerchantResponseFromJson(Map<String, dynamic> json) =>
    PaywayPartnerRegisterMerchantResponse(
      url: trimmedStringFromJson(json['url']),
      token: stringFromJson(json['token']),
      status: PaywayPartnerStatus.fromJson(
        json['status'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$PaywayPartnerRegisterMerchantResponseToJson(
  PaywayPartnerRegisterMerchantResponse instance,
) => <String, dynamic>{
  'url': instance.url,
  'token': instance.token,
  'status': instance.status.toJson(),
};
