class WalletEligibleTopupModel {
  final String id;
  final double amount;
  final String? paymentRef;
  final DateTime createdAt;

  const WalletEligibleTopupModel({
    required this.id,
    required this.amount,
    this.paymentRef,
    required this.createdAt,
  });

  factory WalletEligibleTopupModel.fromJson(Map<String, dynamic> json) =>
      WalletEligibleTopupModel(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        paymentRef: json['paymentRef'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
