/// Détail d'un « solde insuffisant » quand la devise du colis diffère de la
/// devise active : ce que le portefeuille de la devise du colis couvre, ce qui
/// manque (dans les deux devises) et le solde actif. Absent quand les deux
/// devises sont identiques ou avec un ancien back.
class CommissionShortfall {
  final String bidCurrency;
  final double commission;
  final double coveredByBidWallet;
  final double remainingBid;
  final double remainingInActive;
  final String activeCurrency;
  final double activeBalance;

  const CommissionShortfall({
    required this.bidCurrency,
    required this.commission,
    required this.coveredByBidWallet,
    required this.remainingBid,
    required this.remainingInActive,
    required this.activeCurrency,
    required this.activeBalance,
  });

  factory CommissionShortfall.fromJson(Map<String, dynamic> json) =>
      CommissionShortfall(
        bidCurrency: (json['bidCurrency'] as String).toUpperCase(),
        commission: (json['commission'] as num).toDouble(),
        coveredByBidWallet:
            (json['coveredByBidWallet'] as num?)?.toDouble() ?? 0,
        remainingBid: (json['remainingBid'] as num?)?.toDouble() ?? 0,
        remainingInActive: (json['remainingInActive'] as num?)?.toDouble() ?? 0,
        activeCurrency: (json['activeCurrency'] as String).toUpperCase(),
        activeBalance: (json['activeBalance'] as num?)?.toDouble() ?? 0,
      );
}
