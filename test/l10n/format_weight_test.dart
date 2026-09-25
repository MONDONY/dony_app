import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatWeightKg', () {
    test('fr : entier sans décimale, décimale avec virgule', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(formatWeightKg(l, 4.0), '4 kg');
      expect(formatWeightKg(l, 4.5), '4,5 kg');
    });

    test('fr : cas limite, un poids qui s\'arrondit à un entier perd sa '
        'décimale (4,04 → « 4 kg », déclaré en PR)', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(formatWeightKg(l, 4.04), '4 kg');
    });

    test('en : entier sans décimale, décimale avec point', () {
      final l = lookupAppLocalizations(AppL10n.en);
      expect(formatWeightKg(l, 4.0), '4 kg');
      expect(formatWeightKg(l, 4.5), '4.5 kg');
    });
  });
}
