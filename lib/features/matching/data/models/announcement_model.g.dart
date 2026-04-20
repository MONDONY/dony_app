// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnnouncementModel _$AnnouncementModelFromJson(Map<String, dynamic> json) =>
    AnnouncementModel(
      id: json['id'] as String,
      travelerId: json['travelerId'] as String,
      departureCity: json['departureCity'] as String,
      arrivalCity: json['arrivalCity'] as String,
      departureDate: DateTime.parse(json['departureDate'] as String),
      availableKg: (json['availableKg'] as num).toDouble(),
      pricePerKg: (json['pricePerKg'] as num).toDouble(),
      status: json['status'] as String,
      bidsCount: json['bidsCount'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AnnouncementModelToJson(AnnouncementModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'travelerId': instance.travelerId,
      'departureCity': instance.departureCity,
      'arrivalCity': instance.arrivalCity,
      'departureDate': instance.departureDate.toIso8601String(),
      'availableKg': instance.availableKg,
      'pricePerKg': instance.pricePerKg,
      'status': instance.status,
      if (instance.bidsCount != null) 'bidsCount': instance.bidsCount,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
