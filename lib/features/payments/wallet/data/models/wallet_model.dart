import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';

class WalletModel {
  final double balance;
  final String currency;
  final List<WalletTransactionModel> transactions;
  final List<WalletCurrencyBalanceModel> balances;
  final bool refundEligible;

  const WalletModel({
    required this.balance,
    required this.currency,
    required this.transactions,
    this.balances = const [],
    this.refundEligible = false,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
    balance: (json['balance'] as num).toDouble(),
    currency: json['currency'] as String,
    transactions: ((json['transactions'] as List<dynamic>?) ?? [])
        .map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    balances: ((json['balances'] as List<dynamic>?) ?? [])
        .map(
          (e) => WalletCurrencyBalanceModel.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    refundEligible: json['refundEligible'] as bool? ?? false,
  );
}
