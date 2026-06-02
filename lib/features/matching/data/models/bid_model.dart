import 'package:json_annotation/json_annotation.dart';

part 'bid_model.g.dart';

enum BidPaymentMethod {
  @JsonValue('STRIPE') stripe,
  @JsonValue('CASH') cash,
  @JsonValue('WAVE') wave,
  @JsonValue('ORANGE_MONEY') orangeMoney,
}

/// Extension exposing the canonical API string value for each [BidPaymentMethod].
///
/// Delegates to the json_serializable-generated [_$BidPaymentMethodEnumMap] so
/// the mapping is always in sync with the @JsonValue annotations — no manual
/// string manipulation needed in datasources.
extension BidPaymentMethodApi on BidPaymentMethod {
  /// Returns the `@JsonValue` string that must be sent to the API.
  /// e.g. [BidPaymentMethod.orangeMoney] → `'ORANGE_MONEY'`
  String get apiValue => _$BidPaymentMethodEnumMap[this]!;
}

enum CommissionStatus {
  @JsonValue('PENDING') pending,
  @JsonValue('REQUIRES_3DS') requires3ds,
  @JsonValue('CHARGED') charged,
  @JsonValue('FAILED') failed,
  @JsonValue('REFUNDED') refunded,
}

enum BidPricingMode {
  @JsonValue('KG') kg,
  @JsonValue('GRID') grid,
  @JsonValue('MIXED') mixed,
}

@JsonSerializable()
class BidModel {
  final String id;
  final String announcementId;
  final String senderId;
  final String? senderName;
  final String? senderPhone;
  final int? senderTotalShipments;
  final bool senderKycVerified;
  final bool senderIsProAccount;
  final bool senderKiloPro;
  final double? weightKg;
  // Nullable: bids issued from the package_request marketplace flow have
  // null declared value until the sender completes the post-acceptance details.
  final double? declaredValueEur;
  // Nullable for the same reason — request.description is optional.
  final String? description;
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
  final String? trackingToken;
  final String? confirmationCode;
  final String? travelerId;
  final String? travelerName;
  final String? travelerPhone;
  final bool travelerKycVerified;
  final bool travelerIsProAccount;
  final bool travelerKiloPro;
  final int? travelerTotalTrips;
  final double? travelerAverageRating;
  final bool senderHasRated;
  final bool travelerHasRated;
  final int confirmationCodeRefreshCount;
  final DateTime? confirmationCodeRefreshWindowStart;
  final BidPaymentMethod paymentMethod;
  final CommissionStatus? commissionStatus;
  final String? cancellationNoShowStatus;
  final DateTime? contestationDeadline;
  final BidPricingMode pricingMode;
  final double? totalAmountEur;

  /// Code promo entré par l'expéditeur à la création du bid (nullable).
  final String? promoCode;

  /// ID du code promo figé au moment du paiement (nullable, UUID string).
  @JsonKey(name: 'promoCodeId')
  final String? promoCodeId;

  const BidModel({
    required this.id,
    required this.announcementId,
    required this.senderId,
    this.senderName,
    this.senderPhone,
    this.senderTotalShipments,
    this.senderKycVerified = false,
    this.senderIsProAccount = false,
    this.senderKiloPro = false,
    this.weightKg,
    this.declaredValueEur,
    this.description,
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
    this.trackingToken,
    this.confirmationCode,
    this.travelerId,
    this.travelerName,
    this.travelerPhone,
    this.travelerKycVerified = false,
    this.travelerIsProAccount = false,
    this.travelerKiloPro = false,
    this.travelerTotalTrips,
    this.travelerAverageRating,
    this.senderHasRated = false,
    this.travelerHasRated = false,
    this.confirmationCodeRefreshCount = 0,
    this.confirmationCodeRefreshWindowStart,
    this.paymentMethod = BidPaymentMethod.stripe,
    this.commissionStatus,
    this.cancellationNoShowStatus,
    this.contestationDeadline,
    this.pricingMode = BidPricingMode.kg,
    this.totalAmountEur,
    this.promoCode,
    this.promoCodeId,
  });

  factory BidModel.fromJson(Map<String, dynamic> json) =>
      _$BidModelFromJson(json);

  Map<String, dynamic> toJson() => _$BidModelToJson(this);

  /// Minimal placeholder used when navigating from a deep-link (no BidModel in extra).
  /// The screen fetches the real data immediately via BidDetailRequested.
  factory BidModel.skeleton(String id) => BidModel(
        id: id,
        announcementId: '',
        senderId: '',
        weightKg: 0,
        status: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get isSkeleton => senderId.isEmpty;

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
