import 'package:equatable/equatable.dart';

/// Détails du trajet lié à une négociation.
///
/// Mappé sur le record backend `LinkedTripSummary` exposé dans
/// `NegotiationThreadResponse.linkedTrip`. Tous les champs sont optionnels
/// sauf [announcementId] — le backend peut ne pas tous les renseigner.
class LinkedTripSummary extends Equatable {
  const LinkedTripSummary({
    required this.announcementId,
    this.departureCity,
    this.arrivalCity,
    this.departureDate,
    this.departureTime,
    this.transportMode,
    this.pickupAddressLabel,
    this.deliveryAddressLabel,
    this.availableKg,
    this.description,
  });

  final String announcementId;
  final String? departureCity;
  final String? arrivalCity;

  /// Date ISO `"2026-06-12"`.
  final String? departureDate;

  /// Heure `"14:30"`.
  final String? departureTime;

  /// `"PLANE"` | `"TRAIN"` | `"CAR"`.
  final String? transportMode;

  final String? pickupAddressLabel;
  final String? deliveryAddressLabel;
  final int? availableKg;
  final String? description;

  factory LinkedTripSummary.fromJson(Map<String, dynamic> json) =>
      LinkedTripSummary(
        announcementId: json['announcementId'] as String,
        departureCity: json['departureCity'] as String?,
        arrivalCity: json['arrivalCity'] as String?,
        departureDate: json['departureDate'] as String?,
        departureTime: json['departureTime'] as String?,
        transportMode: json['transportMode'] as String?,
        pickupAddressLabel: json['pickupAddressLabel'] as String?,
        deliveryAddressLabel: json['deliveryAddressLabel'] as String?,
        availableKg: (json['availableKg'] as num?)?.toInt(),
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [
        announcementId,
        departureCity,
        arrivalCity,
        departureDate,
        departureTime,
        transportMode,
        pickupAddressLabel,
        deliveryAddressLabel,
        availableKg,
        description,
      ];
}
