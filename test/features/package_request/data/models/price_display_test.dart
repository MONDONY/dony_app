import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grossFromNet applies 12% for form preview', () {
    expect(PriceDisplay.grossFromNet(35), closeTo(39.20, 0.001));
  });
  test('format euros fr', () {
    expect(PriceDisplay.eur(39.20), '39,20 €');
    expect(PriceDisplay.eur(35), '35,00 €');
  });
}
