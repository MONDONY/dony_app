import 'package:dony/features/matching/presentation/widgets/create_bid/payer_phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePayerPhone', () {
    test('chaîne vide → null', () {
      expect(normalizePayerPhone(''), isNull);
    });

    test('espaces seuls → null', () {
      expect(normalizePayerPhone('   '), isNull);
    });

    test('numéro international avec espaces → indicatif + chiffres', () {
      expect(normalizePayerPhone('+221 77 345 67 89'), '+221773456789');
    });

    test('numéro local avec tirets → chiffres seuls, sans +', () {
      expect(normalizePayerPhone('77-345-67-89'), '773456789');
    });

    test('un seul « + » sans aucun chiffre → null', () {
      expect(normalizePayerPhone('+'), isNull);
    });

    test(
      'un « + » non initial est retiré comme un caractère non numérique '
      '(seul le premier caractère compte pour repérer un préfixe international)',
      () {
        expect(normalizePayerPhone('077+123'), '077123');
      },
    );

    test('points et parenthèses retirés', () {
      expect(normalizePayerPhone('(077).345.67.89'), '0773456789');
    });

    test('espaces en tête/fin conservent le contenu utile', () {
      expect(normalizePayerPhone('  +221773456789  '), '+221773456789');
    });
  });
}
