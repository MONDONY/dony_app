import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/announcement_search_page.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../../video_modal/moment_test_support.dart';

class _MockRepo extends Mock implements AnnouncementRepository {}

AnnouncementModel _trip(String id, {bool full = false}) => AnnouncementModel(
  id: id,
  travelerId: 'traveler-001',
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
  departureDate: DateTime.now().add(const Duration(days: 10)),
  availableKg: full ? 0 : 20,
  totalKg: 20,
  pricePerKg: 5,
  status: 'ACTIVE',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

/// Une recherche de trajet émet au plus UN moment : « sans résultat » ou
/// « peu de résultats », jamais les deux, et seulement si une ville est saisie.
void main() {
  late _MockRepo repo;
  late RecordingMoments moments;

  setUp(() {
    repo = _MockRepo();
    moments = useRecordingMoments();
  });

  Future<void> search(
    AnnouncementSearchPage page, {
    String? from,
    String? to,
  }) async {
    when(
      () => repo.searchAnnouncementsPage(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        sortBy: any(named: 'sortBy'),
        sortDir: any(named: 'sortDir'),
        urgent: any(named: 'urgent'),
        page: any(named: 'page'),
        includeFull: true,
      ),
    ).thenAnswer((_) async => page);
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    await analytics.onConfigured();
    final bloc = AnnouncementBloc(repo, analytics);
    addTearDown(bloc.close);
    bloc.add(AnnouncementSearchRequested(departureCity: from, arrivalCity: to));
    await bloc.stream.firstWhere((s) => s is AnnouncementSearchLoaded);
  }

  test('aucun résultat : un seul moment « sans résultat de trajet »', () async {
    await search(
      const AnnouncementSearchPage(content: [], totalElements: 0, page: 0),
      from: 'Paris',
      to: 'Abidjan',
    );
    expect(moments.triggers, [VideoModalTrigger.searchNoTripResults]);
    final corridor = moments.emitted.single.corridor!;
    expect(
      const VideoModalCorridor(from: 'PARIS', to: 'abidjan').matches(corridor),
      isTrue,
    );
  });

  test(
    'peu de résultats : un seul moment, avec le nombre réservable',
    () async {
      await search(
        AnnouncementSearchPage(
          content: [_trip('a'), _trip('f', full: true)],
          totalElements: 2,
          bookableElements: 1,
          page: 0,
        ),
        from: 'Paris',
      );
      expect(moments.triggers, [VideoModalTrigger.searchFewResults]);
      expect(moments.emitted.single.resultCount, 1);
    },
  );

  test('sans total réservable : le total serveur', () async {
    await search(
      AnnouncementSearchPage(
        content: [_trip('a'), _trip('b'), _trip('c')],
        totalElements: 3,
        page: 0,
      ),
      to: 'Dakar',
    );
    expect(moments.emitted.single.resultCount, 3);
  });

  test(
    'liste par défaut de l\'accueil (aucune ville) : aucun moment',
    () async {
      await search(
        const AnnouncementSearchPage(content: [], totalElements: 0, page: 0),
      );
      await search(
        const AnnouncementSearchPage(content: [], totalElements: 0, page: 0),
        from: '  ',
        to: '',
      );
      expect(moments.emitted, isEmpty);
    },
  );
}
