import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/profile/presentation/screens/help_tutorial_player.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:dony/features/video_modal/presentation/screens/video_modal_player_screen.dart';
import 'package:dony/features/video_modal/presentation/video_modal_gate.dart';
import 'package:dony/features/video_modal/presentation/video_modal_host.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../video_modal_test_data.dart';
import 'video_modal_widget_harness.dart';

class _MockRepo extends Mock implements VideoModalRepository {}

class _MockProbe extends Mock implements FirebaseSessionProbe {}

void main() {
  late _MockRepo repo;
  late VideoModalBloc bloc;
  late FakePlayerSession session;
  late ValueNotifier<int> tab;
  late _MockProbe probe;
  var realSession = true;
  var loadResult = <VideoModalCampaign>[];

  setUpAll(() {
    registerFallbackValue(campaign());
    registerFallbackValue(VideoModalEventType.shown);
  });

  setUp(() {
    VideoModalPresenter.resetForTest();
    repo = _MockRepo();
    realSession = true;
    loadResult = [
      campaign(triggers: {VideoModalTrigger.appOpen}),
    ];
    when(() => repo.syncGuestEvents()).thenAnswer((_) async => 0);
    when(
      () => repo.loadEligible(
        lang: any(named: 'lang'),
        realSession: any(named: 'realSession'),
      ),
    ).thenAnswer((_) async => loadResult);
    when(
      () => repo.record(any(), any(), realSession: any(named: 'realSession')),
    ).thenAnswer((_) async {});
    session = FakePlayerSession();
    tab = ValueNotifier(0);
    probe = _MockProbe();
    when(() => probe.hasRealSession).thenAnswer((_) => realSession);
    getIt.registerSingleton<FirebaseSessionProbe>(probe);
  });

  tearDown(() async {
    tab.dispose();
    await getIt.reset();
  });

  Future<void> pumpHost(WidgetTester tester) async {
    // Créé dans la zone du test : ses traitements suivent l'horloge factice.
    bloc = VideoModalBloc(
      repo,
      makeEnabledAnalytics(MockAnalyticsBackend()),
      hasRealSession: () => realSession,
    );
    addTearDown(bloc.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (_, index, _) => VideoModalHost(
              tabIndex: index,
              bloc: bloc,
              hasRealSession: () => realSession,
              lang: () => 'fr',
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(content: Text('dlg')),
                    ),
                    child: const Text('dialogue'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(path: '/home', builder: (_, _) => const Text('accueil')),
        GoRoute(
          path: '/trips/publish-intro',
          builder: (_, _) => const Text('intro trajet'),
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

  List<VideoModalEventType> recorded() => verify(
    () => repo.record(
      any(),
      captureAny(),
      realSession: any(named: 'realSession'),
    ),
  ).captured.cast<VideoModalEventType>();

  testWidgets(
    'APP_OPEN : affiché au premier écran, « Commencer » = DISMISSED',
    (tester) async {
      usePhone360(tester);
      await pumpHost(tester);
      await settleAfterOpenDelay(tester);
      expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
      verify(() => repo.loadEligible(lang: 'fr', realSession: true)).called(1);
      expect(bloc.state.appOpenConsumed, isTrue);
      await tester.tap(find.byKey(const Key('video-modal-secondary')));
      await settleTransitions(tester);
      expect(find.text('Bienvenue sur Yadony'), findsNothing);
      expect(recorded(), [
        VideoModalEventType.shown,
        VideoModalEventType.dismissed,
      ]);
    },
  );

  testWidgets('onglet : affiché à l\'arrivée sur l\'onglet visé, une fois', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [
      campaign(triggers: {VideoModalTrigger.profileTab}),
      campaign(id: 'c2', triggers: {VideoModalTrigger.messagesTab}),
    ];
    await pumpHost(tester);
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    tab.value = 4;
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
    // Fermé d'un geste (retour) : SHOWN seulement.
    await tester.binding.handlePopRoute();
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    // Un seul modal par session, même sur un autre onglet visé.
    tab.value = 3;
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    expect(recorded(), [VideoModalEventType.shown]);
  });

  testWidgets('jamais par-dessus une boîte de dialogue : attend sa fermeture', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [
      campaign(triggers: {VideoModalTrigger.messagesTab}),
    ];
    await pumpHost(tester);
    await settleTransitions(tester);
    await tester.tap(find.text('dialogue'));
    await settleTransitions(tester);
    tab.value = 3;
    await settleAfterOpenDelay(tester);
    expect(find.text('dlg'), findsOneWidget);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await settleAfterOpenDelay(tester);
    expect(find.text('dlg'), findsNothing);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets('back absent : aucun modal, aucune erreur', (tester) async {
    usePhone360(tester);
    loadResult = [];
    await pumpHost(tester);
    await settleAfterOpenDelay(tester);
    tab.value = 1;
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans BLoC enregistré : rien', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: VideoModalHost(tabIndex: 0, child: Text('shell')),
      ),
    );
    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('vidéo : OPENED, COMPLETED, puis « Rechercher un trajet »', (
    tester,
  ) async {
    usePhone360(tester);
    await pumpHost(tester);
    await settleAfterOpenDelay(tester);
    await tester.tap(find.byKey(const Key('video-modal-primary')));
    await settleTransitions(tester);
    session.emit(HelpTutorialPlayerEvent.ended);
    await settleTransitions(tester);
    await tester.tap(find.byKey(const Key('video-modal-end-search')));
    await settleTransitions(tester);
    expect(find.text('accueil'), findsOneWidget);
    expect(recorded(), [
      VideoModalEventType.shown,
      VideoModalEventType.opened,
      VideoModalEventType.completed,
    ]);
  });

  testWidgets('vidéo : « Publier mon trajet » ouvre la publication', (
    tester,
  ) async {
    usePhone360(tester);
    await pumpHost(tester);
    await settleAfterOpenDelay(tester);
    await tester.tap(find.byKey(const Key('video-modal-primary')));
    await settleTransitions(tester);
    session.emit(HelpTutorialPlayerEvent.ended);
    await settleTransitions(tester);
    await tester.tap(find.byKey(const Key('video-modal-end-publish')));
    await settleTransitions(tester);
    expect(find.text('intro trajet'), findsOneWidget);
  });

  testWidgets('visiteur : « Publier mon trajet » demande un compte', (
    tester,
  ) async {
    usePhone360(tester);
    realSession = false;
    await pumpHost(tester);
    await settleAfterOpenDelay(tester);
    verify(() => repo.loadEligible(lang: 'fr', realSession: false)).called(1);
    verifyNever(() => repo.syncGuestEvents());
    await tester.tap(find.byKey(const Key('video-modal-primary')));
    await settleTransitions(tester);
    session.emit(HelpTutorialPlayerEvent.ended);
    await settleTransitions(tester);
    await tester.tap(find.byKey(const Key('video-modal-end-publish')));
    await settleTransitions(tester);
    expect(find.text('intro trajet'), findsNothing);
    expect(find.text(AppL10n.current.authRequiredTitle), findsOneWidget);
  });

  testWidgets(
    'connexion pendant la session : rechargement au changement d\'onglet',
    (tester) async {
      usePhone360(tester);
      realSession = false;
      loadResult = [];
      await pumpHost(tester);
      await settleAfterOpenDelay(tester);
      realSession = true;
      loadResult = [
        campaign(triggers: {VideoModalTrigger.activitiesTab}),
      ];
      tab.value = 1;
      await settleAfterOpenDelay(tester);
      verify(() => repo.syncGuestEvents()).called(1);
      expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
    },
  );

  group('délai d\'ouverture de 2 secondes', () {
    final modal = find.text('Bienvenue sur Yadony');

    testWidgets('rien avant 2 s, modal après', (tester) async {
      usePhone360(tester);
      await pumpHost(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1700));
      expect(modal, findsNothing);
      verifyNever(
        () => repo.record(any(), any(), realSession: any(named: 'realSession')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(modal, findsOneWidget);
      expect(recorded(), [VideoModalEventType.shown]);
    });

    testWidgets('changement d\'onglet pendant le délai : il repart à zéro', (
      tester,
    ) async {
      usePhone360(tester);
      await pumpHost(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      tab.value = 2;
      await tester.pump(const Duration(milliseconds: 100));
      // 1,1 s + 1,9 s : le premier délai aurait expiré, pas le nouveau.
      await tester.pump(const Duration(milliseconds: 1900));
      expect(modal, findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(modal, findsOneWidget);
    });

    testWidgets('boîte de dialogue ouverte pendant le délai : attend sa '
        'fermeture, puis un nouveau délai', (tester) async {
      usePhone360(tester);
      await pumpHost(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('dialogue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('dlg'), findsOneWidget);
      expect(modal, findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('dlg'), findsNothing);
      expect(modal, findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(modal, findsOneWidget);
    });

    testWidgets('app passée en arrière-plan pendant le délai : attend le '
        'retour au premier plan', (tester) async {
      usePhone360(tester);
      await pumpHost(tester);
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 3));
      expect(modal, findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(modal, findsOneWidget);
    });

    testWidgets('un autre modal ouvert pendant le délai : pas de second', (
      tester,
    ) async {
      usePhone360(tester);
      await pumpHost(tester);
      await tester.pump(const Duration(milliseconds: 100));
      // Par exemple celui d'un bouton « Publier » touché pendant le délai.
      bloc.add(
        VideoModalAnswerRequested(
          campaign: campaign(id: 'autre'),
          trigger: VideoModalTrigger.publishTrip,
          event: VideoModalEventType.shown,
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(modal, findsNothing);
      expect(recorded(), [VideoModalEventType.shown]);
    });

    testWidgets('écran quitté pendant le délai : aucun modal, aucune erreur', (
      tester,
    ) async {
      usePhone360(tester);
      await pumpHost(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(modal, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('priorité : la campagne la plus haute passe d\'abord', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = VideoModalCampaign.sortByPriority([
        campaign(id: 'bas', triggers: {VideoModalTrigger.appOpen}),
        campaign(
          id: 'haut',
          priority: 4,
          triggers: {VideoModalTrigger.appOpen},
        ),
      ]);
      await pumpHost(tester);
      await settleAfterOpenDelay(tester);
      final shown = verify(
        () => repo.record(
          captureAny(),
          any(),
          realSession: any(named: 'realSession'),
        ),
      ).captured.cast<VideoModalCampaign>();
      expect(shown.single.id, 'haut');
    });
  });
}
