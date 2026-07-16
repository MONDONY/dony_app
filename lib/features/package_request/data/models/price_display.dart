import 'package:dony/core/pricing/dony_pricing.dart';

class PriceDisplay {
  /// Taux d'aperçu aligné sur la source unique [donyCommissionRate]
  /// (chargée du backend au démarrage, repli [kDonyCommissionRateDefault]).
  static double get previewRate => donyCommissionRate;

  static double grossFromNet(double net) => net * (1 + previewRate);
  static double netFromGross(double gross) => gross / (1 + previewRate);
  static double feeFromNet(double net) => net * previewRate;

  static String eur(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

  /// Returns the role-aware price label for the negotiation thread.
  ///
  /// - Traveler sees their net take: "Tu reçois 35,00 €"
  /// - Sender  sees the gross they pay: "Tu paies 39,20 €"
  ///   (uses [gross] if provided, otherwise computes it from [net])
  static String threadPriceLabel(
    double net,
    double? gross,
    bool isTraveler,
  ) {
    if (isTraveler) return 'Tu reçois ${eur(net)}';
    final g = gross ?? grossFromNet(net);
    return 'Tu paies ${eur(g)}';
  }
}
