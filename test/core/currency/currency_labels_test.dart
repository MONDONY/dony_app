import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportedCurrencyL10n.name', () {
    final fr = lookupAppLocalizations(AppL10n.fr);
    final en = lookupAppLocalizations(AppL10n.en);

    // Anciennes valeurs de SupportedCurrency.displayName (toujours en
    // français), remplacé par cette extension à la langue.
    const oldDisplayNames = <String, String>{
      'EUR': 'Euro',
      'USD': 'Dollar américain',
      'CAD': 'Dollar canadien',
      'GBP': 'Livre sterling',
      'CHF': 'Franc suisse',
      'XOF': 'Franc CFA Ouest',
      'XAF': 'Franc CFA Centre',
    };

    test(
      'chaque devise du catalogue a un nom fr égal à l\'ancien displayName',
      () {
        for (final currency in SupportedCurrency.values) {
          expect(
            currency.name(fr),
            oldDisplayNames[currency.code],
            reason: currency.code,
          );
        }
      },
    );

    test('chaque devise du catalogue a un nom en, non vide', () {
      for (final currency in SupportedCurrency.values) {
        expect(currency.name(en), isNotEmpty, reason: currency.code);
      }
    });

    test(
      'nom anglais distinct du français pour les devises non invariantes',
      () {
        expect(SupportedCurrency.usd.name(en), 'US dollar');
        expect(SupportedCurrency.cad.name(en), 'Canadian dollar');
        expect(SupportedCurrency.gbp.name(en), 'Pound sterling');
        expect(SupportedCurrency.chf.name(en), 'Swiss franc');
        expect(SupportedCurrency.xof.name(en), 'West African CFA franc');
        expect(SupportedCurrency.xaf.name(en), 'Central African CFA franc');
      },
    );

    test('EUR est identique en fr et en', () {
      expect(SupportedCurrency.eur.name(fr), SupportedCurrency.eur.name(en));
      expect(SupportedCurrency.eur.name(en), 'Euro');
    });
  });
}
