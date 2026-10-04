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
}
