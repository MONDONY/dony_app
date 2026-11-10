import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../video_modal_test_data.dart';

class _MockRepo extends Mock implements VideoModalRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  var realSession = true;

  setUpAll(() {
    registerFallbackValue(campaign());
    registerFallbackValue(VideoModalEventType.shown);
  });

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    realSession = true;
    when(() => repo.syncGuestEvents()).thenAnswer((_) async => 0);
    when(
      () => repo.loadEligible(
        lang: any(named: 'lang'),
        realSession: any(named: 'realSession'),
      ),
    ).thenAnswer((_) async => [campaign()]);
    when(
      () => repo.record(any(), any(), realSession: any(named: 'realSession')),
    ).thenAnswer((_) async {});
  });

  VideoModalBloc build() =>
      VideoModalBloc(repo, analytics, hasRealSession: () => realSession);

  blocTest<VideoModalBloc, VideoModalState>(
    'compte : synchronise les réponses visiteur puis charge',
    build: build,
    act: (b) =>
        b.add(const VideoModalLoadRequested(lang: 'fr', realSession: true)),
    expect: () => [
      const VideoModalState(status: VideoModalStatus.loading),
      VideoModalState(
        status: VideoModalStatus.ready,
        campaigns: [campaign()],
        loadedLang: 'fr',
        loadedForRealSession: true,
      ),
    ],
    verify: (_) {
      verify(() => repo.syncGuestEvents()).called(1);
    },
  );

  blocTest<VideoModalBloc, VideoModalState>(
    'visiteur : pas de synchro ; une seconde demande identique est ignorée',
    build: build,
    act: (b) async {
      b.add(const VideoModalLoadRequested(lang: 'fr', realSession: false));
      b.add(const VideoModalLoadRequested(lang: 'fr', realSession: false));
      await Future<void>.delayed(Duration.zero);
      b.add(const VideoModalLoadRequested(lang: 'fr', realSession: false));
    },
    skip: 1,
    expect: () => [
      isA<VideoModalState>()
          .having((s) => s.status, 'status', VideoModalStatus.ready)
          .having((s) => s.loadedForRealSession, 'real', false),
    ],
    verify: (_) {
      verifyNever(() => repo.syncGuestEvents());
      verify(() => repo.loadEligible(lang: 'fr', realSession: false)).called(1);
    },
  );

  blocTest<VideoModalBloc, VideoModalState>(
    'connexion pendant le chargement visiteur : le chargement compte gagne',
    build: build,
    act: (b) async {
      b.add(const VideoModalLoadRequested(lang: 'fr', realSession: false));
      b.add(const VideoModalLoadRequested(lang: 'fr', realSession: true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    },
    verify: (b) {
      expect(b.state.status, VideoModalStatus.ready);
      expect(b.state.loadedForRealSession, isTrue);
    },
  );

  blocTest<VideoModalBloc, VideoModalState>(
    'changement de langue : rechargement',
    build: build,
    seed: () => VideoModalState(
      status: VideoModalStatus.ready,
      campaigns: [campaign()],
      loadedLang: 'fr',
      loadedForRealSession: true,
    ),
    act: (b) =>
        b.add(const VideoModalLoadRequested(lang: 'en', realSession: true)),
    verify: (b) => expect(b.state.loadedLang, 'en'),
  );

  blocTest<VideoModalBloc, VideoModalState>(
    'SHOWN : session marquée, événement envoyé et tracé',
    build: build,
    seed: () => VideoModalState(
      status: VideoModalStatus.ready,
      campaigns: [campaign()],
    ),
    act: (b) => b.add(
      VideoModalAnswerRequested(
        campaign: campaign(),
        trigger: VideoModalTrigger.searchTab,
        event: VideoModalEventType.shown,
      ),
    ),
    expect: () => [
      VideoModalState(
        status: VideoModalStatus.ready,
        campaigns: [campaign()],
        shownThisSession: true,
      ),
    ],
    verify: (b) {
      expect(b.state.candidateFor({VideoModalTrigger.searchTab}), isNull);
      verify(
        () => repo.record(
          campaign(),
          VideoModalEventType.shown,
          realSession: true,
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.videoModalShown,
          properties: {
            'campaign_id': 'c1',
            'version': 2,
            'trigger': 'SEARCH_TAB',
            'guest': false,
          },
        ),
      ).called(1);
    },
  );

  for (final (event, name) in [
    (VideoModalEventType.opened, AnalyticsEvents.videoModalVideoOpened),
    (VideoModalEventType.completed, AnalyticsEvents.videoModalVideoCompleted),
    (VideoModalEventType.dismissed, AnalyticsEvents.videoModalDismissed),
  ]) {
    blocTest<VideoModalBloc, VideoModalState>(
      '${event.wire} : visiteur, tracé avec guest',
      build: () {
        realSession = false;
        return build();
      },
      act: (b) => b.add(
        VideoModalAnswerRequested(
          campaign: campaign(),
          trigger: VideoModalTrigger.publishTrip,
          event: event,
        ),
      ),
      expect: () => <VideoModalState>[],
      verify: (_) {
        verify(
          () => repo.record(campaign(), event, realSession: false),
        ).called(1);
        verify(
          () => analytics.logEvent(
            name,
            properties: {
              'campaign_id': 'c1',
              'version': 2,
              'trigger': 'PUBLISH_TRIP',
              'guest': true,
            },
          ),
        ).called(1);
      },
    );
  }

  blocTest<VideoModalBloc, VideoModalState>(
    'APP_OPEN consommé',
    build: build,
    act: (b) => b.add(const VideoModalAppOpenConsumedRequested()),
    expect: () => [const VideoModalState(appOpenConsumed: true)],
  );

  group('candidateFor', () {
    test("ordre du back, déclencheur requis, rien avant d'être prêt", () {
      final a = campaign(id: 'a', triggers: {VideoModalTrigger.profileTab});
      final b = campaign(
        id: 'b',
        triggers: {VideoModalTrigger.searchTab, VideoModalTrigger.appOpen},
      );
      final c = campaign(id: 'c', triggers: {VideoModalTrigger.searchTab});
      final ready = VideoModalState(
        status: VideoModalStatus.ready,
        campaigns: [a, b, c],
      );
      expect(ready.candidateFor({VideoModalTrigger.searchTab}), b);
      expect(ready.candidateFor({VideoModalTrigger.profileTab}), a);
      expect(ready.candidateFor({VideoModalTrigger.messagesTab}), isNull);
      expect(
        ready.copyWith(status: VideoModalStatus.loading).candidateFor({
          VideoModalTrigger.searchTab,
        }),
        isNull,
      );
    });
  });

  test('égalité des événements', () {
    expect(
      const VideoModalLoadRequested(lang: 'fr', realSession: true),
      const VideoModalLoadRequested(lang: 'fr', realSession: true),
    );
    expect(
      const VideoModalAppOpenConsumedRequested(),
      const VideoModalAppOpenConsumedRequested(),
    );
    expect(
      VideoModalAnswerRequested(
        campaign: campaign(),
        trigger: VideoModalTrigger.appOpen,
        event: VideoModalEventType.shown,
      ),
      VideoModalAnswerRequested(
        campaign: campaign(),
        trigger: VideoModalTrigger.appOpen,
        event: VideoModalEventType.shown,
      ),
    );
  });
}
