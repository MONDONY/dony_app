class WalletCurrencyBalanceModel {
  final String currency;
  final double balance;
  final bool active;
  final bool refundEligible;

  /// Part du solde remboursable sur la carte (calculée côté back par rejeu
  /// du ledger). `null` tant que le back n'expose pas encore le champ.
  final double? refundableAmount;

  /// Part non remboursable (parrainage, remboursements internes), perdue à la
  /// suppression du compte. `null` sur l'ancien contrat.
  final double? nonRefundableAmount;

  const WalletCurrencyBalanceModel({
    required this.currency,
    required this.balance,
    required this.active,
    this.refundEligible = false,
    this.refundableAmount,
    this.nonRefundableAmount,
  });

  factory WalletCurrencyBalanceModel.fromJson(Map<String, dynamic> json) =>
      WalletCurrencyBalanceModel(
        currency: json['currency'] as String,
        balance: (json['balance'] as num).toDouble(),
        active: json['active'] as bool,
        refundEligible: json['refundEligible'] as bool? ?? false,
        refundableAmount: (json['refundableAmount'] as num?)?.toDouble(),
        nonRefundableAmount: (json['nonRefundableAmount'] as num?)?.toDouble(),
      );
}
