import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';

class WalletModel {
  final double balance;
  final String currency;
  final List<WalletTransactionModel> transactions;
  final List<WalletCurrencyBalanceModel> balances;
  final bool refundEligible;

  /// Somme de tous les portefeuilles convertie dans [currency] au taux du
  /// jour (back). `null` sur l'ancien contrat : l'écran retombe alors sur
  /// l'en-tête « Solde disponible ».
  final double? estimatedTotal;

  /// `false` quand une devise détenue n'a pas de taux et a été exclue du
  /// total (le back le signale ; l'écran dit « estimation partielle »).
  final bool estimateComplete;

  const WalletModel({
    required this.balance,
    required this.currency,
    required this.transactions,
    this.balances = const [],
    this.refundEligible = false,
    this.estimatedTotal,
    this.estimateComplete = true,
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
    estimatedTotal: (json['estimatedTotal'] as num?)?.toDouble(),
    estimateComplete: json['estimateComplete'] as bool? ?? true,
  );

  /// Portefeuille de la devise active, s'il est listé dans [balances].
  WalletCurrencyBalanceModel? get activeBalance {
    for (final b in balances) {
      if (b.active) return b;
    }
    return null;
  }

  bool get hasEstimate => estimatedTotal != null;

  /// Devises réellement détenues : solde non nul, plus la devise active même
  /// à zéro (elle porte l'en-tête). Une seule source pour l'en-tête et la
  /// carte des soldes, qui doivent se contredire nulle part.
  List<WalletCurrencyBalanceModel> get heldBalances =>
      balances.where((b) => b.active || b.balance != 0).toList();

  /// Devises dont une demande de remboursement est possible : éligibles et
  /// dont le net après frais est strictement positif (même règle que
  /// `_HeroHeader._canRefund` avant ce chantier, étendue à toutes les
  /// devises). `refundNetAmount` prime, repli `refundableAmount`, ancien
  /// contrat (les deux nuls) laissé à `refundEligible` seul.
  List<WalletCurrencyBalanceModel> get eligibleBalances => balances
      .where(
        (b) =>
            b.refundEligible &&
            (b.refundNetAmount ?? b.refundableAmount ?? 1) > 0,
      )
      .toList();
}
