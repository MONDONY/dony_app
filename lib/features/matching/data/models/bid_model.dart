import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bid_model.g.dart';

enum BidPaymentMethod {
  @JsonValue('STRIPE')
  stripe,
  @JsonValue('CASH')
  cash,
  @JsonValue('WAVE')
  wave,
  @JsonValue('ORANGE_MONEY')
  orangeMoney,
  @JsonValue('MOBILE_MONEY')
  mobileMoney,
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

  /// Valeur reçue de l'API, ou null si l'app ne la connaît pas encore :
  /// une nouvelle méthode côté backend ne doit jamais faire planter un parsing.
  static BidPaymentMethod? fromApi(String? raw) {
    if (raw == null) return null;
    for (final entry in _$BidPaymentMethodEnumMap.entries) {
      if (entry.value == raw) return entry.key;
    }
    return null;
  }
}

/// Rails de paiement par devise, miroir de `CurrencyPaymentRails` côté backend :
/// la carte n'existe pas en zone CFA (pas de Stripe Connect), le mobile money
/// n'existe qu'en zone CFA. Le backend reste l'autorité (il filtre les moyens
/// d'une annonce à l'écriture et refuse un checkout carte hors rail) ; ce filtre
/// évite de proposer un moyen que la demande ne pourra jamais honorer. Recette du
/// 2026-09-09 : une annonce XOF proposait la carte et le séquestre Stripe partait
/// en euros pour un montant en francs CFA.
extension BidPaymentMethodRails on BidPaymentMethod {
  /// Vrai si ce moyen de paiement existe dans la devise [currency] (code ISO,
  /// repli euro comme le backend quand il manque ou n'est pas connu).
  bool isAllowedIn(String? currency) {
    final resolved = SupportedCurrency.fromCodeOrDefault(
      currency?.toUpperCase(),
    );
    final cfa =
        resolved == SupportedCurrency.xof || resolved == SupportedCurrency.xaf;
    return switch (this) {
      BidPaymentMethod.cash => true,
      BidPaymentMethod.stripe => !cfa,
      BidPaymentMethod.mobileMoney => cfa,
      BidPaymentMethod.wave || BidPaymentMethod.orangeMoney => false,
    };
  }
}

/// Parsing tolérant de `acceptedPaymentMethods` : valeurs inconnues ignorées,
/// liste absente = carte (comportement historique).
Set<BidPaymentMethod> acceptedPaymentMethodsFromJson(Object? raw) {
  if (raw is! List) return const {BidPaymentMethod.stripe};
  return {for (final v in raw) ?BidPaymentMethodApi.fromApi(v as String?)};
}

enum CommissionStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('REQUIRES_3DS')
  requires3ds,
  @JsonValue('CHARGED')
  charged,
  @JsonValue('FAILED')
  failed,
  @JsonValue('REFUNDED')
  refunded,
  @JsonValue('REFUND_FAILED')
  refundFailed,
}

enum BidPricingMode {
  @JsonValue('KG')
  kg,
  @JsonValue('GRID')
  grid,
  @JsonValue('MIXED')
  mixed,
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

  /// Fenêtre de contact téléphonique ouverte (yadony-back #414, FLUTTER-DK) :
  /// de ACCEPTED à ARRIVED, puis en COMPLETED jusqu'à J+3 après la livraison,
  /// même règle que l'appel in-app. Nul pour un back antérieur : l'UI retombe
  /// alors sur la règle de statut locale.
  final bool? contactWindowOpen;
  final int? senderTotalShipments;

  /// Fiabilité de l'expéditeur (FLUTTER-E0/E6) : annulations après acceptation
  /// et absences au rendez-vous de remise confirmées. Nul sur un back antérieur.
  final int? senderIncidentCount;
  final bool senderKycVerified;
  final bool senderIsProAccount;
  final bool senderKiloPro;
  final double? weightKg;
  // Nullable for the same reason — request.description is optional.
  final String? description;
  final String? contentCategory;
  final String? recipientName;
  final String? recipientPhone;

  /// Lien du destinataire dans Yadony (lot 2), visible par l'expéditeur
  /// seulement : `PENDING`, `CONFIRMED` (il suit le colis dans l'app),
  /// `DECLINED` (le titulaire du numéro dit que le colis n'est pas pour lui).
  /// `null` sans compte rattaché, pour le voyageur, ou sur un back antérieur.
  final String? recipientAppStatus;

