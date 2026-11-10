import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../video_modal/moment_test_support.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

PackageRequestSearchItem _request(String id) => PackageRequestSearchItem(
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

/// Une recherche de colis émet au plus UN moment : « sans résultat » ou
/// « peu de résultats », jamais les deux, et seulement pour une vraie
/// recherche (au moins une ville, hors liste « Pour mes trajets »).
void main() {
  late _MockRepo repo;
  late RecordingMoments moments;

  setUpAll(() => registerFallbackValue(ParcelSize.small));

  setUp(() {
    repo = _MockRepo();
    moments = useRecordingMoments();
  });

  Future<void> search(
    SearchFiltersChanged event, {
    required List<PackageRequestSearchItem> content,
    int? total,
  }) async {
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
        totalElements: total ?? content.length,
        page: 0,
        size: 20,
      ),
    );
    final bloc = PackageRequestSearchBloc(repo);
    addTearDown(bloc.close);
    bloc.add(event);
    await bloc.stream.firstWhere((s) => s.status == SearchStatus.loaded);
  }

  test('aucun résultat : un seul moment « sans résultat de colis »', () async {
    await search(
      const SearchFiltersChanged(departure: 'Paris', arrival: 'Dakar'),
      content: const [],
    );
    expect(moments.triggers, [VideoModalTrigger.searchNoParcelResults]);
    expect(
      const VideoModalCorridor(
        to: 'dakar',
      ).matches(moments.emitted.single.corridor),
      isTrue,
    );
  });

  test('peu de résultats : un seul moment, avec le total serveur', () async {
    await search(
      const SearchFiltersChanged(arrival: 'Dakar'),
      content: [_request('r-1')],
      total: 7,
    );
    expect(moments.triggers, [VideoModalTrigger.searchFewResults]);
    expect(moments.emitted.single.resultCount, 7);
  });

  test('aucune ville : aucun moment', () async {
    await search(const SearchFiltersChanged(departure: ' '), content: const []);
    expect(moments.emitted, isEmpty);
  });

  test('liste « Pour mes trajets » : aucun moment', () async {
    await search(
      const SearchFiltersChanged(departure: 'Paris', matchingMyTrips: true),
      content: const [],
    );
    expect(moments.emitted, isEmpty);
  });
}
