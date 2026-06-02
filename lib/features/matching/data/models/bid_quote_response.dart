import 'package:json_annotation/json_annotation.dart';

part 'bid_quote_response.g.dart';

/// Résultat du devis POST /bids/quote.
/// Permet d'afficher le total exact (promo inclus) sans calcul local.
@JsonSerializable()
class BidQuoteResponse {
  const BidQuoteResponse({
    required this.netEur,
    required this.rate,
    required this.commissionEur,
    required this.totalEur,
    required this.promoApplied,
    this.promoLabel,
  });

  /// Montant net voyageur (weightKg × pricePerKg).
  final double netEur;

  /// Taux de commission Dony effectif (promo/override/global).
  final double rate;

  /// Commission Dony = netEur × rate.
  final double commissionEur;

  /// Total expéditeur = netEur + commissionEur.
  final double totalEur;

  /// true si un code promo a été appliqué.
  final bool promoApplied;

  /// Ex. « Code WELCOME10 : 6 % de commission » (null si pas de promo).
  final String? promoLabel;

  factory BidQuoteResponse.fromJson(Map<String, dynamic> json) =>
      _$BidQuoteResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BidQuoteResponseToJson(this);
}
