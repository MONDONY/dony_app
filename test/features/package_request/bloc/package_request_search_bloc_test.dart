import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

PackageRequestSearchItem _fakeRequest(String id) => PackageRequestSearchItem(
  id: id,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 6, 15),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: ParcelSize.small,
  categories: const ['Vêtements'],
  sender: const SenderPublicProfile(
    id: 's-1',
    displayName: 'Sender',
    averageRating: 0,
    totalRatings: 0,
    kycVerified: true,
  ),
);

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
  });

  setUp(() => repo = _MockRepo());

  // ─── SearchFiltersChanged → Loading then Loaded ───────────────────────────────

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'SearchFiltersChanged emits Loading then Loaded with results',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
        ),
      ).thenAnswer(
        (_) async => PackageRequestSearchPage(
          content: [_fakeRequest('r-1'), _fakeRequest('r-2')],
          totalElements: 2,
          page: 0,
          size: 20,
        ),
      );
      return PackageRequestSearchBloc(repo);
    },
    act: (bloc) => bloc.add(
      const SearchFiltersChanged(departure: 'Paris', arrival: 'Dakar'),
    ),
    expect: () => [
      isA<PackageRequestSearchState>().having(
        (s) => s.status,
        'status',
        SearchStatus.loading,
      ),
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.loaded)
          .having((s) => s.results.length, 'results.length', 2)
          .having((s) => s.departure, 'departure', 'Paris')
          .having((s) => s.arrival, 'arrival', 'Dakar'),
    ],
  );

  // ─── SearchLoadMore appends page 2 ───────────────────────────────────────────

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'SearchLoadMore appends page 2 to results',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
        ),
      ).thenAnswer(
        (_) async => PackageRequestSearchPage(
          content: [_fakeRequest('r-3'), _fakeRequest('r-4')],
          totalElements: 4,
          page: 1,
          size: 20,
        ),
      );
      return PackageRequestSearchBloc(repo);
    },
    seed: () => PackageRequestSearchState(
      status: SearchStatus.loaded,
      results: [_fakeRequest('r-1'), _fakeRequest('r-2')],
      page: 0,
      hasMore: true,
      departure: 'Paris',
      arrival: 'Dakar',
    ),
    act: (bloc) => bloc.add(const SearchLoadMore()),
    expect: () => [
      isA<PackageRequestSearchState>().having(
        (s) => s.status,
        'status',
        SearchStatus.loadingMore,
      ),
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.loaded)
          .having((s) => s.results.length, 'results.length', 4)
          .having((s) => s.page, 'page', 1),
    ],
    verify: (_) {
      verify(
        () => repo.search(
          departure: 'Paris',
          arrival: 'Dakar',
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: 1,
          urgent: any(named: 'urgent'),
        ),
      ).called(1);
    },
  );

  // ─── Repo error → Error state ─────────────────────────────────────────────────

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'repo error on SearchFiltersChanged emits Error state',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
        ),
      ).thenThrow(Exception('network error'));
      return PackageRequestSearchBloc(repo);
    },
    act: (bloc) => bloc.add(const SearchFiltersChanged(departure: 'Paris')),
    expect: () => [
      isA<PackageRequestSearchState>().having(
        (s) => s.status,
        'status',
        SearchStatus.loading,
      ),
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
  );

  // ─── SearchLoadMore skipped when no hasMore ───────────────────────────────────

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'SearchLoadMore is ignored when hasMore=false',
    build: () => PackageRequestSearchBloc(repo),
    seed: () => const PackageRequestSearchState(
      status: SearchStatus.loaded,
      hasMore: false,
    ),
    act: (bloc) => bloc.add(const SearchLoadMore()),
    expect: () => [],
  );

  // ─── SearchRefresh re-uses current filters ────────────────────────────────────

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'SearchRefresh re-fetches with current filters',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
        ),
      ).thenAnswer(
        (_) async => PackageRequestSearchPage(
          content: [_fakeRequest('r-fresh')],
          totalElements: 1,
          page: 0,
          size: 20,
        ),
      );
      return PackageRequestSearchBloc(repo);
    },
    seed: () => const PackageRequestSearchState(
      status: SearchStatus.loaded,
      departure: 'Lyon',
      arrival: 'Abidjan',
    ),
    act: (bloc) => bloc.add(const SearchRefresh()),
    expect: () => [
      isA<PackageRequestSearchState>().having(
        (s) => s.status,
        'status',
        SearchStatus.loading,
      ),
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.loaded)
          .having((s) => s.results.length, 'results.length', 1),
    ],
    verify: (_) {
      verify(
        () => repo.search(
          departure: 'Lyon',
          arrival: 'Abidjan',
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: 0,
          urgent: any(named: 'urgent'),
        ),
      ).called(1);
    },
  );

  // ─── SearchFiltersChanged(urgent: true) propagates to repo.search ────────────

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'SearchFiltersChanged(urgent: true) → repo appelé avec urgent: true',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
        ),
      ).thenAnswer(
        (_) async => const PackageRequestSearchPage(
          content: [],
          totalElements: 0,
          page: 0,
          size: 20,
        ),
      );
      return PackageRequestSearchBloc(repo);
    },
    act: (bloc) => bloc.add(const SearchFiltersChanged(urgent: true)),
    verify: (_) {
      verify(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: true,
        ),
      ).called(1);
    },
  );

  // ─── SearchFiltersChanged sans urgent → jamais false explicite ───────────────

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'SearchFiltersChanged sans urgent → repo appelé avec urgent: null',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
        ),
      ).thenAnswer(
        (_) async => const PackageRequestSearchPage(
          content: [],
          totalElements: 0,
          page: 0,
          size: 20,
        ),
      );
      return PackageRequestSearchBloc(repo);
    },
    act: (bloc) => bloc.add(const SearchFiltersChanged(departure: 'Paris')),
    verify: (_) {
      verify(
        () => repo.search(
          departure: 'Paris',
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: null,
        ),
      ).called(1);
    },
  );

  // ─── matchingMyTrips : plomberie event → repo ────────────────────────────────

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'SearchFiltersChanged(matchingMyTrips: true) → repo appelé avec true',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
          matchingMyTrips: any(named: 'matchingMyTrips'),
        ),
      ).thenAnswer(
        (_) async => const PackageRequestSearchPage(
          content: [],
          totalElements: 0,
          page: 0,
          size: 20,
        ),
      );
      return PackageRequestSearchBloc(repo);
    },
    act: (bloc) => bloc.add(const SearchFiltersChanged(matchingMyTrips: true)),
    verify: (_) {
      verify(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
          matchingMyTrips: true,
        ),
      ).called(1);
    },
  );

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'SearchFiltersChanged sans matchingMyTrips → repo appelé avec null',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
          matchingMyTrips: any(named: 'matchingMyTrips'),
        ),
      ).thenAnswer(
        (_) async => const PackageRequestSearchPage(
          content: [],
          totalElements: 0,
          page: 0,
          size: 20,
        ),
      );
      return PackageRequestSearchBloc(repo);
    },
    act: (bloc) => bloc.add(const SearchFiltersChanged(departure: 'Paris')),
    verify: (_) {
      final captured = verify(
        () => repo.search(
          departure: 'Paris',
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
          matchingMyTrips: captureAny(named: 'matchingMyTrips'),
        ),
      ).captured;
      // Absent, pas `false` : c'est la convention serveur du filtre.
      expect(captured.single, isNull);
    },
  );

  // L'état porte le filtre : « charger plus » et « rafraîchir » repartent de
  // `state`, pas de l'event, et le perdraient sinon.
  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'SearchLoadMore conserve matchingMyTrips depuis l\'état',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
          matchingMyTrips: any(named: 'matchingMyTrips'),
        ),
      ).thenAnswer(
        (_) async => const PackageRequestSearchPage(
          content: [],
          totalElements: 0,
          page: 0,
          size: 0,
        ),
      );
      return PackageRequestSearchBloc(repo);
    },
    act: (bloc) async {
      bloc.add(const SearchFiltersChanged(matchingMyTrips: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SearchLoadMore());
    },
    verify: (_) {
      verify(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: 1,
          urgent: any(named: 'urgent'),
          matchingMyTrips: true,
        ),
      ).called(1);
    },
  );

  // ─── Analytics : trip_matching_viewed sur recherche filtrée ─────────────────
  //
  // L'event vivait sur `TripMatchingBloc`, supprimé avec l'écran dédié. Son
  // point d'appel est désormais ici : la liste scorée n'est plus qu'une
  // recherche de demandes filtrée.
  group('analytics trip_matching_viewed', () {
    late _MockAnalytics analytics;

    void stubSearch(List<PackageRequestSearchItem> content) {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          page: any(named: 'page'),
          urgent: any(named: 'urgent'),
          matchingMyTrips: any(named: 'matchingMyTrips'),
        ),
      ).thenAnswer(
        (_) async => PackageRequestSearchPage(
          content: content,
          totalElements: content.length,
          page: 0,
          size: 20,
        ),
      );
    }

    setUp(() {
      analytics = _MockAnalytics();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
    });

    blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
      'recherche filtrée → trip_matching_viewed avec le nombre de résultats',
      build: () {
        stubSearch([_fakeRequest('r-1'), _fakeRequest('r-2')]);
        return PackageRequestSearchBloc(repo, analytics);
      },
      act: (bloc) =>
          bloc.add(const SearchFiltersChanged(matchingMyTrips: true)),
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.tripMatchingViewed,
            properties: {'count': 2},
          ),
        ).called(1);
      },
    );

    blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
      'recherche non filtrée → aucun trip_matching_viewed',
      build: () {
        stubSearch([_fakeRequest('r-1')]);
        return PackageRequestSearchBloc(repo, analytics);
      },
      act: (bloc) => bloc.add(const SearchFiltersChanged(departure: 'Paris')),
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.tripMatchingViewed,
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
      'échec de la recherche filtrée → aucun trip_matching_viewed',
      build: () {
        when(
          () => repo.search(
            departure: any(named: 'departure'),
            arrival: any(named: 'arrival'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            maxWeight: any(named: 'maxWeight'),
            parcelSize: any(named: 'parcelSize'),
            page: any(named: 'page'),
            urgent: any(named: 'urgent'),
            matchingMyTrips: any(named: 'matchingMyTrips'),
          ),
        ).thenThrow(Exception('réseau'));
        return PackageRequestSearchBloc(repo, analytics);
      },
      act: (bloc) =>
          bloc.add(const SearchFiltersChanged(matchingMyTrips: true)),
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.tripMatchingViewed,
            properties: any(named: 'properties'),
          ),
        );
      },
    );
  });
}
