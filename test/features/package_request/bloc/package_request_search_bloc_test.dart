import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

PackageRequest _fakeRequest(String id) => PackageRequest(
      id: id,
      senderId: 's-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 15),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.small,
      contentCategory: 'vetements',
      status: PackageRequestStatus.open,
      createdAt: DateTime(2026, 5, 10),
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
      when(() => repo.search(
            departure: any(named: 'departure'),
            arrival: any(named: 'arrival'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            maxWeight: any(named: 'maxWeight'),
            parcelSize: any(named: 'parcelSize'),
            page: any(named: 'page'),
          )).thenAnswer((_) async => PackageRequestPage(
            content: [_fakeRequest('r-1'), _fakeRequest('r-2')],
            totalElements: 2,
            page: 0,
            size: 20,
          ));
      return PackageRequestSearchBloc(repo);
    },
    act: (bloc) => bloc.add(const SearchFiltersChanged(
      departure: 'Paris',
      arrival: 'Dakar',
    )),
    expect: () => [
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.loading),
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
      when(() => repo.search(
            departure: any(named: 'departure'),
            arrival: any(named: 'arrival'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            maxWeight: any(named: 'maxWeight'),
            parcelSize: any(named: 'parcelSize'),
            page: any(named: 'page'),
          )).thenAnswer((_) async => PackageRequestPage(
            content: [_fakeRequest('r-3'), _fakeRequest('r-4')],
            totalElements: 4,
            page: 1,
            size: 20,
          ));
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
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.loadingMore),
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.loaded)
          .having((s) => s.results.length, 'results.length', 4)
          .having((s) => s.page, 'page', 1),
    ],
    verify: (_) {
      verify(() => repo.search(
            departure: 'Paris',
            arrival: 'Dakar',
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            maxWeight: any(named: 'maxWeight'),
            parcelSize: any(named: 'parcelSize'),
            page: 1,
          )).called(1);
    },
  );

  // ─── Repo error → Error state ─────────────────────────────────────────────────

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'repo error on SearchFiltersChanged emits Error state',
    build: () {
      when(() => repo.search(
            departure: any(named: 'departure'),
            arrival: any(named: 'arrival'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            maxWeight: any(named: 'maxWeight'),
            parcelSize: any(named: 'parcelSize'),
            page: any(named: 'page'),
          )).thenThrow(Exception('network error'));
      return PackageRequestSearchBloc(repo);
    },
    act: (bloc) => bloc.add(const SearchFiltersChanged(departure: 'Paris')),
    expect: () => [
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.loading),
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
      when(() => repo.search(
            departure: any(named: 'departure'),
            arrival: any(named: 'arrival'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            maxWeight: any(named: 'maxWeight'),
            parcelSize: any(named: 'parcelSize'),
            page: any(named: 'page'),
          )).thenAnswer((_) async => PackageRequestPage(
            content: [_fakeRequest('r-fresh')],
            totalElements: 1,
            page: 0,
            size: 20,
          ));
      return PackageRequestSearchBloc(repo);
    },
    seed: () => const PackageRequestSearchState(
      status: SearchStatus.loaded,
      departure: 'Lyon',
      arrival: 'Abidjan',
    ),
    act: (bloc) => bloc.add(const SearchRefresh()),
    expect: () => [
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.loading),
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.loaded)
          .having((s) => s.results.length, 'results.length', 1),
    ],
    verify: (_) {
      verify(() => repo.search(
            departure: 'Lyon',
            arrival: 'Abidjan',
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            maxWeight: any(named: 'maxWeight'),
            parcelSize: any(named: 'parcelSize'),
            page: 0,
          )).called(1);
    },
  );
}
