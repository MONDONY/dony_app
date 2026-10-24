import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bid_amendment.g.dart';

/// États d'une modification de colis, miroir de `BidAmendmentStatus` côté
/// back. Un statut inconnu de l'app (back plus récent) devient [unknown] :
/// l'encart ne s'affiche pas, rien ne plante. Le statut d'une modification ne
/// change jamais celui du colis.
enum BidAmendmentStatus {
  /// Carte : le montant n'est pas encore bloqué (PaymentSheet en cours).
  @JsonValue('AUTHORIZATION_PENDING')
  authorizationPending,
  @JsonValue('PROPOSED')
  proposed,

  /// Espèces : la commission du voyageur n'est pas encore prélevée (3DS).
  @JsonValue('COMMISSION_PENDING')
  commissionPending,

  /// Mobile money : le voyageur a accepté, le dépôt de l'expéditeur attend.
  @JsonValue('PAYMENT_PENDING')
  paymentPending,
  @JsonValue('ACCEPTED')
  accepted,
  @JsonValue('PAYOUT_PENDING')
  payoutPending,
  @JsonValue('PAID_OUT')
  paidOut,
  @JsonValue('DECLINED')
  declined,
  @JsonValue('EXPIRED')
  expired,
  @JsonValue('CANCELLED')
  cancelled,
  @JsonValue('REFUND_PENDING')
  refundPending,
  @JsonValue('REFUNDED')
  refunded,
  unknown;

  /// Valeur du serveur (`AUTHORIZATION_PENDING`...).
  String get wire => switch (this) {
    authorizationPending => 'AUTHORIZATION_PENDING',
    proposed => 'PROPOSED',
    commissionPending => 'COMMISSION_PENDING',
    paymentPending => 'PAYMENT_PENDING',
    accepted => 'ACCEPTED',
    payoutPending => 'PAYOUT_PENDING',
    paidOut => 'PAID_OUT',
    declined => 'DECLINED',
    expired => 'EXPIRED',
    cancelled => 'CANCELLED',
    refundPending => 'REFUND_PENDING',
    refunded => 'REFUNDED',
    unknown => 'UNKNOWN',
  };

  /// En attente d'une autorisation, d'une réponse ou d'un paiement : une seule
  /// par colis, elle bloque la remise et finit par expirer.
  bool get isOpen =>
      this == authorizationPending ||
      this == proposed ||
      this == commissionPending ||
      this == paymentPending;

  /// Acceptée par le voyageur et pas remboursée : elle compte dans les totaux.
  bool get isSecured =>
      this == accepted || this == payoutPending || this == paidOut;

  /// Close sans avoir été acquise : refusée, expirée, retirée ou remboursée.
  bool get isClosedUnaccepted =>
      this == declined ||
      this == expired ||
      this == cancelled ||
      this == refundPending ||
      this == refunded;
}

/// Article de grille ajouté par une modification. [netAmount] est nul pour
/// l'expéditeur, qui ne voit que le brut.
@JsonSerializable()
class BidAmendmentItem {
  const BidAmendmentItem({
    required this.label,
    required this.quantity,
    required this.grossAmount,
    this.netAmount,
  });

  final String label;
  final int quantity;
  final double grossAmount;
  final double? netAmount;

  factory BidAmendmentItem.fromJson(Map<String, dynamic> json) =>
      _$BidAmendmentItemFromJson(json);

  Map<String, dynamic> toJson() => _$BidAmendmentItemToJson(this);
}

/// Modification d'un colis accepté (kilos ou articles de grille ajoutés par
/// l'expéditeur), servie dans `BidResponse.amendments` et par les routes
/// `/bids/{bidId}/amendments`. Montants dans la devise du colis, dates en UTC.
///
/// L'expéditeur ne reçoit que le brut : [netAmount], [commissionAmount],
/// [commissionStatus] et le net de chaque article sont nuls pour lui.
@JsonSerializable()
class BidAmendment {
  const BidAmendment({
    required this.id,
    required this.status,
    this.rail,
    this.currency = 'EUR',
    this.addedWeightKg = 0,
    this.items = const [],
    required this.grossAmount,
    this.netAmount,
    this.commissionAmount,
    this.expiresAt,
    this.paymentExpiresAt,
    this.closedReason,
    this.blocksHandover = false,
    this.commissionStatus,
    this.commissionClientSecret,
  });

