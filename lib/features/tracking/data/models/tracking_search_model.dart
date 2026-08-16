class TrackingSearchModel {
  final String trackingNumber;
  final String bidId;
  final String departureCity;
  final String arrivalCity;
  final String currentStep;
  final String stepLabel;
  final String paymentStatus;
  final String? arrivalInstructions;

  const TrackingSearchModel({
    required this.trackingNumber,
    required this.bidId,
    required this.departureCity,
    required this.arrivalCity,
    required this.currentStep,
    required this.stepLabel,
    required this.paymentStatus,
    this.arrivalInstructions,
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
      );
}
