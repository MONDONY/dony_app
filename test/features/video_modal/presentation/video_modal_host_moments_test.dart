import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/datasources/video_modal_local_datasource.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:dony/features/video_modal/data/video_modal_moments.dart';
import 'package:dony/features/video_modal/presentation/video_modal_gate.dart';
import 'package:dony/features/video_modal/presentation/video_modal_host.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../video_modal_test_data.dart';
import 'video_modal_widget_harness.dart';

class _MockRepo extends Mock implements VideoModalRepository {}

class _MockProbe extends Mock implements FirebaseSessionProbe {}

/// Service réel dont on note les remises à zéro de compteurs.
class _SpyMoments extends VideoModalMoments {
  _SpyMoments({super.local, super.appVersion, super.clock});

  final List<String> resets = [];

  @override
  Future<void> resetTripViews(String tripId) {
    resets.add(tripId);
    return super.resetTripViews(tripId);
  }
}

/// Moments d'action (étape 2) : l'hôte ouvre le modal 2 secondes après le
/// moment, avec les mêmes règles que pour les écrans (un par lancement, jamais
/// par-dessus une autre fenêtre ni pendant une saisie, premier plan revérifié).
void main() {
  late _MockRepo repo;
  late VideoModalBloc bloc;
  late _SpyMoments moments;
  late GoRouter router;
  late _MockProbe probe;
  var loadResult = <VideoModalCampaign>[];
  var now = DateTime.utc(2026, 11, 10, 12);
  var appVersion = '1.0.4';
  var realSession = true;
  BuildContext? secondContext;

  setUpAll(() {
    registerFallbackValue(campaign());
    registerFallbackValue(VideoModalEventType.shown);
  });

  setUp(() {
    VideoModalPresenter.resetForTest();
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 11, 10, 12);
    appVersion = '1.0.4';
    realSession = true;
    secondContext = null;
    repo = _MockRepo();
    loadResult = [];
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
    probe = _MockProbe();
    when(() => probe.hasRealSession).thenAnswer((_) => realSession);
    getIt.registerSingleton<FirebaseSessionProbe>(probe);
    moments = _SpyMoments(
      local: VideoModalLocalDatasource(),
      appVersion: () async => appVersion,
      clock: () => now,
    );
    addTearDown(moments.dispose);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    Duration momentMaxAge = kVideoModalMomentMaxAge,
  }) async {
    bloc = VideoModalBloc(
      repo,
      makeEnabledAnalytics(MockAnalyticsBackend()),
      hasRealSession: () => realSession,
    );
    addTearDown(bloc.close);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => VideoModalHost(
            tabIndex: 0,
            bloc: bloc,
            hasRealSession: () => realSession,
            lang: () => 'fr',
            moments: moments,
            momentMaxAge: momentMaxAge,
            clock: () => now,
            child: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const AlertDialog(content: Text('dlg')),
                      ),
                      child: const Text('dialogue'),
                    ),
                    const TextField(key: Key('champ')),
                  ],
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/second',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) {
                secondContext = context;
                return const Text('second');
              },
            ),
          ),
        ),
        GoRoute(path: '/home', builder: (_, _) => const Text('accueil')),
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
    // Campagnes chargées, rien d'évaluable pour les écrans.
    await settleTransitions(tester);
  }

  VideoModalCampaign forMoment(
    VideoModalTrigger trigger, {
    String id = 'c1',
    int priority = 0,
    Map<String, Object?> extra = const {},
  }) => VideoModalCampaign.tryParse(
    campaignJson(
      id: id,
      triggers: [trigger.wire],
      extra: {'priority': priority, ...extra},
    ),
  )!;

  List<String> shownIds() => verify(
    () => repo.record(
      captureAny(),
      VideoModalEventType.shown,
      realSession: any(named: 'realSession'),
    ),
  ).captured.cast<VideoModalCampaign>().map((c) => c.id).toList();

  void emit(VideoModalMoment moment, {BuildContext? origin}) =>
      moments.emit(moment, origin: origin);

  Future<void> closeModal(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settleTransitions(tester);
  }

  testWidgets('ouvre le modal 2 s après le moment, pas avant', (tester) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.paymentSucceeded)];
    await pumpHost(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
    // Livraison du moment à l'hôte, puis l'image qui lance le délai.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
    expect(shownIds(), ['c1']);
    expect(tester.takeException(), isNull);
    // « Commencer » : réponse enregistrée, rien d'autre ne s'ouvre.
    await tester.tap(find.byKey(const Key('video-modal-secondary')));
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
  });

  testWidgets('chaque déclencheur de moment ouvre sa campagne', (tester) async {
    usePhone360(tester);
    final moment = <VideoModalTrigger, VideoModalMoment>{
      VideoModalTrigger.deliveryConfirmed: VideoModalMoment.action(
        VideoModalTrigger.deliveryConfirmed,
      ),
      VideoModalTrigger.kycVerified: VideoModalMoment.action(
        VideoModalTrigger.kycVerified,
      ),
      VideoModalTrigger.searchNoTripResults: VideoModalMoment.search(
        kind: VideoModalSearchKind.trip,
        resultCount: 0,
      ),
      VideoModalTrigger.searchNoParcelResults: VideoModalMoment.search(
        kind: VideoModalSearchKind.parcel,
        resultCount: 0,
      ),
    };
    for (final entry in moment.entries) {
      VideoModalPresenter.resetForTest();
      loadResult = [forMoment(entry.key)];
      await pumpHost(tester);
      emit(entry.value);
      await settleAfterOpenDelay(tester);
      expect(
        find.text('Bienvenue sur Yadony'),
        findsOneWidget,
        reason: entry.key.wire,
      );
      await closeModal(tester);
      await tester.pumpWidget(const SizedBox());
      await getIt.reset();
      getIt.registerSingleton<FirebaseSessionProbe>(probe);
    }
  });

  testWidgets('une campagne qui ne liste pas le déclencheur : rien', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.kycVerified)];
    await pumpHost(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('peu de résultats : seulement jusqu\'au seuil de la campagne', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [
      forMoment(
        VideoModalTrigger.searchFewResults,
        extra: {
          'triggerOptions': {'fewResultsMax': 3},
        },
      ),
    ];
    await pumpHost(tester);
    emit(
      VideoModalMoment.search(kind: VideoModalSearchKind.trip, resultCount: 4),
    );
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    // Une recherche sans résultat n'ouvre pas non plus cette campagne.
    emit(
      VideoModalMoment.search(kind: VideoModalSearchKind.trip, resultCount: 0),
    );
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    emit(
      VideoModalMoment.search(kind: VideoModalSearchKind.trip, resultCount: 3),
    );
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets('corridor : accents, casse et espaces ignorés', (tester) async {
    usePhone360(tester);
    loadResult = [
      forMoment(
        VideoModalTrigger.favoriteAdded,
        extra: {
          'corridors': [
            {'from': 'PARIS', 'to': "cote d'ivoire"},
          ],
        },
      ),
    ];
    await pumpHost(tester);
    emit(
      VideoModalMoment.action(
        VideoModalTrigger.favoriteAdded,
        corridor: VideoModalMomentCorridor(
          fromCity: 'Lyon',
          toCity: 'Abidjan',
          toCountryCode: 'CI',
        ),
      ),
    );
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    emit(
      VideoModalMoment.action(
        VideoModalTrigger.favoriteAdded,
        corridor: VideoModalMomentCorridor(
          fromCity: ' paris ',
          toCity: 'Abidjan',
          toCountryCode: 'CI',
        ),
      ),
    );
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets('jamais par-dessus une fenêtre : attend, puis 2 s de plus', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.paymentFailed)];
    await pumpHost(tester);
    await tester.tap(find.text('dialogue'));
    await settleTransitions(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.paymentFailed));
    await tester.pump(const Duration(seconds: 5));
    await settleTransitions(tester);
    expect(find.text('dlg'), findsOneWidget);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await settleTransitions(tester);
    expect(find.text('dlg'), findsNothing);
    // Le délai d'ouverture repart au retour au premier plan.
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets('jamais pendant une saisie : attend la fin de la frappe', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.deliveryConfirmed)];
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('champ')));
    await tester.pump();
    emit(VideoModalMoment.action(VideoModalTrigger.deliveryConfirmed));
    await tester.pump(const Duration(seconds: 6));
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets(
    's\'ouvre sur l\'écran d\'origine tant qu\'il est au premier plan',
    (tester) async {
      usePhone360(tester);
      loadResult = [forMoment(VideoModalTrigger.paymentSucceeded)];
      await pumpHost(tester);
      unawaited(router.push('/second'));
      await settleTransitions(tester);
      expect(find.text('second'), findsOneWidget);
      // Le shell est recouvert : sans origine le modal attendrait.
      emit(
        VideoModalMoment.action(VideoModalTrigger.paymentSucceeded),
        origin: secondContext,
      );
      await settleAfterOpenDelay(tester);
      expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sans origine, un shell recouvert attend son retour', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.paymentSucceeded)];
    await pumpHost(tester);
    unawaited(router.push('/second'));
    await settleTransitions(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
    await tester.pump(const Duration(seconds: 5));
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    router.pop();
    await settleTransitions(tester);
    await tester.pump(const Duration(seconds: 3));
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets('écran d\'origine fermé entre-temps : repli sur le shell', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.tripPublished)];
    await pumpHost(tester);
    unawaited(router.push('/second'));
    await settleTransitions(tester);
    emit(
      VideoModalMoment.action(VideoModalTrigger.tripPublished),
      origin: secondContext,
    );
    // Quitté avant la fin du délai.
    await tester.pump(const Duration(milliseconds: 500));
    router.pop();
    await settleTransitions(tester);
    await tester.pump(const Duration(seconds: 3));
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets('un seul modal par lancement, moments compris', (tester) async {
    usePhone360(tester);
    loadResult = [
      forMoment(VideoModalTrigger.kycVerified, id: 'a'),
      forMoment(VideoModalTrigger.paymentSucceeded, id: 'b'),
    ];
    await pumpHost(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.kycVerified));
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
    await closeModal(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    expect(shownIds(), ['a']);
  });

  testWidgets(
    'plusieurs moments en attente : la campagne prioritaire d\'abord',
    (tester) async {
      usePhone360(tester);
      loadResult = [
        forMoment(VideoModalTrigger.kycVerified, id: 'bas'),
        forMoment(VideoModalTrigger.paymentSucceeded, id: 'haut', priority: 5),
      ];
      await pumpHost(tester);
      await tester.tap(find.text('dialogue'));
      await settleTransitions(tester);
      emit(VideoModalMoment.action(VideoModalTrigger.kycVerified));
      emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
      await tester.tapAt(const Offset(10, 10));
      await settleAfterOpenDelay(tester);
      expect(shownIds(), ['haut']);
    },
  );

  testWidgets('un paiement réussi retire le paiement échoué en attente', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [
      forMoment(VideoModalTrigger.paymentFailed, id: 'echec', priority: 9),
      forMoment(VideoModalTrigger.paymentSucceeded, id: 'succes'),
    ];
    await pumpHost(tester);
    await tester.tap(find.text('dialogue'));
    await settleTransitions(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.paymentFailed));
    emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
    await tester.tapAt(const Offset(10, 10));
    await settleAfterOpenDelay(tester);
    expect(shownIds(), ['succes']);
  });

  testWidgets('un moment trop ancien est abandonné', (tester) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.deliveryConfirmed)];
    await pumpHost(tester);
    await tester.tap(find.text('dialogue'));
    await settleTransitions(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.deliveryConfirmed));
    await tester.pump(const Duration(seconds: 3));
    now = now.add(const Duration(minutes: 3));
    await tester.tapAt(const Offset(10, 10));
    await settleAfterOpenDelay(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    verifyNever(
      () => repo.record(any(), any(), realSession: any(named: 'realSession')),
    );
  });

  testWidgets('trajet consulté N fois : modal puis compteur remis à zéro', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [
      forMoment(
        VideoModalTrigger.tripViewedRepeatedly,
        extra: {
          'triggerOptions': {'tripViewedTimes': 3},
          'corridors': [
            {'to': 'Abidjan'},
          ],
        },
      ),
    ];
    await pumpHost(tester);
    final corridor = VideoModalMomentCorridor(
      fromCity: 'Paris',
      toCity: 'Abidjan',
    );
    // 1re et 2e consultation : pas assez pour cette campagne.
    await tester.runAsync(() async {
      await moments.recordTripView('t1', corridor: corridor);
      await moments.recordTripView('t1', corridor: corridor);
    });
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    await tester.runAsync(
      () => moments.recordTripView('t1', corridor: corridor),
    );
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
    expect(moments.resets, isEmpty);
    await closeModal(tester);
    // Compteur remis à zéro une fois le modal affiché.
    expect(moments.resets, ['t1']);
  });

  testWidgets('trajet consulté dans un autre corridor : rien', (tester) async {
    usePhone360(tester);
    loadResult = [
      forMoment(
        VideoModalTrigger.tripViewedRepeatedly,
        extra: {
          'corridors': [
            {'to': 'Dakar'},
          ],
        },
      ),
    ];
    await pumpHost(tester);
    await tester.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        await moments.recordTripView(
          't1',
          corridor: VideoModalMomentCorridor(toCity: 'Abidjan'),
        );
      }
    });
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
  });

  testWidgets(
    'APP_UPDATED : modal à la première ouverture après la mise à jour',
    (tester) async {
      usePhone360(tester);
      SharedPreferences.setMockInitialValues({
        VideoModalLocalDatasource.lastAppVersionKey: '1.0.3',
      });
      loadResult = [forMoment(VideoModalTrigger.appUpdated)];
      await pumpHost(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settleAfterOpenDelay(tester);
      expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
      expect(shownIds(), ['c1']);
    },
  );

  testWidgets('APP_UPDATED : jamais à la toute première installation', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.appUpdated)];
    await pumpHost(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    await tester.runAsync(() async {
      expect(
        await VideoModalLocalDatasource().readLastAppVersion(),
        appVersion,
      );
    });
  });

  testWidgets('back absent (aucune campagne) : aucun modal, aucune erreur', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [];
    await pumpHost(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
    emit(
      VideoModalMoment.search(kind: VideoModalSearchKind.trip, resultCount: 0),
    );
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un moment émis avant le chargement attend les campagnes', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.requestPublished)];
    bloc = VideoModalBloc(
      repo,
      makeEnabledAnalytics(MockAnalyticsBackend()),
      hasRealSession: () => true,
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VideoModalHost(
          tabIndex: 0,
          bloc: bloc,
          hasRealSession: () => true,
          lang: () => 'fr',
          moments: moments,
          clock: () => now,
          child: const Scaffold(body: Text('shell')),
        ),
      ),
    );
    // Émis dans la même image que le chargement : il attend l'état « prêt ».
    emit(VideoModalMoment.action(VideoModalTrigger.requestPublished));
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets('app en arrière-plan : attend le retour au premier plan', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.deliveryConfirmed)];
    await pumpHost(tester);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    emit(VideoModalMoment.action(VideoModalTrigger.deliveryConfirmed));
    await tester.pump(const Duration(seconds: 5));
    await settleTransitions(tester);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets('une fenêtre s\'ouvre pendant le délai : on revérifie', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.kycVerified)];
    await pumpHost(tester);
    emit(VideoModalMoment.action(VideoModalTrigger.kycVerified));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('dialogue'));
    await tester.pump(const Duration(milliseconds: 1100));
    await settleTransitions(tester);
    // Le délai est écoulé mais la boîte de dialogue est toujours là.
    expect(find.text('dlg'), findsOneWidget);
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await settleAfterOpenDelay(tester);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });

  testWidgets('un modal d\'écran s\'ouvre avant : le moment est abandonné', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [
      campaign(id: 'ouverture', triggers: {VideoModalTrigger.appOpen}),
      forMoment(VideoModalTrigger.paymentSucceeded, id: 'moment'),
    ];
    // L'ouverture de l'app part 2 s après le chargement : le moment, émis
    // juste après, arrive plus tard.
    await tester.pumpWidget(const SizedBox());
    bloc = VideoModalBloc(
      repo,
      makeEnabledAnalytics(MockAnalyticsBackend()),
      hasRealSession: () => true,
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VideoModalHost(
          tabIndex: 0,
          bloc: bloc,
          hasRealSession: () => true,
          lang: () => 'fr',
          moments: moments,
          clock: () => now,
          child: const Scaffold(body: Text('shell')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
    await settleAfterOpenDelay(tester);
    expect(shownIds(), ['ouverture']);
    await closeModal(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Bienvenue sur Yadony'), findsNothing);
  });

  testWidgets('connexion pendant la session : campagnes rechargées', (
    tester,
  ) async {
    usePhone360(tester);
    loadResult = [forMoment(VideoModalTrigger.paymentSucceeded)];
    await pumpHost(tester);
    realSession = false;
    emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
    await settleAfterOpenDelay(tester);
    await settleAfterOpenDelay(tester);
    verify(() => repo.loadEligible(lang: 'fr', realSession: false)).called(1);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
  });
}
