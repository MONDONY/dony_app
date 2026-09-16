import 'package:dony/core/phone/phone_country.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kPhoneCountries', () {
    test('couvre tout le catalogue pays, plus la RD Congo', () {
      expect(kPhoneCountries.length, greaterThanOrEqualTo(38));
      expect(
        kPhoneCountries.map((c) => c.dialCode),
        containsAll(<String>['+33', '+44', '+225', '+32', '+39', '+351']),
      );
    });

    test('la France est le choix par défaut du sélecteur', () {
      // Elle n'ouvre plus la liste, qui suit l'ordre du catalogue par zone,
      // mais reste le pays présélectionné : c'est le départ le plus fréquent.
      expect(kDefaultPhoneCountry.dialCode, '+33');
      expect(kDefaultPhoneCountry.code, 'FR');
    });

    test('le Canada et les États-Unis partagent un indicatif', () {
      // D'où l'identification par code ISO plutôt que par indicatif.
      final plusUn = kPhoneCountries.where((c) => c.dialCode == '+1');
      expect(plusUn.map((c) => c.code).toSet(), {'CA', 'US'});
    });

    test('phoneCountryFor retrouve un pays par son indicatif', () {
      expect(phoneCountryFor('+225')?.name, 'Côte d\'Ivoire');
      expect(phoneCountryFor('+33')?.name, 'France');
      expect(phoneCountryFor('+999'), isNull);
    });

    test('phoneCountryForCode retrouve un pays par son code ISO', () {
      expect(phoneCountryForCode('CI')?.dialCode, '+225');
      expect(phoneCountryForCode('ci')?.dialCode, '+225');
      expect(phoneCountryForCode('ZZ'), isNull);
    });

    test('chaque pays porte un exemple de saisie non vide', () {
      for (final country in kPhoneCountries) {
        expect(country.hint, isNotEmpty, reason: country.name);
      }
    });
  });

  group('toE164', () {
    test('France : le zéro initial est un préfixe interurbain, il saute', () {
      expect(toE164('+33', '0612345678'), '+33612345678');
    });

    test('France : un numéro déjà sans zéro est inchangé', () {
      expect(toE164('+33', '612345678'), '+33612345678');
    });

    test('Royaume-Uni : le zéro initial saute aussi', () {
      expect(toE164('+44', '07911123456'), '+447911123456');
    });

    test('RD Congo : le zéro initial saute aussi', () {
      expect(toE164('+243', '0812345678'), '+243812345678');
    });

    test('Côte d\'Ivoire : le zéro fait partie du numéro, il reste', () {
      // Depuis le passage à dix chiffres (2021) les numéros ivoiriens
      // commencent par 01, 05, 07, 25 ou 27 — le zéro est significatif.
      expect(toE164('+225', '0748840874'), '+2250748840874');
    });

    test('Sénégal : numéro sans zéro, rien n\'est retiré', () {
      expect(toE164('+221', '771234567'), '+221771234567');
    });

    test('Cameroun : numéro sans zéro, rien n\'est retiré', () {
      expect(toE164('+237', '671234567'), '+237671234567');
    });

    test('Gabon : le zéro fait partie du numéro, il reste', () {
      expect(toE164('+241', '06031234'), '+24106031234');
    });

    test('Congo : le zéro fait partie du numéro, il reste', () {
      expect(toE164('+242', '061234567'), '+242061234567');
    });

    test('espaces, points et tirets de saisie sont ignorés', () {
      expect(toE164('+225', '07 48 84 08 74'), '+2250748840874');
      expect(toE164('+33', '06-12.34 56 78'), '+33612345678');
    });

    test('un indicatif inconnu ne retire jamais le zéro', () {
      // Prudence : sans métadonnée, supprimer un chiffre est le choix qui
      // fabrique un faux numéro. On préfère transmettre la saisie telle quelle.
      expect(toE164('+999', '0123456'), '+9990123456');
    });

    test('un indicatif déjà présent dans la saisie n\'est pas doublé', () {
      expect(toE164('+225', '+2250748840874'), '+2250748840874');
      expect(toE164('+33', '+33612345678'), '+33612345678');
    });

    test('un préfixe international 00 est traité comme un plus', () {
      expect(toE164('+225', '002250748840874'), '+2250748840874');
      expect(toE164('+33', '0033612345678'), '+33612345678');
    });

    test('un seul zéro est retiré, jamais deux', () {
      // « 00 » suivi d'autre chose que l'indicatif choisi n'est pas un préfixe
      // international : la saisie est fautive. Elle reste reconnaissable dans
      // les journaux plutôt que d'être silencieusement amputée de deux chiffres.
      expect(toE164('+44', '007911123456'), '+4407911123456');
    });
  });
}
