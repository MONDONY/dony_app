import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';

class PriceDisplay {
  /// Taux d'aperçu aligné sur la source unique [donyCommissionRate]
  /// (chargée du backend au démarrage, repli [kDonyCommissionRateDefault]).
  static double get previewRate => donyCommissionRate;

  /// Même calcul que le back (`PriceBreakdown.fromNet`) : commission arrondie
  /// au centime, puis brut = net + commission. Arrondir le total d'un coup
  /// donnait un centime d'écart avec l'en-tête du fil (FLUTTER-Q4).
  static double grossFromNet(double net) => _cents(net) + feeFromNet(net);
  static double netFromGross(double gross) => gross / (1 + previewRate);
  static double feeFromNet(double net) => _cents(net * previewRate);

  static double _cents(double v) => (v * 100).round() / 100;

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
