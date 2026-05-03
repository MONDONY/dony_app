// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_suggestion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddressSuggestion _$AddressSuggestionFromJson(Map<String, dynamic> json) =>
    AddressSuggestion(
      placeId: json['placeId'] as String,
      mainText: json['mainText'] as String,
      secondaryText: json['secondaryText'] as String,
    );

Map<String, dynamic> _$AddressSuggestionToJson(AddressSuggestion instance) =>
    <String, dynamic>{
      'placeId': instance.placeId,
      'mainText': instance.mainText,
      'secondaryText': instance.secondaryText,
    };
