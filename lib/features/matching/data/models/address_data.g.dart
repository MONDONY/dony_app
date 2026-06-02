// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddressData _$AddressDataFromJson(Map<String, dynamic> json) => AddressData(
  label: json['label'] as String,
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
  street: json['street'] as String?,
  city: json['city'] as String?,
  postalCode: json['postalCode'] as String?,
  country: json['country'] as String?,
);

Map<String, dynamic> _$AddressDataToJson(AddressData instance) =>
    <String, dynamic>{
      'label': instance.label,
      'lat': instance.lat,
      'lng': instance.lng,
      'street': instance.street,
      'city': instance.city,
      'postalCode': instance.postalCode,
      'country': instance.country,
    };
