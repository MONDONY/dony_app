import 'dart:async';

import 'package:dony/core/services/camera_handoff.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const settle = Duration(milliseconds: 500);

  test('sans lecteur : l\'appareil photo s\'ouvre tout de suite', () {
    fakeAsync((async) {
      final handoff = CameraHandoff();
      final activeDuringOpen = <bool>[];
      String? result;
      handoff
          .runWithSystemCamera(() async {
            activeDuringOpen.add(handoff.systemCameraActive.value);
            return 'photo';
          })
          .then((value) => result = value);
      async.flushMicrotasks();

      expect(result, 'photo');
      expect(activeDuringOpen, [true]);
      expect(handoff.systemCameraActive.value, isFalse);
      expect(handoff.lastSystemCameraEnd, isNotNull);
    });
  });

  test('lecteur en marche : arrêté, puis délai, puis appareil photo', () {
    fakeAsync((async) {
      final handoff = CameraHandoff();
      final calls = <String>[];
      handoff.register(() async {
        calls.add('release');
        return true;
      });
      handoff.runWithSystemCamera(() async => calls.add('open'));

      async.flushMicrotasks();
      expect(calls, ['release']);
      async.elapse(const Duration(milliseconds: 499));
      expect(calls, ['release']);
      async.elapse(const Duration(milliseconds: 1));
      expect(calls, ['release', 'open']);
    });
  });

  test('lecteur déjà arrêté : aucun délai', () {
    fakeAsync((async) {
      final handoff = CameraHandoff();
      var opened = false;
      handoff.register(() async => false);
      handoff.runWithSystemCamera(() async => opened = true);
      async.flushMicrotasks();
      expect(opened, isTrue);
    });
  });

  test('un lecteur en erreur ne bloque pas l\'appareil photo', () {
    fakeAsync((async) {
      final handoff = CameraHandoff();
      var opened = false;
      handoff.register(() async {
        throw StateError('caméra');
      });
      handoff.runWithSystemCamera(() async => opened = true);
      async.flushMicrotasks();
      expect(opened, isTrue);
    });
  });

  test('lecteur sans réponse : l\'appareil photo s\'ouvre quand même', () {
    fakeAsync((async) {
      final handoff = CameraHandoff();
      var opened = false;
      handoff.register(() => Completer<bool>().future);
      handoff.runWithSystemCamera(() async => opened = true);
      async.elapse(CameraHandoff.defaultReleaseTimeout);
      expect(opened, isFalse);
      async.elapse(settle);
      expect(opened, isTrue);
    });
  });

  test('désinscrit : le lecteur n\'est plus appelé', () {
    fakeAsync((async) {
      final handoff = CameraHandoff();
      var released = 0;
      final unregister = handoff.register(() async {
        released++;
        return true;
      });
      expect(handoff.releaserCount, 1);
      unregister();
      expect(handoff.releaserCount, 0);
      handoff.runWithSystemCamera(() async {});
      async.flushMicrotasks();
      expect(released, 0);
    });
  });

  test('appareil photo en erreur : l\'erreur remonte, l\'état est rendu', () {
    fakeAsync((async) {
      final handoff = CameraHandoff();
      Object? error;
      handoff
          .runWithSystemCamera<void>(() async => throw StateError('picker'))
          .catchError((Object e) => error = e);
      async.flushMicrotasks();
      expect(error, isA<StateError>());
      expect(handoff.systemCameraActive.value, isFalse);
    });
  });

  test('ouvertures imbriquées : actif jusqu\'à la dernière fermeture', () {
    fakeAsync((async) {
      final handoff = CameraHandoff();
      final activeAfterInner = <bool>[];
      handoff.runWithSystemCamera(() async {
        await handoff.runWithSystemCamera(() async {});
        activeAfterInner.add(handoff.systemCameraActive.value);
      });
      async.flushMicrotasks();
      expect(activeAfterInner, [true]);
      expect(handoff.systemCameraActive.value, isFalse);
    });
  });

  test('délai par défaut : 500 ms', () {
    expect(CameraHandoff().settleDelay, CameraHandoff.defaultSettleDelay);
    expect(CameraHandoff.defaultSettleDelay, settle);
  });
}
