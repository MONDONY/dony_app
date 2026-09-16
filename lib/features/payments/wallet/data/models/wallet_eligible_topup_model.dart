class WalletEligibleTopupModel {
  final String id;
  final double amount;
  final String? paymentRef;
  final DateTime createdAt;

  /// Montant d'origine de la recharge. `amount` est le reliquat encore
  /// remboursable après les dépenses (rejeu du ledger côté back). `null` sur
  /// l'ancien contrat.
  final double? originalAmount;

  const WalletEligibleTopupModel({
    required this.id,
    required this.amount,
    this.paymentRef,
    required this.createdAt,
    this.originalAmount,
  });

  factory WalletEligibleTopupModel.fromJson(Map<String, dynamic> json) =>
      WalletEligibleTopupModel(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        paymentRef: json['paymentRef'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        originalAmount: (json['originalAmount'] as num?)?.toDouble(),
      );
}
