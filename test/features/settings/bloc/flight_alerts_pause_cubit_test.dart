import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/flights/bloc/flight_alert_updates.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/settings/bloc/flight_alerts_pause_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../flights/bloc/flights_test_doubles.dart';

FlightAlert _alert(String id, {bool active = true}) => FlightAlert(
  id: id,
  originCode: 'PAR',
  destinationCode: 'ABJ',
  directOnly: false,
  maxPrice: 450,
  currency: 'EUR',
  active: active,
);

DioException _offline() => DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.connectionError,
);

void main() {
  late MockFlightsRepository repository;
  late MockAnalyticsService analytics;
  late FlightAlertUpdates updates;
  late FlightAlertsPauseCubit cubit;

  setUp(() {
    repository = MockFlightsRepository();
    analytics = silentAnalytics();
    updates = FlightAlertUpdates();
    cubit = FlightAlertsPauseCubit(repository, analytics, updates: updates);
    when(() => repository.setAlertActive(any(), any())).thenAnswer(
      (inv) async => _alert(
        inv.positionalArguments[0] as String,
        active: inv.positionalArguments[1] as bool,
      ),
    );
  });

  tearDown(() async {
    await cubit.close();
    await updates.dispose();
  });

  void verifyPrompt(int activeCount, String choice) => verify(
    () => analytics.logEvent(
      AnalyticsEvents.settingsFlightsAlertsPausePrompt,
      properties: {'active_count': activeCount, 'choice': choice},
    ),
  ).called(1);

  Future<void> prompt() async {
    when(() => repository.alerts()).thenAnswer(
      (_) async => [_alert('a'), _alert('b', active: false), _alert('c')],
    );
    await cubit.onFlightsHidden();
  }

  test('alertes actives : la feuille est proposée avec leur nombre', () async {
    await prompt();

    expect(cubit.state.phase, FlightAlertsPausePhase.prompt);
    expect(cubit.state.activeIds, ['a', 'c']);
    expect(cubit.state.activeCount, 2);
  });

  test('aucune alerte active : rien n\'est proposé', () async {
    when(
      () => repository.alerts(),
    ).thenAnswer((_) async => [_alert('a', active: false)]);

    await cubit.onFlightsHidden();

    expect(cubit.state, const FlightAlertsPauseState());
    verifyNever(() => repository.setAlertActive(any(), any()));
  });

  test('lecture en échec (hors ligne) : masquage sans feuille', () async {
    when(() => repository.alerts()).thenThrow(_offline());

    await cubit.onFlightsHidden();

    expect(cubit.state.phase, FlightAlertsPausePhase.idle);
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
  });

  test('lecture déjà en cours : pas de seconde lecture', () async {
    final pending = Completer<List<FlightAlert>>();
    when(() => repository.alerts()).thenAnswer((_) => pending.future);

    final first = cubit.onFlightsHidden();
    await cubit.onFlightsHidden();
    pending.complete([]);
    await first;

    verify(() => repository.alerts()).called(1);
  });

  test('cubit fermé pendant la lecture : aucun état émis', () async {
    final pending = Completer<List<FlightAlert>>();
    when(() => repository.alerts()).thenAnswer((_) => pending.future);

    final call = cubit.onFlightsHidden();
    await cubit.close();
    pending.complete([_alert('a')]);
    await call;

    expect(cubit.state.phase, FlightAlertsPausePhase.checking);
  });

  test('pause : PATCH sur chaque alerte active seulement', () async {
    await prompt();
    final published = <FlightAlert>[];
    final sub = updates.stream.listen(published.add);

    await cubit.pause();
    await Future<void>.delayed(Duration.zero);

    verify(() => repository.setAlertActive('a', false)).called(1);
    verify(() => repository.setAlertActive('c', false)).called(1);
    verifyNever(() => repository.setAlertActive('b', any()));
    expect(
      cubit.state,
      const FlightAlertsPauseState(
        phase: FlightAlertsPausePhase.done,
        activeIds: ['a', 'c'],
        paused: 2,
      ),
    );
    expect(published.map((a) => a.id), ['a', 'c']);
    expect(published.every((a) => !a.active), isTrue);
    verifyPrompt(2, 'pause');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.settingsFlightsAlertsPaused,
        properties: {'count': 2, 'failed': 0},
      ),
    ).called(1);

    cubit.acknowledge();
    expect(cubit.state.phase, FlightAlertsPausePhase.idle);
    await sub.cancel();
  });

  test('pause : état de chargement pendant les appels', () async {
    await prompt();
    final pending = Completer<FlightAlert>();
    when(
      () => repository.setAlertActive('a', false),
    ).thenAnswer((_) => pending.future);

    final call = cubit.pause();
    expect(cubit.state.phase, FlightAlertsPausePhase.pausing);
    // Un second appui ne relance rien.
    await cubit.pause();
    pending.complete(_alert('a', active: false));
    await call;

    verify(() => repository.setAlertActive('a', false)).called(1);
    expect(cubit.state.phase, FlightAlertsPausePhase.done);
  });

  test('échec partiel : les alertes refusées sont comptées', () async {
    await prompt();
    when(() => repository.setAlertActive('c', false)).thenThrow(_offline());

    await cubit.pause();

    expect(cubit.state.paused, 1);
    expect(cubit.state.failed, 1);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.settingsFlightsAlertsPaused,
        properties: {'count': 1, 'failed': 1},
      ),
    ).called(1);
  });

  test('keep : aucun PATCH, réponse mesurée', () async {
    await prompt();

    cubit.keep();

    expect(cubit.state.phase, FlightAlertsPausePhase.idle);
    verifyNever(() => repository.setAlertActive(any(), any()));
    verifyPrompt(2, 'keep');
  });

  test('dismiss : aucun PATCH, réponse mesurée', () async {
    await prompt();

    cubit.dismiss();

    expect(cubit.state.phase, FlightAlertsPausePhase.idle);
    verifyNever(() => repository.setAlertActive(any(), any()));
    verifyPrompt(2, 'dismiss');
  });

  test('dismiss après la pause ou hors feuille : sans effet', () async {
    cubit.dismiss();
    await prompt();
    await cubit.pause();

    cubit.dismiss();

    expect(cubit.state.phase, FlightAlertsPausePhase.done);
    verifyNever(
      () => analytics.logEvent(
        AnalyticsEvents.settingsFlightsAlertsPausePrompt,
        properties: {'active_count': 2, 'choice': 'dismiss'},
      ),
    );
  });

  test(
    'cancel : feuille abandonnée sans mesure (billets réaffichés)',
    () async {
      await prompt();

      cubit.cancel();

      expect(cubit.state.phase, FlightAlertsPausePhase.idle);
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
      // Hors feuille : sans effet.
      cubit
        ..cancel()
        ..acknowledge();
      expect(cubit.state.phase, FlightAlertsPausePhase.idle);
    },
  );

  test('pause sans canal de mise à jour', () async {
    final bare = FlightAlertsPauseCubit(repository, analytics);
    when(() => repository.alerts()).thenAnswer((_) async => [_alert('a')]);
    await bare.onFlightsHidden();

    await bare.pause();

    expect(bare.state.paused, 1);
    await bare.close();
  });

  test('cubit fermé pendant la pause : aucun état émis', () async {
    await prompt();
    final pending = Completer<FlightAlert>();
    when(
      () => repository.setAlertActive('a', false),
    ).thenAnswer((_) => pending.future);

    final call = cubit.pause();
    await cubit.close();
    pending.complete(_alert('a', active: false));
    await call;

    expect(cubit.state.phase, FlightAlertsPausePhase.pausing);
  });

  group('FlightAlertsCubit vivant', () {
    test('applique les alertes mises en pause ailleurs', () async {
      final alerts = FlightAlertsCubit(repository, analytics, updates: updates);
      when(
        () => repository.alerts(),
      ).thenAnswer((_) async => [_alert('a'), _alert('z')]);
      await alerts.load();

      updates
        ..publish(_alert('a', active: false))
        ..publish(_alert('inconnue', active: false));
      await Future<void>.delayed(Duration.zero);

      expect(alerts.state.alerts, [_alert('a', active: false), _alert('z')]);
      await alerts.close();
      // Fermé : plus aucune mise à jour reçue.
      updates.publish(_alert('z', active: false));
      await Future<void>.delayed(Duration.zero);
      expect(alerts.state.alerts.last.active, isTrue);
    });

    test('canal fermé : publication ignorée', () async {
      final closed = FlightAlertUpdates();
      await closed.dispose();

      expect(() => closed.publish(_alert('a')), returnsNormally);
    });
  });
}
