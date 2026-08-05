import 'package:dony/core/services/gdpr_helper.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive/hive.dart';

class MockBox extends Mock implements Box<dynamic> {}

void main() {
  group('GdprHelper.requiresConsent', () {
    group('via countryCode direct (test)', () {
      final gdprCountries = {
        'FR': 'France',
        'DE': 'Allemagne',
        'BE': 'Belgique',
        'ES': 'Espagne',
        'IT': 'Italie',
        'NL': 'Pays-Bas',
        'PL': 'Pologne',
        'PT': 'Portugal',
        'SE': 'Suède',
        'GB': 'Royaume-Uni',
        'NO': 'Norvège',
        'IS': 'Islande',
        'LI': 'Liechtenstein',
        'CH': 'Suisse',
      };

      for (final entry in gdprCountries.entries) {
        test('${entry.value} (${entry.key}) → true', () {
          expect(GdprHelper.requiresConsent(countryCode: entry.key), isTrue);
        });

        test(
          '${entry.value} minuscule (${entry.key.toLowerCase()}) → true',
          () {
            expect(
              GdprHelper.requiresConsent(countryCode: entry.key.toLowerCase()),
              isTrue,
            );
          },
        );
      }

      final nonGdprCountries = {
        'SN': 'Sénégal',
        'CI': "Côte d'Ivoire",
        'ML': 'Mali',
        'CM': 'Cameroun',
        'GA': 'Gabon',
        'CN': 'Chine',
        'US': 'États-Unis',
        'CA': 'Canada',
      };

      for (final entry in nonGdprCountries.entries) {
        test('${entry.value} (${entry.key}) → false', () {
          expect(GdprHelper.requiresConsent(countryCode: entry.key), isFalse);
        });
      }
    });

    group('via Hive (GPS détecté)', () {
      late MockBox mockBox;

      setUp(() {
        mockBox = MockBox();
      });

      test('pays RGPD stocké dans Hive → true', () {
        when(
          () => mockBox.get(HiveService.kDetectedCountryCode),
        ).thenReturn('FR');
        expect(GdprHelper.requiresConsent(prefs: mockBox), isTrue);
      });

      test('pays non-RGPD stocké dans Hive → false', () {
        when(
          () => mockBox.get(HiveService.kDetectedCountryCode),
        ).thenReturn('SN');
        expect(GdprHelper.requiresConsent(prefs: mockBox), isFalse);
      });

      test('countryCode direct a priorité sur Hive', () {
        // Hive dit SN (Sénégal) mais on force FR → doit retourner true
        when(
          () => mockBox.get(HiveService.kDetectedCountryCode),
        ).thenReturn('SN');
        expect(
          GdprHelper.requiresConsent(countryCode: 'FR', prefs: mockBox),
          isTrue,
        );
      });

      test('Hive a priorité sur la locale du device quand renseigné', () {
        // Hive dit FR (pays RGPD) → true même si locale device = fr_SN
        when(
          () => mockBox.get(HiveService.kDetectedCountryCode),
        ).thenReturn('FR');
        expect(GdprHelper.requiresConsent(prefs: mockBox), isTrue);
      });

      test('Hive vide → fallback sur locale device (ne doit pas crasher)', () {
        when(
          () => mockBox.get(HiveService.kDetectedCountryCode),
        ).thenReturn(null);
        expect(GdprHelper.requiresConsent(prefs: mockBox), isA<bool>());
      });
    });

    group('cas limites', () {
      test('code vide → true (approche conservative)', () {
        expect(GdprHelper.requiresConsent(countryCode: ''), isTrue);
      });

      test('null sans prefs → utilise locale device (ne doit pas crasher)', () {
        expect(GdprHelper.requiresConsent(), isA<bool>());
      });
    });
  });

  group('GdprHelper.resolveConsentAction', () {
    test('pas configuré → none, même sans réponse et en zone RGPD', () {
      expect(
        GdprHelper.resolveConsentAction(
          isConfigured: false,
          hasAnswered: false,
          requiresConsent: true,
        ),
        AnalyticsConsentAction.none,
      );
    });

    test('déjà répondu → none, même en zone RGPD', () {
      expect(
        GdprHelper.resolveConsentAction(
          isConfigured: true,
          hasAnswered: true,
          requiresConsent: true,
        ),
        AnalyticsConsentAction.none,
      );
    });

    test('configuré + pas répondu + zone RGPD → askConsent', () {
      expect(
        GdprHelper.resolveConsentAction(
          isConfigured: true,
          hasAnswered: false,
          requiresConsent: true,
        ),
        AnalyticsConsentAction.askConsent,
      );
    });

    test('configuré + pas répondu + hors RGPD → autoGrantNonGdpr', () {
      expect(
        GdprHelper.resolveConsentAction(
          isConfigured: true,
          hasAnswered: false,
          requiresConsent: false,
        ),
        AnalyticsConsentAction.autoGrantNonGdpr,
      );
    });

    test('pas configuré + hors RGPD → none (rien à accorder avant setup)', () {
      expect(
        GdprHelper.resolveConsentAction(
          isConfigured: false,
          hasAnswered: false,
          requiresConsent: false,
        ),
        AnalyticsConsentAction.none,
      );
    });
  });
}
