import 'package:equatable/equatable.dart';

/// Demande colis scorée renvoyée par les matchs d'une alerte corridor.
/// Mappe le même contrat de résultat que le backend expose pour les alertes.
class MatchingRequestModel extends Equatable {
  const MatchingRequestModel({
    required this.id,
    this.tripId,
    this.tripCorridor,
    this.tripDepartureDate,
    this.tripAvailableKg,
    required this.senderId,
    required this.senderName,
    required this.senderInitials,
    required this.senderRating,
    required this.senderTotalSent,
    required this.weightKg,
    this.contentType,
    this.budgetPerKg,
    this.packagePhotoUrl,
    this.messageExcerpt,
    required this.matchScore,
    required this.requestedAt,
    this.currency = 'EUR',
  });

  final String id;
  final String? tripId;
  final String? tripCorridor;
  final DateTime? tripDepartureDate;
  final double? tripAvailableKg;
  final String senderId;
  final String senderName;
  final String senderInitials;
  final double senderRating;
  final int senderTotalSent;
  final double weightKg;
  final String? contentType;
  final double? budgetPerKg;
  final String? packagePhotoUrl;
  final String? messageExcerpt;
  final int matchScore;
  final DateTime requestedAt;
  final String currency;

  factory MatchingRequestModel.fromJson(Map<String, dynamic> json) =>
      MatchingRequestModel(
        id: json['id'] as String,
        tripId: json['tripId'] as String?,
        tripCorridor: json['tripCorridor'] as String?,
        tripDepartureDate: json['tripDepartureDate'] == null
            ? null
            : DateTime.parse(json['tripDepartureDate'] as String),
        tripAvailableKg: (json['tripAvailableKg'] as num?)?.toDouble(),
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        senderInitials: json['senderInitials'] as String,
        senderRating: (json['senderRating'] as num).toDouble(),
        senderTotalSent: (json['senderTotalSent'] as num).toInt(),
        weightKg: (json['weightKg'] as num).toDouble(),
        contentType: json['contentType'] as String?,
        budgetPerKg: (json['budgetPerKg'] as num?)?.toDouble(),
        packagePhotoUrl: json['packagePhotoUrl'] as String?,
        messageExcerpt: json['messageExcerpt'] as String?,
        matchScore: (json['matchScore'] as num).toInt(),
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        currency: json['currency'] as String? ?? 'EUR',
      );

  @override
  List<Object?> get props => [
    id,
    tripId,
    tripCorridor,
    tripDepartureDate,
    tripAvailableKg,
    senderId,
    senderName,
    senderInitials,
    senderRating,
    senderTotalSent,
    weightKg,
    contentType,
    budgetPerKg,
    packagePhotoUrl,
    messageExcerpt,
    matchScore,
    requestedAt,
    currency,
  ];
}
