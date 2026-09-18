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

  /// Frais retenus au remboursement (mobile money : pawaPay). `null` tant
  /// que le back n'expose pas encore le champ.
  final double? refundFeeAmount;

  /// Net qui repart réellement vers l'utilisateur
  /// (`refundableAmount - refundFeeAmount`). `null` sur l'ancien contrat.
  final double? refundNetAmount;

  /// Équivalent de [balance] dans la devise active du portefeuille, calculé
  /// par le back au taux du jour. Purement informatif : l'argent reste dans
  /// sa devise. `null` sur l'ancien contrat ou quand le taux manque.
  final double? estimatedInActive;

  const WalletCurrencyBalanceModel({
    required this.currency,
    required this.balance,
    required this.active,
    this.refundEligible = false,
    this.refundableAmount,
    this.nonRefundableAmount,
    this.refundFeeAmount,
    this.refundNetAmount,
    this.estimatedInActive,
  });

  factory WalletCurrencyBalanceModel.fromJson(Map<String, dynamic> json) =>
      WalletCurrencyBalanceModel(
        currency: json['currency'] as String,
        balance: (json['balance'] as num).toDouble(),
        active: json['active'] as bool,
        refundEligible: json['refundEligible'] as bool? ?? false,
        refundableAmount: (json['refundableAmount'] as num?)?.toDouble(),
        nonRefundableAmount: (json['nonRefundableAmount'] as num?)?.toDouble(),
        refundFeeAmount: (json['refundFeeAmount'] as num?)?.toDouble(),
        refundNetAmount: (json['refundNetAmount'] as num?)?.toDouble(),
        estimatedInActive: (json['estimatedInActive'] as num?)?.toDouble(),
      );
}
