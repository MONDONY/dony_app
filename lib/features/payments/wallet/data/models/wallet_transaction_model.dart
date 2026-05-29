class WalletTransactionModel {
  final String type;
  final double amount;
  final double balanceAfter;
  final String? paymentRef;
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.paymentRef,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) =>
      WalletTransactionModel(
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        balanceAfter: (json['balanceAfter'] as num).toDouble(),
        paymentRef: json['paymentRef'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  bool get isCredit => amount > 0;
}
