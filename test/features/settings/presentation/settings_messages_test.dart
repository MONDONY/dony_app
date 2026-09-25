// Messages ICU imposés par la fiche H1 (réglages, sécurité, appareils) :
// vérifie le rendu fr et en pour 1 et 3, en distinguant les corrections
// d'accord déclarées (nouveau rendu, différent de l'ancien texte concaténé)
// des messages inchangés (égalité avec l'ancien rendu concaténé).
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  group('devicesSignedInCount — correction d\'accord « appareil(s) »', () {
    test('fr, 1 appareil : nouveau rendu accordé', () {
      final l = AppL10n.current;
      expect(l.devicesSignedInCount(1), 'Tu es connecté sur 1 appareil');
      // L'ancien texte concaténé ne distinguait jamais le singulier.
      expect(
        l.devicesSignedInCount(1),
        isNot('Tu es connecté sur 1 appareil(s)'),
      );
    });

    test('fr, 3 appareils : nouveau rendu accordé', () {
      final l = AppL10n.current;
      expect(l.devicesSignedInCount(3), 'Tu es connecté sur 3 appareils');
      expect(
        l.devicesSignedInCount(3),
        isNot('Tu es connecté sur 3 appareil(s)'),
      );
    });

    test('en, 1 device', () {
      useEnglish();
      final l = AppL10n.current;
      expect(l.devicesSignedInCount(1), "You're signed in on 1 device");
    });

    test('en, 3 devices', () {
      useEnglish();
      final l = AppL10n.current;
      expect(l.devicesSignedInCount(3), "You're signed in on 3 devices");
    });
  });

  group('devicesAgoMinutes — inchangé', () {
    test('fr, égalité avec l\'ancien rendu concaténé', () {
      final l = AppL10n.current;
      const minutes = 5;
      expect(l.devicesAgoMinutes(minutes), 'il y a $minutes min');
    });

    test('en', () {
      useEnglish();
      final l = AppL10n.current;
      const minutes = 5;
      expect(l.devicesAgoMinutes(minutes), '$minutes min ago');
    });
  });

  group('devicesAgoHours — inchangé', () {
    test('fr, égalité avec l\'ancien rendu concaténé', () {
      final l = AppL10n.current;
      const hours = 2;
      expect(l.devicesAgoHours(hours), 'il y a $hours h');
    });

    test('en', () {
      useEnglish();
      final l = AppL10n.current;
      const hours = 2;
      expect(l.devicesAgoHours(hours), '$hours h ago');
    });
  });

  group('devicesAgoDays — correction d\'accord « il y a 1 jours »', () {
    test('fr, 1 jour : nouveau rendu accordé (jamais atteint par l\'ancien '
        'code, qui renvoyait « hier » avant ce cas — cf. brief)', () {
      final l = AppL10n.current;
      expect(l.devicesAgoDays(1), 'il y a 1 jour');
      expect(l.devicesAgoDays(1), isNot('il y a 1 jours'));
    });

    test('fr, 3 jours : égalité avec l\'ancien rendu concaténé', () {
      final l = AppL10n.current;
      const days = 3;
      expect(l.devicesAgoDays(days), 'il y a $days jours');
    });

    test('en, 1 day', () {
      useEnglish();
      final l = AppL10n.current;
      expect(l.devicesAgoDays(1), '1 day ago');
    });

    test('en, 3 days', () {
      useEnglish();
      final l = AppL10n.current;
      expect(l.devicesAgoDays(3), '3 days ago');
    });
  });

  group('devicesUnknown — inchangé', () {
    test('fr, égalité avec l\'ancien texte', () {
      final l = AppL10n.current;
      expect(l.devicesUnknown, 'Appareil inconnu');
    });

    test('en', () {
      useEnglish();
      final l = AppL10n.current;
      expect(l.devicesUnknown, 'Unknown device');
    });
  });

  group(
    'pinAttemptsLeft — correction d\'accord « tentative(s) restante(s) »',
    () {
      test('fr, 1 tentative : nouveau rendu accordé', () {
        final l = AppL10n.current;
        expect(l.pinAttemptsLeft(1), '1 tentative restante');
        expect(l.pinAttemptsLeft(1), isNot('1 tentative(s) restante(s)'));
      });

      test('fr, 3 tentatives : nouveau rendu accordé', () {
        final l = AppL10n.current;
        expect(l.pinAttemptsLeft(3), '3 tentatives restantes');
        expect(l.pinAttemptsLeft(3), isNot('3 tentative(s) restante(s)'));
      });

      test('en, 1 attempt left', () {
        useEnglish();
        final l = AppL10n.current;
        expect(l.pinAttemptsLeft(1), '1 attempt left');
      });

      test('en, 3 attempts left', () {
        useEnglish();
        final l = AppL10n.current;
        expect(l.pinAttemptsLeft(3), '3 attempts left');
      });
    },
  );
}
