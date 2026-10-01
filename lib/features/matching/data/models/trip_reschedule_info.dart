import 'package:json_annotation/json_annotation.dart';

part 'trip_reschedule_info.g.dart';

/// Dernier report du trajet d'un colis (vol annulé, voyage repoussé), servi
/// par le back dans la réponse du colis (`BidResponse.reschedule`).
@JsonSerializable()
class TripRescheduleInfo {
  const TripRescheduleInfo({
    required this.id,
    required this.reason,
    this.note,
    this.previousDepartureDate,
    this.previousDepartureTime,
    this.newDepartureDate,
    this.newDepartureTime,
    this.rescheduledAt,
    this.decisionPending = false,
    this.decisionDeadline,
  });

  final String id;

  /// `FLIGHT_CANCELLED`, `POSTPONED` ou `OTHER`.
  final String reason;
  final String? note;
  final DateTime? previousDepartureDate;

  /// "HH:mm:ss" ou "HH:mm" selon le back.
  final String? previousDepartureTime;
  final DateTime? newDepartureDate;
  final String? newDepartureTime;
  final DateTime? rescheduledAt;

  /// L'expéditeur peut encore garder son colis ou se retirer sans frais.
  @JsonKey(defaultValue: false)
  final bool decisionPending;

  /// Jusqu'à quand (heure locale du trajet). Sans réponse, le colis reste.
  final DateTime? decisionDeadline;

  factory TripRescheduleInfo.fromJson(Map<String, dynamic> json) =>
      _$TripRescheduleInfoFromJson(json);

  Map<String, dynamic> toJson() => _$TripRescheduleInfoToJson(this);
}
