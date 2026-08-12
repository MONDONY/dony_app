/// Devis transparent GET /negotiations/{id}/quote : net voyageur, commission
/// Yadony (taux + montant, toujours au taux de base — jamais affecté par le
/// promo), total réellement payé (promo déjà déduit), et statut du promo.
class NegotiationQuote {
  const NegotiationQuote({
    required this.netEur,
    required this.rate,
    required this.commissionEur,
    required this.totalEur,
    required this.promoApplied,
    this.promoLabel,
  });

  final double netEur;
  final double rate;
  final double commissionEur;
  final double totalEur;
  final bool promoApplied;
  final String? promoLabel;

  factory NegotiationQuote.fromJson(Map<String, dynamic> json) => NegotiationQuote(
        netEur: (json['netEur'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
        commissionEur: (json['commissionEur'] as num).toDouble(),
        totalEur: (json['totalEur'] as num).toDouble(),
        promoApplied: json['promoApplied'] as bool? ?? false,
        promoLabel: json['promoLabel'] as String?,
      );
}
