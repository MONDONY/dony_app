class WalletCurrencyBalanceModel {
  final String currency;
  final double balance;
  final bool active;

  const WalletCurrencyBalanceModel({
    required this.currency,
    required this.balance,
    required this.active,
  });

  factory WalletCurrencyBalanceModel.fromJson(Map<String, dynamic> json) =>
      WalletCurrencyBalanceModel(
        currency: json['currency'] as String,
        balance: (json['balance'] as num).toDouble(),
        active: json['active'] as bool,
      );
}
