import 'package:dony/core/services/gdpr_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GdprHelper.requiresConsent', () {
    group('pays RGPD obligatoire', () {
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

        test('${entry.value} minuscule (${entry.key.toLowerCase()}) → true', () {
          expect(
            GdprHelper.requiresConsent(countryCode: entry.key.toLowerCase()),
            isTrue,
          );
        });
      }
    });

    group('pays hors RGPD', () {
      final nonGdprCountries = {
        'SN': 'Sénégal',
        'CI': "Côte d'Ivoire",
        'ML': 'Mali',
        'CM': 'Cameroun',
        'GA': 'Gabon',
        'CG': 'Congo',
        'CD': 'RD Congo',
        'US': 'États-Unis',
        'CA': 'Canada',
      };

      for (final entry in nonGdprCountries.entries) {
        test('${entry.value} (${entry.key}) → false', () {
          expect(GdprHelper.requiresConsent(countryCode: entry.key), isFalse);
        });
      }
    });

    group('cas limites', () {
      test('code vide → true (approche conservative)', () {
        expect(GdprHelper.requiresConsent(countryCode: ''), isTrue);
      });

      test('null explicite → utilise locale device (ne doit pas crasher)', () {
        // En environnement de test la locale peut être vide,
        // on vérifie juste que ça retourne un bool sans exception.
        expect(GdprHelper.requiresConsent(), isA<bool>());
      });
    });
  });
}
