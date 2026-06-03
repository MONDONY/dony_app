import 'package:dony/core/utils/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeSearch', () {
    test('met en minuscules', () {
      expect(normalizeSearch('DAKAR'), 'dakar');
    });
    test('supprime les diacritiques', () {
      expect(normalizeSearch('Géné Abîmé çà'), 'gene abime ca');
    });
    test('préserve la longueur (1 char -> 1 char)', () {
      expect(normalizeSearch('éàü').length, 3);
    });
    test('chaîne vide -> vide', () {
      expect(normalizeSearch(''), '');
    });
  });
}
