import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  test('chaque pays du catalogue a un nom français identique au catalogue', () {
    for (final c in CountryCatalog.all) {
      expect(countryName(fr, c.code), c.name, reason: c.code);
    }
  });

  test('chaque pays du catalogue a un nom anglais (pas le code brut)', () {
    for (final c in CountryCatalog.all) {
      expect(countryName(en, c.code), isNot(c.code), reason: c.code);
    }
  });

  test('exemples anglais', () {
    expect(countryName(en, 'SN'), 'Senegal');
    expect(countryName(en, 'US'), 'United States');
    expect(countryName(en, 'CI'), "Côte d'Ivoire");
  });

  test('code inconnu → le code lui-même', () {
    expect(countryName(en, 'ZZ'), 'ZZ');
  });

  test('zones : français identique au catalogue, anglais traduit', () {
    for (final z in CountryZone.values) {
      expect(countryZoneLabel(fr, z), z.label, reason: z.name);
    }
    expect(countryZoneLabel(en, CountryZone.afriqueOuest), 'West Africa');
  });
}
