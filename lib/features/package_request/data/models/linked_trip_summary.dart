import 'package:equatable/equatable.dart';

class LinkedTripSummary extends Equatable {
  const LinkedTripSummary({
    required this.announcementId,
    required this.departureCity,
    required this.arrivalCity,
    this.departureDate,
    this.departureTime,
    this.transportMode,
    this.pickupAddressLabel,
    this.deliveryAddressLabel,
    required this.availableKg,
    this.capacityUnit,
    this.description,
  });

  final String announcementId;
  final String departureCity;
  final String arrivalCity;
  final String? departureDate;    // "2026-06-12"
  final String? departureTime;    // "14:30"
  final String? transportMode;    // "PLANE" | "TRAIN" | "CAR"
  final String? pickupAddressLabel;
  final String? deliveryAddressLabel;
  final int availableKg;
  final String? capacityUnit;    // "SUITCASE_23KG" | "KG_FREE" | ...
  final String? description;

  bool get isKgFree => capacityUnit == 'KG_FREE';

  factory LinkedTripSummary.fromJson(Map<String, dynamic> json) =>
      LinkedTripSummary(
        announcementId: json['announcementId'] as String,
        departureCity: json['departureCity'] as String,
        arrivalCity: json['arrivalCity'] as String,
        departureDate: json['departureDate'] as String?,
        departureTime: json['departureTime'] as String?,
        transportMode: json['transportMode'] as String?,
        pickupAddressLabel: json['pickupAddressLabel'] as String?,
        deliveryAddressLabel: json['deliveryAddressLabel'] as String?,
        availableKg: (json['availableKg'] as num?)?.toInt() ?? 0,
        capacityUnit: json['capacityUnit'] as String?,
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [
        announcementId, departureCity, arrivalCity,
        departureDate, departureTime, transportMode,
        pickupAddressLabel, deliveryAddressLabel,
        availableKg, capacityUnit, description,
      ];
}
