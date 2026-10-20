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
    this.minimumApplied = false,
    this.minimumAmount,
    this.commissionGridId,
    this.promoIneffectiveReason,
  });

  final double netEur;
  final double rate;
  final double commissionEur;
  final double totalEur;
  final bool promoApplied;
  final String? promoLabel;

  /// Sous grille : le minimum de la devise a relevé la commission finale.
  final bool minimumApplied;

  /// Sous grille : commission minimum de la devise du devis ; null sans grille.
  final double? minimumAmount;

  /// Grille appliquée (celle du fil, ou la grille en vigueur pour un nouveau
  /// budget) ; null sans grille.
  final String? commissionGridId;

  /// `COMMISSION_MINIMUM` quand un code promo valide ne change rien parce que
  /// le minimum annule tout le gain ; null sinon.
  final String? promoIneffectiveReason;

  /// Le code promo saisi est valide mais sans effet à cause du minimum.
  bool get promoIneffectiveBecauseMinimum =>
      promoIneffectiveReason == 'COMMISSION_MINIMUM';

  factory NegotiationQuote.fromJson(Map<String, dynamic> json) =>
      NegotiationQuote(
        netEur: (json['netEur'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
        commissionEur: (json['commissionEur'] as num).toDouble(),
        totalEur: (json['totalEur'] as num).toDouble(),
        promoApplied: json['promoApplied'] as bool? ?? false,
        promoLabel: json['promoLabel'] as String?,
        minimumApplied: json['minimumApplied'] as bool? ?? false,
        minimumAmount: (json['minimumAmount'] as num?)?.toDouble(),
        commissionGridId: json['commissionGridId'] as String?,
        promoIneffectiveReason: json['promoIneffectiveReason'] as String?,
      );
}
