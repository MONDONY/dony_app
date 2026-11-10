import 'package:dony/core/utils/money_keyword_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyKeywordDetector.firstMatch', () {
    group('déclenche', () {
      const cases = {
        'Bague en ARGENT': 'argent',
        'des Espèces': 'especes',
        "enveloppe d'argent": 'argent',
        'enveloppe d’argent': 'argent',
        '2 liasses': 'liasses',
        'une liasse': 'liasse',
        'cash': 'cash',
        'Chèque': 'cheque',
        'trois chèques': 'cheques',
        'carte prépayée': 'carte prepayee',
        'CARTES PRÉPAYÉES': 'cartes prepayees',
        'une carte bancaire': 'carte bancaire',
        'deux cartes bancaires': 'cartes bancaires',
        'un billet de banque': 'billet de banque',
        'des billets de banque': 'billets de banque',
        'des devises étrangères': 'devises',
        'some money': 'money',
        'a banknote': 'banknote',
        'banknotes': 'banknotes',
        'a bank note': 'bank note',
        'bank notes': 'bank notes',
        'prepaid card': 'prepaid card',
        'two prepaid cards': 'prepaid cards',
        'my bank card': 'bank card',
        'bank cards': 'bank cards',
      };
      cases.forEach((input, expected) {
        test('« $input » → $expected', () {
          expect(MoneyKeywordDetector.firstMatch(input), expected);
        });
      });

      test('ponctuation autour du mot : « (cash). »', () {
        expect(MoneyKeywordDetector.firstMatch('Vêtements (cash).'), 'cash');
      });

      test('plusieurs espaces entre les mots d\'un terme', () {
        expect(
          MoneyKeywordDetector.firstMatch('carte    bancaire'),
          'carte bancaire',
        );
      });

      test('ponctuation entre les mots d\'un terme : séparateur', () {
        expect(
          MoneyKeywordDetector.firstMatch('carte-bancaire'),
          'carte bancaire',
        );
      });

      test('accent saisi en deux caractères (e + accent combinant)', () {
        expect(MoneyKeywordDetector.firstMatch('espe\u0300ces'), 'especes');
      });

      test('rend le premier terme dans l\'ordre du texte', () {
        expect(MoneyKeywordDetector.firstMatch('du cash et un chèque'), 'cash');
        expect(
          MoneyKeywordDetector.firstMatch('un chèque et du cash'),
          'cheque',
        );
      });

      test('à position égale, le terme le plus long l\'emporte', () {
        expect(
          MoneyKeywordDetector.firstMatch('cartes bancaires'),
          'cartes bancaires',
        );
      });
    });

    group('ne déclenche pas', () {
      const cases = [
        'argentine',
        'Maillot de l\'Argentine',
        'argenterie',
        'collier argenté',
        "billets d'avion",
        'enveloppe',
        'une espèce de vase',
        'devise',
        'vêtements',
        'cashmere',
        'moneypenny',
        'cheque123',
        'carte postale',
        'carte',
        'bank',
        '',
        '   ',
      ];
      for (final input in cases) {
        test('« $input »', () {
          expect(MoneyKeywordDetector.firstMatch(input), isNull);
        });
      }

      test('texte nul', () {
        expect(MoneyKeywordDetector.firstMatch(null), isNull);
      });
    });
  });

  group('MoneyKeywordDetector.normalize', () {
    test('minuscules, accents retirés, séparateurs ramenés à un espace', () {
      expect(
        MoneyKeywordDetector.normalize("Enveloppe d'ARGENT,  Chèques !"),
        'enveloppe d argent cheques ',
      );
    });
  });

  test('tous les termes sont déjà normalisés et se détectent seuls', () {
    for (final term in MoneyKeywordDetector.terms) {
      expect(MoneyKeywordDetector.normalize(term), term, reason: term);
      expect(MoneyKeywordDetector.firstMatch(term), term, reason: term);
    }
  });
}
