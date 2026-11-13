import 'package:dony/core/utils/format_volume.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVolumeM3', () {
    test('français : virgule, milliers groupés, une décimale au plus', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(formatVolumeM3(l, 12.5), '12,5 m³');
      expect(formatVolumeM3(l, 20), '20 m³');
      expect(formatVolumeM3(l, 0.1), '0,1 m³');
      expect(
        formatVolumeM3(l, 1200).replaceAll(' ', ' ').replaceAll(' ', ' '),
        '1 200 m³',
      );
    });

    test('anglais : point décimal', () {
      final l = lookupAppLocalizations(AppL10n.en);
      expect(formatVolumeM3(l, 12.5), '12.5 m³');
      expect(formatVolumeM3(l, 1200), '1,200 m³');
    });
  });

  group(
    'formatVolumeRemainingM3 : arrondi vers le bas, sans dérive flottante',
    () {
      final fr = lookupAppLocalizations(AppL10n.fr);
      final en = lookupAppLocalizations(AppL10n.en);
      String fmt(double v) => formatVolumeRemainingM3(
        fr,
        v,
      ).replaceAll('\u202f', ' ').replaceAll('\u00a0', ' ');

      test('les volumes à une décimale restent exacts', () {
        expect(fmt(8.2), '8,2 m³');
        expect(fmt(2.3), '2,3 m³');
        expect(fmt(0.4), '0,4 m³');
      });

      test('les volumes à deux décimales restent exacts', () {
        expect(fmt(0.29), '0,29 m³');
        expect(fmt(1.15), '1,15 m³');
        expect(fmt(0.35), '0,35 m³');
        expect(fmt(4.35), '4,35 m³');
      });

      test(
        'la troisième décimale est tronquée, jamais arrondie vers le haut',
        () {
          expect(fmt(0.399), '0,39 m³');
          expect(fmt(0.356), '0,35 m³');
          expect(fmt(0.009), '0 m³');
        },
      );

      test('plafond 9 999 et zéro', () {
        expect(fmt(9999), '9 999 m³');
        expect(fmt(0), '0 m³');
      });

      test('anglais : point décimal', () {
        expect(formatVolumeRemainingM3(en, 8.2), '8.2 m³');
        expect(formatVolumeRemainingM3(en, 9999), '9,999 m³');
      });
    },
  );

  group('formatVolumeSoldM3 : arrondi vers le haut', () {
    final fr = lookupAppLocalizations(AppL10n.fr);
    String fmt(double v) => formatVolumeSoldM3(
      fr,
      v,
    ).replaceAll('\u202f', ' ').replaceAll('\u00a0', ' ');

    test('vendu + restant = capacité, même nombre de décimales', () {
      // 12 m³ dont 0,29 restants : 11,71 vendus (12 - 0,29 flotte à 11,71).
      expect(fmt(12 - 0.29), '11,71 m³');
      expect(fmt(11.7), '11,7 m³');
      expect(fmt(8.2), '8,2 m³');
      expect(fmt(0), '0 m³');
      expect(fmt(9999), '9 999 m³');
    });

    test('la troisième décimale est arrondie vers le haut', () {
      expect(fmt(0.601), '0,61 m³');
      expect(fmt(0.6), '0,6 m³');
    });
  });

  group('formatParcelVolumeM3 : volume d\'un colis', () {
    test('français : deux décimales au moins, trois au plus', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(formatParcelVolumeM3(l, 0.1), '0,10 m³');
      expect(formatParcelVolumeM3(l, 0.024), '0,024 m³');
      expect(formatParcelVolumeM3(l, 0.001), '0,001 m³');
      expect(formatParcelVolumeM3(l, 1.5), '1,50 m³');
    });

    test('anglais : point décimal', () {
      final l = lookupAppLocalizations(AppL10n.en);
      expect(formatParcelVolumeM3(l, 0.1), '0.10 m³');
      expect(formatParcelVolumeM3(l, 0.024), '0.024 m³');
    });
  });

  test('formatVolumeValue : valeur seule, sans milliers', () {
    expect(formatVolumeValue('en', 12.5), '12.5');
    expect(formatVolumeValue('en', 9999), '9999');
    expect(formatVolumeValue('fr', 3.0), '3');
  });

  test('readVolumeInput : virgule ou point, vide ou illisible = null', () {
    expect(readVolumeInput('12,5'), 12.5);
    expect(readVolumeInput(' 3.2 '), 3.2);
    expect(readVolumeInput(''), isNull);
    expect(readVolumeInput('abc'), isNull);
  });
}
