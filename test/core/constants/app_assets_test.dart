import 'package:dony/core/constants/app_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppAssets', () {
    group('getLogoForBackground', () {
      test('returns logoWhiteSvg for dark background', () {
        expect(
          AppAssets.getLogoForBackground(isDarkBackground: true),
          AppAssets.logoWhiteSvg,
        );
      });

      test('returns logoSvg for light background', () {
        expect(
          AppAssets.getLogoForBackground(isDarkBackground: false),
          AppAssets.logoSvg,
        );
      });
    });

    group('getOnboardingImage', () {
      test('returns step 1 image', () {
        expect(AppAssets.getOnboardingImage(step: 1), AppAssets.onboarding1);
      });
      test('returns step 2 image', () {
        expect(AppAssets.getOnboardingImage(step: 2), AppAssets.onboarding2);
      });
      test('returns step 3 image', () {
        expect(AppAssets.getOnboardingImage(step: 3), AppAssets.onboarding3);
      });
      test('returns step 1 for out-of-range step', () {
        expect(AppAssets.getOnboardingImage(step: 99), AppAssets.onboarding1);
      });
    });

    group('getEmptyState', () {
      test('returns trips image for trips context', () {
        expect(AppAssets.getEmptyState(context: EmptyStateContext.trips), AppAssets.emptyStateTrips);
      });
      test('returns profile image for profile context', () {
        expect(AppAssets.getEmptyState(context: EmptyStateContext.profile), AppAssets.emptyStateProfile);
      });
    });

    group('getPlaceholder', () {
      test('returns driver placeholder', () {
        expect(AppAssets.getPlaceholder(type: PlaceholderType.driver), AppAssets.placeholderDriver);
      });
      test('returns avatar placeholder', () {
        expect(AppAssets.getPlaceholder(type: PlaceholderType.avatar), AppAssets.placeholderAvatar);
      });
    });

    test('all constants are non-empty strings', () {
      final constants = [
        AppAssets.logo,
        AppAssets.logoWhite,
        AppAssets.logoSvg,
        AppAssets.logoWhiteSvg,
        AppAssets.logoMark,
        AppAssets.patternWax,
        AppAssets.onboarding1,
        AppAssets.onboarding2,
        AppAssets.onboarding3,
        AppAssets.emptyStateTrips,
        AppAssets.emptyStateProfile,
        AppAssets.placeholderDriver,
        AppAssets.placeholderAvatar,
      ];
      for (final c in constants) {
        expect(c, isNotEmpty, reason: 'Constant must not be empty');
      }
    });
  });
}
