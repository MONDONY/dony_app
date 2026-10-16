import 'dart:async';

import 'package:dony/core/network/maintenance_signal.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/maintenance/bloc/maintenance_cubit.dart';
import 'package:dony/features/maintenance/data/models/maintenance_status.dart';
import 'package:dony/features/maintenance/data/repositories/maintenance_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements MaintenanceRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _off = MaintenanceStatus(enabled: false);
final _on = MaintenanceStatus(
  enabled: true,
  message: 'Pause',
  estimatedEndAt: DateTime.utc(2026, 10, 16, 14, 30),
);

void main() {
  late _MockRepository repo;
  late MaintenanceSignal signal;
  late _MockAnalytics analytics;
  late StreamController<bool> live;

  setUp(() {
    repo = _MockRepository();
    signal = MaintenanceSignal();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    live = StreamController<bool>.broadcast();
    when(() => repo.watchEnabled()).thenAnswer((_) => live.stream);
    when(() => repo.fetchStatus()).thenAnswer((_) async => _off);
  });

  tearDown(() => live.close());

  MaintenanceCubit build() => MaintenanceCubit(repo, signal, analytics);

  test('démarrage hors maintenance : rien ne s’affiche', () async {
    final cubit = build()..start();
    await pumpEventQueue();
    expect(cubit.state.active, isFalse);
    verify(() => repo.fetchStatus()).called(1);
    await cubit.close();
  });

  test('Firestore annonce la maintenance : relecture puis écran', () async {
    final cubit = build()..start();
    await pumpEventQueue();
    when(() => repo.fetchStatus()).thenAnswer((_) async => _on);

    live.add(true);
    await pumpEventQueue();

    expect(cubit.state.active, isTrue);
    expect(cubit.state.message, 'Pause');
    expect(cubit.state.estimatedEndAt, DateTime.utc(2026, 10, 16, 14, 30));
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.maintenanceScreenShown,
        properties: {'source': 'status'},
      ),
    ).called(1);
    await cubit.close();
  });

  test('compte exempté : jamais bloqué', () async {
    when(() => repo.fetchStatus()).thenAnswer(
      (_) async => const MaintenanceStatus(enabled: true, exempt: true),
    );
    final cubit = build()..start();
    live.add(true);
    await pumpEventQueue();
    expect(cubit.state.active, isFalse);
    await cubit.close();
  });

  test(
    '503 maintenance : écran immédiat, message affiné par la relecture',
    () async {
      final cubit = build()..start();
      await pumpEventQueue();
      final end = Completer<MaintenanceStatus>();
      when(() => repo.fetchStatus()).thenAnswer((_) => end.future);

      signal.notify(const MaintenanceNotice(message: 'Texte serveur'));
      await pumpEventQueue();
      expect(cubit.state.active, isTrue);
      expect(cubit.state.message, 'Texte serveur');
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.maintenanceScreenShown,
          properties: {'source': 'api'},
        ),
      ).called(1);

      end.complete(const MaintenanceStatus(enabled: true));
      await pumpEventQueue();
      expect(cubit.state.active, isTrue);
      expect(cubit.state.message, isNull, reason: 'texte par défaut de l’app');
      await cubit.close();
    },
  );

  test('réouverture : l’écran se referme et la durée est tracée', () async {
    when(() => repo.fetchStatus()).thenAnswer((_) async => _on);
    final cubit = build()..start();
    await pumpEventQueue();
    expect(cubit.state.active, isTrue);

    when(() => repo.fetchStatus()).thenAnswer((_) async => _off);
    live.add(false);
    await pumpEventQueue();

    expect(cubit.state.active, isFalse);
    expect(cubit.state.message, isNull);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.maintenanceEnded,
        properties: any(named: 'properties'),
      ),
    ).called(1);
    await cubit.close();
  });

  test('erreur réseau : l’état courant reste', () async {
    when(() => repo.fetchStatus()).thenAnswer((_) async => _on);
    final cubit = build()..start();
    await pumpEventQueue();
    when(() => repo.fetchStatus()).thenThrow(Exception('offline'));

    await cubit.check();

    expect(cubit.state.active, isTrue);
    await cubit.close();
  });

  test('Firestore en erreur : sans effet', () async {
    final cubit = build()..start();
    live.addError(Exception('permission-denied'));
    await pumpEventQueue();
    expect(cubit.state.active, isFalse);
    await cubit.close();
  });

  test('deux vérifications simultanées partagent la requête', () async {
    final pending = Completer<MaintenanceStatus>();
    when(() => repo.fetchStatus()).thenAnswer((_) => pending.future);
    final cubit = build();
    final a = cubit.check();
    final b = cubit.check();
    pending.complete(_off);
    await Future.wait([a, b]);
    verify(() => repo.fetchStatus()).called(1);
    await cubit.close();
  });

  test('pendant la maintenance, revérifie toutes les 30 s puis s’arrête', () {
    fakeAsync((async) {
      when(() => repo.fetchStatus()).thenAnswer((_) async => _on);
      final cubit = build()..start();
      async.flushMicrotasks();
      expect(cubit.state.active, isTrue);
      clearInteractions(repo);

      async.elapse(const Duration(seconds: 61));
      verify(() => repo.fetchStatus()).called(2);

      when(() => repo.fetchStatus()).thenAnswer((_) async => _off);
      async.elapse(const Duration(seconds: 30));
      expect(cubit.state.active, isFalse);
      clearInteractions(repo);

      async.elapse(const Duration(minutes: 5));
      verifyNever(() => repo.fetchStatus());
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  test(
    'Réessayer : indicateur pendant la vérification, événement tracé',
    () async {
      when(() => repo.fetchStatus()).thenAnswer((_) async => _on);
      final cubit = build()..start();
      await pumpEventQueue();
      final pending = Completer<MaintenanceStatus>();
      when(() => repo.fetchStatus()).thenAnswer((_) => pending.future);

      final retry = cubit.retry();
      expect(cubit.state.checking, isTrue);
      pending.complete(_off);
      await retry;

      expect(cubit.state.checking, isFalse);
      expect(cubit.state.active, isFalse);
      verify(
        () => analytics.logEvent(AnalyticsEvents.maintenanceRetryTapped),
      ).called(1);
      await cubit.close();
    },
  );

  test('start est idempotent', () async {
    final cubit = build()
      ..start()
      ..start();
    await pumpEventQueue();
    verify(() => repo.watchEnabled()).called(1);
    await cubit.close();
  });
}
