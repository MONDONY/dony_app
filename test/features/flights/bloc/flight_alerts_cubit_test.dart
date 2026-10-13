import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'flights_test_doubles.dart';

FlightAlert _alert(String id, {bool active = true}) => FlightAlert(
  id: id,
  originCode: 'PAR',
  destinationCode: 'ABJ',
  directOnly: false,
  maxPrice: 450,
  currency: 'EUR',
  active: active,
);

final _draft = FlightAlertDraft(
  originCode: 'PAR',
  destinationCode: 'ABJ',
  departureFrom: DateTime(2026, 12),
  departureTo: DateTime(2026, 12, 20),
  returnFrom: DateTime(2027, 1, 2),
  returnTo: DateTime(2027, 1, 15),
  maxPrice: 450,
);

DioException _error(String code) => DioException(
  requestOptions: RequestOptions(),
  error: NetworkException('x', code: code),
);

void main() {
  late MockFlightsRepository repository;
  late MockAnalyticsService analytics;
  late FlightAlertsCubit cubit;

  setUpAll(() => registerFallbackValue(_draft));

  setUp(() {
    repository = MockFlightsRepository();
    analytics = silentAnalytics();
    cubit = FlightAlertsCubit(repository, analytics);
  });

  tearDown(() => cubit.close());

  test('chargement', () async {
    when(() => repository.alerts()).thenAnswer((_) async => [_alert('a')]);

    await cubit.load();

    expect(cubit.state.status, FlightAlertsStatus.loaded);
    expect(cubit.state.alerts, [_alert('a')]);
  });

  test('chargement en échec', () async {
    when(
      () => repository.alerts(),
    ).thenThrow(_error('flights-account-required'));

    await cubit.load();

    expect(cubit.state.status, FlightAlertsStatus.error);
    expect(cubit.state.error?.code, 'flights-account-required');
  });

  test('création : ajoutée en tête et tracée sans trajet ni prix', () async {
    when(() => repository.alerts()).thenAnswer((_) async => [_alert('a')]);
    when(
      () => repository.createAlert(any()),
    ).thenAnswer((_) async => _alert('b'));
    await cubit.load();

    final ok = await cubit.create(_draft, source: 'results');

    expect(ok, isTrue);
    expect(cubit.state.alerts.map((a) => a.id), ['b', 'a']);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.flightsAlertCreated,
        properties: {
          'round_trip': true,
          'has_period': true,
          'direct_only': false,
          'source': 'results',
        },
      ),
    ).called(1);
  });

  test('création refusée (doublon) : false et erreur exposée', () async {
    when(
      () => repository.createAlert(any()),
    ).thenThrow(_error('flight-alert-duplicate'));

    final ok = await cubit.create(_draft, source: 'alerts');

    expect(ok, isFalse);
    expect(cubit.state.creating, isFalse);
    expect(cubit.state.error?.code, 'flight-alert-duplicate');
  });

  test('bascule optimiste, annulée si le serveur refuse', () async {
    when(() => repository.alerts()).thenAnswer((_) async => [_alert('a')]);
    when(() => repository.setAlertActive('a', false)).thenThrow(_error('x'));
    await cubit.load();

    await cubit.setActive('a', false);

    expect(cubit.state.alerts.single.active, isTrue);
    expect(cubit.state.error, isNotNull);
  });

  test('bascule acceptée : état du serveur et event', () async {
    when(() => repository.alerts()).thenAnswer((_) async => [_alert('a')]);
    when(
      () => repository.setAlertActive('a', false),
    ).thenAnswer((_) async => _alert('a', active: false));
    await cubit.load();

    await cubit.setActive('a', false);

    expect(cubit.state.alerts.single.active, isFalse);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.flightsAlertToggled,
        properties: {'active': false},
      ),
    ).called(1);
  });

  test('suppression optimiste, restaurée en cas d\'échec', () async {
    when(
      () => repository.alerts(),
    ).thenAnswer((_) async => [_alert('a'), _alert('b')]);
    when(() => repository.deleteAlert('a')).thenThrow(_error('x'));
    await cubit.load();

    await cubit.delete('a');

    expect(cubit.state.alerts.map((a) => a.id), ['a', 'b']);
  });

  test('un échec ne rétablit que son alerte : une suppression menée pendant '
      'l\'appel garde son effet', () async {
    when(
      () => repository.alerts(),
    ).thenAnswer((_) async => [_alert('a'), _alert('b')]);
    final toggle = Completer<FlightAlert>();
    when(
      () => repository.setAlertActive('a', false),
    ).thenAnswer((_) => toggle.future);
    when(() => repository.deleteAlert('b')).thenAnswer((_) async {});
    await cubit.load();

    final pending = cubit.setActive('a', false);
    await cubit.delete('b');
    toggle.completeError(_error('x'));
    await pending;

    expect(cubit.state.alerts.map((a) => a.id), ['a']);
    expect(cubit.state.alerts.single.active, isTrue);
  });

  test('suppression réussie', () async {
    when(
      () => repository.alerts(),
    ).thenAnswer((_) async => [_alert('a'), _alert('b')]);
    when(() => repository.deleteAlert('a')).thenAnswer((_) async {});
    await cubit.load();

    await cubit.delete('a');

    expect(cubit.state.alerts.map((a) => a.id), ['b']);
    verify(
      () => analytics.logEvent(AnalyticsEvents.flightsAlertDeleted),
    ).called(1);
  });

  test('rechargement discret : pas d\'état de chargement émis', () async {
    when(() => repository.alerts()).thenAnswer((_) async => [_alert('a')]);
    await cubit.load();
    final statuses = <FlightAlertsStatus>[];
    final sub = cubit.stream.listen((s) => statuses.add(s.status));

    await cubit.load(silent: true);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(statuses, isNot(contains(FlightAlertsStatus.loading)));
    expect(cubit.state.status, FlightAlertsStatus.loaded);
  });

  test('rechargement discret sans liste : chargement émis', () async {
    when(() => repository.alerts()).thenAnswer((_) async => const []);
    final statuses = <FlightAlertsStatus>[];
    final sub = cubit.stream.listen((s) => statuses.add(s.status));

    await cubit.load(silent: true);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(statuses, [FlightAlertsStatus.loading, FlightAlertsStatus.loaded]);
  });

  test('ligne des Outils touchée : état tracé, sans trajet ni prix', () async {
    cubit.trackHubOpened();
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.activitesHubFlightAlertsOpened,
        properties: {'state': 'empty'},
      ),
    ).called(1);

    when(() => repository.alerts()).thenAnswer(
      (_) async => [
        const FlightAlert(
          id: 'a',
          originCode: 'PAR',
          destinationCode: 'ABJ',
          directOnly: false,
          maxPrice: 450,
          currency: 'EUR',
          active: true,
          lastSeenPrice: 389,
          matchCount: 2,
        ),
      ],
    );
    await cubit.load();
    cubit.trackHubOpened();
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.activitesHubFlightAlertsOpened,
        properties: {'state': 'hit'},
      ),
    ).called(1);
  });
}
