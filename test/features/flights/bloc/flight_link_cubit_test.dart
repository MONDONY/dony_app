import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'flights_test_doubles.dart';

class MockExternalUrlLauncher extends Mock implements ExternalUrlLauncher {}

void main() {
  late MockFlightsRepository repository;
  late MockAnalyticsService analytics;
  late MockExternalUrlLauncher launcher;
  late FlightLinkCubit cubit;
  final theOffer = offer('/search/X');

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(theOffer);
  });

  setUp(() {
    repository = MockFlightsRepository();
    analytics = silentAnalytics();
    launcher = MockExternalUrlLauncher();
    cubit = FlightLinkCubit(repository, analytics, launcher);
  });

  tearDown(() => cubit.close());

  test('lien obtenu puis ouvert dans le navigateur externe', () async {
    when(
      () => repository.affiliateLink(any(), source: any(named: 'source')),
    ).thenAnswer((_) async => 'https://www.aviasales.com/search/X?marker=1');
    when(() => launcher.open(any())).thenAnswer((_) async => true);

    await cubit.open(theOffer, source: 'search');

    verify(
      () => launcher.open(
        Uri.parse('https://www.aviasales.com/search/X?marker=1'),
      ),
    ).called(1);
    expect(cubit.state.openingPath, isNull);
    expect(cubit.state.failures, 0);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.flightsOfferClicked,
        properties: {
          'source': 'search',
          'airline_code': 'AT',
          'stops': 1,
          'round_trip': false,
        },
      ),
    ).called(1);
  });

  test('navigateur introuvable : échec signalé', () async {
    when(
      () => repository.affiliateLink(any(), source: any(named: 'source')),
    ).thenAnswer((_) async => 'https://www.aviasales.com/search/X');
    when(() => launcher.open(any())).thenAnswer((_) async => false);

    await cubit.open(theOffer, source: 'deal');

    expect(cubit.state.failures, 1);
    expect(cubit.state.error?.code, 'flights-launch-failed');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.flightsOfferOpenFailed,
        properties: {'reason': 'launch'},
      ),
    ).called(1);
  });

  test('back indisponible : rien n\'est ouvert', () async {
    when(
      () => repository.affiliateLink(any(), source: any(named: 'source')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        error: const NetworkException('x', code: 'flights-unavailable'),
      ),
    );

    await cubit.open(theOffer, source: 'search');

    verifyNever(() => launcher.open(any()));
    expect(cubit.state.error?.code, 'flights-unavailable');
    expect(cubit.state.failures, 1);
  });

  group('voir toutes les compagnies', () {
    const result = FlightSearchResult(
      originCode: 'PAR',
      destinationCode: 'ABJ',
      roundTrip: true,
      currency: 'XOF',
      offers: [],
      searchPath: '/search/PAR1212ABJ03011',
    );

    test('la recherche Aviasales passe par le même lien affilié', () async {
      FlightOffer? sent;
      when(
        () => repository.affiliateLink(any(), source: any(named: 'source')),
      ).thenAnswer((inv) async {
        sent = inv.positionalArguments.first as FlightOffer;
        return 'https://www.aviasales.com/search/PAR1212ABJ03011?marker=1';
      });
      when(() => launcher.open(any())).thenAnswer((_) async => true);

      await cubit.openAllAirlines(result, from: 'results');

      expect(sent?.offerPath, '/search/PAR1212ABJ03011');
      expect(sent?.originCode, 'PAR');
      expect(sent?.currency, 'XOF');
      verify(() => repository.affiliateLink(any(), source: 'search')).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsAllAirlinesOpened,
          properties: {'from': 'results'},
        ),
      ).called(1);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.flightsOfferClicked,
          properties: any(named: 'properties'),
        ),
      );
    });

    test('sans chemin de recherche : rien ne part', () async {
      await cubit.openAllAirlines(
        const FlightSearchResult(
          originCode: 'PAR',
          destinationCode: 'ABJ',
          roundTrip: false,
          currency: 'EUR',
          offers: [],
        ),
        from: 'empty',
      );
      verifyNever(
        () => repository.affiliateLink(any(), source: any(named: 'source')),
      );
    });
  });
}
