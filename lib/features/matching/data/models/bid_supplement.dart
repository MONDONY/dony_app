import 'package:json_annotation/json_annotation.dart';

part 'bid_supplement.g.dart';

/// États d'un supplément de prix, miroir de `BidSupplementStatus` côté back.
/// Un statut inconnu de l'app (back plus récent) devient [unknown] : l'encart
/// ne s'affiche pas, rien ne plante.
enum BidSupplementStatus {
  /// Espèces : la commission du supplément n'est pas encore prélevée au
  /// voyageur (3DS en cours). L'expéditeur n'a encore rien reçu.
  @JsonValue('COMMISSION_PENDING')
  commissionPending,
  @JsonValue('PROPOSED')
  proposed,
  @JsonValue('PAYMENT_PENDING')
  paymentPending,
  @JsonValue('PAID')
  paid,
  @JsonValue('PAYOUT_PENDING')
  payoutPending,
  @JsonValue('PAID_OUT')
  paidOut,
  @JsonValue('DECLINED')
  declined,
  @JsonValue('EXPIRED')
  expired,
  @JsonValue('WITHDRAWN')
  withdrawn,
  @JsonValue('CANCELLED')
  cancelled,
  @JsonValue('REFUND_PENDING')
  refundPending,
  @JsonValue('REFUNDED')
  refunded,
  unknown;

  /// En attente d'une réponse ou d'un paiement de l'expéditeur.
  bool get isOpen =>
      this == commissionPending || this == proposed || this == paymentPending;

  /// Payé par l'expéditeur et pas remboursé.
  bool get isPaid => this == paid || this == payoutPending || this == paidOut;

  /// Remboursé à l'expéditeur, ou en cours de remboursement.
  bool get isRefunded => this == refundPending || this == refunded;
}

/// Motif d'un supplément. [apiValue] part au back, [analyticsValue] dans
/// l'analytics ; jamais le texte libre saisi.
enum BidSupplementReason {
  /// Un article de la grille du trajet (ex. un téléphone déclaré au kilo).
  gridItem('GRID_ITEM', 'grid_item'),

  /// Le colis pèse plus que déclaré.
  extraWeight('EXTRA_WEIGHT', 'extra_weight'),

  /// Autre motif : le détail devient obligatoire.
  other('OTHER', 'other');

  const BidSupplementReason(this.apiValue, this.analyticsValue);

  final String apiValue;
  final String analyticsValue;

  static BidSupplementReason? fromApi(String? raw) {
    for (final r in values) {
      if (r.apiValue == raw) return r;
    }
    return null;
  }
}

/// Supplément de prix demandé par le voyageur à la remise, servi dans
/// `BidResponse.supplement` et par les endpoints `/bids/{bidId}/supplements`.
/// Montants dans la devise du colis.
///
/// L'expéditeur ne reçoit que le brut : [netAmount], [commissionAmount] et
/// [commissionStatus] sont nuls pour lui.
@JsonSerializable()
class BidSupplement {
  const BidSupplement({
    required this.id,
    required this.status,
    this.rail,
    this.currency = 'EUR',
    this.netAmount,
    this.commissionAmount,
    required this.grossAmount,
    this.reasonCode,
    this.reasonText,
    this.gridItemLabel,
    this.photoUrl,
    this.expiresAt,
    this.paidAt,
    this.commissionStatus,
    this.blocksHandover = false,
  });

  final String id;

  @JsonKey(unknownEnumValue: BidSupplementStatus.unknown)
  final BidSupplementStatus status;

  /// `STRIPE`, `PAWAPAY` ou `CASH` : celui du colis.
  final String? rail;

  @JsonKey(defaultValue: 'EUR')
  final String currency;

  /// Net demandé pour le voyageur. Nul côté expéditeur.
  final double? netAmount;

  /// Commission Yadony du supplément. Nulle côté expéditeur.
  final double? commissionAmount;

  /// Total payé par l'expéditeur (net + commission).
  final double grossAmount;

  /// `GRID_ITEM`, `EXTRA_WEIGHT` ou `OTHER` (texte brut : un motif inconnu de
  /// l'app ne casse pas le parsing).
  final String? reasonCode;
  final String? reasonText;
  final String? gridItemLabel;

  /// URL présignée (1 h) de la photo du colis.
  final String? photoUrl;

  /// Échéance de réponse de l'expéditeur (UTC).
  final DateTime? expiresAt;
  final DateTime? paidAt;

  /// Espèces, voyageur seulement : état de la commission du supplément.
  final String? commissionStatus;

  /// Vrai tant que la demande attend une réponse ou un paiement : le scan de
  /// remise (DEPART) est refusé en 409 `handover-supplement-pending`.
  @JsonKey(defaultValue: false)
  final bool blocksHandover;

  BidSupplementReason? get reason => BidSupplementReason.fromApi(reasonCode);

  factory BidSupplement.fromJson(Map<String, dynamic> json) =>
      _$BidSupplementFromJson(json);

  Map<String, dynamic> toJson() => _$BidSupplementToJson(this);
}

/// Montant suggéré pour un supplément : un article de la grille du trajet, ou
/// un kilo de plus au prix du trajet.
class SupplementSuggestion {
  const SupplementSuggestion({
    required this.kind,
    this.label,
    required this.unitNet,
  });

  static const kindGridItem = 'GRID_ITEM';
  static const kindKg = 'KG';

  /// [kindGridItem] ou [kindKg].
  final String kind;

  /// Libellé de l'article ; nul pour un kilo.
  final String? label;

  /// Net d'une unité pour le voyageur.
  final double unitNet;

  bool get isGridItem => kind == kindGridItem;

  factory SupplementSuggestion.fromJson(Map<String, dynamic> json) =>
      SupplementSuggestion(
        kind: json['kind'] as String? ?? kindKg,
        label: json['label'] as String?,
        unitNet: (json['unitNet'] as num).toDouble(),
      );
}

/// De quoi composer une demande (`GET /bids/{bidId}/supplements/options`) :
/// bornes du net dans la devise du colis, montants suggérés, rail.
class SupplementOptions {
  const SupplementOptions({
    required this.currency,
    required this.minNet,
    required this.maxNet,
    this.suggestions = const [],
    this.rail,
  });

  final String currency;
  final double minNet;
  final double maxNet;
  final List<SupplementSuggestion> suggestions;
  final String? rail;

  factory SupplementOptions.fromJson(Map<String, dynamic> json) =>
      SupplementOptions(
        currency: json['currency'] as String? ?? 'EUR',
        minNet: (json['minNet'] as num).toDouble(),
        maxNet: (json['maxNet'] as num).toDouble(),
        suggestions: [
          for (final s in (json['suggestions'] as List?) ?? const [])
            SupplementSuggestion.fromJson(s as Map<String, dynamic>),
        ],
        rail: json['rail'] as String?,
      );
}

/// Devis d'un supplément pour le voyageur
/// (`POST /bids/{bidId}/supplements/quote`) : son net, la commission Yadony,
/// le total payé par l'expéditeur.
class SupplementQuote {
  const SupplementQuote({
    required this.netAmount,
    required this.commissionAmount,
    required this.grossAmount,
    required this.currency,
  });

  final double netAmount;
  final double commissionAmount;
  final double grossAmount;
  final String currency;

  factory SupplementQuote.fromJson(Map<String, dynamic> json) =>
      SupplementQuote(
        netAmount: (json['netAmount'] as num).toDouble(),
        commissionAmount: (json['commissionAmount'] as num).toDouble(),
        grossAmount: (json['grossAmount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'EUR',
      );
}
