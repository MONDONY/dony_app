import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('format euros fr, décimales toujours affichées', () {
    expect(PriceDisplay.money(39.20), '39,20 €');
    expect(PriceDisplay.money(35), '35,00 €');
  });

  test('devise passée : même rendu que CurrencyFormatter, non compact', () {
    expect(
      PriceDisplay.money(35000, 'XOF'),
      CurrencyFormatter.format(35000, SupportedCurrency.xof),
    );
    expect(
      PriceDisplay.money(12.5, 'USD'),
      CurrencyFormatter.format(12.5, SupportedCurrency.usd),
    );
    expect(PriceDisplay.money(35000, 'XOF'), isNot(contains('€')));
    // Franc CFA sans unité mineure : aucune décimale.
    expect(PriceDisplay.money(35000, 'XOF'), isNot(contains(',')));
  });

  test('devise inconnue ou absente : repli EUR', () {
    expect(PriceDisplay.money(10, 'ZZZ'), PriceDisplay.money(10));
    expect(PriceDisplay.money(10), '10,00 €');
  });
}
