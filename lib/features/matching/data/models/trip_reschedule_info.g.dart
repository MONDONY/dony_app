// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_reschedule_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TripRescheduleInfo _$TripRescheduleInfoFromJson(Map<String, dynamic> json) =>
    TripRescheduleInfo(
      id: json['id'] as String,
      reason: json['reason'] as String,
      note: json['note'] as String?,
      previousDepartureDate: json['previousDepartureDate'] == null
          ? null
          : DateTime.parse(json['previousDepartureDate'] as String),
      previousDepartureTime: json['previousDepartureTime'] as String?,
      newDepartureDate: json['newDepartureDate'] == null
          ? null
          : DateTime.parse(json['newDepartureDate'] as String),
      newDepartureTime: json['newDepartureTime'] as String?,
      rescheduledAt: json['rescheduledAt'] == null
          ? null
          : DateTime.parse(json['rescheduledAt'] as String),
      decisionPending: json['decisionPending'] as bool? ?? false,
      decisionDeadline: json['decisionDeadline'] == null
          ? null
          : DateTime.parse(json['decisionDeadline'] as String),
    );

Map<String, dynamic> _$TripRescheduleInfoToJson(
  TripRescheduleInfo instance,
) => <String, dynamic>{
  'id': instance.id,
  'reason': instance.reason,
  'note': instance.note,
  'previousDepartureDate': instance.previousDepartureDate?.toIso8601String(),
  'previousDepartureTime': instance.previousDepartureTime,
  'newDepartureDate': instance.newDepartureDate?.toIso8601String(),
  'newDepartureTime': instance.newDepartureTime,
  'rescheduledAt': instance.rescheduledAt?.toIso8601String(),
  'decisionPending': instance.decisionPending,
  'decisionDeadline': instance.decisionDeadline?.toIso8601String(),
};
