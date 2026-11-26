import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/datasources/video_modal_local_datasource.dart';
import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:dony/features/video_modal/data/models/parcel_step.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
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

/// Modals d'étape du colis côté hôte : rôle, « une fois par colis » (hors
/// limite de la session, réponse et plafond ignorés, « Ne plus afficher »
/// définitif), un seul modal par moment, variables et boutons du colis.
void main() {
  late _MockRepo repo;
  late VideoModalBloc bloc;
  late VideoModalMoments moments;
  late GoRouter router;
  late _MockProbe probe;
  var loadResult = <VideoModalCampaign>[];
  var now = DateTime.utc(2026, 11, 25, 12);
  var realSession = true;
  late BuildContext screen;
  BuildContext? secondContext;
  late List<String> opened;

  setUpAll(() {
    registerFallbackValue(campaign());
    registerFallbackValue(VideoModalEventType.shown);
  });

  setUp(() {
    VideoModalPresenter.resetForTest();
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 11, 25, 12);
    realSession = true;
    secondContext = null;
    opened = [];
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
    moments = VideoModalMoments(
      local: VideoModalLocalDatasource(),
      appVersion: () async => '1.0.0',
      clock: () => now,
    );
    addTearDown(moments.dispose);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
  }) async {
    bloc = VideoModalBloc(
      repo,
      makeEnabledAnalytics(MockAnalyticsBackend()),
      hasRealSession: () => realSession,
      clock: () => now,
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
            lang: () => locale.languageCode,
            moments: moments,
            clock: () => now,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  screen = context;
                  return const Text('fiche');
                },
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
        GoRoute(
          path: '/bids/:id',
          builder: (_, state) =>
              Scaffold(body: Text('colis ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/receptions/:id',
          builder: (_, state) =>
              Scaffold(body: Text('réception ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: testTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await settleTransitions(tester);
  }

  ParcelActionOpeners openers() => ParcelActionOpeners(
    qr: (_) async => opened.add('qr'),
    sendCode: (_) async => opened.add('sendCode'),
    tracking: (_) async => opened.add('tracking'),
  );

  VideoModalMoment step({
    VideoModalTrigger trigger = VideoModalTrigger.parcelArrived,
    String bidId = 'bid-1',
    Set<ParcelRole> roles = const {ParcelRole.sender},
    Map<String, String> variables = const {},
    bool canSendCode = true,
    bool onDetailScreen = false,
  }) => VideoModalMoment.parcelStep(
    trigger: trigger,
    bidId: bidId,
    roles: roles,
    variables: variables,
    canSendCode: canSendCode,
    openers: openers(),
    onDetailScreen: onDetailScreen,
  );

  VideoModalCampaign parcelInfo({
    String id = 'p1',
    List<String> triggers = const ['PARCEL_ARRIVED'],
    List<String>? roles,
    String frequency = 'ONCE_PER_PARCEL',
    int priority = 0,
    bool stopAfterAnswer = true,
    bool allowDontShowAgain = false,
    String title = 'Votre colis est arrivé',
    String body = 'Préparez la remise.',
    String primaryLabel = 'Voir le QR',
    Object? primary = const {'kind': 'SCREEN', 'screen': 'PARCEL_QR'},
    String secondaryLabel = 'Plus tard',
    Object? secondary = const {'kind': 'CLOSE'},
    Map<String, Object?> extra = const {},
  }) => VideoModalCampaign.tryParse(
    infoJson(
      id: id,
      triggers: triggers,
      primaryAction: primary,
      secondaryAction: secondary,
      body: body,
      extra: {
        'title': title,
        'subtitle': null,
        'primaryLabel': primaryLabel,
        'secondaryLabel': secondaryLabel,
        'frequency': frequency,
        'priority': priority,
        'stopAfterAnswer': stopAfterAnswer,
        'allowDontShowAgain': allowDontShowAgain,
        'parcelRoles': ?roles,
        ...extra,
      },
    ),
  )!;

  Future<void> emitStep(
    WidgetTester tester,
    VideoModalMoment moment, {
    BuildContext? origin,
  }) async {
    // Le stockage du téléphone répond hors du temps simulé du test.
    await tester.runAsync(
      () => moments.emitParcelStep(moment, origin: origin ?? screen),
    );
    await settleAfterOpenDelay(tester);
  }

  List<String> shownIds() => verify(
    () => repo.record(
      captureAny(),
      VideoModalEventType.shown,
      realSession: any(named: 'realSession'),
    ),
  ).captured.cast<VideoModalCampaign>().map((c) => c.id).toList();

  Future<void> tapAndSettle(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settleTransitions(tester);
  }

  Finder primary() => find.byKey(const Key('info-modal-primary'));
  Finder secondary() => find.byKey(const Key('info-modal-secondary'));

  group('rôle sur le colis', () {
    testWidgets('campaignWithRoles_showsOnlyForMatchingRole', (tester) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(roles: ['TRAVELER']),
      ];
      await pumpHost(tester);
      await emitStep(tester, step() /* expéditeur */);
      expect(find.text('Votre colis est arrivé'), findsNothing);
      await emitStep(tester, step(roles: const {ParcelRole.traveler}));
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('emptyRoles_showsForAll', (tester) async {
      usePhone360(tester);
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      await emitStep(tester, step(roles: const {ParcelRole.recipient}));
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
    });

    testWidgets('selfRecipient_oneModalPerMoment_priorityWins', (tester) async {
      usePhone360(tester);
      loadResult = VideoModalCampaign.sortByPriority([
        parcelInfo(id: 'send', roles: ['SENDER'], title: 'Pour l\'expéditeur'),
        parcelInfo(
          id: 'recv',
          roles: ['RECIPIENT'],
          priority: 5,
          title: 'Pour le destinataire',
        ),
      ]);
      await pumpHost(tester);
      await emitStep(
        tester,
        step(roles: const {ParcelRole.sender, ParcelRole.recipient}),
      );
      expect(find.text('Pour le destinataire'), findsOneWidget);
      expect(find.text("Pour l'expéditeur"), findsNothing);
      await tapAndSettle(tester, 'info-modal-secondary');
      await settleAfterOpenDelay(tester);
      // Le même moment n'ouvre pas un second modal.
      expect(find.text("Pour l'expéditeur"), findsNothing);
      expect(shownIds(), ['recv']);
    });

    testWidgets('la même étape du même colis rouverte vite : un seul modal', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [parcelInfo(frequency: 'EVERY_TIME')];
      await pumpHost(tester);
      await tester.runAsync(() async {
        await moments.emitParcelStep(step(), origin: screen);
        await moments.emitParcelStep(
          step(roles: const {ParcelRole.sender, ParcelRole.recipient}),
          origin: screen,
        );
      });
      await settleAfterOpenDelay(tester);
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
      await tapAndSettle(tester, 'info-modal-secondary');
      await settleAfterOpenDelay(tester);
      expect(find.text('Votre colis est arrivé'), findsNothing);
      expect(shownIds(), ['p1']);
    });

    testWidgets('visiteur sans compte : aucun modal de colis', (tester) async {
      usePhone360(tester);
      realSession = false;
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      await emitStep(tester, step());
      expect(find.text('Votre colis est arrivé'), findsNothing);
      verifyNever(
        () => repo.record(any(), any(), realSession: any(named: 'realSession')),
      );
    });

    testWidgets('écran du colis quitté avant le modal : moment abandonné', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      unawaited(router.push('/second'));
      await settleTransitions(tester);
      final gone = secondContext!;
      router.pop();
      await settleTransitions(tester);
      await emitStep(tester, step(), origin: gone);
      expect(find.text('Votre colis est arrivé'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('écran du colis recouvert : le modal attend, sans erreur', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      unawaited(router.push('/second'));
      await settleTransitions(tester);
      await emitStep(tester, step());
      expect(find.text('Votre colis est arrivé'), findsNothing);
      router.pop();
      await settleTransitions(tester);
      await tester.pump(const Duration(seconds: 1));
      await settleAfterOpenDelay(tester);
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('une fois par colis', () {
    testWidgets('oncePerParcel_twoParcelsShowTwice', (tester) async {
      usePhone360(tester);
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      await emitStep(tester, step() /* bid-1 */);
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
      await tapAndSettle(tester, 'info-modal-secondary');
      await emitStep(tester, step(bidId: 'bid-2'));
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
      await tapAndSettle(tester, 'info-modal-secondary');
      expect(shownIds(), ['p1', 'p1']);
      expect(moments.shownForParcelNow('p1', 1, 'bid-1'), isTrue);
      expect(moments.shownForParcelNow('p1', 1, 'bid-2'), isTrue);
    });

    testWidgets('oncePerParcel_sameParcelShowsOnce', (tester) async {
      usePhone360(tester);
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      await emitStep(tester, step());
      await tester.binding.handlePopRoute();
      await settleTransitions(tester);
      // Fiche rouverte : même colis, déjà vu.
      await emitStep(tester, step());
      expect(find.text('Votre colis est arrivé'), findsNothing);
      expect(shownIds(), ['p1']);
    });

    testWidgets('déjà vu sur ce téléphone lors d\'un lancement précédent', (
      tester,
    ) async {
      usePhone360(tester);
      final before = VideoModalMoments(appVersion: () async => '1.0.0');
      await tester.runAsync(() async {
        await before.recordShownForParcel('p1', 1, 'bid-1');
        await before.dispose();
      });
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      await emitStep(tester, step());
      expect(find.text('Votre colis est arrivé'), findsNothing);
      await emitStep(tester, step(bidId: 'bid-2'));
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
    });

    testWidgets('stopAfterAnswer=true ignoré : une réponse sur un colis', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      await emitStep(tester, step() /* bid-1 */);
      // Bouton touché : une réponse.
      await tapAndSettle(tester, 'info-modal-secondary');
      await emitStep(tester, step(bidId: 'bid-2'));
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
    });

    testWidgets('limite « un modal par session » ignorée, dans les deux sens', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(),
        VideoModalCampaign.tryParse(
          infoJson(
            id: 'pay',
            triggers: ['PAYMENT_SUCCEEDED'],
            extra: {'title': 'Paiement reçu'},
          ),
        )!,
      ];
      await pumpHost(tester);
      moments.emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
      await settleAfterOpenDelay(tester);
      expect(find.text('Paiement reçu'), findsOneWidget);
      await tapAndSettle(tester, 'info-modal-secondary');
      // La case des moments d'information est prise : le colis passe quand même.
      await emitStep(tester, step() /* bid-1 */);
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
      await tapAndSettle(tester, 'info-modal-secondary');
      await emitStep(tester, step(bidId: 'bid-2'));
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
      expect(shownIds(), ['pay', 'p1', 'p1']);
    });

    testWidgets("un modal de colis n'occupe pas la case de la session", (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(),
        VideoModalCampaign.tryParse(
          infoJson(
            id: 'pay',
            triggers: ['PAYMENT_SUCCEEDED'],
            extra: {'title': 'Paiement reçu'},
          ),
        )!,
      ];
      await pumpHost(tester);
      await emitStep(tester, step());
      await tapAndSettle(tester, 'info-modal-secondary');
      moments.emit(VideoModalMoment.action(VideoModalTrigger.paymentSucceeded));
      await settleAfterOpenDelay(tester);
      expect(find.text('Paiement reçu'), findsOneWidget);
    });

    testWidgets('plafond de la version ignoré', (tester) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(extra: {'maxDisplays': 1, 'displays': 7}),
      ];
      await pumpHost(tester);
      await emitStep(tester, step() /* bid-1 */);
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
      await tapAndSettle(tester, 'info-modal-secondary');
      await emitStep(tester, step(bidId: 'bid-2'));
      expect(find.text('Votre colis est arrivé'), findsOneWidget);
    });

    testWidgets('« Ne plus afficher » reste définitif', (tester) async {
      usePhone360(tester);
      loadResult = [parcelInfo(allowDontShowAgain: true)];
      await pumpHost(tester);
      await emitStep(tester, step() /* bid-1 */);
      await tester.tap(find.byKey(const Key('video-modal-dont-show-again')));
      await tester.pump();
      await tapAndSettle(tester, 'info-modal-secondary');
      verify(
        () => repo.record(
          any(),
          VideoModalEventType.dontShowAgain,
          realSession: true,
        ),
      ).called(1);
      await emitStep(tester, step(bidId: 'bid-2'));
      expect(find.text('Votre colis est arrivé'), findsNothing);
    });
  });

  group('variables des textes', () {
    testWidgets('variablesFilledWithFallback (FR)', (tester) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(
          title: '{voyageur} est à {ville_arrivee}',
          body: '{destinataire} peut retirer le colis de {expéditeur}.',
          primaryLabel: 'Merci {voyageur}',
          primary: const {'kind': 'CLOSE'},
          secondary: null,
        ),
      ];
      await pumpHost(tester);
      await emitStep(
        tester,
        step(
          variables: const {
            'voyageur': 'Moussa',
            'destinataire': '  ',
            'expéditeur': '',
          },
        ),
      );
      expect(find.text("Moussa est à la ville d'arrivée"), findsOneWidget);
      expect(
        find.text("Votre destinataire peut retirer le colis de l'expéditeur."),
        findsOneWidget,
      );
      expect(find.text('Merci Moussa'), findsOneWidget);
      expectButtonLabelsFit(tester);
    });

    testWidgets('variablesFilledWithFallback (EN)', (tester) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(
          title: '{traveler}',
          body:
              '{destinataire} with {voyageur} from {expéditeur} in {ville_arrivee}.',
          primary: const {'kind': 'CLOSE'},
          secondary: null,
        ),
      ];
      await pumpHost(tester, locale: AppL10n.en);
      await emitStep(tester, step());
      // Variable inconnue : laissée telle quelle.
      expect(find.text('{traveler}'), findsOneWidget);
      expect(
        find.text(
          'Your recipient with your traveler from the sender in the arrival city.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('bodyNeverContainsPickupCode', (tester) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(
          body: 'Votre code {code} pour {destinataire}',
          primary: const {'kind': 'CLOSE'},
          secondary: null,
        ),
      ];
      await pumpHost(tester);
      await emitStep(tester, step(variables: const {'destinataire': 'Awa'}));
      expect(find.text('Votre code {code} pour Awa'), findsOneWidget);
      expect(find.textContaining('482913'), findsNothing);
      expect(find.textContaining(RegExp(r'\d{6}')), findsNothing);
    });
  });

  group('boutons du colis', () {
    testWidgets('qrButtonHiddenForRecipient : le secondaire passe principal', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      await emitStep(tester, step(roles: const {ParcelRole.recipient}));
      expect(find.text('Voir le QR'), findsNothing);
      expect(primary(), findsOneWidget);
      expect(secondary(), findsNothing);
      expect(
        find.descendant(of: primary(), matching: find.text('Plus tard')),
        findsOneWidget,
      );
      await tapAndSettle(tester, 'info-modal-primary');
      expect(opened, isEmpty);
      verify(
        () => repo.record(
          any(),
          VideoModalEventType.dismissed,
          realSession: true,
        ),
      ).called(1);
    });

    testWidgets("QR pour l'expéditeur : la feuille du QR s'ouvre", (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [parcelInfo()];
      await pumpHost(tester);
      await emitStep(tester, step());
      expect(find.text('Voir le QR'), findsOneWidget);
      await tapAndSettle(tester, 'info-modal-primary');
      expect(opened, ['qr']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sendCodeButtonHiddenWithoutCode', (tester) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(
          primaryLabel: 'Envoyer le code',
          primary: const {'kind': 'SCREEN', 'screen': 'PARCEL_SEND_CODE'},
          secondaryLabel: 'Suivre le colis',
          secondary: const {'kind': 'SCREEN', 'screen': 'PARCEL_TRACKING'},
        ),
      ];
      await pumpHost(tester);
      await emitStep(tester, step(canSendCode: false));
      expect(find.text('Envoyer le code'), findsNothing);
      expect(
        find.descendant(of: primary(), matching: find.text('Suivre le colis')),
        findsOneWidget,
      );
      expect(secondary(), findsNothing);
      await tapAndSettle(tester, 'info-modal-primary');
      expect(opened, ['tracking']);
    });

    testWidgets('code présent : « Prévenir » en mode code', (tester) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(
          primaryLabel: 'Envoyer le code',
          primary: const {'kind': 'SCREEN', 'screen': 'PARCEL_SEND_CODE'},
        ),
      ];
      await pumpHost(tester);
      await emitStep(tester, step());
      await tapAndSettle(tester, 'info-modal-primary');
      expect(opened, ['sendCode']);
    });

    testWidgets('les deux boutons masqués : un modal qui se ferme seulement', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(
          secondaryLabel: 'Envoyer le code',
          secondary: const {'kind': 'SCREEN', 'screen': 'PARCEL_SEND_CODE'},
        ),
      ];
      await pumpHost(tester);
      await emitStep(tester, step(roles: const {ParcelRole.traveler}));
      expect(primary(), findsOneWidget);
      expect(secondary(), findsNothing);
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(
        find.descendant(
          of: primary(),
          matching: find.text(l.infoModalCloseFallback),
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, 'info-modal-primary');
      expect(opened, isEmpty);
      expect(primary(), findsNothing);
      expectNoPage(tester);
    });

    testWidgets('détail du colis : ouvre la fiche (expéditeur, voyageur)', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(
          primaryLabel: 'Voir le colis',
          primary: const {'kind': 'SCREEN', 'screen': 'PARCEL_DETAIL'},
        ),
      ];
      await pumpHost(tester);
      await emitStep(tester, step(roles: const {ParcelRole.traveler}));
      await tapAndSettle(tester, 'info-modal-primary');
      expect(find.text('colis bid-1'), findsOneWidget);
    });

    testWidgets('détail du colis émis par sa fiche : le modal se ferme', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(
          frequency: 'EVERY_TIME',
          primaryLabel: 'Voir le colis',
          primary: const {'kind': 'SCREEN', 'screen': 'PARCEL_DETAIL'},
        ),
      ];
      await pumpHost(tester);
      final before = router.routerDelegate.currentConfiguration.matches.length;
      await emitStep(tester, step(onDetailScreen: true));
      await tapAndSettle(tester, 'info-modal-primary');
      expect(primary(), findsNothing);
      expectNoPage(tester);
      expect(
        router.routerDelegate.currentConfiguration.matches,
        hasLength(before),
      );
      // Aucune copie de la fiche, donc aucun nouveau moment.
      await settleAfterOpenDelay(tester);
      expect(find.text('Votre colis est arrivé'), findsNothing);
    });

    testWidgets('détail du colis : la réception pour le destinataire', (
      tester,
    ) async {
      usePhone360(tester);
      loadResult = [
        parcelInfo(
          primaryLabel: 'Voir le colis',
          primary: const {'kind': 'SCREEN', 'screen': 'PARCEL_DETAIL'},
        ),
      ];
      await pumpHost(tester);
      await emitStep(tester, step(roles: const {ParcelRole.recipient}));
      await tapAndSettle(tester, 'info-modal-primary');
      expect(find.text('réception bid-1'), findsOneWidget);
    });
  });

  group('runInfoAction avec le contexte du colis', () {
    ParcelActionContext parcel(Set<ParcelRole> roles) => ParcelActionContext(
      bidId: 'bid-1',
      roles: roles,
      canSendCode: true,
      openers: openers(),
    );

    Future<BuildContext> pumpAt(WidgetTester tester, String location) async {
      late BuildContext captured;
      final r = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) {
                  captured = context;
                  return const Text('accueil');
                },
              ),
            ),
          ),
          GoRoute(
            path: '/bids/:id',
            builder: (_, state) => Scaffold(
              body: Builder(
                builder: (context) {
                  captured = context;
                  return Text('colis ${state.pathParameters['id']}');
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(r.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: r));
      await tester.pumpAndSettle();
      return captured;
    }

    /// Comme dans l'app : la fiche (ou la réception) est poussée par-dessus un
    /// onglet. Rend le contexte de l'écran poussé et le routeur.
    Future<(BuildContext, GoRouter)> pumpPushed(
      WidgetTester tester,
      String path,
    ) async {
      BuildContext? pushed;
      Widget page(String label) => Scaffold(
        body: Builder(
          builder: (context) {
            if (label != 'accueil') pushed = context;
            return Text(label);
          },
        ),
      );
      final r = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => page('accueil')),
          GoRoute(
            path: '/bids/:id',
            builder: (_, state) => page('colis ${state.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/receptions/:id',
            builder: (_, state) =>
                page('réception ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(r.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: r));
      await tester.pumpAndSettle();
      unawaited(r.push(path));
      await tester.pumpAndSettle();
      return (pushed!, r);
    }

    for (final (path, roles, label) in [
      ('/bids/bid-1', const {ParcelRole.sender}, 'colis bid-1'),
      ('/bids/bid-1', const {ParcelRole.traveler}, 'colis bid-1'),
      ('/receptions/bid-1', const {ParcelRole.recipient}, 'réception bid-1'),
    ]) {
      testWidgets(
        '$path poussé (${roles.single.wire}) : « Voir le colis » ne le double pas',
        (tester) async {
          final (context, r) = await pumpPushed(tester, path);
          final before = r.routerDelegate.currentConfiguration.matches.length;
          final left = await VideoModalPresenter.runInfoAction(
            context,
            const VideoModalAction.openScreen(InfoScreen.parcelDetail),
            parcel: parcel(roles),
          );
          await tester.pumpAndSettle();
          expect(left, isFalse);
          expect(
            r.routerDelegate.currentConfiguration.matches,
            hasLength(before),
          );
          expect(find.text(label), findsOneWidget);
        },
      );
    }

    testWidgets('fiche d\'un autre colis au sommet : la bonne fiche s\'ouvre', (
      tester,
    ) async {
      final (context, r) = await pumpPushed(tester, '/bids/bid-9');
      final before = r.routerDelegate.currentConfiguration.matches.length;
      final left = await VideoModalPresenter.runInfoAction(
        context,
        const VideoModalAction.openScreen(InfoScreen.parcelDetail),
        parcel: parcel(const {ParcelRole.sender}),
      );
      await tester.pumpAndSettle();
      expect(left, isTrue);
      expect(
        r.routerDelegate.currentConfiguration.matches,
        hasLength(before + 1),
      );
      expect(find.text('colis bid-1'), findsOneWidget);
    });

    testWidgets('déjà sur la fiche du colis : rien ne s\'empile', (
      tester,
    ) async {
      final context = await pumpAt(tester, '/bids/bid-1');
      final left = await VideoModalPresenter.runInfoAction(
        context,
        const VideoModalAction.openScreen(InfoScreen.parcelDetail),
        parcel: parcel(const {ParcelRole.sender}),
      );
      await tester.pumpAndSettle();
      expect(left, isFalse);
      expect(find.text('colis bid-1'), findsOneWidget);
      expect(
        GoRouter.of(context).routerDelegate.currentConfiguration.matches,
        hasLength(1),
      );
    });

    testWidgets('bouton non applicable exécuté quand même : aucune action', (
      tester,
    ) async {
      final context = await pumpAt(tester, '/bids/bid-1');
      for (final screen in [InfoScreen.parcelQr, InfoScreen.parcelSendCode]) {
        expect(
          await VideoModalPresenter.runInfoAction(
            context,
            VideoModalAction.openScreen(screen),
            parcel: parcel(const {ParcelRole.recipient}),
          ),
          isFalse,
        );
      }
      expect(opened, isEmpty);
      expect(
        await VideoModalPresenter.runInfoAction(
          context,
          const VideoModalAction.openScreen(InfoScreen.parcelTracking),
          parcel: parcel(const {ParcelRole.recipient}),
        ),
        isTrue,
      );
      expect(opened, ['tracking']);
    });

    testWidgets('sans contexte colis : la garde de P1 tient toujours', (
      tester,
    ) async {
      final context = await pumpAt(tester, '/');
      for (final screen in InfoScreen.values.where(
        (s) => s.needsParcelContext,
      )) {
        expect(
          await VideoModalPresenter.runInfoAction(
            context,
            VideoModalAction.openScreen(screen),
            hasRealSession: () => true,
          ),
          isFalse,
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('accueil'), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('une action qui lève : aucune exception ne remonte', (
      tester,
    ) async {
      final context = await pumpAt(tester, '/');
      final broken = ParcelActionContext(
        bidId: 'bid-1',
        roles: const {ParcelRole.sender},
        canSendCode: true,
        openers: ParcelActionOpeners(
          qr: (_) async => throw StateError('colis inconnu'),
        ),
      );
      expect(
        await VideoModalPresenter.runInfoAction(
          context,
          const VideoModalAction.openScreen(InfoScreen.parcelQr),
          parcel: broken,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// Ni fiche colis ni réception ouverte par-dessus l'écran.
void expectNoPage(WidgetTester tester) {
  expect(find.textContaining('colis bid-'), findsNothing);
  expect(find.textContaining('réception bid-'), findsNothing);
}
