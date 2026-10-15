/// Crédit obtenu par un code de recharge : montant et devise du code, solde
/// de cette devise après crédit (POST /wallet/topup-codes/redeem).
class WalletTopupCodeRedemptionModel {
  const WalletTopupCodeRedemptionModel({
    required this.amount,
    required this.currency,
    required this.balance,
    this.transactionId,
  });

  final double amount;
  final String currency;
  final double balance;
  final String? transactionId;

  factory WalletTopupCodeRedemptionModel.fromJson(Map<String, dynamic> json) {
    return WalletTopupCodeRedemptionModel(
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      balance: (json['balance'] as num).toDouble(),
      transactionId: json['transactionId'] as String?,
    );
  }
}
