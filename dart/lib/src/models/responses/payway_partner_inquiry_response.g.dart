// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payway_partner_inquiry_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaywayPartnerInquiryResponse _$PaywayPartnerInquiryResponseFromJson(
  Map<String, dynamic> json,
) => PaywayPartnerInquiryResponse(
  data: stringFromJson(json['data']),
  status: PaywayPartnerStatus.fromJson(json['status'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PaywayPartnerInquiryResponseToJson(
  PaywayPartnerInquiryResponse instance,
) => <String, dynamic>{
  'data': instance.data,
  'status': instance.status.toJson(),
};
