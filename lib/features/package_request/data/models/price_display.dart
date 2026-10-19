import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';

/// Mise en forme des montants des fils de demande. Les calculs de prix passent
/// par `ThreadPricer` (fil) ou `senderPriceForNet` (hors fil).
class PriceDisplay {
  /// Montant avec sa devise, décimales toujours affichées (contrairement à
  /// [formatPriceIn], compact) : ces libellés sont des prix négociés, où
  /// « 35,00 € » se lit mieux que « 35 € ».
  ///
  /// [currencyCode] est optionnel pour ne pas casser les appelants qui ne
  /// connaissent pas encore la devise du contexte — repli EUR dans ce cas.
  static String money(double v, [String? currencyCode]) =>
      CurrencyFormatter.format(
        v,
        SupportedCurrency.fromCodeOrDefault(currencyCode),
      );
}
