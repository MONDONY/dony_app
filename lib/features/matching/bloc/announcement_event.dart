import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';

abstract class AnnouncementEvent {}

class AnnouncementCreateRequested extends AnnouncementEvent {
  final String departureCity;
  final String arrivalCity;
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

  AnnouncementCreateRequested({
    required this.departureCity,
    required this.arrivalCity,
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
  });
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
  final double? maxPricePerKg;
  final bool? kiloProOnly;
  final double? minRating;
  final bool? weekendOnly;
  final double? userLat;
  final double? userLng;
  final double? radiusKm;
  final String sortBy; // date | price | rating
  final String sortDir; // asc | desc

  AnnouncementSearchRequested({
    this.departureCity,
    this.arrivalCity,
    this.departureDateFrom,
    this.departureDateTo,
    this.minAvailableKg,
    this.maxPricePerKg,
    this.kiloProOnly,
    this.minRating,
    this.weekendOnly,
    this.userLat,
    this.userLng,
    this.radiusKm,
    this.sortBy = 'date',
    this.sortDir = 'asc',
  });
}

class AnnouncementDeleteRequested extends AnnouncementEvent {
  final String id;
  AnnouncementDeleteRequested(this.id);
}

class AnnouncementUpdateRequested extends AnnouncementEvent {
  final String id;
  final String departureCity;
  final String arrivalCity;
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

  AnnouncementUpdateRequested({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
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
  });
}
