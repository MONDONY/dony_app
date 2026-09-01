import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Ces tests couvrent le formatage multidevise des montants.
///
/// Sans conteneur d'injection enregistré, `ActiveCurrency.current` vaut null et
/// les helpers « devise active » retombent sur l'euro : c'est précisément le
/// repli qu'on veut vérifier ici. Les cas non-euro passent par [formatPriceIn]
/// et [formatMinorAmount], qui reçoivent la devise explicitement.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  group('priceFilterBoundsFor — bornes du filtre prix par devise', () {
    test('EUR : bornes historiques inchangées (3, 25, pas 1)', () {
      final b = priceFilterBoundsFor(SupportedCurrency.eur);
      expect(b.min, 3);
      expect(b.max, 25);
      expect(b.step, 1);
    });

    test('XOF : scalées et arrondies au 500, pas 500', () {
      // 3 € ≈ 1968 F → 2000 ; 25 € ≈ 16 399 F → 16 500. Figées à 3–25, les
      // bornes éliminaient 100 % des annonces XOF (tout prix CFA dépasse 25).
      final b = priceFilterBoundsFor(SupportedCurrency.xof);
      expect(b.min, 2000);
      expect(b.max, 16500);
      expect(b.step, 500);
    });

    test('USD : arrondies à l\'entier, pas 1', () {
      final b = priceFilterBoundsFor(SupportedCurrency.usd);
      expect(b.min, 3);
      expect(b.max, 27);
      expect(b.step, 1);
    });
  });

  group('quickPriceFilterOptionsFor — réponses rapides scalées', () {
    test('EUR : 6 et 9, comme les anciennes options figées', () {
      expect(quickPriceFilterOptionsFor(SupportedCurrency.eur), [6, 9]);
    });

    test('XOF : montants « humains », arrondis au 500', () {
      // 6 € ≈ 3936 F → 4000 ; 9 € ≈ 5904 F → 6000.
      expect(quickPriceFilterOptionsFor(SupportedCurrency.xof), [4000, 6000]);
    });

    test('USD : arrondis au demi', () {
      // 6 € ≈ 6,48 $ → 6,5 ; 9 € ≈ 9,72 $ → 9,5.
      expect(quickPriceFilterOptionsFor(SupportedCurrency.usd), [6.5, 9.5]);
    });
  });

  group('formatMinorAmount — la sous-unité dépend de la devise', () {
    test('l\'euro a des centimes : 4000 unités mineures valent 40,00 €', () {
      expect(formatMinorAmount(4000, 'EUR'), contains('40,00'));
    });

    test('le franc CFA n\'a pas de sous-unité : 5000 restent 5000', () {
      // Diviser par 100 en dur affichait « 50 » pour 5000 XOF, soit un
      // centième du montant réel.
      final formatted = formatMinorAmount(5000, 'XOF');

      expect(formatted, contains('5'));
      expect(formatted, isNot(contains('50,00')));
      expect(formatted.replaceAll(RegExp(r'[^0-9]'), ''), '5000');
    });

    test('une devise inconnue retombe sur l\'euro', () {
      expect(
        formatMinorAmount(100, 'ZZZ'),
        equals(formatMinorAmount(100, 'EUR')),
      );
      expect(
        formatMinorAmount(100, null),
        equals(formatMinorAmount(100, 'EUR')),
      );
    });
  });

  group('formatPriceIn — le symbole suit la devise', () {
    test('chaque devise porte son propre symbole', () {
      expect(formatPriceIn(8, 'EUR'), contains('€'));
      expect(formatPriceIn(8, 'XOF'), contains('CFA'));
      expect(formatPriceIn(8, 'GBP'), contains('£'));
    });

    test('la casse du code est indifférente', () {
      expect(formatPriceIn(8, 'xof'), equals(formatPriceIn(8, 'XOF')));
    });
  });

  group('maxUnitPriceActive — plafond de saisie par devise', () {
    test('vaut le plafond de référence en euros', () {
      // Sans devise active enregistrée, le repli est l'euro.
      expect(maxUnitPriceActive, kMaxUnitPriceEur);
    });

    test('le plafond de référence reste aligné sur le backend', () {
      // CurrencyBounds.MAX_PRICE_PER_KG_EUR côté serveur. Les deux valeurs
      // doivent bouger ensemble, sinon le formulaire accepte ce que l'API
      // refuse — ou l'inverse.
      expect(kMaxUnitPriceEur, 500);
    });
  });

  group(
    'maxUnitPriceFor — suit la devise DE L\'ANNONCE, pas celle du profil',
    () {
      // Cœur de la Tâche 13 : une annonce se publie désormais dans la devise
      // choisie à la création, potentiellement distincte du portefeuille. La
      // borne de saisie doit suivre ce choix, pas ActiveCurrency.current.
      test('EUR : 500', () {
        expect(maxUnitPriceFor(SupportedCurrency.eur), 500);
      });

      test('USD : mise à l\'échelle avec deux décimales', () {
        expect(maxUnitPriceFor(SupportedCurrency.usd), 500 * 1.08);
      });

      test(
        'XOF : mise à l\'échelle puis arrondie au franc (zéro décimale)',
        () {
          // 500 * 655.957 = 327978.5 → arrondi au franc inférieur.
          expect(maxUnitPriceFor(SupportedCurrency.xof), 327978.0);
        },
      );

      test(
        'changer de devise change la borne, indépendamment de la devise active',
        () {
          // Deux devises, deux bornes très différentes — la même saisie (600)
          // est refusée en EUR mais acceptée en XOF.
          const price = 600.0;
          expect(price, greaterThan(maxUnitPriceFor(SupportedCurrency.eur)));
          expect(price, lessThan(maxUnitPriceFor(SupportedCurrency.xof)));
        },
      );
    },
  );

  group('formatPriceActive — repli quand aucune devise n\'est résolue', () {
    test('formate en euros sans lever d\'exception', () {
      expect(formatPriceActive(12.5), contains('12,50'));
    });
  });
}
