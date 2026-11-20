import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

void main() {
  late _MockAnnouncementRepository repository;
  late MockAnalyticsBackend backend;

  setUp(() {
    repository = _MockAnnouncementRepository();
    backend = MockAnalyticsBackend();
  });

  const audience = TripAudienceModel(
    uniqueViewerCount: 12,
    shareViewCount: 7,
    likeCount: 4,
  );

  blocTest<TripAudienceCubit, TripAudienceState>(
    'load → loading puis loaded, event avec les trois compteurs',
    build: () {
      when(
        () => repository.getTripAudience('ann-1'),
      ).thenAnswer((_) async => audience);
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      return TripAudienceCubit(repository, analytics);
    },
    act: (c) => c.load('ann-1'),
    expect: () => [
      const TripAudienceState.loading(),
      const TripAudienceState.loaded(audience),
    ],
    verify: (_) {
      verify(
        () => backend.capture(AnalyticsEvents.tripAudienceLoaded, {
          'unique_viewers': 12,
          'share_views': 7,
          'likes': 4,
        }),
      ).called(1);
    },
  );

  blocTest<TripAudienceCubit, TripAudienceState>(
    'load sans j\'aime : l\'event porte likes: 0',
    build: () {
      when(() => repository.getTripAudience('ann-1')).thenAnswer(
        (_) async =>
            const TripAudienceModel(uniqueViewerCount: 1, shareViewCount: 0),
      );
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      return TripAudienceCubit(repository, analytics);
    },
    act: (c) => c.load('ann-1'),
    verify: (_) {
      verify(
        () => backend.capture(AnalyticsEvents.tripAudienceLoaded, {
          'unique_viewers': 1,
          'share_views': 0,
          'likes': 0,
        }),
      ).called(1);
    },
  );

  blocTest<TripAudienceCubit, TripAudienceState>(
    'load → hidden sur erreur (ancien back sans la route, réseau), sans event',
    build: () {
      when(
        () => repository.getTripAudience('ann-1'),
      ).thenThrow(Exception('404'));
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      return TripAudienceCubit(repository, analytics);
    },
    act: (c) => c.load('ann-1'),
    expect: () => [
      const TripAudienceState.loading(),
      const TripAudienceState.hidden(),
    ],
    verify: (_) {
      verifyNever(
        () => backend.capture(AnalyticsEvents.tripAudienceLoaded, any()),
      );
    },
  );
}
