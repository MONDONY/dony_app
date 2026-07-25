import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
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
  @JsonValue('REFUND_FAILED') refundFailed,
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
  /// L'expéditeur est joignable : l'UI peut afficher le bouton d'appel. Le numéro
  /// lui-même s'obtient au tap via `GET /bids/{id}/contact` — il ne transite plus
  /// dans les réponses de liste.
  final bool senderPhoneAvailable;
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
  // Instant canonique de départ (date + heure, fuseau ville de départ).
  // Référence du verrou d'annulation après remise.
  final DateTime? departureAt;
  final String? arrivalTime;
  final double? pricePerKg;

  /// Tarif/kg BRUT affiché à l'expéditeur (net + commission). L'API ne renvoie
  /// pas le tarif net à l'expéditeur ; ce champ est la source côté sender.
  final double? pricePerKgSenderEur;

  /// Tarif/kg à afficher à l'EXPÉDITEUR (brut). Préfère [pricePerKgSenderEur]
  /// (le backend ne renvoie pas le net au sender), sinon dérive de [pricePerKg].
  double? get senderPricePerKg =>
      pricePerKgSenderEur ??
      (pricePerKg != null ? netToSenderPrice(pricePerKg!) : null);
  final String? trackingNumber;
  final String? trackingToken;
  final String? confirmationCode;
  final String? travelerId;
  final String? travelerName;
  /// Idem [senderPhoneAvailable], côté voyageur.
  final bool travelerPhoneAvailable;
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

  // Rematch automatique (annulation par le voyageur AVANT remise uniquement —
  // jamais pour no-show ou après-remise). `tripCancellationId` pointe vers
  // l'annulation source, `tripCancellationRematchStatus` vaut 'SUGGESTED'
  // quand des trajets alternatifs sont proposés à l'expéditeur.
  final String? tripCancellationId;
  final String? tripCancellationRematchStatus;

  // Signalement d'absence à la livraison (no-show réception, distinct de
  // cancellationNoShowStatus qui couvre l'absence à la remise/avant départ).
  final String? deliveryNoShowStatus;
  final DateTime? deliveryNoShowContestationDeadline;
  final bool? deliveryNoShowReportedByTraveler;

  // Annulation après remise (D5/D7) : code de retour détenu par l'expéditeur, saisi
  // par le voyageur pour confirmer la restitution physique du colis.
  // `returnCode` n'est renseigné par le backend que pour l'expéditeur (sender-gated).
  final String? returnCode;
  final DateTime? returnDeadline;
  final DateTime? returnedAt;

  final BidPricingMode pricingMode;

  /// Net reçu par le voyageur, calculé côté backend (somme des items de grille +
  /// part au kilo). Le backend l'expose sous la clé `totalNetAmountEur` ; sans ce
  /// mapping le champ restait null en mode grille (pricePerKg=0) → "0 €"/"—".
  @JsonKey(name: 'totalNetAmountEur')
  final double? totalAmountEur;

  /// Montant total payé par l'EXPÉDITEUR : net voyageur + commission Dony pour un
  /// paiement Stripe, égal au net pour le cash (la commission est alors prélevée
  /// au voyageur). À afficher côté expéditeur (« payé / séquestré / remboursé »)
  /// au lieu de [totalAmountEur] qui est le net reçu par le voyageur.
  final double? totalSenderAmountEur;

  /// Code promo entré par l'expéditeur à la création du bid (nullable).
  final String? promoCode;

  /// ID du code promo figé au moment du paiement (nullable, UUID string).
  @JsonKey(name: 'promoCodeId')
  final String? promoCodeId;

  /// URL de l'avatar de l'expéditeur (nullable, fourni par le backend).
  final String? senderAvatarUrl;

  /// URL de l'avatar du voyageur (nullable, fourni par le backend).
  final String? travelerAvatarUrl;

  /// Photos du colis (présignées, ACTIVE). Vide si aucune ou après passage DELETING serveur.
  @JsonKey(defaultValue: <BidPhoto>[])
  final List<BidPhoto> photos;

  const BidModel({
    required this.id,
    required this.announcementId,
    required this.senderId,
    this.senderName,
    this.senderPhoneAvailable = false,
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
    this.departureAt,
    this.arrivalTime,
    this.pricePerKg,
    this.pricePerKgSenderEur,
    this.trackingNumber,
    this.trackingToken,
    this.confirmationCode,
    this.travelerId,
    this.travelerName,
    this.travelerPhoneAvailable = false,
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
    this.tripCancellationId,
    this.tripCancellationRematchStatus,
    this.deliveryNoShowStatus,
    this.deliveryNoShowContestationDeadline,
    this.deliveryNoShowReportedByTraveler,
    this.returnCode,
    this.returnDeadline,
    this.returnedAt,
    this.pricingMode = BidPricingMode.kg,
    this.totalAmountEur,
    this.totalSenderAmountEur,
    this.promoCode,
    this.promoCodeId,
    this.senderAvatarUrl,
    this.travelerAvatarUrl,
    this.photos = const [],
  });

  factory BidModel.fromJson(Map<String, dynamic> json) =>
      _$BidModelFromJson(json);

  Map<String, dynamic> toJson() => _$BidModelToJson(this);

  /// Instant de départ canonique. Le backend l'envoie (`departureAt`) ; fallback
  /// par fusion `departureDate` + `departureTime` ("HH:mm") pour les anciens payloads.
  DateTime? get resolvedDepartureAt {
    if (departureAt != null) return departureAt;
    if (departureDate == null || departureTime == null) return null;
    final parts = departureTime!.split(':');
    if (parts.length < 2) return departureDate;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateTime(
        departureDate!.year, departureDate!.month, departureDate!.day, h, m);
  }

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

  /// Le colis a été restitué (le voyageur a saisi le code de retour).
  bool get isParcelReturned => returnedAt != null;

  /// Annulation après remise en attente de restitution : un délai de retour existe
  /// et le colis n'a pas encore été rendu.
  bool get isAwaitingReturn => returnDeadline != null && returnedAt == null;

  /// Annulation AVANT remise possible côté expéditeur : offre soumise/payée
  /// (en séquestre Stripe) ou acceptée par le voyageur, mais colis pas encore
  /// remis. Couvre l'ancien statut `PENDING` (legacy, conservé par sécurité),
  /// le statut Stripe `PAYMENT_ESCROWED` et `ACCEPTED`. Le serveur
  /// (CancellationGuard) reste l'autorité — il rembourse l'expéditeur.
  bool get canCancelBeforeHandover =>
      status == 'PENDING' ||
      status == 'PAYMENT_ESCROWED' ||
      status == 'ACCEPTED';

  /// Annulation après remise possible (D3) : colis remis ET départ canonique pas
  /// encore atteint. Source unique du verrou côté client (le serveur via
  /// CancellationGuard reste l'autorité). Consommé par les options sheets voyageur
  /// et expéditeur.
  bool get canCancelAfterHandover =>
      status == 'HANDED_OVER' &&
      (resolvedDepartureAt == null ||
          DateTime.now().isBefore(resolvedDepartureAt!));

  /// Signalement d'absence à la livraison possible : bid IN_TRANSIT, trajet
  /// déjà parti, aucun signalement en cours ou contesté sur ce bid.
  bool get canReportDeliveryNoShow =>
      status == 'IN_TRANSIT' &&
      deliveryNoShowStatus == null &&
      resolvedDepartureAt != null &&
      DateTime.now().isAfter(resolvedDepartureAt!);

  /// Nom à afficher pour l'expéditeur. Le téléphone ne sert plus de repli : il
  /// n'est plus dans la réponse, et un numéro affiché en guise de nom se lisait mal.
  String get resolvedSenderName {
    if (senderName != null && senderName!.isNotEmpty) return senderName!;
    return 'Expéditeur';
  }
}
