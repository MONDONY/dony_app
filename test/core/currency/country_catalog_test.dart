import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chaque pays porte la devise de sa zone', () {
    expect(CountryCatalog.byCode('FR')!.currency, SupportedCurrency.eur);
    expect(CountryCatalog.byCode('CA')!.currency, SupportedCurrency.cad);
    expect(CountryCatalog.byCode('SN')!.currency, SupportedCurrency.xof);
    expect(CountryCatalog.byCode('CM')!.currency, SupportedCurrency.xaf);
  });

  test('le code est normalise, un pays absent renvoie null', () {
    expect(CountryCatalog.byCode('fr')!.code, 'FR');
    expect(CountryCatalog.byCode('ZZ'), isNull);
    expect(CountryCatalog.byCode(null), isNull);
    expect(CountryCatalog.byCode(''), isNull);
  });

  test('le catalogue couvre les 38 memes pays que le backend', () {
    expect(CountryCatalog.all.length, 38);
  });

  test('la recherche ignore la casse et les accents', () {
    expect(CountryCatalog.search('senegal').map((c) => c.code), contains('SN'));
    expect(CountryCatalog.search('CANADA').map((c) => c.code), contains('CA'));
  });

  test('une recherche vide renvoie le catalogue complet', () {
    expect(CountryCatalog.search(''), CountryCatalog.all);
    expect(CountryCatalog.search('   '), CountryCatalog.all);
  });

  test('la recherche ignore les espaces en tete et en queue', () {
    expect(
      CountryCatalog.search('  senegal  ').map((c) => c.code),
      contains('SN'),
    );
  });
}
