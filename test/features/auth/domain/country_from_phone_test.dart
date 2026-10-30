import 'package:dony/features/auth/domain/country_from_phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countryFromPhone', () {
    test('+33 donne la France', () {
      expect(countryFromPhone('+33612345678'), 'FR');
    });

    test('+221 donne le Sénégal', () {
      expect(countryFromPhone('+221771234567'), 'SN');
    });

    test('le plus long indicatif gagne : +225 donne la Côte d\'Ivoire', () {
      expect(countryFromPhone('+2250748840874'), 'CI');
    });

    test('les espaces de confort sont ignorés', () {
      expect(countryFromPhone(' +33 6 12 34 56 78 '), 'FR');
    });

    test('null et chaîne vide donnent null', () {
      expect(countryFromPhone(null), isNull);
      expect(countryFromPhone(''), isNull);
      expect(countryFromPhone('   '), isNull);
    });

    test('un indicatif inconnu donne null', () {
      expect(countryFromPhone('+999123456'), isNull);
      expect(countryFromPhone('0612345678'), isNull);
    });

    test('un indicatif partagé (+1 : Canada, États-Unis) donne null', () {
      expect(countryFromPhone('+15145550123'), isNull);
    });

    test('un pays hors catalogue (RD Congo, +243) donne null : le serveur le '
        'refuserait', () {
      expect(countryFromPhone('+243812345678'), isNull);
    });
  });
}
