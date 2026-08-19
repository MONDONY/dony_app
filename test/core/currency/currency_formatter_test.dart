import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formate USD avec deux décimales et le code local', () {
    expect(
      CurrencyFormatter.format(1234.5, SupportedCurrency.usd, locale: 'en_US'),
      r'$1,234.50',
    );
  });

  test('formate CAD avec deux décimales', () {
    expect(
      CurrencyFormatter.format(25, SupportedCurrency.cad, locale: 'en_CA'),
      r'CA$25.00',
    );
  });

  test('formate EUR avec la locale française', () {
    expect(
      CurrencyFormatter.format(25.5, SupportedCurrency.eur, locale: 'fr_FR'),
      contains('25,50'),
    );
    expect(
      CurrencyFormatter.format(25.5, SupportedCurrency.eur, locale: 'fr_FR'),
      contains('€'),
    );
  });

  test('formate XOF et XAF sans décimales', () {
    expect(
      CurrencyFormatter.format(1250.75, SupportedCurrency.xof, locale: 'fr_SN'),
      contains('1 251'),
    );
    expect(
      CurrencyFormatter.format(1250.75, SupportedCurrency.xaf, locale: 'fr_CM'),
      contains('1 251'),
    );
  });

  test('ne forge aucune devise lorsque la devise active est indisponible', () {
    expect(CurrencyFormatter.formatOrPlain(25, null), '25');
  });

  group('CurrencyFormatter.format compact', () {
    test('valeur entière → pas de décimales', () {
      final result = CurrencyFormatter.format(
        8,
        SupportedCurrency.eur,
        locale: 'fr_FR',
        compact: true,
      );
      expect(result, contains('8'));
      expect(result, contains('€'));
      expect(result, isNot(contains(',00')));
    });

    test('valeur non entière → décimales conservées', () {
      expect(
        CurrencyFormatter.format(
          8.5,
          SupportedCurrency.eur,
          locale: 'fr_FR',
          compact: true,
        ),
        contains('8,50'),
      );
    });

    test('compact respecte la position/symbole de la devise (CAD)', () {
      expect(
        CurrencyFormatter.format(
          25,
          SupportedCurrency.cad,
          locale: 'en_CA',
          compact: true,
        ),
        r'CA$25',
      );
    });
  });
}
