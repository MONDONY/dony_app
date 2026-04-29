import 'package:dony/core/constants/app_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppAssets', () {
    group('getLogoForBackground', () {
      test('returns logoWhiteOrange for dark background', () {
        expect(
          AppAssets.getLogoForBackground(isDarkBackground: true),
          AppAssets.logoWhiteOrange,
        );
      });

      test('returns logoBlueOrange for light background', () {
        expect(
          AppAssets.getLogoForBackground(isDarkBackground: false),
          AppAssets.logoBlueOrange,
        );
      });
    });

    test('logo alias points to logoBlueOrange', () {
      expect(AppAssets.logo, AppAssets.logoBlueOrange);
    });

    test('logoWhite alias points to logoWhiteOrange', () {
      expect(AppAssets.logoWhite, AppAssets.logoWhiteOrange);
    });

    test('all constants are non-empty strings pointing to assets/logos/', () {
      final constants = {
        'logoBlueOrange':     AppAssets.logoBlueOrange,
        'logoBlueOrangeGlow': AppAssets.logoBlueOrangeGlow,
        'logoBlackBlue':      AppAssets.logoBlackBlue,
        'logoBlackOrange':    AppAssets.logoBlackOrange,
        'logoWhiteBlue':      AppAssets.logoWhiteBlue,
        'logoWhiteOrange':    AppAssets.logoWhiteOrange,
        'patternWax':         AppAssets.patternWax,
      };
      for (final entry in constants.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key} must not be empty');
        expect(
          entry.value,
          startsWith('assets/logos/'),
          reason: '${entry.key} must be in assets/logos/',
        );
      }
    });
  });
}
