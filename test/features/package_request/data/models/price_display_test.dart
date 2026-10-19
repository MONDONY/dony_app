import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('format euros fr', () {
    expect(PriceDisplay.money(39.20), '39,20\u00A0€');
    expect(PriceDisplay.money(35), '35,00\u00A0€');
  });

  test('format dans la devise passée', () {
    expect(PriceDisplay.money(1000, 'XOF'), contains('1'));
    expect(PriceDisplay.money(1000, 'XOF'), isNot(contains('€')));
  });
}
