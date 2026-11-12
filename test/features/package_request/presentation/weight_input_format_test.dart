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
  });

  group('parseWeightInput', () {
    test('ignore les séparateurs de milliers, accepte virgule et point', () {
      expect(parseWeightInput('1${sep}200'), 1200);
      expect(parseWeightInput('1 200'), 1200);
      expect(parseWeightInput('4,5'), 4.5);
      expect(parseWeightInput('4.5'), 4.5);
      expect(parseWeightInput(''), isNull);
      expect(parseWeightInput(','), isNull);
    });
  });

  group('GroupedWeightInputFormatter', () {
    const formatter = GroupedWeightInputFormatter();

    TextEditingValue type(String text, [int? caret]) =>
        formatter.formatEditUpdate(
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

    test('un million à six chiffres : 999 999', () {
      expect(type('999999').text, '999${sep}999');
    });

    test('les décimales ne sont pas groupées, une seule marque', () {
      expect(type('1200,5').text, '1${sep}200,5');
      expect(type('1.2.3').text, '1.23');
    });

    test('lettres et espaces écartés', () {
      expect(type('1a2 0b0').text, '1${sep}200');
    });

    test('le curseur reste sur le même chiffre après regroupement', () {
      // « 1 20|0 » : trois chiffres avant le curseur.
      final v = type('1${sep}2000', 4);
      expect(v.text, '12${sep}000');
      expect(v.text.substring(0, v.selection.baseOffset), '12${sep}0');
    });

    test('saisie vide', () {
      expect(type('').text, '');
    });

    test('curseur invalide : fin de texte', () {
      final v = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1200'),
      );
      expect(v.selection.baseOffset, v.text.length);
    });
  });
}
