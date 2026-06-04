class PriceDisplay {
  static const double previewRate = 0.12;

  static double grossFromNet(double net) => net * (1 + previewRate);
  static double feeFromNet(double net) => net * previewRate;

  static String eur(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} €';
}
