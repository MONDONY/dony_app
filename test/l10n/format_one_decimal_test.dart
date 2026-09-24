import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatOneDecimal', () {
    test('fr : virgule décimale', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(formatOneDecimal(l, 4.5), '4,5');
      expect(formatOneDecimal(l, 4.0), '4,0');
    });

    test('en : point décimal', () {
      final l = lookupAppLocalizations(AppL10n.en);
      expect(formatOneDecimal(l, 4.5), '4.5');
      expect(formatOneDecimal(l, 4.0), '4.0');
    });
  });
}