  static const railStripe = 'STRIPE';
  static const railPawapay = 'PAWAPAY';
  static const railCash = 'CASH';

  final String id;

  @JsonKey(unknownEnumValue: BidAmendmentStatus.unknown)
  final BidAmendmentStatus status;

  /// `STRIPE`, `PAWAPAY` ou `CASH` : le rail choisi par l'expéditeur.
  final String? rail;

  @JsonKey(defaultValue: 'EUR')
  final String currency;

  /// Kilos ajoutés ; 0 pour une modification faite d'articles seulement.
  @JsonKey(defaultValue: 0)
  final double addedWeightKg;

  @JsonKey(defaultValue: <BidAmendmentItem>[])
  final List<BidAmendmentItem> items;

  /// Total payé par l'expéditeur pour cette modification.
  final double grossAmount;

  /// Gain du voyageur. Nul côté expéditeur.
  final double? netAmount;

  /// Commission Yadony. Nulle côté expéditeur.
  final double? commissionAmount;

  /// Échéance de réponse du voyageur (UTC).
  final DateTime? expiresAt;

  /// Mobile money : échéance du dépôt de l'expéditeur après l'acceptation (UTC).
  final DateTime? paymentExpiresAt;

  /// Pourquoi elle a été close sans aboutir, sinon nul.
  final String? closedReason;

  /// Vrai tant qu'elle attend une autorisation, une réponse ou un paiement :
  /// le scan de remise (DEPART) est refusé.
  @JsonKey(defaultValue: false)
  final bool blocksHandover;

  /// Espèces, voyageur seulement : état de la commission de la modification.
  final String? commissionStatus;

  /// Espèces, voyageur seulement : client secret de la 3DS de la commission,
  /// rendu par la seule réponse qui la déclenche. Jamais réécrit en JSON : un
  /// secret de paiement ne se met pas en cache.
  @JsonKey(includeToJson: false)
  final String? commissionClientSecret;

  /// Rail espèces : l'expéditeur remet le montant en main propre.
  bool get isCash => rail == railCash;

  /// Rail carte : montant autorisé à la création, capturé à l'acceptation.
  bool get isCard => rail == railStripe;

  /// Rail mobile money : l'expéditeur dépose après l'acceptation.
  bool get isMobileMoney => rail == railPawapay;

  /// Une authentification bancaire (3DS) attend le voyageur.
  bool get needsCommissionAuth =>
      status == BidAmendmentStatus.commissionPending &&
      (commissionClientSecret?.isNotEmpty ?? false);

  /// Même modification avec le client secret de la 3DS de la commission, que
  /// le back sert à côté de la vue (réponse d'acceptation).
  BidAmendment withCommissionClientSecret(String? secret) => BidAmendment(
    id: id,
    status: status,
    rail: rail,
    currency: currency,
    addedWeightKg: addedWeightKg,
    items: items,
    grossAmount: grossAmount,
    netAmount: netAmount,
    commissionAmount: commissionAmount,
    expiresAt: expiresAt,
    paymentExpiresAt: paymentExpiresAt,
    closedReason: closedReason,
    blocksHandover: blocksHandover,
    commissionStatus: commissionStatus,
    commissionClientSecret: secret,
  );

  factory BidAmendment.fromJson(Map<String, dynamic> json) =>
      _$BidAmendmentFromJson(json);

  Map<String, dynamic> toJson() => _$BidAmendmentToJson(this);
}

