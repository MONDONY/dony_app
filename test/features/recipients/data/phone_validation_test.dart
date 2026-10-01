import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('internationalizeRecipientPhone', () {
    test("Sénégal : l'indicatif est ajouté", () {
      expect(
        internationalizeRecipientPhone('77 123 45 67', 'SN'),
        '+221771234567',
      );
    });

    test("Côte d'Ivoire : le zéro initial fait partie du numéro", () {
      expect(
        internationalizeRecipientPhone('07 48 84 08 74', 'CI'),
        '+2250748840874',
      );
    });

    test('France : le zéro national est retiré', () {
      expect(
        internationalizeRecipientPhone('06 12 34 56 78', 'FR'),
        '+33612345678',
      );
    });

    test('Italie : le zéro est gardé', () {
      expect(
        internationalizeRecipientPhone('06 1234 5678', 'IT'),
        '+390612345678',
      );
    });

    test('00 devient +, sans indicatif ajouté', () {
      expect(
        internationalizeRecipientPhone('00221 77 123 45 67', 'FR'),
        '+221771234567',
      );
    });

    test('déjà international : inchangé, séparateurs retirés', () {
      expect(
        internationalizeRecipientPhone('+221 77-123.45.67', 'FR'),
        '+221771234567',
      );
    });

    test('vide ou pays inconnu : rien ajouté', () {
      expect(internationalizeRecipientPhone('  ', 'SN'), '');
      expect(internationalizeRecipientPhone('771234567', null), '771234567');
      expect(internationalizeRecipientPhone('771234567', 'ZZ'), '771234567');
    });
  });

  test('kRecipientEmail', () {
    expect(kRecipientEmail.hasMatch('awa@example.com'), isTrue);
    expect(kRecipientEmail.hasMatch('awa@example'), isFalse);
    expect(kRecipientEmail.hasMatch('awa example.com'), isFalse);
  });
}
