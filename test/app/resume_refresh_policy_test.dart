import 'package:dony/app/resume_refresh_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chaque retour au premier plan relançait support, Stripe et pastilles, y
/// compris après un simple coup d'œil au centre de notifications ou une
/// validation Face ID. Seule une vraie absence justifie de tout relire.
void main() {
  final now = DateTime(2026, 10, 5, 12);

  group('isResumeRefreshDue', () {
    test(
      'jamais passé en arrière-plan (Face ID, centre de notifications) : non',
      () {
        expect(isResumeRefreshDue(hiddenAt: null, now: now), isFalse);
      },
    );

    test('absent 20 s : non', () {
      expect(
        isResumeRefreshDue(
          hiddenAt: now.subtract(const Duration(seconds: 20)),
          now: now,
        ),
        isFalse,
      );
    });

    test('absent 60 s : oui', () {
      expect(
        isResumeRefreshDue(
          hiddenAt: now.subtract(const Duration(seconds: 60)),
          now: now,
        ),
        isTrue,
      );
    });

    test('absent 10 min : oui', () {
      expect(
        isResumeRefreshDue(
          hiddenAt: now.subtract(const Duration(minutes: 10)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('ProfileRefreshThrottle', () {
    test('première reprise : relecture due', () {
      expect(ProfileRefreshThrottle().shouldRefresh(now), isTrue);
    });

    test('plusieurs reprises dans la fenêtre : un seul rafraîchissement', () {
      final throttle = ProfileRefreshThrottle();
      expect(throttle.shouldRefresh(now), isTrue);
      expect(
        throttle.shouldRefresh(now.add(const Duration(seconds: 5))),
        isFalse,
      );
      expect(
        throttle.shouldRefresh(now.add(const Duration(seconds: 29))),
        isFalse,
      );
    });

    test('après la fenêtre de 30 s : de nouveau due', () {
      final throttle = ProfileRefreshThrottle();
      expect(throttle.shouldRefresh(now), isTrue);
      expect(
        throttle.shouldRefresh(now.add(const Duration(seconds: 30))),
        isTrue,
      );
    });
  });
}
