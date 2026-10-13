import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/flights/bloc/flight_alert_offers_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_alert_offers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'flights_test_doubles.dart';

final _alert = FlightAlert(
  id: 'a1',
  originCode: 'PAR',
  destinationCode: 'ABJ',
  departureFrom: DateTime(2099, 12),
  departureTo: DateTime(2099, 12, 20),
  directOnly: false,
  maxPrice: 450,
  currency: 'EUR',
  active: true,
);

FlightAlertOffers _result({List<double> prices = const [389, 438]}) =>
    FlightAlertOffers(
      alertId: 'a1',
      originCode: 'PAR',
      destinationCode: 'ABJ',
      roundTrip: false,
      currency: 'EUR',
      maxPrice: 450,
      offers: [for (final p in prices) offer('/search/$p', price: p)],
      searchPath: '/search/PAR0112ABJ1',
    );

DioException _dio(AppException error) =>
    DioException(requestOptions: RequestOptions(), error: error);

void main() {
  late MockFlightsRepository repository;
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockFlightsRepository();
    analytics = silentAnalytics();
  });

  FlightAlertOffersCubit build({
    FlightAlert? alert,
    FlightAlertOffersSource source = FlightAlertOffersSource.list,
  }) => FlightAlertOffersCubit(
    repository,
    analytics,
    alertId: 'a1',
    alert: alert,
    source: source,
  );

  test('source lue depuis la query', () {
    expect(
      FlightAlertOffersSource.parse('notification'),
      FlightAlertOffersSource.notification,
    );
    expect(FlightAlertOffersSource.parse(null), FlightAlertOffersSource.list);
    expect(FlightAlertOffersSource.parse('x'), FlightAlertOffersSource.list);
  });

  test('vols chargés : tracé une fois (nombre et source)', () async {
    when(() => repository.alertOffers('a1')).thenAnswer((_) async => _result());
    final cubit = build(alert: _alert);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.load();

    expect(cubit.state.status, FlightAlertOffersStatus.loaded);
    expect(cubit.state.result!.offers, hasLength(2));
    expect(cubit.state.alert, _alert);
    verifyNever(() => repository.alerts());
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.flightsAlertOffersViewed,
        properties: {'count': 2, 'source': 'list'},
      ),
    ).called(1);
  });

  test('ouvert par une notification : l\'alerte est retrouvée', () async {
    when(
      () => repository.alertOffers('a1'),
    ).thenAnswer((_) async => _result(prices: const []));
    when(() => repository.alerts()).thenAnswer((_) async => [_alert]);
    final cubit = build(source: FlightAlertOffersSource.notification);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, FlightAlertOffersStatus.empty);
    expect(cubit.state.alert, _alert);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.flightsAlertOffersViewed,
        properties: {'count': 0, 'source': 'notification'},
      ),
    ).called(1);
  });

  test('liste des alertes en échec : l\'écran reste utilisable', () async {
    when(() => repository.alertOffers('a1')).thenAnswer((_) async => _result());
    when(() => repository.alerts()).thenThrow(Exception('offline'));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, FlightAlertOffersStatus.loaded);
    expect(cubit.state.alert, isNull);
  });

  test(
    '404 (ancien back) : vide, Aviasales reconstruit depuis l\'alerte',
    () async {
      when(
        () => repository.alertOffers('a1'),
      ).thenThrow(_dio(const NotFoundException()));
      final cubit = build(alert: _alert);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, FlightAlertOffersStatus.empty);
      expect(cubit.state.result, isNull);
      final now = DateTime(2026, 10, 13);
      expect(cubit.state.searchPath(now), '/search/PAR0112ABJ1');
      final target = cubit.state.aviasalesTarget(now)!;
      expect(target.originCode, 'PAR');
      expect(target.offers, isEmpty);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsAlertOffersViewed,
          properties: {'count': 0, 'source': 'list'},
        ),
      ).called(1);
    },
  );

  test('404 sans alerte connue : pas d\'Aviasales', () async {
    when(
      () => repository.alertOffers('a1'),
    ).thenThrow(_dio(const NotFoundException()));
    when(() => repository.alerts()).thenAnswer((_) async => const []);
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, FlightAlertOffersStatus.empty);
    expect(cubit.state.aviasalesTarget(DateTime(2026)), isNull);
  });

  test('autre erreur : état d\'erreur, réessayer recharge', () async {
    var calls = 0;
    when(() => repository.alertOffers('a1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw _dio(const NetworkException('x', code: 'flights-provider-error'));
      }
      return _result();
    });
    final cubit = build(alert: _alert);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, FlightAlertOffersStatus.error);
    expect(cubit.state.error?.code, 'flights-provider-error');
    verifyNever(
      () => analytics.logEvent(
        AnalyticsEvents.flightsAlertOffersViewed,
        properties: any(named: 'properties'),
      ),
    );

    await cubit.load();
    expect(cubit.state.status, FlightAlertOffersStatus.loaded);
    expect(cubit.state.error, isNull);
    expect(
      cubit.state.aviasalesTarget(DateTime(2026))!.searchPath,
      '/search/PAR0112ABJ1',
    );
  });

  test('cubit fermé pendant l\'appel : rien n\'est émis', () async {
    when(() => repository.alertOffers('a1')).thenAnswer((_) async => _result());
    final cubit = build(alert: _alert);
    final future = cubit.load();
    await cubit.close();
    await future;
    expect(cubit.state.status, FlightAlertOffersStatus.loading);
  });

  test('cubit fermé pendant un échec : rien n\'est émis', () async {
    when(
      () => repository.alertOffers('a1'),
    ).thenAnswer((_) async => throw _dio(const NotFoundException()));
    final cubit = build(alert: _alert);
    final future = cubit.load();
    await cubit.close();
    await future;
    expect(cubit.state.status, FlightAlertOffersStatus.loading);
  });
}
