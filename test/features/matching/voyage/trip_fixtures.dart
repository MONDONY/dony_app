import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';

/// Données partagées des tests du voyage à plusieurs étapes (FLUTTER-4D).
const kParis = AddressData(label: 'CDG', lat: 49.0, lng: 2.5);
const kAbidjan = AddressData(label: 'Abidjan FHB', lat: 5.25, lng: -3.93);
const kDouala = AddressData(label: 'Douala DLA', lat: 4.0, lng: 9.7);

AnnouncementCreateRequested firstLeg({
  bool draft = false,
  String pricingMode = 'KG',
  TripStops? stops,
}) => AnnouncementCreateRequested(
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
  departureCountryCode: 'FR',
  arrivalCountryCode: 'CI',
  departureDate: DateTime(2026, 11, 10),
  departureTime: '10:00',
  arrivalTime: '18:00',
  pickupAddress: kParis,
  deliveryAddress: kAbidjan,
  availableKg: 20,
  pricePerKg: 8,
  transportMode: TransportMode.plane,
  stops: stops,
  description: 'Bagage soute',
  acceptedContentTypes: const ['CLOTHES'],
  refusedTypes: const ['FOOD'],
  acceptedPaymentMethods: const ['CASH'],
  capacityUnit: 'KG_EXACT',
  pricingMode: pricingMode,
  // 24 h avant le départ.
  handoverDeadline: DateTime(2026, 11, 9, 10),
  negotiable: true,
  saveAsDraft: draft,
  currency: 'EUR',
);

TripLegDraft doualaLeg({DateTime? date, double? price = 6, TripStops? stops}) =>
    TripLegDraft(
      arrivalCity: 'Douala',
      arrivalCountryCode: 'CM',
      departureDate: date ?? DateTime(2026, 11, 14),
      departureTime: '09:30',
      deliveryAddress: kDouala,
      availableKg: 12,
      pricePerKg: price,
      stops: stops,
    );

AnnouncementModel legModel({
  required String id,
  required String from,
  required String to,
  String? group,
  int? index,
  int? count,
  String status = 'ACTIVE',
  DateTime? date,
}) => AnnouncementModel(
  id: id,
  travelerId: 'trav',
  departureCity: from,
  arrivalCity: to,
  departureDate: date ?? DateTime(2026, 11, 10),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 5,
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tripGroupId: group,
  tripLegIndex: index,
  tripLegCount: count,
);

/// Copie d'une étape vers une autre ville d'arrivée.
abstract final class TripLegDraftCopy {
  static TripLegDraft withCity(TripLegDraft leg, String city, String code) =>
      TripLegDraft(
        arrivalCity: city,
        arrivalCountryCode: code,
        departureDate: leg.departureDate,
        departureTime: leg.departureTime,
        deliveryAddress: leg.deliveryAddress,
        availableKg: leg.availableKg,
        pricePerKg: leg.pricePerKg,
        stops: leg.stops,
      );
}
