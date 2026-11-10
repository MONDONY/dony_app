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

  setUpAll(() {
    registerFallbackValue(infoCampaign());
    registerFallbackValue(VideoModalEventType.shown);
  });

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => repo.record(any(), any(), realSession: any(named: 'realSession')),
    ).thenAnswer((_) async {});
    when(() => repo.syncGuestEvents()).thenAnswer((_) async => 0);
    when(
      () => repo.loadEligible(
        lang: any(named: 'lang'),
        realSession: any(named: 'realSession'),
      ),
    ).thenAnswer((_) async => [infoCampaign(), campaign()]);
  });

  VideoModalBloc build() =>
      VideoModalBloc(repo, analytics, hasRealSession: () => true);

  for (final (event, name, kind, expectedKind) in [
    (VideoModalEventType.shown, AnalyticsEvents.videoModalShown, null, null),
    (
      VideoModalEventType.opened,
      AnalyticsEvents.videoModalVideoOpened,
      VideoModalActionKind.screen,
      'screen',
    ),
    (
      VideoModalEventType.dismissed,
      AnalyticsEvents.videoModalDismissed,
      VideoModalActionKind.url,
      'url',
    ),
  ]) {
    blocTest<VideoModalBloc, VideoModalState>(
      'INFO ${event.wire} : envoyé au back et tracé avec type=info',
      build: build,
      act: (b) => b.add(
        VideoModalAnswerRequested(
          campaign: infoCampaign(),
          trigger: VideoModalTrigger.searchTab,
          event: event,
          actionKind: kind,
        ),
      ),
      verify: (_) {
        verify(
          () => repo.record(infoCampaign(), event, realSession: true),
        ).called(1);
        verify(
          () => analytics.logEvent(
            name,
            properties: {
              'campaign_id': 'i1',
              'version': 1,
              'trigger': 'SEARCH_TAB',
              'guest': false,
              'type': 'info',
              'action_kind': ?expectedKind,
            },
          ),
        ).called(1);
      },
    );
  }

  blocTest<VideoModalBloc, VideoModalState>(
    'un INFO et une vidéo passent dans la même file : un seul modal par session',
    build: build,
    act: (b) async {
      b.add(const VideoModalLoadRequested(lang: 'fr', realSession: true));
      await b.stream.firstWhere((s) => s.status == VideoModalStatus.ready);
    },
    verify: (b) {
      final first = b.state.candidateFor({VideoModalTrigger.searchTab});
      expect(first!.isInfo, isTrue);
      final afterShown = b.state.copyWith(shownThisSession: true);
      expect(afterShown.candidateFor({VideoModalTrigger.searchTab}), isNull);
    },
  );
}
