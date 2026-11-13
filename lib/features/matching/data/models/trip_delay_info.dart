import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';

/// Motif d'un retard annoncé par le voyageur (`POST /announcements/{id}/delays`).
/// `portCongestion` est propre au bateau : le back le refuse (422
/// `trip-delay-reason-invalid`) sur tout autre mode.
enum TripDelayReason {
  portCongestion('PORT_CONGESTION'),
  weather('WEATHER'),
  extendedStopover('EXTENDED_STOPOVER'),
  transportDisruption('TRANSPORT_DISRUPTION'),
  other('OTHER');

  const TripDelayReason(this.wire);

  /// Valeur échangée avec le back.
  final String wire;

  /// Motif inconnu (back plus récent) ou absent : `null`, jamais une erreur.
  static TripDelayReason? fromWire(String? wire) {
    for (final reason in values) {
      if (reason.wire == wire) return reason;
    }
    return null;
  }

  /// Motifs proposables pour un trajet de ce [mode]. Le motif propre au bateau
  /// n'est offert qu'en bateau.
  static List<TripDelayReason> forMode(TransportMode? mode) => [
    for (final reason in values)
      if (reason != portCongestion || mode == TransportMode.boat) reason,
  ];
}

/// Dernier retard annoncé sur un trajet (`latestTripDelay` du détail du trajet
/// pour son propriétaire, et du colis). Nul sans retard, ou sur un back
/// antérieur au lot 3.
class TripDelayInfo extends Equatable {
  const TripDelayInfo({
    this.id,
    required this.reason,
    required this.arrivalDate,
    required this.arrivalDateMax,
    this.message,
    required this.announcedAt,
  });

  final String? id;

  /// Motif brut du back (`PORT_CONGESTION`, `WEATHER`...). Un motif que l'app
  /// ne connaît pas est conservé tel quel ; [reasonKind] vaut alors `null`.
  final String reason;

  /// Nouvelle arrivée estimée au plus tôt.
  final DateTime arrivalDate;

  /// Nouvelle arrivée estimée au plus tard.
  final DateTime arrivalDateMax;

  /// Message libre du voyageur (300 caractères au plus).
  final String? message;

  /// Instant de l'annonce.
  final DateTime announcedAt;

  TripDelayReason? get reasonKind => TripDelayReason.fromWire(reason);

  /// Une date illisible ou un motif absent rend `null` : le retard n'est
  /// alors pas affiché, plutôt qu'une erreur de lecture du trajet.
  static TripDelayInfo? fromJsonOrNull(Object? json) {
    if (json is! Map) return null;
    final reason = json['reason'];
    final arrival = _date(json['arrivalDate']);
    final arrivalMax = _date(json['arrivalDateMax']);
    final announcedAt = _date(json['announcedAt']);
    if (reason is! String || arrival == null || arrivalMax == null) {
      return null;
    }
    final message = json['message'];
    final id = json['id'];
    return TripDelayInfo(
      id: id is String ? id : null,
      reason: reason,
      arrivalDate: arrival,
      arrivalDateMax: arrivalMax,
      message: message is String && message.trim().isNotEmpty ? message : null,
      announcedAt: announcedAt ?? arrival,
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'reason': reason,
    'arrivalDate': _dateOnly(arrivalDate),
    'arrivalDateMax': _dateOnly(arrivalDateMax),
    'message': message,
    'announcedAt': announcedAt.toIso8601String(),
  };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [
    id,
    reason,
    arrivalDate,
    arrivalDateMax,
    message,
    announcedAt,
  ];
}

Map<String, dynamic>? tripDelayToJson(TripDelayInfo? info) => info?.toJson();
