import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Corps d'une création de trajet (`POST /announcements`), et de chaque étape
/// d'un voyage (`POST /announcements/trips`, FLUTTER-4D) : une étape est une
/// annonce ordinaire, son corps est donc le même.
class AnnouncementPayload extends Equatable {
  const AnnouncementPayload({
    required this.departureCity,
    required this.arrivalCity,
    this.departureCountryCode,
    this.arrivalCountryCode,
    required this.departureDate,
    this.departureTime,
    this.arrivalTime,
    this.arrivalDate,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.availableKg,
    required this.pricePerKg,
    required this.transportMode,
    this.stops,
    this.description,
    this.acceptedContentTypes = const [],
    this.refusedTypes = const [],
    this.acceptedPaymentMethods = const ['STRIPE'],
    this.capacityUnit,
    this.pricingMode = 'KG',
    required this.handoverDeadline,
    this.negotiable = false,
    this.saveAsDraft = false,
    this.currency,
  });

  final String departureCity;
  final String arrivalCity;
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime departureDate;
  final String? departureTime;
  final String? arrivalTime;
  final String? arrivalDate;
  final AddressData pickupAddress;
  final AddressData deliveryAddress;
  final double availableKg;
  final double pricePerKg;
  final TransportMode transportMode;

  /// Escales (FLUTTER-GE), envoyées seulement pour un trajet en avion.
  final TripStops? stops;
  final String? description;
  final List<String> acceptedContentTypes;
  final List<String> refusedTypes;
  final List<String> acceptedPaymentMethods;
  final String? capacityUnit;
  final String pricingMode;
  final DateTime handoverDeadline;
  final bool negotiable;
  final bool saveAsDraft;
  final String? currency;

  Map<String, dynamic> toJson() => {
    'departureCity': departureCity,
    'arrivalCity': arrivalCity,
    'departureCountryCode': ?departureCountryCode,
    'arrivalCountryCode': ?arrivalCountryCode,
    'departureDate': DateFormat('yyyy-MM-dd').format(departureDate),
    'departureTime': ?departureTime,
    'arrivalTime': ?arrivalTime,
    'arrivalDate': ?arrivalDate,
    'pickupAddress': pickupAddress.toJson(),
    'deliveryAddress': deliveryAddress.toJson(),
    'availableKg': availableKg,
    'pricePerKg': pricePerKg,
    'transportMode': transportModeToWire(transportMode),
    if (stops != null && supportsStops(transportMode))
      'stopsCount': stops!.wire,
    if (description != null && description!.isNotEmpty)
      'description': description,
    'acceptedContentTypes': acceptedContentTypes,
    'refusedTypes': refusedTypes,
    'acceptedPaymentMethods': acceptedPaymentMethods,
    'capacityUnit': ?capacityUnit,
    'pricingMode': pricingMode,
    'handoverDeadline': handoverDeadline.toUtc().toIso8601String(),
    'negotiable': negotiable,
    if (saveAsDraft) 'saveAsDraft': true,
    // Optionnelle : absente, l'API retombe sur la devise du portefeuille du
    // créateur (cf. plan devise-par-annonce, tâche 5).
    'currency': ?currency,
  };

  @override
  List<Object?> get props => [toJson()];
}
