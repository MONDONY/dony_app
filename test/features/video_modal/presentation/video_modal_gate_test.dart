import 'package:dony/core/di/injection.dart';
import 'package:dony/features/profile/presentation/screens/help_tutorial_player.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:dony/features/video_modal/presentation/screens/video_modal_player_screen.dart';
import 'package:dony/features/video_modal/presentation/video_modal_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../video_modal_test_data.dart';
import 'video_modal_widget_harness.dart';

class _MockRepo extends Mock implements VideoModalRepository {}

void main() {
  late _MockRepo repo;
  late VideoModalBloc bloc;
  late FakePlayerSession session;
  late List<String> log;

  setUpAll(() {
    registerFallbackValue(campaign());
    registerFallbackValue(VideoModalEventType.shown);
  });

  setUp(() async {
    VideoModalPresenter.resetForTest();
    repo = _MockRepo();
    when(() => repo.syncGuestEvents()).thenAnswer((_) async => 0);
    when(
      () => repo.loadEligible(
        lang: any(named: 'lang'),
        realSession: any(named: 'realSession'),
      ),
    ).thenAnswer(
      (_) async => [
        campaign(id: 'trip', triggers: {VideoModalTrigger.publishTrip}),
        campaign(id: 'parcel', triggers: {VideoModalTrigger.sendParcel}),
      ],
    );
    when(
      () => repo.record(any(), any(), realSession: any(named: 'realSession')),
    ).thenAnswer((_) async {});
    bloc = VideoModalBloc(
      repo,
      makeEnabledAnalytics(MockAnalyticsBackend()),
      hasRealSession: () => true,
    );
    getIt.registerSingleton<VideoModalBloc>(bloc);
    session = FakePlayerSession();
    log = [];
  });

  tearDown(() async {
    await getIt.reset();
    await bloc.close();
  });

  Future<void> load() async {
    bloc.add(const VideoModalLoadRequested(lang: 'fr', realSession: true));
    await bloc.stream.firstWhere((s) => s.status == VideoModalStatus.ready);
  }

  /// Écran avec un bouton « Publier » qui passe par la porte puis « ouvre le
  /// formulaire » (journal [log]).
  Future<void> pump(WidgetTester tester, VideoModalTrigger trigger) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () async {
                    await VideoModalGate.before(context, trigger);
                    log.add('formulaire');
                  },
                  child: const Text('publier'),
                ),
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    useRootNavigator: true,
                    builder: (_) => const SizedBox(height: 200),
                  ),
                  child: const Text('feuille'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: videoModalPlayerRoute,
          builder: (_, state) => VideoModalPlayerScreen(
            args: state.extra! as VideoModalPlayerArgs,
            modalBloc: bloc,
            sessionFactory: (HelpTutorialPlayerConfiguration _) => session,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: testTheme,
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets('sans campagne chargée : le formulaire s\'ouvre aussitôt', (
    tester,
  ) async {
    await pump(tester, VideoModalTrigger.publishTrip);
    await tester.tap(find.text('publier'));
    await settleTransitions(tester);
    expect(log, ['formulaire']);
    expect(find.byKey(const Key('video-modal-primary')), findsNothing);
  });

  testWidgets('sans BLoC enregistré : le formulaire s\'ouvre aussitôt', (
    tester,
  ) async {
    await getIt.reset();
    await pump(tester, VideoModalTrigger.publishTrip);
    await tester.tap(find.text('publier'));
    await settleTransitions(tester);
    expect(log, ['formulaire']);
  });

  testWidgets('PUBLISH_TRIP : modal AVANT le formulaire, puis « Commencer »', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(tester, VideoModalTrigger.publishTrip);
    await tester.runAsync(load);
    await tester.tap(find.text('publier'));
    await settleTransitions(tester);
    expect(find.byKey(const Key('video-modal-primary')), findsOneWidget);
    expect(log, isEmpty);
    await tester.tap(find.byKey(const Key('video-modal-secondary')));
    await settleTransitions(tester);
    expect(log, ['formulaire']);
    // Un seul modal par session : le suivant ouvre directement.
    await tester.tap(find.text('publier'));
    await settleTransitions(tester);
    expect(log, ['formulaire', 'formulaire']);
    expect(find.byKey(const Key('video-modal-primary')), findsNothing);
  });

  for (final trigger in [
    VideoModalTrigger.publishTrip,
    VideoModalTrigger.sendParcel,
  ]) {
    testWidgets('${trigger.wire} : aucun délai d\'ouverture', (tester) async {
      usePhone360(tester);
      await pump(tester, trigger);
      await tester.runAsync(load);
      await tester.tap(find.text('publier'));
      // Bien moins que les 2 s du shell : le modal précède le formulaire
      // demandé, la personne n'attend pas.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('video-modal-primary')), findsOneWidget);
      expect(log, isEmpty);
    });
  }

  testWidgets('SEND_PARCEL : fin de vidéo puis formulaire', (tester) async {
    usePhone360(tester);
    await pump(tester, VideoModalTrigger.sendParcel);
    await tester.runAsync(load);
    await tester.tap(find.text('publier'));
    await settleTransitions(tester);
    await tester.tap(find.byKey(const Key('video-modal-primary')));
    await settleTransitions(tester);
    expect(log, isEmpty);
    session.emit(HelpTutorialPlayerEvent.ended);
    await settleTransitions(tester);
    expect(log, ['formulaire']);
    final events = verify(
      () => repo.record(captureAny(), captureAny(), realSession: true),
    ).captured;
    expect((events[0] as VideoModalCampaign).id, 'parcel');
    expect(events.whereType<VideoModalEventType>(), [
      VideoModalEventType.shown,
      VideoModalEventType.opened,
      VideoModalEventType.completed,
    ]);
  });

  testWidgets('fermeture du lecteur puis formulaire', (tester) async {
    usePhone360(tester);
    await pump(tester, VideoModalTrigger.publishTrip);
    await tester.runAsync(load);
    await tester.tap(find.text('publier'));
    await settleTransitions(tester);
    await tester.tap(find.byKey(const Key('video-modal-primary')));
    await settleTransitions(tester);
    await tester.tap(find.byKey(const Key('video-modal-player-close')));
    await settleTransitions(tester);
    expect(log, ['formulaire']);
  });

  testWidgets('écran sous une feuille ouverte : pas de modal', (tester) async {
    usePhone360(tester);
    await pump(tester, VideoModalTrigger.publishTrip);
    await tester.runAsync(load);
    final pageContext = tester.element(find.text('publier'));
    expect(isVideoModalFrontmost(pageContext), isTrue);
    await tester.tap(find.text('feuille'));
    await settleTransitions(tester);
    expect(isVideoModalFrontmost(pageContext), isFalse);
    var done = false;
    // ignore: use_build_context_synchronously
    final future = VideoModalGate.before(
      pageContext,
      VideoModalTrigger.publishTrip,
    ).then((_) => done = true);
    await settleTransitions(tester);
    await future;
    expect(done, isTrue);
    expect(find.byKey(const Key('video-modal-primary')), findsNothing);
    expect(bloc.state.usedSlots, isEmpty);
  });
}
