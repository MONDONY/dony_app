import 'package:dony/core/utils/lenient_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lenientDoubleOrNull', () {
    test('lit un entier, un décimal et un zéro sans décimale', () {
      expect(lenientDoubleOrNull(19678), 19678.0);
      expect(lenientDoubleOrNull(20.5), 20.5);
      expect(lenientDoubleOrNull(0), 0.0);
    });

    test('lit un texte décimal, espaces de bord ignorés', () {
      expect(lenientDoubleOrNull('20.00'), 20.0);
      expect(lenientDoubleOrNull('  7.25 '), 7.25);
    });

    test('rend null pour tout le reste', () {
      expect(lenientDoubleOrNull(null), isNull);
      expect(lenientDoubleOrNull(true), isNull);
      expect(lenientDoubleOrNull('abc'), isNull);
      expect(lenientDoubleOrNull(''), isNull);
      expect(lenientDoubleOrNull(const <String, dynamic>{}), isNull);
    });
  });
}
