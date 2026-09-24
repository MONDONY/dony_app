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

    test('fr : arrondi au dixième le plus proche', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(formatOneDecimal(l, 4.46), '4,5'); // arrondi au-dessus
      expect(formatOneDecimal(l, 4.44), '4,4'); // arrondi en-dessous
      expect(formatOneDecimal(l, 12.05), '12,1'); // valeur pile ronde
      expect(formatOneDecimal(l, 0.96), '1,0'); // passage à la dizaine
    });

    test('en : arrondi au dixième le plus proche', () {
      final l = lookupAppLocalizations(AppL10n.en);
      expect(formatOneDecimal(l, 4.46), '4.5');
      expect(formatOneDecimal(l, 4.44), '4.4');
      expect(formatOneDecimal(l, 12.05), '12.1');
      expect(formatOneDecimal(l, 0.96), '1.0');
    });
  });
}
