import 'package:dony/features/matching/presentation/address_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gpsPositionLabel', () {
    test('en français : coordonnées à 4 décimales', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(
        gpsPositionLabel(l, 48.8566, 2.3522),
        'Position GPS (48.8566, 2.3522)',
      );
    });
  });

  group('isGpsPositionLabel', () {
    test('vrai pour un libellé français', () {
      expect(isGpsPositionLabel('Position GPS (48.8566, 2.3522)'), isTrue);
    });

    test('vrai pour un libellé anglais', () {
      expect(isGpsPositionLabel('GPS location (-4.3217, 15.3125)'), isTrue);
    });

    test('faux pour une adresse ordinaire', () {
      expect(isGpsPositionLabel('12 rue de la Paix'), isFalse);
    });

    test('faux pour un libellé sans coordonnées', () {
      expect(isGpsPositionLabel('Position GPS'), isFalse);
    });
  });
}
