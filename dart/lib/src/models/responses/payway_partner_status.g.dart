// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payway_partner_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaywayPartnerStatus _$PaywayPartnerStatusFromJson(Map<String, dynamic> json) =>
    PaywayPartnerStatus(
      code: stringFromJson(json['code']),
      message: stringFromJson(json['message']),
      tranId: nullableStringFromJson(json['tran_id']),
      traceId: nullableStringFromJson(json['trace_id']),
      correlationId: nullableStringFromJson(json['correlation_id']),
    );

Map<String, dynamic> _$PaywayPartnerStatusToJson(
  PaywayPartnerStatus instance,
) => <String, dynamic>{
  'code': instance.code,
  'message': instance.message,
  'tran_id': ?instance.tranId,
  'trace_id': ?instance.traceId,
  'correlation_id': ?instance.correlationId,
};
