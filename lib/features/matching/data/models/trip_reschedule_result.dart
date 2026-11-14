/// Motif d'un report de trajet, valeurs du back (`TripRescheduleReason`).
///
/// [flightCancelled] reste le motif envoyé pour un avion (le back prod ne
/// connaît pas encore [transportCancelled]) ; les deux sont lus.
enum TripRescheduleReason {
  flightCancelled('FLIGHT_CANCELLED'),
  transportCancelled('TRANSPORT_CANCELLED'),
  postponed('POSTPONED'),
  other('OTHER');

  const TripRescheduleReason(this.wire);
  final String wire;

  static TripRescheduleReason? fromWire(String? wire) {
    for (final r in values) {
      if (r.wire == wire) return r;
    }
    return null;
  }
}

/// Réponse de `POST /announcements/{id}/reschedule`.
class TripRescheduleResult {
  const TripRescheduleResult({
    required this.rescheduleId,
    required this.rescheduleCount,
    required this.remainingReschedules,
    required this.parcelsAwaitingDecision,
    required this.requestsInformed,
  });

  final String rescheduleId;
  final int rescheduleCount;
  final int remainingReschedules;

  /// Colis acceptés ou remis dont l'expéditeur doit répondre.
  final int parcelsAwaitingDecision;

  /// Demandes pas encore acceptées, dont l'expéditeur est seulement prévenu.
  final int requestsInformed;

  factory TripRescheduleResult.fromJson(Map<String, dynamic> json) =>
      TripRescheduleResult(
        rescheduleId: json['rescheduleId'] as String,
        rescheduleCount: (json['rescheduleCount'] as num?)?.toInt() ?? 0,
        remainingReschedules:
            (json['remainingReschedules'] as num?)?.toInt() ?? 0,
        parcelsAwaitingDecision:
            (json['parcelsAwaitingDecision'] as num?)?.toInt() ?? 0,
        requestsInformed: (json['requestsInformed'] as num?)?.toInt() ?? 0,
      );
}
