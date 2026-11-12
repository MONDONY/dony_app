import 'package:dony/features/package_request/presentation/weight_input_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sep = kWeightGroupSeparator;

  group('formatWeightInput', () {
    test('groupe les milliers : 1 200, 999 999', () {
      expect(formatWeightInput(1200), '1${sep}200');
      expect(formatWeightInput(999999), '999${sep}999');
      expect(formatWeightInput(12), '12');
      expect(formatWeightInput(0.5), '0.5');
      expect(formatWeightInput(1500.5), '1${sep}500.5');
    });

    test('le texte du champ se relit à l\'identique, route comme avion', () {
      for (final kg in [1200.0, 1500.5, 999999.0, 0.5, 12.25]) {
        for (final heavy in [true, false]) {
          expect(
            parseWeightInput(formatWeightInput(kg), heavy: heavy),
            kg,
            reason: '$kg heavy=$heavy',
          );
        }
      }
    });
  });

  group('parseWeightInput : route et bateau', () {
    double? route(String t) => parseWeightInput(t, heavy: true);

    test('« 1,200 » (anglais) vaut 1 200 kg, jamais 1,2', () {
      expect(route('1,200'), 1200);
      expect(route('1,200,500'), 1200500);
      expect(route('999,999'), 999999);
    });

    test('« 1 200 » (français, espace, insécable, fine) vaut 1 200', () {
      expect(route('1 200'), 1200);
      expect(route('1 200'), 1200);
      expect(route('1${sep}200'), 1200);
    });

    test('« 1.200 » (français collé) vaut 1 200', () {
      expect(route('1.200'), 1200);
    });

    test('décimales : 1.5, 1,5, 1200.5, 1200,5', () {
      expect(route('1.5'), 1.5);
      expect(route('1,5'), 1.5);
      expect(route('1200.5'), 1200.5);
      expect(route('1200,5'), 1200.5);
      expect(route('1,25'), 1.25);
    });

    test('milliers et décimale ensemble : 1,200.5 (EN) et 1.200,5 (FR)', () {
      expect(route('1,200.5'), 1200.5);
      expect(route('1.200,5'), 1200.5);
      expect(route('1 200,5'), 1200.5);
    });

    test('quatre chiffres avant la marque : décimale, pas des milliers', () {
      expect(route('1200,500'), 1200.5);
    });

    test('0.500 : 0,5 kg (le zéro de tête n\'est pas un millier)', () {
      expect(route('0.500'), 0.5);
      expect(route('0,500'), 0.5);
    });

    test('saisie vide, marque seule : pas un nombre', () {
      expect(route(''), isNull);
      expect(route(','), isNull);
    });

    test('marque finale en cours de frappe : « 12, » vaut 12', () {
      expect(route('12,'), 12);
    });
  });

  group('parseWeightInput : avion et peu importe', () {
    double? plane(String t) => parseWeightInput(t);

    test('« 1,200 » reste décimal : 1,2 kg', () {
      expect(plane('1,200'), 1.2);
      expect(plane('1.200'), 1.2);
    });

    test('les autres lectures sont celles de la route', () {
      expect(plane('4,5'), 4.5);
      expect(plane('4.5'), 4.5);
      expect(plane('1 200'), 1200);
      expect(plane('1,200.5'), 1200.5);
    });
  });

  group('GroupedWeightInputFormatter', () {
    TextEditingValue type(String text, {int? caret, bool heavy = false}) =>
        GroupedWeightInputFormatter(heavy: heavy).formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: caret ?? text.length),
          ),
        );

    test('1200 devient 1 200, curseur en fin', () {
      final v = type('1200');
      expect(v.text, '1${sep}200');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('999999 devient 999 999', () {
      expect(type('999999').text, '999${sep}999');
    });

    test('route : « 1,200 » tapé ou collé devient « 1 200 »', () {
      expect(type('1,200', heavy: true).text, '1${sep}200');
      expect(type('1.200', heavy: true).text, '1${sep}200');
      expect(type('1,200,500', heavy: true).text, '1${sep}200${sep}500');
    });

    test('avion : « 1,200 » reste décimal (deux décimales gardées)', () {
      expect(type('1,200').text, '1,20');
    });

    test('route : « 1,2 » et « 1,20 » restent décimaux pendant la frappe', () {
      expect(type('1,2', heavy: true).text, '1,2');
      expect(type('1,20', heavy: true).text, '1,20');
    });

    test('décimales groupées et tronquées à deux', () {
      expect(type('1200,5', heavy: true).text, '1${sep}200,5');
      expect(type('4,567').text, '4,56');
      expect(type('1,200.5', heavy: true).text, '1${sep}200.5');
    });

    test('une marque répétée est un séparateur de milliers', () {
      expect(type('1.2.3').text, '123');
    });

    test('lettres écartées, espaces refaits', () {
      expect(type('1a2 0b0').text, '1${sep}200');
    });

    test('le curseur reste sur le même chiffre après regroupement', () {
      final v = type('1${sep}2000', caret: 4);
      expect(v.text, '12${sep}000');
      expect(v.text.substring(0, v.selection.baseOffset), '12${sep}0');
    });

    test('le curseur reste après la marque décimale', () {
      final v = type('1200,5', caret: 6, heavy: true);
      expect(v.selection.baseOffset, v.text.length);
      final mid = type('12,50', caret: 3, heavy: true);
      expect(mid.text.substring(0, mid.selection.baseOffset), '12,');
    });

    test('saisie vide', () {
      expect(type('').text, '');
    });

    test('curseur invalide : fin de texte', () {
      final v = const GroupedWeightInputFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1200'),
      );
      expect(v.selection.baseOffset, v.text.length);
    });

    test('ce que le champ montre est ce que lit parseWeightInput', () {
      for (final heavy in [true, false]) {
        for (final raw in ['1,200', '1.200', '1200.5', '1 200', '0.500']) {
          final shown = type(raw, heavy: heavy).text;
          expect(
            parseWeightInput(shown, heavy: heavy),
            parseWeightInput(raw, heavy: heavy),
            reason: '$raw heavy=$heavy',
          );
        }
      }
    });
  });
}
