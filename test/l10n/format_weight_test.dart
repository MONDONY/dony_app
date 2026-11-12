import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

  group('formatWeightKg : milliers', () {
    test('en : séparateur de milliers', () {
      final l = lookupAppLocalizations(AppL10n.en);
      expect(formatWeightKg(l, 1200), '1,200 kg');
      expect(formatWeightKg(l, 999999.99), '1,000,000 kg');
      expect(formatWeightKg(l, 1200.5), '1,200.5 kg');
    });

    test('fr : groupé selon la langue (« 1 200 kg »)', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(
        formatWeightKg(l, 1200),
        '${NumberFormat('#,##0', 'fr').format(1200)} kg',
      );
      expect(formatWeightKg(l, 4.5), '4,5 kg');
      expect(formatWeightKg(l, 999), '999 kg');
    });
  });

  group('formatWeightGrouped : valeur seule avec milliers', () {
    test('fr : espace fine insécable, virgule décimale, deux décimales', () {
      expect(formatWeightGrouped('fr', 1200), '1\u202f200');
      expect(formatWeightGrouped('fr', 0.25), '0,25');
      expect(formatWeightGrouped('fr', 999999), '999\u202f999');
    });

    test('en : virgule des milliers, point décimal', () {
      expect(formatWeightGrouped('en', 1200), '1,200');
      expect(formatWeightGrouped('en', 12.5), '12.5');
      expect(formatWeightGrouped('en', 20), '20');
    });
  });

  group('formatWeightValue : champs de saisie', () {
    test('reste non groupé', () {
      expect(formatWeightValue('fr', 1200), '1200');
      expect(formatWeightValue('en', 0.25), '0.25');
    });
  });
}
