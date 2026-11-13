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
