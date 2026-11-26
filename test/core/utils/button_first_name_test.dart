import 'package:dony/core/utils/button_first_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buttonFirstName', () {
    test('nom absent ou vide : chaîne vide (le libellé prend son repli)', () {
      expect(buttonFirstName(null), '');
      expect(buttonFirstName(''), '');
      expect(buttonFirstName('   '), '');
    });

    test('garde le premier mot seulement', () {
      expect(buttonFirstName('Fatou Diallo'), 'Fatou');
      expect(buttonFirstName('  Mamadou   D. '), 'Mamadou');
    });

    test('un prénom court reste entier', () {
      expect(buttonFirstName('Awa'), 'Awa');
      // Pile à la limite : pas de points de suspension.
      expect(kButtonFirstNameMax, 11);
      expect(buttonFirstName('Abdoulkarim'), 'Abdoulkarim');
    });

    test('un prénom trop long est coupé avec des points de suspension, '
        'limite comprise', () {
      final cut = buttonFirstName('Maximilienne-Aurore Dupont');
      expect(cut, 'Maximilien…');
      expect(cut.length, kButtonFirstNameMax);
    });

    test('la limite se règle', () {
      expect(buttonFirstName('Christophe', maxChars: 6), 'Chris…');
    });

    test('ne coupe jamais un emoji en deux', () {
      final cut = buttonFirstName('Aminata👩🏾‍🦱👩🏾‍🦱👩🏾‍🦱', maxChars: 9);
      expect(cut, 'Aminata👩🏾‍🦱…');
    });
  });
}
