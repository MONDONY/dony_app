import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';

class PriceDisplay {
  /// Taux d'aperçu aligné sur la source unique [donyCommissionRate]
  /// (chargée du backend au démarrage, repli [kDonyCommissionRateDefault]).
  static double get previewRate => donyCommissionRate;

  static double grossFromNet(double net) => net * (1 + previewRate);
  static double netFromGross(double gross) => gross / (1 + previewRate);
  static double feeFromNet(double net) => net * previewRate;

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

  /// Returns the role-aware price label for the negotiation thread.
  ///
  /// - Traveler sees their net take: "Tu reçois 35,00 €"
  /// - Sender  sees the gross they pay: "Tu paies 39,20 €"
  ///   (uses [gross] if provided, otherwise computes it from [net])
  static String threadPriceLabel(
    double net,
    double? gross,
    bool isTraveler, [
    String? currencyCode,
  ]) {
    if (isTraveler) return 'Tu reçois ${money(net, currencyCode)}';
    final g = gross ?? grossFromNet(net);
    return 'Tu paies ${money(g, currencyCode)}';
  }
}
