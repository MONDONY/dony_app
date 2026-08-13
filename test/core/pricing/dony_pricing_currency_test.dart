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

  group('formatPriceActive — repli quand aucune devise n\'est résolue', () {
    test('formate en euros sans lever d\'exception', () {
      expect(formatPriceActive(12.5), contains('12,50'));
    });
  });
}
