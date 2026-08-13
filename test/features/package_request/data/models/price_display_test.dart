import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  test('previewRate suit la source unique donyCommissionRate', () {
    expect(PriceDisplay.previewRate, donyCommissionRate);
    setDonyCommissionRate(0.12);
    expect(PriceDisplay.previewRate, 0.12);
  });
  test(
    'grossFromNet applique le taux courant pour l\'aperçu du formulaire',
    () {
      // Taux par défaut (5 %)
      expect(PriceDisplay.grossFromNet(35), closeTo(36.75, 0.001));
      // Suit un changement de taux chargé du backend
      setDonyCommissionRate(0.12);
      expect(PriceDisplay.grossFromNet(35), closeTo(39.20, 0.001));
    },
  );
  test('format euros fr', () {
    expect(PriceDisplay.money(39.20), '39,20 €');
    expect(PriceDisplay.money(35), '35,00 €');
  });
}
