// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payway_partner.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaywayPartner _$PaywayPartnerFromJson(Map<String, dynamic> json) =>
    PaywayPartner(
      partnerName: json['partnerName'] as String,
      partnerID: json['partnerID'] as String,
      partnerKey: json['partnerKey'] as String,
      partnerPrivateKey: json['partnerPrivateKey'] as String,
      partnerPublicKey: json['partnerPublicKey'] as String,
      partnerReferer: json['partnerReferer'] as String,
      baseApiUrl: json['baseApiUrl'] as String,
    );

Map<String, dynamic> _$PaywayPartnerToJson(PaywayPartner instance) =>
    <String, dynamic>{
      'partnerName': instance.partnerName,
      'partnerID': instance.partnerID,
      'partnerKey': instance.partnerKey,
      'partnerPrivateKey': instance.partnerPrivateKey,
      'partnerPublicKey': instance.partnerPublicKey,
      'partnerReferer': instance.partnerReferer,
      'baseApiUrl': instance.baseApiUrl,
    };
