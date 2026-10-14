import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';

/// Modèle de trajet tiré d'un trajet publié (« En faire un modèle », après
/// un trajet récurrent). Tout est repris sauf les dates : la date limite de
/// dépôt devient un délai en jours avant le départ (0 à 7), la date
/// d'arrivée un décalage en jours (0 à 3), bornes du back.
TripTemplate tripTemplateFromAnnouncement(
  AnnouncementModel a, {
  required String label,
}) {
  final methods = [for (final m in a.acceptedPaymentMethods) m.apiValue];
  return TripTemplate(
    id: '',
    label: label,
    departureCity: a.departureCity,
    departureLat: a.pickupAddress?.lat,
    departureLng: a.pickupAddress?.lng,
    arrivalCity: a.arrivalCity,
    arrivalLat: a.deliveryAddress?.lat,
    arrivalLng: a.deliveryAddress?.lng,
    transportMode: transportModeToWire(a.transportMode ?? TransportMode.plane),
    capacityUnit: a.capacityUnit ?? 'SUITCASE_23KG',
    availableKg: a.totalKg.round().clamp(1, 1000),
    pricePerKg: a.pricePerKg,
    acceptedCategories: a.acceptedContentTypes ?? const [],
    arrivalTime: _hhmm(a.arrivalTime),
    currency: a.currency,
    pricingMode: a.pricingMode,
    acceptedPaymentMethods: methods,
    cashAccepted: a.acceptedPaymentMethods.contains(BidPaymentMethod.cash),
    negotiable: a.negotiable,
    refusedTypes: a.refusedTypes ?? const [],
    description: a.description,
    pickupAddress: a.pickupAddress,
    deliveryAddress: a.deliveryAddress,
    departureTime: _hhmm(a.departureTime),
    handoverLeadDays: _leadDays(a),
    departureCountryCode: a.departureCountryCode,
    arrivalCountryCode: a.arrivalCountryCode,
    arrivalDayOffset: _arrivalOffset(a),
  );
}

String? _hhmm(String? value) {
  if (value == null) return null;
  return value.length >= 5 ? value.substring(0, 5) : value;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

int? _leadDays(AnnouncementModel a) {
  final deadline = a.handoverDeadline;
  if (deadline == null) return null;
  return _day(a.departureDate).difference(_day(deadline)).inDays.clamp(0, 7);
}

int _arrivalOffset(AnnouncementModel a) {
  final arrival = a.arrivalDate;
  if (arrival == null) return 0;
  return _day(arrival).difference(_day(a.departureDate)).inDays.clamp(0, 3);
}
