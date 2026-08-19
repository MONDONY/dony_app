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
    // Copie figee de `CountryCatalog.java` (payments/currency), qui fait
    // autorite : le serveur derive la devise depuis SA table. Une simple
    // egalite de longueur laisserait passer un GB renomme UK ou un CH bascule
    // sur EUR, exactement les divergences qui produisent des 422 en prod.
    const expected = <String, SupportedCurrency>{
      'AT': SupportedCurrency.eur,
      'BE': SupportedCurrency.eur,
      'HR': SupportedCurrency.eur,
      'CY': SupportedCurrency.eur,
      'EE': SupportedCurrency.eur,
      'FI': SupportedCurrency.eur,
      'FR': SupportedCurrency.eur,
      'DE': SupportedCurrency.eur,
      'GR': SupportedCurrency.eur,
      'IE': SupportedCurrency.eur,
      'IT': SupportedCurrency.eur,
      'LV': SupportedCurrency.eur,
      'LT': SupportedCurrency.eur,
      'LU': SupportedCurrency.eur,
      'MT': SupportedCurrency.eur,
      'NL': SupportedCurrency.eur,
      'PT': SupportedCurrency.eur,
      'SK': SupportedCurrency.eur,
      'SI': SupportedCurrency.eur,
      'ES': SupportedCurrency.eur,
      'CH': SupportedCurrency.chf,
      'GB': SupportedCurrency.gbp,
      'CA': SupportedCurrency.cad,
      'US': SupportedCurrency.usd,
      'BJ': SupportedCurrency.xof,
      'BF': SupportedCurrency.xof,
      'CI': SupportedCurrency.xof,
      'GW': SupportedCurrency.xof,
      'ML': SupportedCurrency.xof,
      'NE': SupportedCurrency.xof,
      'SN': SupportedCurrency.xof,
      'TG': SupportedCurrency.xof,
      'CM': SupportedCurrency.xaf,
      'CF': SupportedCurrency.xaf,
      'TD': SupportedCurrency.xaf,
      'CG': SupportedCurrency.xaf,
      'GQ': SupportedCurrency.xaf,
      'GA': SupportedCurrency.xaf,
    };

    expect(expected.length, 38);
    expect({for (final c in CountryCatalog.all) c.code: c.currency}, expected);
  });

  test('chaque pays est declare une seule fois', () {
    expect(
      CountryCatalog.all.map((c) => c.code).toSet().length,
      CountryCatalog.all.length,
    );
  });

  test('groupedSearch conserve tous les pays et ordonne les zones', () {
    final groups = CountryCatalog.groupedSearch('');
    expect(groups.map((g) => g.zone), CountryZone.values);
    expect(groups.expand((g) => g.countries).length, CountryCatalog.all.length);
    for (final group in groups) {
      for (final country in group.countries) {
        expect(country.zone, group.zone);
      }
    }
  });

  test('groupedSearch n\'expose aucune zone vide', () {
    final groups = CountryCatalog.groupedSearch('senegal');
    expect(groups, hasLength(1));
    expect(groups.single.zone, CountryZone.afriqueOuest);
    expect(groups.single.countries.map((c) => c.code), ['SN']);
    expect(CountryCatalog.groupedSearch('zzzz'), isEmpty);
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
