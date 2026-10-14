import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/bloc/flight_search_cubit.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'flights_test_doubles.dart';

class _MockLauncher extends Mock implements ExternalUrlLauncher {}

Map<String, dynamic> _roundTrip(String path, String out, String back) => {
  'originCode': 'PAR',
  'destinationCode': 'ABJ',
  'departureAt': '${out}T11:45:00+01:00',
  'returnAt': '${back}T20:10:00Z',
  'price': 612,
  'currency': 'EUR',
  'offerPath': path,
};

Map<String, dynamic> _base(Map<String, dynamic> extra) => {
  'originCode': 'PAR',
  'destinationCode': 'ABJ',
  'roundTrip': true,
  'currency': 'EUR',
  'offers': const [],
  ...extra,
};

void main() {
  group('FlightSearchResult : séjours proches', () {
    test('ancien back : champs absents, liste vide et plage nulle', () {
      final r = FlightSearchResult.fromJson(_base({}));
      expect(r.similarOffers, isEmpty);
      expect(r.similarStayMinDays, isNull);
      expect(r.similarStayMaxDays, isNull);
      expect(r.similarStayRange, isNull);
    });

    test('offres et plage du back lues', () {
      final r = FlightSearchResult.fromJson(
        _base({
          'similarOffers': [
            _roundTrip('s1', '2026-11-20', '2026-12-18'),
            _roundTrip('s2', '2027-01-05', '2027-02-02'),
          ],
          'similarStayMinDays': 21,
          'similarStayMaxDays': '35',
        }),
      );
      expect(r.similarOffers.map((o) => o.offerPath), ['s1', 's2']);
      expect(r.similarOffers.first.stayDays, 28);
      expect(r.similarStayRange, (min: 21, max: 35));
      expect(
        r,
        isNot(FlightSearchResult.fromJson(_base({'similarOffers': []}))),
      );
    });

    test('valeurs inattendues ignorées, plage déduite des offres', () {
      final r = FlightSearchResult.fromJson(
        _base({
          'similarOffers': [
            _roundTrip('s1', '2026-11-20', '2026-12-18'),
            'pas un objet',
            _roundTrip('s2', '2026-11-22', '2026-12-14'),
          ],
          'similarStayMinDays': 0,
          'similarStayMaxDays': 'beaucoup',
        }),
      );
      expect(r.similarOffers, hasLength(2));
      expect(r.similarStayMinDays, isNull);
      expect(r.similarStayMaxDays, isNull);
      expect(r.similarStayRange, (min: 22, max: 28));
    });

    test('liste d\'un autre type : vide ; plage inversée : repli', () {
      expect(
        FlightSearchResult.fromJson(
          _base({'similarOffers': 'non'}),
        ).similarOffers,
        isEmpty,
      );
      final r = FlightSearchResult.fromJson(
        _base({
          'similarOffers': [_roundTrip('s1', '2026-11-20', '2026-12-18')],
          'similarStayMinDays': 35,
          'similarStayMaxDays': 21,
        }),
      );
      expect(r.similarStayRange, (min: 28, max: 28));
    });

    test('aller simple : ni durée de séjour ni plage', () {
      const oneWay = FlightOffer(
        originCode: 'PAR',
        destinationCode: 'ABJ',
        price: 300,
        currency: 'EUR',
        offerPath: 'x',
      );
      expect(oneWay.stayDays, isNull);
      expect(
        const FlightSearchResult(
          originCode: 'PAR',
          destinationCode: 'ABJ',
          roundTrip: false,
          currency: 'EUR',
          offers: [],
          similarOffers: [oneWay],
        ).similarStayRange,
        isNull,
      );
      final sameDay = FlightOffer(
        originCode: 'PAR',
        destinationCode: 'ABJ',
        price: 300,
        currency: 'EUR',
        offerPath: 'y',
        departureAt: DateTime(2026, 12, 1, 8),
        returnAt: DateTime(2026, 12, 1, 22),
      );
      expect(sameDay.stayDays, isNull);
    });
  });

  group('FlightSearchCubit : flights_similar_offers_shown', () {
    late MockFlightsRepository repository;
    late MockAnalyticsService analytics;
    late FlightSearchCubit cubit;

    setUpAll(() => registerFallbackValue(const FlightSearchQuery()));

    setUp(() {
      repository = MockFlightsRepository();
      analytics = silentAnalytics();
      cubit = FlightSearchCubit(repository, analytics)
        ..setOrigin(const FlightPlace(code: 'PAR', name: 'Paris'))
        ..setDestination(const FlightPlace(code: 'ABJ', name: 'Abidjan'))
        ..setDates(
          FlightWhen.day(DateTime(2026, 12, 2)),
          FlightWhen.day(DateTime(2026, 12, 29)),
        );
    });

    tearDown(() => cubit.close());

    test('séjours proches reçus : tracés avec leur nombre', () async {
      when(() => repository.search(any())).thenAnswer(
        (_) async => FlightSearchResult.fromJson(
          _base({
            'similarOffers': [
              _roundTrip('s1', '2026-11-20', '2026-12-18'),
              _roundTrip('s2', '2027-01-05', '2027-02-02'),
            ],
          }),
        ),
      );

      await cubit.search();

      expect(cubit.state.result?.similarOffers, hasLength(2));
      // Ni les onglets ni les filtres ne voient les séjours proches.
      expect(cubit.state.visibleOffers, isEmpty);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsSimilarOffersShown,
          properties: {'count': 2, 'empty': true},
        ),
      ).called(1);
    });

    test('aucun séjour proche : rien de tracé', () async {
      when(
        () => repository.search(any()),
      ).thenAnswer((_) async => FlightSearchResult.fromJson(_base({})));

      await cubit.search();

      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.flightsSimilarOffersShown,
          properties: any(named: 'properties'),
        ),
      );
    });
  });

  group('FlightLinkCubit.openSimilar', () {
    final similar = FlightOffer.fromJson(
      _roundTrip('/search/S1', '2026-11-20', '2026-12-18'),
    );

    setUpAll(() {
      registerFallbackValue(Uri());
      registerFallbackValue(similar);
    });

    test('source search pour le back, similar pour l\'analytics', () async {
      final repository = MockFlightsRepository();
      final analytics = silentAnalytics();
      final launcher = _MockLauncher();
      final cubit = FlightLinkCubit(repository, analytics, launcher);
      addTearDown(cubit.close);
      when(
        () => repository.affiliateLink(any(), source: any(named: 'source')),
      ).thenAnswer((_) async => 'https://www.aviasales.com/search/S1');
      when(() => launcher.open(any())).thenAnswer((_) async => true);

      await cubit.openSimilar(similar);

      verify(
        () => repository.affiliateLink(similar, source: 'search'),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsOfferClicked,
          properties: {
            'source': 'similar',
            'stops': -1,
            'round_trip': true,
            'passengers': 1,
          },
        ),
      ).called(1);
    });
  });
}
