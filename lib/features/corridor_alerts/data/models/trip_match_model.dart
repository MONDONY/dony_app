import 'package:equatable/equatable.dart';

/// Match « trajet » d'une alerte corridor (direction senderWantsTrips).
/// Mappe `AlertTripMatchDto` (sous-ensemble de l'annonce voyageur).
class TripMatchModel extends Equatable {
  const TripMatchModel({
    required this.announcementId,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.travelerId,
    required this.travelerName,
    required this.travelerInitials,
    required this.travelerRating,
    required this.availableKg,
    this.pricePerKg,
    this.transportMode,
    this.photoUrl,
    this.currency = 'EUR',
    this.publishedAt,
  });

  final String announcementId;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final String travelerId;
  final String travelerName;
  final String travelerInitials;
  final double travelerRating;
  final double availableKg;
  final double? pricePerKg;
  final String? transportMode;
  final String? photoUrl;
  final String currency;

  /// Publication du trajet ; sert à le classer « nouveau » ou « déjà vu »
  /// par rapport à la dernière consultation de l'alerte. `null` sur un
  /// backend antérieur : le trajet est alors considéré comme déjà vu.
  final DateTime? publishedAt;

  factory TripMatchModel.fromJson(Map<String, dynamic> json) => TripMatchModel(
    announcementId: json['announcementId'] as String,
    departureCity: json['departureCity'] as String,
    arrivalCity: json['arrivalCity'] as String,
    departureDate: DateTime.parse(json['departureDate'] as String),
    travelerId: json['travelerId'] as String,
    travelerName: json['travelerName'] as String,
    travelerInitials: json['travelerInitials'] as String,
    travelerRating: (json['travelerRating'] as num).toDouble(),
    availableKg: (json['availableKg'] as num).toDouble(),
    pricePerKg: (json['pricePerKg'] as num?)?.toDouble(),
    transportMode: json['transportMode'] as String?,
    photoUrl: json['photoUrl'] as String?,
    currency: json['currency'] as String? ?? 'EUR',
    publishedAt: json['publishedAt'] != null
        ? DateTime.parse(json['publishedAt'] as String)
        : null,
  );

  @override
  List<Object?> get props => [
    announcementId,
    departureCity,
    arrivalCity,
    departureDate,
    travelerId,
    travelerName,
    travelerInitials,
    travelerRating,
    availableKg,
    pricePerKg,
    transportMode,
    photoUrl,
    currency,
    publishedAt,
  ];
}
