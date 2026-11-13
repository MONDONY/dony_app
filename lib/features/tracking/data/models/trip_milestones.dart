import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:flutter/foundation.dart';

/// Jalons du trajet qui porte un colis, intercalés par la frise entre les
/// étapes scannées du colis : départ prévu, arrivée estimée (fourchette en
/// bateau) et dernier retard annoncé.
///
/// Tout est facultatif : un colis lu par QR ou par numéro n'en porte aucun, la
/// frise se fonde alors sur les seules étapes scannées.
@immutable
class TripMilestones {
  const TripMilestones({
    this.departureAt,
    this.departureDate,
    this.arrivalDate,
    this.arrivalDateMax,
    this.latestDelay,
  });

  /// Jalons d'un colis de l'utilisateur.
  factory TripMilestones.fromBid(BidModel bid) => TripMilestones(
    departureAt: bid.resolvedDepartureAt,
    departureDate: bid.departureDate,
    arrivalDate: bid.arrivalDate,
    arrivalDateMax: bid.arrivalDateMax,
    latestDelay: bid.latestTripDelay,
  );

  /// Instant de départ prévu (date et heure), `null` sans heure connue.
  final DateTime? departureAt;

  /// Jour de départ prévu.
  final DateTime? departureDate;

  /// Arrivée estimée au plus tôt, et au plus tard (bateau).
  final DateTime? arrivalDate;
  final DateTime? arrivalDateMax;

  /// Dernier retard annoncé par le transporteur, servi une fois le colis remis.
  final TripDelayInfo? latestDelay;

  /// Arrivée estimée à jour : celle du dernier retard, sinon celle du trajet.
  DateTime? get estimatedArrival => latestDelay?.arrivalDate ?? arrivalDate;
  DateTime? get estimatedArrivalMax =>
      latestDelay?.arrivalDateMax ?? arrivalDateMax;

  /// Le départ prévu est passé à [now]. Sans heure, le jour du départ doit
  /// être fini, comme [BidModel.hasDeparted].
  bool departurePassed(DateTime now) {
    final at = departureAt;
    if (at != null) return !now.isBefore(at);
    final day = departureDate;
    if (day == null) return false;
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  bool operator ==(Object other) =>
      other is TripMilestones &&
      other.departureAt == departureAt &&
      other.departureDate == departureDate &&
      other.arrivalDate == arrivalDate &&
      other.arrivalDateMax == arrivalDateMax &&
      other.latestDelay == latestDelay;

  @override
  int get hashCode => Object.hash(
    departureAt,
    departureDate,
    arrivalDate,
    arrivalDateMax,
    latestDelay,
  );
}
