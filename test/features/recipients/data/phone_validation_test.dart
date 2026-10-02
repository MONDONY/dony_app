import 'package:dony/features/recipients/data/models/recipient.dart';
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

  test('recipientPhoneDigits : mêmes chiffres quelle que soit l\'écriture', () {
    expect(recipientPhoneDigits('+221 77 123 45 67'), '221771234567');
    expect(recipientPhoneDigits('00221771234567'), '221771234567');
    expect(recipientPhoneDigits(''), '');
  });

  group('findRecipientByPhone (FLUTTER-7T)', () {
    const sn = Recipient(
      id: 'sn',
      fullName: 'Mamadou',
      phoneE164: '+221771234567',
      country: 'SN',
    );
    const ci = Recipient(
      id: 'ci',
      fullName: 'Koffi',
      phoneE164: '+2250748840874',
      country: 'CI',
    );
    const fr = Recipient(
      id: 'fr',
      fullName: 'Awa',
      phoneE164: '+33612345678',
      country: 'FR',
    );
    const all = [sn, ci, fr];

    test('numéro international, autre écriture : retrouvé', () {
      expect(findRecipientByPhone(all, '+221 77 123 45 67')?.id, 'sn');
      expect(findRecipientByPhone(all, '00221771234567')?.id, 'sn');
    });

    test('format national : comparé avec le pays de chaque entrée', () {
      expect(findRecipientByPhone(all, '07 48 84 08 74')?.id, 'ci');
      expect(findRecipientByPhone(all, '06 12 34 56 78')?.id, 'fr');
      expect(findRecipientByPhone(all, '77 123 45 67')?.id, 'sn');
    });

    test('format national avec le pays fourni', () {
      const otherFr = Recipient(
        id: 'x',
        fullName: 'X',
        phoneE164: '+33612345678',
        country: 'SN',
      );
      expect(
        findRecipientByPhone([otherFr], '0612345678', countryCode: 'FR')?.id,
        'x',
      );
    });

    test('numéro inconnu ou vide : null', () {
      expect(findRecipientByPhone(all, '+221700000000'), isNull);
      expect(findRecipientByPhone(all, '  '), isNull);
      expect(findRecipientByPhone(const [], '+221771234567'), isNull);
    });
  });

  test('kRecipientEmail', () {
    expect(kRecipientEmail.hasMatch('awa@example.com'), isTrue);
    expect(kRecipientEmail.hasMatch('awa@example'), isFalse);
    expect(kRecipientEmail.hasMatch('awa example.com'), isFalse);
  });
}
