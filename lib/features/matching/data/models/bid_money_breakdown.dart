import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bid_money_breakdown.g.dart';

/// Nature d'une transaction d'un colis (`BidMoneyBreakdown.Line.kind`). Un type
/// inconnu de l'app devient [unknown].
enum MoneyLineKind {
  @JsonValue('PRINCIPAL')
  principal,
  @JsonValue('AMENDMENT')
  amendment,
  @JsonValue('SUPPLEMENT')
  supplement,
  unknown,
}

/// Une transaction du colis : le colis initial, un supplément ou une
/// modification. [amount] est un brut pour l'expéditeur, un net pour le
/// voyageur.
@JsonSerializable()
class MoneyLine {
  const MoneyLine({
    required this.kind,
    required this.refId,
    required this.method,
    required this.amount,
    required this.status,
  });

  static const statusSecured = 'SECURED';
  static const statusPending = 'PENDING';

  @JsonKey(unknownEnumValue: MoneyLineKind.unknown)
  final MoneyLineKind kind;

  /// Le colis (principal), le supplément ou la modification.
  final String refId;

  /// `STRIPE`, `MOBILE_MONEY` ou `CASH` (texte brut : un moyen inconnu de
  /// l'app ne casse pas le parsing, voir [paymentMethod]).
  final String method;

  @JsonKey(defaultValue: 0)
  final double amount;

  /// `SECURED` (acquise) ou `PENDING` (modification en attente).
  final String status;

  /// Acquise : elle entre dans le total du serveur.
  bool get isSecured => status == statusSecured;

  /// Moyen de paiement de la ligne, nul s'il est inconnu de l'app.
  BidPaymentMethod? get paymentMethod => BidPaymentMethodApi.fromApi(method);

  factory MoneyLine.fromJson(Map<String, dynamic> json) =>
      _$MoneyLineFromJson(json);

  Map<String, dynamic> toJson() => _$MoneyLineToJson(this);
}

/// Argent d'un colis modifié, calculé par le serveur : l'app l'affiche, elle
/// ne l'additionne jamais. Nul sur le colis tant qu'il n'a ni modification
/// acquise ni modification ouverte (les cartes actuelles restent alors).
///
/// Expéditeur : des bruts, jamais de net ni de commission. Voyageur : des nets,
/// sauf [cashAmount], le brut qu'il encaisse en main propre.
@JsonSerializable()
class BidMoneyBreakdown {
  const BidMoneyBreakdown({
    required this.lines,
    required this.total,
    required this.onlineAmount,
    required this.cashAmount,
    this.cashCommissionPaid,
  });

  @JsonKey(defaultValue: <MoneyLine>[])
  final List<MoneyLine> lines;

  /// Somme des lignes acquises : une ligne en attente n'y entre pas.
  @JsonKey(defaultValue: 0)
  final double total;

  /// Payé en ligne et gardé jusqu'à la livraison (expéditeur), versé sur le
  /// compte après la livraison (voyageur).
  @JsonKey(defaultValue: 0)
  final double onlineAmount;

  /// Brut en espèces : à remettre (expéditeur), à encaisser (voyageur).
  @JsonKey(defaultValue: 0)
  final double cashAmount;

  /// Voyageur seulement (nul pour l'expéditeur) : commission Yadony des lignes
  /// en espèces, déjà réglée.
  final double? cashCommissionPaid;

  factory BidMoneyBreakdown.fromJson(Map<String, dynamic> json) =>
      _$BidMoneyBreakdownFromJson(json);

  Map<String, dynamic> toJson() => _$BidMoneyBreakdownToJson(this);
}
