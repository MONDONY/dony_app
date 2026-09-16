import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Couverture du catalogue pays', () {
    test('chaque pays du catalogue a un indicatif téléphonique', () {
      // C'est ce test qui empêche les deux listes de diverger. Le sélecteur
      // d'indicatif en comptait dix quand le catalogue en listait trente-huit :
      // un Ivoirien installé en Belgique ou au Portugal ne pouvait pas créer
      // de compte par téléphone.
      final sansIndicatif = CountryCatalog.all
          .where((c) => phoneCountryForCode(c.code) == null)
          .map((c) => '${c.code} (${c.name})')
          .toList();
      expect(
        sansIndicatif,
        isEmpty,
        reason:
            'Pays du catalogue sans métadonnée téléphonique. Ajoute-les dans '
            'phone_country.dart, avec leur règle de zéro initial.',
      );
    });

    test('tout indicatif proposé correspond à un pays connu', () {
      // Les entrées hors catalogue sont tolérées mais doivent rester une
      // exception justifiée, pas une dérive silencieuse.
      final horsCatalogue = kPhoneCountries
          .where((p) => CountryCatalog.byCode(p.code) == null)
          .map((p) => p.code)
          .toSet();
      expect(horsCatalogue, {'CD'});
    });

    test('le nom affiché est celui du catalogue', () {
      for (final phone in kPhoneCountries) {
        final country = CountryCatalog.byCode(phone.code);
        if (country == null) continue;
        expect(phone.name, country.name, reason: phone.code);
      }
    });

    test('aucun code ISO en double', () {
      final codes = kPhoneCountries.map((c) => c.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('les corridors du produit sont tous proposés', () {
      final codes = kPhoneCountries.map((c) => c.code).toSet();
      expect(
        codes,
        containsAll(<String>['FR', 'SN', 'CI', 'ML', 'CM', 'BE', 'IT', 'ES']),
      );
    });

    test('chaque entrée porte un indicatif et un drapeau non vides', () {
      for (final c in kPhoneCountries) {
        expect(c.dialCode, startsWith('+'), reason: c.code);
        expect(c.dialCode.length, greaterThanOrEqualTo(2), reason: c.code);
        expect(c.flag, isNotEmpty, reason: c.code);
        expect(c.hint, isNotEmpty, reason: c.code);
      }
    });
  });

  group('Règle du zéro initial, pays par pays', () {
    test('seuls ces pays utilisent un préfixe interurbain', () {
      // Un préfixe interurbain est remplacé par l'indicatif en E.164. Partout
      // ailleurs le zéro est un chiffre du numéro : le retirer fabrique un
      // destinataire inexistant.
      final strip = kPhoneCountries
          .where((c) => c.stripsLeadingZero)
          .map((c) => c.code)
          .toSet();
      expect(strip, <String>{
        'DE', 'AT', 'BE', 'HR', 'FI', 'FR', 'IE', 'NL', //
        'GB', 'SK', 'SI', 'CH', 'CD',
      });
    });

    test('l\'Italie garde son zéro, contrairement à ses voisins', () {
      // Piège classique : en Italie le zéro fait partie du numéro fixe (06 pour
      // Rome) et le pays n'a pas de préfixe interurbain.
      expect(toE164('+39', '0612345678'), '+390612345678');
    });

    test('l\'Espagne et le Portugal n\'ont pas de zéro initial', () {
      expect(toE164('+34', '612345678'), '+34612345678');
      expect(toE164('+351', '912345678'), '+351912345678');
    });

    test('la Belgique retire son zéro', () {
      expect(toE164('+32', '0470123456'), '+32470123456');
    });

    test(
      'l\'Afrique de l\'Ouest et centrale gardent le zéro quand il existe',
      () {
        expect(toE164('+225', '0748840874'), '+2250748840874');
        expect(toE164('+229', '0196123456'), '+2290196123456');
        expect(toE164('+242', '061234567'), '+242061234567');
      },
    );

    test('la RD Congo retire le zéro, seule exception africaine', () {
      expect(toE164('+243', '0812345678'), '+243812345678');
    });
  });
}
