// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TravelerProfile _$TravelerProfileFromJson(Map<String, dynamic> json) =>
    TravelerProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      totalTrips: (json['totalTrips'] as num?)?.toInt(),
      kiloPro: json['kiloPro'] as bool? ?? false,
    );

Map<String, dynamic> _$TravelerProfileToJson(TravelerProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'phoneNumber': instance.phoneNumber,
      'averageRating': instance.averageRating,
      'totalTrips': instance.totalTrips,
      'kiloPro': instance.kiloPro,
    };

AnnouncementModel _$AnnouncementModelFromJson(Map<String, dynamic> json) =>
    AnnouncementModel(
      id: json['id'] as String,
      travelerId: json['travelerId'] as String,
      departureCity: json['departureCity'] as String,
      arrivalCity: json['arrivalCity'] as String,
      departureDate: DateTime.parse(json['departureDate'] as String),
      departureTime: json['departureTime'] as String?,
      arrivalTime: json['arrivalTime'] as String?,
      departureLocation: json['departureLocation'] as String?,
      arrivalLocation: json['arrivalLocation'] as String?,
      availableKg: (json['availableKg'] as num).toDouble(),
      pricePerKg: (json['pricePerKg'] as num).toDouble(),
      status: json['status'] as String,
      bidsCount: (json['bidsCount'] as num?)?.toInt(),
      traveler: json['traveler'] == null
          ? null
          : TravelerProfile.fromJson(json['traveler'] as Map<String, dynamic>),
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
      'departureTime': instance.departureTime,
      'arrivalTime': instance.arrivalTime,
      'departureLocation': instance.departureLocation,
      'arrivalLocation': instance.arrivalLocation,
      'availableKg': instance.availableKg,
      'pricePerKg': instance.pricePerKg,
      'status': instance.status,
      'bidsCount': instance.bidsCount,
      'traveler': instance.traveler,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
