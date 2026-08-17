import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
export 'package:dony/features/matching/data/models/transport_mode.dart';

abstract class AnnouncementEvent {}

class AnnouncementCreateRequested extends AnnouncementEvent {
  final String departureCity;
  final String arrivalCity;
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime departureDate;
  final String? departureTime;
  final String? arrivalTime;
  final AddressData pickupAddress;
  final AddressData deliveryAddress;
  final double availableKg;
  final double pricePerKg;
  final TransportMode transportMode;
  final String? description;
  final List<String> acceptedContentTypes;
  final List<String> refusedTypes;
  final List<String> acceptedPaymentMethods;
  final String? capacityUnit;
  final String pricingMode;
  final DateTime handoverDeadline;
  final bool saveAsDraft;

  AnnouncementCreateRequested({
    required this.departureCity,
    required this.arrivalCity,
    this.departureCountryCode,
    this.arrivalCountryCode,
    required this.departureDate,
    this.departureTime,
    this.arrivalTime,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.availableKg,
    required this.pricePerKg,
    required this.transportMode,
    this.description,
    this.acceptedContentTypes = const [],
    this.refusedTypes = const [],
    this.acceptedPaymentMethods = const ['STRIPE'],
    this.capacityUnit,
    this.pricingMode = 'KG',
    required this.handoverDeadline,
    this.saveAsDraft = false,
  });
}

/// Publie un trajet précédemment sauvegardé en brouillon (statut DRAFT → ACTIVE).
class AnnouncementPublishRequested extends AnnouncementEvent {
  final String id;
  AnnouncementPublishRequested(this.id);
}

class AnnouncementUnpublishRequested extends AnnouncementEvent {
  final String id;
  AnnouncementUnpublishRequested(this.id);
}

class AnnouncementListRequested extends AnnouncementEvent {}

class AnnouncementDetailRequested extends AnnouncementEvent {
  final String id;
  AnnouncementDetailRequested(this.id);
}

class AnnouncementSearchRequested extends AnnouncementEvent {
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDateFrom;
  final DateTime? departureDateTo;
  final double? minAvailableKg;
  final double? maxAvailableKg;
  final double? maxPricePerKg;
  final bool? kiloProOnly;
  final double? minRating;
  final bool? weekendOnly;
  final TransportMode? transportMode;
  final bool? kycVerifiedOnly;
  final String? contentType;
  final double? userLat;
  final double? userLng;
  final double? radiusKm;
  final String sortBy; // date | price | rating
  final String sortDir; // asc | desc
  /// Filtre serveur « annonces urgentes » (`urgent=true`) — jamais `false`
  /// envoyé explicitement, seulement présent ou absent côté datasource.
  final bool? urgent;

  AnnouncementSearchRequested({
    this.departureCity,
    this.arrivalCity,
    this.departureDateFrom,
    this.departureDateTo,
    this.minAvailableKg,
    this.maxAvailableKg,
    this.maxPricePerKg,
    this.kiloProOnly,
    this.minRating,
    this.weekendOnly,
    this.transportMode,
    this.kycVerifiedOnly,
    this.contentType,
    this.userLat,
    this.userLng,
    this.radiusKm,
    this.sortBy = 'date',
    this.sortDir = 'asc',
    this.urgent,
  });
}

class AnnouncementDeleteRequested extends AnnouncementEvent {
  final String id;
  AnnouncementDeleteRequested(this.id);
}

/// Ouverture de la capacité excédentaire d'un trajet dédié au public.
class AnnouncementSurplusOpenRequested extends AnnouncementEvent {
  final String announcementId;
  final double surplusKg;
  final double pricePerKg;

  AnnouncementSurplusOpenRequested({
    required this.announcementId,
    required this.surplusKg,
    required this.pricePerKg,
  });
}

/// Marquage groupé « Arrivé à destination » : passe le trajet à ARRIVED et
/// enregistre en une fois des instructions de retrait optionnelles.
class AnnouncementTripMarkArrivedRequested extends AnnouncementEvent {
  final String announcementId;
  final String? arrivalInstructions;

  AnnouncementTripMarkArrivedRequested({
    required this.announcementId,
    this.arrivalInstructions,
  });
}

/// Édition des instructions de retrait après le marquage initial.
class AnnouncementArrivalInstructionsUpdateRequested extends AnnouncementEvent {
  final String announcementId;
  final String arrivalInstructions;

  AnnouncementArrivalInstructionsUpdateRequested({
    required this.announcementId,
    required this.arrivalInstructions,
  });
}

class AnnouncementUpdateRequested extends AnnouncementEvent {
  final String id;
  final String departureCity;
  final String arrivalCity;
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime departureDate;
  final String? departureTime;
  final String? arrivalTime;
  final AddressData pickupAddress;
  final AddressData deliveryAddress;
  final double availableKg;
  final double pricePerKg;
  final TransportMode transportMode;
  final String? description;
  final List<String> acceptedContentTypes;
  final List<String> refusedTypes;
  final List<String> acceptedPaymentMethods;
  final String? capacityUnit;
  final String pricingMode;
  final DateTime handoverDeadline;

  AnnouncementUpdateRequested({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    this.departureCountryCode,
    this.arrivalCountryCode,
    required this.departureDate,
    this.departureTime,
    this.arrivalTime,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.availableKg,
    required this.pricePerKg,
    required this.transportMode,
    this.description,
    this.acceptedContentTypes = const [],
    this.refusedTypes = const [],
    this.acceptedPaymentMethods = const ['STRIPE'],
    this.capacityUnit,
    this.pricingMode = 'KG',
    required this.handoverDeadline,
  });
}
