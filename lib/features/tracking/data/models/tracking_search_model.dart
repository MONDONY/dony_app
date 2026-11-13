import 'package:dony/features/matching/data/models/transport_mode.dart';

class TrackingSearchModel {
  final String trackingNumber;
  final String bidId;
  final String departureCity;
  final String arrivalCity;
  final String currentStep;
  final String stepLabel;
  final String paymentStatus;
  final String? arrivalInstructions;

  /// Mode du trajet qui porte le colis (`transportMode` du back, lot 3).
  /// `null` quand le back ne le connaît pas, ne le sert pas encore (back
  /// antérieur) ou sert un mode que l'app ne connaît pas : jamais un avion
  /// supposé, l'appelant choisit l'icône neutre.
  final TransportMode? transportMode;

  const TrackingSearchModel({
    required this.trackingNumber,
    required this.bidId,
    required this.departureCity,
    required this.arrivalCity,
    required this.currentStep,
    required this.stepLabel,
    required this.paymentStatus,
    this.arrivalInstructions,
    this.transportMode,
  });

  factory TrackingSearchModel.fromJson(Map<String, dynamic> json) =>
      TrackingSearchModel(
        trackingNumber: json['trackingNumber'] as String,
        bidId: json['bidId'] as String,
        departureCity: json['departureCity'] as String,
        arrivalCity: json['arrivalCity'] as String,
        currentStep: json['currentStep'] as String,
        stepLabel: json['stepLabel'] as String,
        paymentStatus: json['paymentStatus'] as String,
        arrivalInstructions: json['arrivalInstructions'] as String?,
        transportMode: transportModeFromWire(
          json['transportMode'] is String
              ? json['transportMode'] as String
              : null,
        ),
      );
}
