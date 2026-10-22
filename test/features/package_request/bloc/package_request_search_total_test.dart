import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

List<PackageRequestSearchItem> _items(int n, [String prefix = 'r']) =>
    List.generate(n, (i) => _item('$prefix-$i'));

void main() {
  late _MockRepo repo;

  setUpAll(() => registerFallbackValue(ParcelSize.small));
  setUp(() => repo = _MockRepo());

  void stubSearch(Map<int, PackageRequestSearchPage> pages) {
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
    ).thenAnswer((inv) async => pages[inv.namedArguments[#page] as int? ?? 0]!);
  }

  PackageRequestSearchPage page(
    int n,
    int total,
    int number, [
    String p = 'r',
  ]) => PackageRequestSearchPage(
    content: _items(n, p),
    totalElements: total,
    page: number,
    size: 20,
  );

  group('totalElements', () {
    test(
      'posé par la première page, sans changer avec les lignes chargées',
      () async {
        stubSearch({0: page(20, 45, 0)});
        final bloc = PackageRequestSearchBloc(repo)
          ..add(const SearchFiltersChanged(departure: 'Paris'));
        await bloc.stream.firstWhere((s) => s.status == SearchStatus.loaded);

        expect(bloc.state.totalElements, 45);
        expect(bloc.state.results.length, 20);
        expect(bloc.state.displayCount, 45);
        await bloc.close();
      },
    );

    test(
      'conservé et mis à jour par le chargement de la page suivante',
      () async {
        stubSearch({0: page(20, 45, 0), 1: page(20, 46, 1, 'q')});
        final bloc = PackageRequestSearchBloc(repo)
          ..add(const SearchFiltersChanged());
        await bloc.stream.firstWhere((s) => s.status == SearchStatus.loaded);

        bloc.add(const SearchLoadMore());
        await bloc.stream.firstWhere(
          (s) => s.status == SearchStatus.loaded && s.results.length == 40,
        );

        expect(bloc.state.totalElements, 46);
        expect(bloc.state.displayCount, 46);
        await bloc.close();
      },
    );

    test('suit le nouveau total quand les filtres changent', () async {
      stubSearch({0: page(20, 45, 0)});
      final bloc = PackageRequestSearchBloc(repo)
        ..add(const SearchFiltersChanged());
      await bloc.stream.firstWhere((s) => s.status == SearchStatus.loaded);

      stubSearch({0: page(3, 3, 0, 'f')});
      bloc.add(const SearchFiltersChanged(arrival: 'Dakar'));
      // Pendant le chargement, l'ancien total ne survit pas aux filtres.
      final loading = await bloc.stream.firstWhere(
        (s) => s.status == SearchStatus.loading,
      );
      expect(loading.totalElements, isNull);
      await bloc.stream.firstWhere((s) => s.status == SearchStatus.loaded);

      expect(bloc.state.totalElements, 3);
      expect(bloc.state.displayCount, 3);
      await bloc.close();
    });

    test('SearchRefresh relit le total', () async {
      stubSearch({0: page(20, 45, 0)});
      final bloc = PackageRequestSearchBloc(repo)
        ..add(const SearchFiltersChanged());
      await bloc.stream.firstWhere((s) => s.status == SearchStatus.loaded);

      stubSearch({0: page(20, 50, 0)});
      bloc.add(const SearchRefresh());
      await bloc.stream.firstWhere(
        (s) => s.status == SearchStatus.loaded && s.totalElements == 50,
      );
      await bloc.close();
    });

    test('un back sans total (lu 0) retombe sur le nombre chargé', () async {
      stubSearch({0: page(7, 0, 0)});
      final bloc = PackageRequestSearchBloc(repo)
        ..add(const SearchFiltersChanged());
      await bloc.stream.firstWhere((s) => s.status == SearchStatus.loaded);

      expect(bloc.state.displayCount, 7);
      await bloc.close();
    });
  });

  group('displayCount', () {
    test('vaut 0 avant toute réponse', () {
      expect(const PackageRequestSearchState().displayCount, 0);
    });

    test('total inconnu : nombre chargé', () {
      final s = PackageRequestSearchState(results: _items(3));
      expect(s.displayCount, 3);
    });

    test('total plus petit que la liste : nombre chargé', () {
      final s = PackageRequestSearchState(results: _items(5), totalElements: 2);
      expect(s.displayCount, 5);
    });

    test('total plus grand que la liste : total serveur', () {
      final s = PackageRequestSearchState(
        results: _items(20),
        totalElements: 45,
      );
      expect(s.displayCount, 45);
    });

    test('près de moi : nombre chargé, le total back peut être gonflé', () {
      final s = PackageRequestSearchState(
        results: _items(12),
        totalElements: 45,
        userLat: 48.85,
        userLng: 2.35,
      );
      expect(s.isNearMeActive, isTrue);
      expect(s.displayCount, 12);
    });

    test('copyWith conserve le total et peut le remplacer', () {
      final s = const PackageRequestSearchState(totalElements: 45);
      expect(s.copyWith(page: 1).totalElements, 45);
      expect(s.copyWith(totalElements: 46).totalElements, 46);
      expect(s, isNot(equals(s.copyWith(totalElements: 46))));
    });
  });

  test(
    'près de moi : le bloc garde le nombre chargé malgré le total',
    () async {
      stubSearch({0: page(12, 45, 0)});
      final bloc = PackageRequestSearchBloc(repo)
        ..add(const SearchFiltersChanged(userLat: 48.85, userLng: 2.35));
      await bloc.stream.firstWhere((s) => s.status == SearchStatus.loaded);

      expect(bloc.state.totalElements, 45);
      expect(bloc.state.displayCount, 12);
      await bloc.close();
    },
  );
}