/// Article de la grille du trajet que l'expéditeur peut ajouter, au prix tel
/// qu'il le voit en recherche.
class AmendmentGridItemOption {
  const AmendmentGridItemOption({
    required this.id,
    required this.label,
    required this.unitPriceDisplay,
  });

  final String id;
  final String label;
  final double unitPriceDisplay;

  factory AmendmentGridItemOption.fromJson(Map<String, dynamic> json) =>
      AmendmentGridItemOption(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        unitPriceDisplay: (json['unitPriceDisplay'] as num).toDouble(),
      );
}

/// Ce que l'expéditeur peut ajouter à son colis accepté
/// (`GET /bids/{bidId}/amendments/options`).
class AmendmentOptions {
  const AmendmentOptions({
    required this.currency,
    this.availableKg,
    this.pricePerKgDisplay,
    this.gridItems = const [],
    this.paymentMethods = const [],
    this.expiresAt,
    required this.minAmount,
    required this.maxAmount,
  });

  final String currency;

  /// Kilos libres du trajet ; nul quand la capacité est libre.
  final double? availableKg;

  /// Prix au kilo tel que l'expéditeur le voit ; nul sans prix au kilo.
  final double? pricePerKgDisplay;
  final List<AmendmentGridItemOption> gridItems;

  /// Moyens de paiement proposables, déjà filtrés par le serveur. Un moyen
  /// inconnu de l'app est ignoré.
  final List<BidPaymentMethod> paymentMethods;

  /// Échéance de réponse du voyageur pour une demande créée maintenant (UTC).
  final DateTime? expiresAt;

  /// Bornes du net dans la devise du colis : la validation reste côté serveur.
  final double minAmount;
  final double maxAmount;

  factory AmendmentOptions.fromJson(Map<String, dynamic> json) {
    final methods = <BidPaymentMethod>[];
    for (final raw in (json['paymentMethods'] as List?) ?? const []) {
      final method = BidPaymentMethodApi.fromApi(raw as String?);
      if (method != null) methods.add(method);
    }
    final expires = json['expiresAt'] as String?;
    return AmendmentOptions(
      currency: json['currency'] as String? ?? 'EUR',
      availableKg: (json['availableKg'] as num?)?.toDouble(),
      pricePerKgDisplay: (json['pricePerKgDisplay'] as num?)?.toDouble(),
      gridItems: [
        for (final g in (json['gridItems'] as List?) ?? const [])
          AmendmentGridItemOption.fromJson(g as Map<String, dynamic>),
      ],
      paymentMethods: methods,
      expiresAt: expires == null ? null : DateTime.parse(expires).toUtc(),
      minAmount: (json['minAmount'] as num).toDouble(),
      maxAmount: (json['maxAmount'] as num).toDouble(),
    );
  }
}

/// Réponse à la création (`POST /bids/{bidId}/amendments`, 201), vue
/// expéditeur. Carte : de quoi ouvrir la PaymentSheet qui autorise le montant ;
/// espèces et mobile money : aucun secret.
class AmendmentCheckout {
  const AmendmentCheckout({
    required this.amendment,
    this.clientSecret,
    this.paymentMethodTypes = const [],
    this.publishableKey,
  });

  final BidAmendment amendment;
  final String? clientSecret;

  /// Moyens du PaymentIntent (ex. `card`, `paypal`).
  final List<String> paymentMethodTypes;
  final String? publishableKey;

  /// Une feuille de paiement est à ouvrir.
  bool get needsPaymentSheet =>
      clientSecret != null && clientSecret!.isNotEmpty;

  factory AmendmentCheckout.fromJson(Map<String, dynamic> json) =>
      AmendmentCheckout(
        amendment: BidAmendment.fromJson(
          json['amendment'] as Map<String, dynamic>,
        ),
        clientSecret: json['clientSecret'] as String?,
        paymentMethodTypes: [
          for (final t in (json['paymentMethodTypes'] as List?) ?? const [])
            t as String,
        ],
        publishableKey: json['publishableKey'] as String?,
      );
}
