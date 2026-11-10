import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/trip_view_recording.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../../video_modal/moment_test_support.dart';

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

final _trip = AnnouncementModel.fromJson(const {
  'id': 'ann-001',
  'travelerId': 'trav-001',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2026-11-01T00:00:00.000Z',
  'availableKg': 10.0,
  'totalKg': 10.0,
  'pricePerKg': 12.0,
  'status': 'ACTIVE',
  'createdAt': '2026-10-01T00:00:00.000Z',
  'updatedAt': '2026-10-01T00:00:00.000Z',
});

/// Les appels partent sans être attendus : on laisse passer la file des micro-tâches.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _MockAnnouncementRepository repository;
  late MockAnalyticsBackend backend;

  late RecordingMoments moments;

  setUp(() {
    moments = useRecordingMoments();
    repository = _MockAnnouncementRepository();
    backend = MockAnalyticsBackend();
    when(() => repository.recordView(any())).thenAnswer((_) async {});
    getIt.registerSingleton<AnnouncementRepository>(repository);
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(backend)..onConfigured(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  test(
    'un expéditeur connecté : la vue part au back et announcement_viewed est émis',
    () async {
      recordTripView(_trip, viewerId: 'sender-001');
      await _settle();

      verify(() => repository.recordView('ann-001')).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.announcementViewed, {
          'announcement_id': 'ann-001',
          'corridor': 'Paris→Dakar',
        }),
      ).called(1);
    },
  );

  test('le voyageur sur son propre trajet : rien n’est compté', () async {
    recordTripView(_trip, viewerId: 'trav-001');
    await _settle();

    verifyNever(() => repository.recordView(any()));
    verifyNever(
      () => backend.capture(AnalyticsEvents.announcementViewed, any()),
    );
  });

  test(
    'un invité : pas de vue au back (aucun compte), mais l’event analytics part',
    () async {
      recordTripView(_trip, viewerId: null);
      await _settle();

      verifyNever(() => repository.recordView(any()));
      verify(
        () => backend.capture(AnalyticsEvents.announcementViewed, any()),
      ).called(1);
    },
  );

  group('moment « trajet consulté N fois »', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'compteur local par trajet : le moment part dès la 2e consultation',
      () async {
        recordTripView(_trip, viewerId: 'sender-001');
        await pumpEventQueue(times: 50);
        expect(moments.emitted, isEmpty);
        recordTripView(_trip, viewerId: null); // un invité compte aussi
        recordTripView(_trip, viewerId: 'sender-001');
        await pumpEventQueue(times: 100);
        expect(moments.triggers, [
          VideoModalTrigger.tripViewedRepeatedly,
          VideoModalTrigger.tripViewedRepeatedly,
        ]);
        expect(moments.emitted.map((m) => m.viewCount), [2, 3]);
        expect(moments.emitted.first.tripId, 'ann-001');
        // Le corridor du trajet part avec le moment (villes de la fiche).
        expect(
          const VideoModalCorridor(
            from: 'Paris',
            to: 'dakar',
          ).matches(moments.emitted.first.corridor),
          isTrue,
        );
      },
    );

    test(
      'le voyageur sur son propre trajet : aucune consultation comptée',
      () async {
        for (var i = 0; i < 3; i++) {
          recordTripView(_trip, viewerId: 'trav-001');
        }
        await pumpEventQueue(times: 50);
        expect(moments.emitted, isEmpty);
      },
    );
  });

  test('un échec réseau du back est avalé, jamais remonté', () async {
    when(
      () => repository.recordView(any()),
    ).thenAnswer((_) => Future<void>.error(Exception('offline')));

    recordTripView(_trip, viewerId: 'sender-001');
    await _settle();

    verify(() => repository.recordView('ann-001')).called(1);
  });

  test('sans repository ni analytics enregistrés : aucune exception', () async {
    await getIt.reset();

    expect(
      () => recordTripView(_trip, viewerId: 'sender-001'),
      returnsNormally,
    );
  });
}
