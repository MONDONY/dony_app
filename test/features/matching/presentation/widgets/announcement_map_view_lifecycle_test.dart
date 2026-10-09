import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldRecreateNativeMap (FLUTTER-BK)', () {
    test('une pause brève (permission, notification) garde la carte', () {
      expect(shouldRecreateNativeMap(Duration.zero), isFalse);
      expect(shouldRecreateNativeMap(const Duration(seconds: 2)), isFalse);
    });

    test('une vraie pause recrée la vue native de la carte', () {
      expect(shouldRecreateNativeMap(kMapRecreateAfterPause), isTrue);
      expect(shouldRecreateNativeMap(const Duration(minutes: 10)), isTrue);
    });
  });

  group('shouldRecreateOnMemoryPressure (FLUTTER-FF)', () {
    final now = DateTime(2026, 10, 9, 12);

    test('carte créée et visible : recréée tout de suite', () {
      expect(
        shouldRecreateOnMemoryPressure(
          mapCreated: true,
          inForeground: true,
          now: now,
        ),
        isTrue,
      );
    });

    test('carte pas encore créée : rien à recréer', () {
      expect(
        shouldRecreateOnMemoryPressure(
          mapCreated: false,
          inForeground: true,
          now: now,
        ),
        isFalse,
      );
    });

    test('en arrière-plan : on attend le retour', () {
      expect(
        shouldRecreateOnMemoryPressure(
          mapCreated: true,
          inForeground: false,
          now: now,
        ),
        isFalse,
      );
    });

    test('alertes répétées : une recréation par intervalle', () {
      expect(
        shouldRecreateOnMemoryPressure(
          mapCreated: true,
          inForeground: true,
          now: now,
          lastRecreatedAt: now.subtract(const Duration(seconds: 5)),
        ),
        isFalse,
      );
      expect(
        shouldRecreateOnMemoryPressure(
          mapCreated: true,
          inForeground: true,
          now: now,
          lastRecreatedAt: now.subtract(kMapMemoryRecreateCooldown),
        ),
        isTrue,
      );
    });
  });

  group('shouldRecreateOnResume (FLUTTER-BK + FLUTTER-FF)', () {
    test('pause brève sans alerte mémoire : carte gardée', () {
      expect(
        shouldRecreateOnResume(
          pausedFor: const Duration(seconds: 1),
          mapCreated: true,
          memoryPressureWhilePaused: false,
        ),
        isFalse,
      );
    });

    test('pause brève mais alerte mémoire sur une carte créée : recréée', () {
      expect(
        shouldRecreateOnResume(
          pausedFor: const Duration(seconds: 1),
          mapCreated: true,
          memoryPressureWhilePaused: true,
        ),
        isTrue,
      );
    });

    test('alerte mémoire sans carte créée : pause brève, rien à faire', () {
      expect(
        shouldRecreateOnResume(
          pausedFor: const Duration(seconds: 1),
          mapCreated: false,
          memoryPressureWhilePaused: true,
        ),
        isFalse,
      );
    });

    test('vraie pause : recréée comme avant', () {
      expect(
        shouldRecreateOnResume(
          pausedFor: kMapRecreateAfterPause,
          mapCreated: false,
          memoryPressureWhilePaused: false,
        ),
        isTrue,
      );
    });
  });
}
