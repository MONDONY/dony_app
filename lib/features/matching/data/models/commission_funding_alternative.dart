import 'package:equatable/equatable.dart';

/// Autre portefeuille du voyageur capable, à lui seul, de couvrir ce qui reste
/// de la commission après le portefeuille de la devise du trajet (409
/// INSUFFICIENT_WALLET, champ `alternatives`). [requiredAmount] est le montant
/// qui serait prélevé dans [currency] au taux du jour (FLUTTER-CG).
class CommissionFundingAlternative extends Equatable {
  final String currency;
  final double balance;
  final double requiredAmount;

  const CommissionFundingAlternative({
    required this.currency,
    required this.balance,
    required this.requiredAmount,
  });

  /// `null` pour une entrée inexploitable (devise ou montant absent).
  static CommissionFundingAlternative? tryParse(Object? json) {
    if (json is! Map) return null;
    final currency = json['currency'];
    final required = json['required'];
    if (currency is! String || currency.trim().isEmpty || required is! num) {
      return null;
    }
    return CommissionFundingAlternative(
      currency: currency.trim().toUpperCase(),
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      requiredAmount: required.toDouble(),
    );
  }

  /// Liste tolérante : absente (ancien back) ou mal formée → liste vide.
  static List<CommissionFundingAlternative> listFromJson(Object? json) {
    if (json is! List) return const [];
    return [for (final item in json) ?tryParse(item)];
  }

  @override
  List<Object?> get props => [currency, balance, requiredAmount];
}
