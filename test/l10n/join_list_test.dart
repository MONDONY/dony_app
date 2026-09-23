import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('joinList — fr', () {
    final l = lookupAppLocalizations(AppL10n.fr);

    test('liste vide', () {
      expect(joinList(l, const []), '');
    });

    test('un seul élément', () {
      expect(joinList(l, const ['a']), 'a');
    });

    test('deux éléments', () {
      expect(joinList(l, const ['a', 'b']), 'a et b');
    });

    test('trois éléments ou plus', () {
      expect(joinList(l, const ['a', 'b', 'c']), 'a, b et c');
    });
  });

  group('joinList — en', () {
    final l = lookupAppLocalizations(AppL10n.en);

    test('un seul élément', () {
      expect(joinList(l, const ['a']), 'a');
    });

    test('deux éléments', () {
      expect(joinList(l, const ['a', 'b']), 'a and b');
    });

    test('trois éléments ou plus', () {
      expect(joinList(l, const ['a', 'b', 'c']), 'a, b, and c');
    });
  });
}
