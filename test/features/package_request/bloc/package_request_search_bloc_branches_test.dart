// Événements construits à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/value_equality.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

PackageRequestSearchItem _item(String id) => PackageRequestSearchItem(
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

  setUpAll(() => registerFallbackValue(ParcelSize.small));
  setUp(() => repo = _MockRepo());

  group('événements — égalité de valeur', () {
    test('SearchFiltersChanged : chaque filtre participe à l’égalité', () {
      SearchFiltersChanged make({
        String? departure = 'Paris',
        double? radius = 25,
        bool? urgent,
        bool? matching,
      }) => SearchFiltersChanged(
        departure: departure,
        arrival: 'Dakar',
        dateFrom: DateTime(2026, 6, 2),
        dateTo: DateTime(2026, 6, 30),
        maxWeight: 10,
        parcelSize: ParcelSize.medium,
        userLat: 48.85,
        userLng: 2.35,
        radiusKm: radius,
        urgent: urgent,
        matchingMyTrips: matching,
      );
      expectValueEquality(make, [
        make(departure: 'Lyon'),
        make(radius: 50),
        make(urgent: true),
        make(matching: true),
      ]);
    });

    test('pagination et rafraîchissement : sans champ, distincts', () {
      expectValueEquality(() => SearchLoadMore(), [SearchRefresh()]);
      expectValueEquality(() => SearchRefresh(), [SearchLoadMore()]);
      expect(SearchRefresh().props, isEmpty);
    });
  });

  test('isNearMeActive exige latitude ET longitude', () {
    expect(const PackageRequestSearchState().isNearMeActive, isFalse);
    expect(
      const PackageRequestSearchState(userLat: 48.8).isNearMeActive,
      isFalse,
    );
    expect(
      const PackageRequestSearchState(
        userLat: 48.8,
        userLng: 2.3,
      ).isNearMeActive,
      isTrue,
    );
  });

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'page suivante en échec → erreur, résultats et filtres conservés',
    build: () {
      when(
        () => repo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          radiusKm: any(named: 'radiusKm'),
          urgent: any(named: 'urgent'),
          matchingMyTrips: any(named: 'matchingMyTrips'),
          page: any(named: 'page'),
        ),
      ).thenThrow(const ServerException());
      return PackageRequestSearchBloc(repo);
    },
    seed: () => PackageRequestSearchState(
      status: SearchStatus.loaded,
      results: [_item('r-1')],
      departure: 'Paris',
    ),
    act: (b) => b.add(SearchLoadMore()),
    expect: () => [
      isA<PackageRequestSearchState>().having(
        (s) => s.status,
        'status',
        SearchStatus.loadingMore,
      ),
      isA<PackageRequestSearchState>()
          .having((s) => s.status, 'status', SearchStatus.error)
          .having((s) => s.errorMessage, 'error', isA<ServerException>())
          .having((s) => s.results, 'results', hasLength(1))
          .having((s) => s.departure, 'departure', 'Paris'),
    ],
    verify: (_) => verify(
      () => repo.search(
        departure: 'Paris',
        arrival: any(named: 'arrival'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        maxWeight: any(named: 'maxWeight'),
        parcelSize: any(named: 'parcelSize'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
        matchingMyTrips: any(named: 'matchingMyTrips'),
        page: 1,
      ),
    ).called(1),
  );

  blocTest<PackageRequestSearchBloc, PackageRequestSearchState>(
    'page suivante ignorée quand il n’y a plus de résultats',
    build: () => PackageRequestSearchBloc(repo),
    seed: () =>
        PackageRequestSearchState(status: SearchStatus.loaded, hasMore: false),
    act: (b) => b.add(SearchLoadMore()),
    expect: () => <PackageRequestSearchState>[],
    verify: (_) => verifyZeroInteractions(repo),
  );
}
