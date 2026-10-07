import 'dart:math' as math;

import 'package:dony/core/currency/active_rates.dart';
import 'package:dony/core/currency/supported_currency.dart';

/// Convertit [amount] de [from] vers [to] avec le MÊME calcul que le backend
/// (`ExchangeRateService.convert`) : passage par le pivot EUR (division à
/// 10 décimales), puis arrondi HALF_UP au nombre de décimales de la devise
/// cible (0 pour XOF/XAF, 2 sinon). Même devise : montant rendu inchangé.
///
/// Les taux sont exprimés en unités de devise pour un euro, comme la table
/// `exchange_rates`. Fonction pure : aucun état global consulté.
double convertCurrencyAmount(
  double amount, {
  required SupportedCurrency from,
  required double fromUnitsPerEur,
  required SupportedCurrency to,
  required double toUnitsPerEur,
}) {
  if (from == to) return amount;
  final amountInEur = from == SupportedCurrency.eur
      ? amount
      : roundHalfUp(amount / fromUnitsPerEur, 10);
  final converted = to == SupportedCurrency.eur
      ? amountInEur
      : amountInEur * toUnitsPerEur;
  return roundHalfUp(converted, to.minorUnit);
}

/// Variante branchée sur les taux SERVEUR ([ActiveRates.serverUnitsPerEurFor]) :
/// `null` quand l'un des deux taux n'est pas encore chargé, pour que l'appelant
/// n'affiche jamais un montant que le backend ne produirait pas.
double? convertWithServerRates(
  double amount, {
  required SupportedCurrency from,
  required SupportedCurrency to,
}) {
  if (from == to) return amount;
  final fromRate = ActiveRates.serverUnitsPerEurFor(from);
  final toRate = ActiveRates.serverUnitsPerEurFor(to);
  if (fromRate == null || toRate == null) return null;
  return convertCurrencyAmount(
    amount,
    from: from,
    fromUnitsPerEur: fromRate,
    to: to,
    toUnitsPerEur: toRate,
  );
}

/// Arrondi « HALF_UP » de Java (`RoundingMode.HALF_UP`) à [decimals] chiffres.
///
/// La petite marge absorbe l'erreur de représentation binaire des doubles :
/// sans elle, 1,005 × 100 vaut 100,4999… et s'arrondirait vers le bas, là où
/// le `BigDecimal` du backend arrondit vers le haut.
double roundHalfUp(double value, int decimals) {
  final factor = math.pow(10, decimals).toDouble();
  final scaled = value * factor;
  final nudged = scaled + (scaled >= 0 ? 1e-7 : -1e-7);
  return nudged.round() / factor;
}
