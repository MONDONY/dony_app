import 'package:json_annotation/json_annotation.dart';

part 'bid_model.g.dart';

@JsonSerializable()
class BidModel {
  final String id;
  final String announcementId;
  final String senderId;
  final String? senderName;
  final String? senderPhone;
  final double weightKg;
  final double declaredValueEur;
  final String description;
  final String? contentCategory;
  final String? recipientName;
  final String? recipientPhone;
  final String status;
  final String? rejectionReason;
  final String? handoverLocation;
  final DateTime? handoverWindowStart;
  final DateTime? handoverWindowEnd;
  final bool voyageurConfirmed;
  final DateTime? disclaimerSignedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDate;
  final String? departureTime;
  final String? arrivalTime;
  final double? pricePerKg;
  final String? trackingNumber;
  final String? confirmationCode;

  const BidModel({
    required this.id,
    required this.announcementId,
    required this.senderId,
    this.senderName,
    this.senderPhone,
    required this.weightKg,
    required this.declaredValueEur,
    required this.description,
    this.contentCategory,
    this.recipientName,
    this.recipientPhone,
    required this.status,
    this.rejectionReason,
    this.handoverLocation,
    this.handoverWindowStart,
    this.handoverWindowEnd,
    this.voyageurConfirmed = false,
    this.disclaimerSignedAt,
    required this.createdAt,
    required this.updatedAt,
    this.departureCity,
    this.arrivalCity,
    this.departureDate,
    this.departureTime,
    this.arrivalTime,
    this.pricePerKg,
    this.trackingNumber,
    this.confirmationCode,
  });

  factory BidModel.fromJson(Map<String, dynamic> json) =>
      _$BidModelFromJson(json);

  Map<String, dynamic> toJson() => _$BidModelToJson(this);

  /// Nom à afficher pour l'expéditeur (même logique que TravelerProfile.resolvedName).
  /// Si le nom est défini → retourne le nom (le téléphone est géré séparément dans l'UI).
  /// Si le nom est null → retourne le téléphone.
  /// Si les deux sont null → retourne 'Expéditeur'.
  String get resolvedSenderName {
    if (senderName != null && senderName!.isNotEmpty) return senderName!;
    if (senderPhone != null && senderPhone!.isNotEmpty) return senderPhone!;
    return 'Expéditeur';
  }
}
