import 'package:json_annotation/json_annotation.dart';

part 'bid_model.g.dart';

@JsonSerializable()
class BidModel {
  final String id;
  final String announcementId;
  final String senderId;
  final String? senderName;
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

  const BidModel({
    required this.id,
    required this.announcementId,
    required this.senderId,
    this.senderName,
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
  });

  factory BidModel.fromJson(Map<String, dynamic> json) =>
      _$BidModelFromJson(json);

  Map<String, dynamic> toJson() => _$BidModelToJson(this);
}