  /// Vue voyageur : le destinataire inscrit a masqué son numéro
  /// ([recipientPhone] est alors `null`) ; il se joint par la messagerie de
  /// l'app seulement (Sentry FLUTTER-6J). `false` sur un back antérieur.
  @JsonKey(defaultValue: false)
  final bool recipientPhoneHidden;

  /// Vue voyageur : le destinataire a refusé le colis ou s'en est retiré (lien
  /// `DECLINED`, yadony-back #412). [recipientName] et [recipientPhone] sont
  /// alors `null` : le voyageur peut demander à l'expéditeur d'en désigner un
  /// autre. Toujours `false` pour l'expéditeur (il lit [recipientAppStatus]) et
  /// sur un back antérieur.
  @JsonKey(defaultValue: false)
  final bool recipientDeclined;

  /// Dernière demande de remplacement faite par le voyageur depuis le refus en
  /// cours (UTC). Une nouvelle demande est possible 12 h après. `null` sans
  /// demande, hors refus ou sur un back antérieur.
  final DateTime? recipientReplacementRequestedAt;
  final String status;
  final String? rejectionReason;
  final String? handoverLocation;

  /// Date limite de dépôt héritée du trajet à l'acceptation.
  final DateTime? handoverDeadline;
  final bool voyageurConfirmed;
  final DateTime? disclaimerSignedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? departureCity;
  final String? arrivalCity;

  /// Instructions d'arrivée laissées par le voyageur pour l'expéditeur (ex :
  /// point de rendez-vous précis, consignes de retrait). Facultatif, hérité
  /// du trajet à l'acceptation.
  final String? arrivalInstructions;
  final DateTime? departureDate;
  final String? departureTime;
  // Instant canonique de départ (date + heure, fuseau ville de départ).
  // Référence du verrou d'annulation après remise.
  final DateTime? departureAt;
  final String? arrivalTime;
  // Date d'arrivée si différente du départ (vol de nuit) ; null = même jour.
  final DateTime? arrivalDate;
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
  final bool confirmationCodePublicEnabled;
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
  @JsonKey(unknownEnumValue: BidPaymentMethod.stripe)
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

  /// Montant total payé par l'EXPÉDITEUR : net voyageur + commission Yadony pour un
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

  /// Devise du bid, héritée de l'annonce à la création. `EUR` par défaut pour
  /// les anciens payloads sans ce champ.
  @JsonKey(defaultValue: 'EUR')
  final String currency;

  /// Dernier report du trajet et réponse attendue de l'expéditeur. Nul si le
  /// trajet n'a jamais été reporté (ou back antérieur au report de trajet).
  final TripRescheduleInfo? reschedule;

  /// Lieu de remise du colis au voyageur, avec ses coordonnées (adresse de
  /// départ du trajet). Nul sur un back antérieur : la carte Lieux est alors
  /// masquée.
  final AddressData? handoverAddress;

  /// Lieu où le destinataire récupère le colis à l'arrivée (adresse d'arrivée
  /// du trajet). Nul pour une demande sortie de la course ou un back antérieur.
  final AddressData? deliveryAddress;

  const BidModel({
    required this.id,
    required this.announcementId,
    required this.senderId,
    this.senderName,
    this.senderPhoneAvailable = false,
    this.contactWindowOpen,
    this.senderTotalShipments,
    this.senderIncidentCount,
    this.senderKycVerified = false,
    this.senderIsProAccount = false,
    this.senderKiloPro = false,
    this.weightKg,
    this.description,
    this.contentCategory,
    this.recipientName,
    this.recipientPhone,
    this.recipientAppStatus,
    this.recipientPhoneHidden = false,
    this.recipientDeclined = false,
    this.recipientReplacementRequestedAt,
    required this.status,
    this.rejectionReason,
    this.handoverLocation,
    this.handoverDeadline,
    this.voyageurConfirmed = false,
    this.disclaimerSignedAt,
    required this.createdAt,
    required this.updatedAt,
    this.departureCity,
    this.arrivalCity,
    this.arrivalInstructions,
    this.departureDate,
    this.departureTime,
    this.departureAt,
    this.arrivalTime,
    this.arrivalDate,
    this.pricePerKg,
    this.pricePerKgSenderEur,
    this.trackingNumber,
    this.trackingToken,
    this.confirmationCode,
    this.confirmationCodePublicEnabled = false,
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
    this.currency = 'EUR',
    this.reschedule,
    this.handoverAddress,
    this.deliveryAddress,
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
      departureDate!.year,
      departureDate!.month,
      departureDate!.day,
      h,
      m,
    );
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

  /// Colis remis au voyageur mais sans code de retrait : le serveur l'a effacé
  /// après trois essais faux ou à l'expiration (FLUTTER-G1). Seul l'expéditeur
  /// peut en générer un nouveau (`POST /tracking/{bidId}/refresh-code`).
  bool get needsNewPickupCode =>
      (confirmationCode == null || confirmationCode!.isEmpty) &&
      const {'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED'}.contains(status);

  /// Colis carte créé mais pas encore payé : c'est l'expéditeur qui doit agir.
  /// Le paiement le fait passer en PAYMENT_ESCROWED, et le voyageur ne peut
  /// l'accepter qu'après (BidService.doAcceptBid). Source unique pour le
  /// talon, le tampon et la carte « prochaine étape » (FLUTTER-G7).
  bool get isAwaitingSenderCardPayment =>
      status == 'PENDING' && paymentMethod == BidPaymentMethod.stripe;

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
  bool get canCancelAfterHandover => status == 'HANDED_OVER' && !hasDeparted;

  /// Délai minimal entre deux demandes de remplacement du destinataire (miroir
  /// de `RecipientReplacementService.COOLDOWN` côté back).
  static const recipientReplacementCooldown = Duration(hours: 12);

  /// Instant à partir duquel le voyageur peut redemander un autre destinataire,
  /// ou `null` si aucune demande n'a été faite depuis le refus en cours.
  DateTime? get nextRecipientReplacementAllowedAt =>
      recipientReplacementRequestedAt?.add(recipientReplacementCooldown);

  /// Le destinataire est en refus côté expéditeur (il a refusé le colis ou
  /// s'en est retiré).
  bool get isRecipientDeclinedForSender => recipientAppStatus == 'DECLINED';

  /// L'expéditeur peut changer de destinataire jusqu'à la remise : demande
  /// acceptée, colis chez le voyageur, en route ou arrivé. Miroir de la
  /// fenêtre de `PUT /bids/{id}/recipient` (le serveur reste l'autorité et
  /// répond 409 hors de ces statuts).
  bool get canChangeRecipient =>
      status == 'ACCEPTED' ||
      status == 'HANDED_OVER' ||
      status == 'IN_TRANSIT' ||
      status == 'ARRIVED';

  /// Le trajet est-il parti ? Miroir de `CancellationGuard.hasDeparted` côté
  /// serveur : heure de départ si elle est connue, sinon le lendemain de la date
  /// de départ. Le scan Transit, facultatif, ne ferme plus aucune fenêtre.
  bool get hasDeparted {
    final at = resolvedDepartureAt;
    if (at != null) return !DateTime.now().isBefore(at);
    final day = departureDate;
    if (day == null) return false;
    final now = DateTime.now();
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Signalement d'absence à la livraison possible : colis récupéré
  /// (HANDED_OVER, IN_TRANSIT ou ARRIVED), trajet déjà parti, aucun signalement
  /// en cours ou contesté sur ce bid. HANDED_OVER suit le back (#336) : le scan
  /// Transit est facultatif, un colis récupéré jamais marqué arrivé doit rester
  /// signalable.
  ///
  /// ARRIVED est inclus (miroir de `CancellationService.assertDeliveryReportable`
  /// côté backend) : les signalements d'absence à la livraison ne se déclenchent
  /// qu'à destination, donc justement sur un bid ARRIVED. Sans lui, un voyageur
  /// pourrait marquer son trajet arrivé puis ne jamais livrer, sans que
  /// l'expéditeur puisse signaler l'absence.
  bool get canReportDeliveryNoShow =>
      (status == 'HANDED_OVER' ||
          status == 'IN_TRANSIT' ||
          status == 'ARRIVED') &&
      deliveryNoShowStatus == null &&
      hasDeparted;
}
