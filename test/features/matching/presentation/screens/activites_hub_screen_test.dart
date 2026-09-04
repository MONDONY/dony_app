import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/bloc/tools_completion_cubit.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/tools_completion_repository.dart';
import 'package:dony/features/matching/presentation/screens/activites_hub_screen.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _activitiesHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "activities_intro",
      "title": "Découvrir l'espace Activités",
      "description": "Suivre vos trajets, envois et négociations au même endroit.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["activities"]
    }
  ]
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockTravelerBidsBloc
    extends MockBloc<TravelerBidsEvent, TravelerBidsState>
    implements TravelerBidsBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockToolsCompletionRepository extends Mock
    implements ToolsCompletionRepository {}

// Le vrai Hive est inutilisable sous testWidgets : ses écritures passent par
// un verrou asynchrone qui ne se résout jamais dans la zone FakeAsync et
// bloque tous les accès suivants. On mocke la box, le contrat suffit.
class _MockHiveService extends Mock implements HiveService {}

class _MockBox extends Mock implements Box {}

class _FakeBidEvent extends Fake implements BidEvent {}

// ── Helpers ───────────────────────────────────────────────────────────────────

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'a1',
  senderId: 's1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Routes atteintes pendant le test, dans l'ordre.
late List<String> visited;

/// Exposé pour vérifier le nombre de rechargements déclenchés par
/// [EnvoisRefreshNotifier] (throttle anti-rafale).
late _MockTravelerBidsBloc _travelerBidsBlocUnderTest;

/// Exposé pour compter les rechargements de la complétion des outils.
late _MockToolsCompletionRepository _toolsRepoUnderTest;

Future<void> _pump(
  WidgetTester tester, {
  TripsSummaryModel? summary,
  BidState? bidState,
  TravelerBidsState? travelerBidsState,
  NegotiationListState? negoState,
  PackageRequestState? packageRequestState,
  ToolsCompletionModel? toolsCompletion,
  bool toolsCompletionFails = false,
  String helpConfigJson = _emptyHelpConfigJson,

  /// Largeur logique de la vue (devicePixelRatio 1). Par défaut une vue large
  /// où rien ne serre ; passer 360 px pour éprouver le plus petit téléphone
  /// visé, là où les tuiles-outils tombent à 154 px de large.
  Size? physicalSize,
}) async {
  tester.view.physicalSize = physicalSize ?? const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  visited = [];

  final repo = _MockAnnouncementRepository();
  when(() => repo.getTripsSummary(period: any(named: 'period'))).thenAnswer(
    (_) async =>
        summary ??
        const TripsSummaryModel(activeTrips: 6, kgSold: 0, revenue: 0),
  );

  final bidBloc = _MockBidBloc();
  when(() => bidBloc.state).thenReturn(
    bidState ??
        BidListLoaded([
          _bid('b1', 'IN_TRANSIT'),
          _bid('b2', 'ACCEPTED'),
          _bid('b3', 'COMPLETED'),
        ]),
  );

  final travelerBids = _MockTravelerBidsBloc();
  when(() => travelerBids.state).thenReturn(
    travelerBidsState ??
        TravelerBidsLoaded(
          bids: [_bid('r1', 'PENDING'), _bid('r2', 'PAYMENT_ESCROWED')],
          page: 0,
          hasMore: false,
          filter: TravelerBidFilter.aTraiter,
        ),
  );
  _travelerBidsBlocUnderTest = travelerBids;

  final nego = _MockNegotiationListBloc();
  when(() => nego.state).thenReturn(negoState ?? NegotiationListState());

  final packageRequests = _MockPackageRequestBloc();
  when(
    () => packageRequests.state,
  ).thenReturn(packageRequestState ?? PackageRequestState());

  final summaryCubit = TripsSummaryCubit(repo);

  final toolsRepo = _MockToolsCompletionRepository();
  if (toolsCompletionFails) {
    when(() => toolsRepo.getToolsCompletion()).thenThrow(Exception('down'));
  } else {
    when(() => toolsRepo.getToolsCompletion()).thenAnswer(
      (_) async =>
          toolsCompletion ??
          const ToolsCompletionModel(
            tools: [
              ToolStatus(key: ToolKey.addresses, count: 2),
              ToolStatus(key: ToolKey.recipients, count: 0),
              ToolStatus(key: ToolKey.alerts, count: 0),
              ToolStatus(key: ToolKey.tripTemplates, count: 1),
              ToolStatus(key: ToolKey.priceGrid, count: 6),
            ],
          ),
    );
  }
  _toolsRepoUnderTest = toolsRepo;
  final toolsCubit = ToolsCompletionCubit(
    toolsRepo,
    makeDisabledAnalytics(MockAnalyticsBackend()),
  );

  Widget stub(String label) => Scaffold(body: Text(label));

  GoRoute route(String path, String label) => GoRoute(
    path: path,
    builder: (_, _) {
      visited.add(path);
      return stub(label);
    },
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<TripsSummaryCubit>.value(value: summaryCubit),
            BlocProvider<TravelerBidsBloc>.value(value: travelerBids),
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<StatsPeriodCubit>(create: (_) => StatsPeriodCubit()),
            BlocProvider<NegotiationListBloc>.value(value: nego),
            BlocProvider<PackageRequestBloc>.value(value: packageRequests),
            BlocProvider<ToolsCompletionCubit>.value(value: toolsCubit),
            BlocProvider<HelpCenterBloc>(
              create: (_) => HelpCenterBloc(
                HelpCenterRepository(
                  _StaticHelpCenterSource(helpConfigJson),
                  fallbackJsonLoader: () async => _emptyHelpConfigJson,
                ),
                makeDisabledAnalytics(MockAnalyticsBackend()),
              )..add(const HelpCenterLoadRequested()),
            ),
          ],
          child: const ActivitesHubScreenTesting(),
        ),
      ),
      route('/announcements/trips', 'Trajets'),
      route('/envois', 'Écran envois'),
      route('/demandes', 'Écran demandes'),
      route('/negotiations', 'Écran négociations'),
      route('/trips/create', 'Créer trajet'),
      route('/trips/publish-intro', 'Intro trajet'),
      route('/parcels/send-intro', 'Intro colis'),
      route('/tracking/search', 'Recherche'),
      route('/tracking/scan-hub', 'Scan'),
      route('/settings', 'Paramètres'),
      route('/payments/wallet', 'Portefeuille'),
      route('/profile/shipments/history', 'Écran historique'),
      route('/profile/help/faq', 'FAQ'),
      route('/corridor-alerts', 'Alertes'),
      route('/trip-templates', 'Modèles'),
      route('/profile/addresses', 'Adresses'),
      route('/profile/recipients', 'Destinataires'),
      route('/profile/price-grid', 'Grille de prix'),
      GoRoute(
        path: '/profile/help/tutorial/:tutorialId',
        builder: (_, state) => Scaffold(
          body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
    // Événements sealed : on enregistre une instance concrète plutôt qu'un Fake.
    registerFallbackValue(const TravelerBidsRequested());
    registerFallbackValue(const NegotiationListFetchRequested());
    registerFallbackValue('');
  });

  setUp(() {
    if (!getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.registerLazySingleton<EnvoisRefreshNotifier>(
        EnvoisRefreshNotifier.new,
      );
    }
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      when(
        () => analytics.logScreen(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    }
  });

  tearDown(() => getIt.reset());

  group('compteurs', () {
    testWidgets('les quatre tuiles affichent les compteurs de leur bloc', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Trajets actifs'), findsOneWidget);
      expect(find.text('Mes colis'), findsOneWidget);
      expect(find.text('Demandes reçues'), findsOneWidget);
      expect(find.text('Discussions de prix'), findsOneWidget);

      // 6 trajets actifs (summary), 2 envois en cours (IN_TRANSIT + ACCEPTED,
      // le COMPLETED est exclu), 2 demandes à traiter. La négociation à zéro
      // n'affiche pas « 0 » mais son invite.
      expect(find.text('6'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2));
      expect(find.text('0'), findsNothing);
      expect(find.text('Aucune en cours'), findsOneWidget);
    });

    testWidgets('demande publiée en négo allume la pastille de « Mes colis », '
        'pas celle de « Demandes reçues »', (tester) async {
      final negoReq = PackageRequest.fromJson(const {
        'id': 'pr-1',
        'senderId': 's1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'desiredDate': '2026-08-01',
        'dateToleranceDays': 2,
        'weightKg': 3.0,
        'parcelSize': 'SMALL',
        'status': 'NEGOTIATING',
        'createdAt': '2026-07-01T10:00:00Z',
      });

      await _pump(
        tester,
        // Aucune demande reçue à traiter…
        travelerBidsState: TravelerBidsLoaded(
          bids: const [],
          page: 0,
          hasMore: false,
          filter: TravelerBidFilter.aTraiter,
        ),
        // …mais une demande publiée porte une discussion non lue.
        packageRequestState: PackageRequestState(requests: [negoReq]),
        negoState: NegotiationListState(
          threads: [
            NegotiationThread(
              id: 'th-1',
              packageRequestId: 'pr-1',
              travelerId: 'tr-1',
              status: NegotiationThreadStatus.open,
              currentPriceEur: 45,
              roundsCount: 1,
              lastActivityAt: DateTime(2026, 6, 10),
              createdAt: DateTime(2026, 6),
              travelerTravelDate: DateTime(2026, 7),
              travelerAvailableKg: 10,
              messages: const [],
              hasUnread: true,
            ),
          ],
        ),
      );

      // La tuile Demandes reçues ne parle plus que des demandes reçues :
      // son invite reste « Aucune » et elle ne porte aucun point rouge.
      expect(find.text('Aucune pour l\'instant'), findsOneWidget);

      Finder dotIn(String tileKey) => find.descendant(
        of: find.byKey(Key(tileKey)),
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) {
            return false;
          }
          final deco = w.decoration;
          return deco is BoxDecoration &&
              deco.shape == BoxShape.circle &&
              deco.color == DonyColors.error;
        }),
      );

      expect(dotIn('hub-tile-requests'), findsNothing);
      // Le point d'attention est porté par la tuile qui ouvre la liste où
      // la négociation se trouve réellement.
      expect(dotIn('hub-tile-shipments'), findsOneWidget);
    });

    testWidgets('« Mes colis » agrège les envois et les demandes publiées', (
      tester,
    ) async {
      final openReq = PackageRequest.fromJson(const {
        'id': 'pr-2',
        'senderId': 's1',
        'departureCity': 'Lyon',
        'arrivalCity': 'Bamako',
        'desiredDate': '2026-08-01',
        'dateToleranceDays': 2,
        'weightKg': 3.0,
        'parcelSize': 'SMALL',
        'status': 'OPEN',
        'createdAt': '2026-07-01T10:00:00Z',
      });

      await _pump(
        tester,
        packageRequestState: PackageRequestState(requests: [openReq]),
      );

      // 2 envois en cours (fixture par défaut) + 1 demande publiée.
      expect(
        find.descendant(
          of: find.byKey(const Key('hub-tile-shipments')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('une erreur de résumé n\'affecte que sa propre tuile', (
      tester,
    ) async {
      final repo = _MockAnnouncementRepository();
      when(
        () => repo.getTripsSummary(period: any(named: 'period')),
      ).thenThrow(Exception('network'));

      await _pump(tester);
      // Les autres tuiles gardent leurs compteurs même si le résumé échoue.
      expect(find.text('Mes colis'), findsOneWidget);
      expect(find.text('Demandes reçues'), findsOneWidget);
    });
  });

  group('navigation', () {
    Future<void> expectNavigation(
      WidgetTester tester,
      String label,
      String expectedRoute,
    ) async {
      await _pump(tester);
      await tester.ensureVisible(find.text(label).first);
      await tester.tap(find.text(label).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(visited, contains(expectedRoute));
    }

    testWidgets('Trajets actifs → liste des trajets', (tester) async {
      await expectNavigation(tester, 'Trajets actifs', '/announcements/trips');
    });

    testWidgets('Mes colis → liste des envois', (tester) async {
      await expectNavigation(tester, 'Mes colis', '/envois');
    });

    testWidgets('Demandes reçues → écran Demandes', (tester) async {
      await expectNavigation(tester, 'Demandes reçues', '/demandes');
    });

    testWidgets('Discussions de prix → liste des négociations', (tester) async {
      await expectNavigation(tester, 'Discussions de prix', '/negotiations');
    });

    testWidgets('Publier un trajet → écran d\'intro trajet', (tester) async {
      await expectNavigation(
        tester,
        'Publier un trajet',
        '/trips/publish-intro',
      );
    });

    testWidgets('Publier un colis → écran d\'intro colis', (tester) async {
      await expectNavigation(tester, 'Publier un colis', '/parcels/send-intro');
    });

    testWidgets('Historique → historique des envois', (tester) async {
      await expectNavigation(
        tester,
        'Historique',
        '/profile/shipments/history',
      );
    });

    testWidgets('Aide & support → FAQ', (tester) async {
      await expectNavigation(tester, 'Aide & support', '/profile/help/faq');
    });

    testWidgets('Mes alertes → alertes corridor (toutes directions)', (
      tester,
    ) async {
      await expectNavigation(tester, 'Mes alertes', '/corridor-alerts');
    });

    testWidgets('Modèles de trajet → modèles', (tester) async {
      await expectNavigation(tester, 'Modèles de trajet', '/trip-templates');
    });

    testWidgets('Mes adresses → carnet d\'adresses', (tester) async {
      await expectNavigation(tester, 'Mes adresses', '/profile/addresses');
    });

    testWidgets('Mes destinataires → destinataires', (tester) async {
      await expectNavigation(
        tester,
        'Mes destinataires',
        '/profile/recipients',
      );
    });

    // L'entrée a quitté la section ARGENT du profil : si elle n'ouvre pas
    // depuis les outils, elle n'ouvre plus de nulle part.
    testWidgets('Ma grille de prix → grille de prix', (tester) async {
      await expectNavigation(
        tester,
        'Ma grille de prix',
        '/profile/price-grid',
      );
    });
  });

  group('menu de l\'en-tête', () {
    Future<void> openMenu(WidgetTester tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('hub-menu-button')));
      await tester.pumpAndSettle();
    }

    Future<void> expectMenuNavigation(
      WidgetTester tester,
      Key entry,
      String expectedRoute,
    ) async {
      await openMenu(tester);
      await tester.ensureVisible(find.byKey(entry));
      await tester.tap(find.byKey(entry), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(visited, contains(expectedRoute));
    }

    // Le bouton « Suivre un colis » de l'en-tête a disparu : le suivi ne
    // s'atteint plus que par le menu.
    testWidgets('le burger remplace l\'ancien bouton de suivi', (tester) async {
      await _pump(tester);

      expect(find.byKey(const Key('hub-menu-button')), findsOneWidget);
      expect(find.text('Suivre un colis'), findsNothing);
    });

    testWidgets('Suivre un colis → recherche de suivi', (tester) async {
      await expectMenuNavigation(
        tester,
        const Key('menu-quick-track'),
        '/tracking/search',
      );
    });

    testWidgets('Scanner un colis → hub de scan', (tester) async {
      await expectMenuNavigation(
        tester,
        const Key('menu-quick-scan'),
        '/tracking/scan-hub',
      );
    });

    testWidgets('Paramètres → réglages', (tester) async {
      await expectMenuNavigation(
        tester,
        const Key('menu-quick-settings'),
        '/settings',
      );
    });

    testWidgets('Portefeuille → wallet', (tester) async {
      await expectMenuNavigation(
        tester,
        const Key('menu-item-wallet'),
        '/payments/wallet',
      );
    });

    testWidgets('Mes alertes → alertes corridor', (tester) async {
      await expectMenuNavigation(
        tester,
        const Key('menu-tool-alerts'),
        '/corridor-alerts',
      );
    });

    // Un outil ouvert depuis le menu passe par le même chemin que sa tuile :
    // au retour, la complétion est rechargée pour que la jauge suive.
    testWidgets('un outil du menu recharge la complétion au retour', (
      tester,
    ) async {
      await openMenu(tester);
      clearInteractions(_toolsRepoUnderTest);

      await tester.tap(
        find.byKey(const Key('menu-tool-recipients')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(visited, contains('/profile/recipients'));

      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      verify(() => _toolsRepoUnderTest.getToolsCompletion()).called(1);
    });

    // La règle de contenu du menu : il ne redouble jamais « En ce moment ».
    // Chaque libellé reste unique dans l'arbre, celui de sa tuile.
    testWidgets('le menu ne reprend pas les tuiles « En ce moment »', (
      tester,
    ) async {
      await openMenu(tester);

      expect(find.text('Trajets actifs'), findsOneWidget);
      expect(find.text('Mes colis'), findsOneWidget);
      expect(find.text('Demandes reçues'), findsOneWidget);
      expect(find.text('Discussions de prix'), findsOneWidget);
    });

    testWidgets('les outils portent leur pastille et le décompte global', (
      tester,
    ) async {
      await openMenu(tester);

      // Le jeu par défaut du harnais : adresses 2, modèles 1, grille 6 →
      // trois outils prêts sur cinq.
      expect(find.text('3/5 prêts'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('menu-tool-alerts')),
          matching: find.text('À configurer'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('menu-tool-addresses')),
          matching: find.text('2 adresses'),
        ),
        findsOneWidget,
      );
    });
  });

  group('throttle de rechargement', () {
    testWidgets(
      'deux demandes de rafraîchissement rapprochées ne redéclenchent '
      'qu\'un seul rechargement (anti-rafale rate-limit)',
      (tester) async {
        await _pump(tester);
        // Un appel au montage (initState._loadAll).
        verify(
          () => _travelerBidsBlocUnderTest.add(
            const TravelerBidsRequested(force: true),
          ),
        ).called(1);

        final notifier = getIt<EnvoisRefreshNotifier>();
        notifier.requestRefresh();
        await tester.pump();
        notifier.requestRefresh();
        await tester.pump();

        // Les deux demandes arrivent moins de 3s après le chargement initial
        // (celui du montage) : le throttle les absorbe intégralement, aucun
        // rechargement supplémentaire n'est déclenché.
        verifyNever(
          () => _travelerBidsBlocUnderTest.add(
            const TravelerBidsRequested(force: true),
          ),
        );
      },
    );
  });

  group('rangée d\'actions', () {
    testWidgets('les deux boutons tiennent sur une ligne, à hauteur égale', (
      tester,
    ) async {
      await _pump(tester);

      final publish = tester.getSize(find.byKey(const Key('hub-publish-trip')));
      final send = tester.getSize(find.byKey(const Key('hub-new-request')));

      // Un libellé qui passe sur deux lignes fait grandir son bouton et casse
      // la symétrie de la paire — c'est ce que cette assertion attrape.
      expect(send.height, publish.height);
      expect(send.height, lessThanOrEqualTo(56));
    });
  });

  group('statistiques', () {
    testWidgets('les trois périodes sont proposées, 30 jours par défaut', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('7 jours'), findsOneWidget);
      expect(find.text('30 jours'), findsOneWidget);
      expect(find.text('12 mois'), findsOneWidget);
    });

    testWidgets('changer de période recharge le résumé', (tester) async {
      await _pump(tester);

      await tester.ensureVisible(find.text('12 mois'));
      await tester.tap(find.text('12 mois'));
      await tester.pump();

      // La sélection est reflétée dans le cubit de période.
      final context = tester.element(find.text('12 mois'));
      expect(
        BlocProvider.of<StatsPeriodCubit>(context).state,
        StatsPeriod.twelveMonths,
      );
    });

    testWidgets('les quatre métriques sont affichées', (tester) async {
      await _pump(tester);

      expect(find.text('Revenus'), findsOneWidget);
      expect(find.text('Kg vendus'), findsOneWidget);
      expect(find.text('Trajets'), findsOneWidget);
      expect(find.text('Envois'), findsOneWidget);
    });

    testWidgets('la section est masquée tant que tout est à zéro', (
      tester,
    ) async {
      await _pump(
        tester,
        summary: const TripsSummaryModel(activeTrips: 0, kgSold: 0, revenue: 0),
        bidState: BidListLoaded(const []),
        travelerBidsState: TravelerBidsLoaded(
          bids: const [],
          page: 0,
          hasMore: false,
          filter: TravelerBidFilter.aTraiter,
        ),
      );

      // « Revenus 0 € » n'apprend rien à un nouvel utilisateur : la section
      // n'apparaît qu'à la première activité.
      expect(find.text('Statistiques'), findsNothing);
      expect(find.text('Revenus'), findsNothing);
      // Les tuiles à zéro deviennent des invites à agir.
      expect(find.text('Publiez un trajet'), findsOneWidget);
      expect(find.text('Envoyez un colis'), findsOneWidget);
    });
  });

  group('carte d\'introduction', () {
    late _MockBox box;

    setUp(() {
      box = _MockBox();
      when(() => box.put(any<String>(), any<bool>())).thenAnswer((_) async {});
      // Clé de fermeture du tutoriel contextuel « activités » : non fermée
      // par défaut, sinon ContextualTutorialCard ne s'affiche jamais.
      when(
        () => box.get(
          '${HiveService.kContextualTutorialDismissedPrefix}activities_intro',
          defaultValue: any<Object?>(named: 'defaultValue'),
        ),
      ).thenReturn(false);
      final hive = _MockHiveService();
      when(() => hive.userPrefs).thenReturn(box);
      when(
        () => hive.listenUserPrefs(keys: any(named: 'keys')),
      ).thenReturn(ValueNotifier<Box>(box));
      getIt.registerLazySingleton<HiveService>(() => hive);
    });

    void introDismissed({required bool value}) => when(
      () => box.get(
        HiveService.kHubIntroDismissed,
        defaultValue: any<Object?>(named: 'defaultValue'),
      ),
    ).thenReturn(value);

    testWidgets('visible au premier lancement, le X la ferme et persiste', (
      tester,
    ) async {
      introDismissed(value: false);

      await _pump(tester);

      expect(find.textContaining('voyageurs de confiance'), findsOneWidget);

      await tester.tap(find.byKey(const Key('hub-intro-dismiss')));
      await tester.pump();

      expect(find.textContaining('voyageurs de confiance'), findsNothing);
      verify(() => box.put(HiveService.kHubIntroDismissed, true)).called(1);
    });

    testWidgets('absente une fois fermée', (tester) async {
      introDismissed(value: true);

      await _pump(tester);

      expect(find.textContaining('voyageurs de confiance'), findsNothing);
    });

    testWidgets(
      'la carte tutoriel apparaît après l\'introduction et navigue au tap',
      (tester) async {
        introDismissed(value: false);

        await _pump(tester, helpConfigJson: _activitiesHelpConfigJson);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        final introTop = tester
            .getTopLeft(find.textContaining('voyageurs de confiance'))
            .dy;
        final cardTop = tester
            .getTopLeft(find.text('Besoin d\'aide ? Voir le tutoriel'))
            .dy;
        expect(cardTop, greaterThan(introTop));

        await tester.ensureVisible(
          find.text('Besoin d\'aide ? Voir le tutoriel'),
        );
        await tester.tap(find.text('Besoin d\'aide ? Voir le tutoriel'));
        await tester.pumpAndSettle();

        expect(find.text('TutorialStub:activities_intro'), findsOneWidget);
      },
    );

    testWidgets(
      'la carte tutoriel reste présente même quand l\'introduction est fermée',
      (tester) async {
        introDismissed(value: true);

        await _pump(tester, helpConfigJson: _activitiesHelpConfigJson);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsOneWidget);
      },
    );
  });

  group('complétion des outils', () {
    testWidgets('carte partielle + badges cohérents avec les compteurs', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tools-completion-card')), findsOneWidget);
      expect(find.text('Publiez en 3 taps'), findsOneWidget);
      expect(find.text('2 adresses'), findsOneWidget);
      expect(find.text('1 modèle'), findsOneWidget);
      expect(find.text('Configurée'), findsOneWidget);
      expect(find.text('À configurer'), findsNWidgets(2));
      // Historique et Aide n'ont rien à remplir : 5 badges, pas 7.
      expect(find.byType(ToolStatusBadge), findsNWidgets(5));
    });

    testWidgets('échec réseau : ni carte ni badge, tuiles intactes', (
      tester,
    ) async {
      await _pump(tester, toolsCompletionFails: true);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tools-completion-card')), findsNothing);
      expect(find.byKey(const Key('tools-completion-complete')), findsNothing);
      expect(find.byType(ToolStatusBadge), findsNothing);
      expect(find.text('Mes alertes'), findsOneWidget);
    });

    testWidgets('5 / 5 : bandeau compact, badges tous verts', (tester) async {
      await _pump(
        tester,
        toolsCompletion: const ToolsCompletionModel(
          tools: [
            ToolStatus(key: ToolKey.addresses, count: 1),
            ToolStatus(key: ToolKey.recipients, count: 4),
            ToolStatus(key: ToolKey.alerts, count: 2),
            ToolStatus(key: ToolKey.tripTemplates, count: 1),
            ToolStatus(key: ToolKey.priceGrid, count: 3),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tools-completion-complete')),
        findsOneWidget,
      );
      expect(find.text('4 destinataires'), findsOneWidget);
      expect(find.text('À configurer'), findsNothing);
    });

    testWidgets('à 360 px la pastille prend toute la largeur de la tuile', (
      tester,
    ) async {
      await _pump(
        tester,
        physicalSize: const Size(360, 1800),
        // Les compteurs qui donnent les libellés les plus longs de chaque
        // outil : c'est le pire cas de largeur.
        toolsCompletion: const ToolsCompletionModel(
          tools: [
            ToolStatus(key: ToolKey.addresses, count: 2),
            ToolStatus(key: ToolKey.recipients, count: 4),
            ToolStatus(key: ToolKey.alerts, count: 0),
            ToolStatus(key: ToolKey.tripTemplates, count: 1),
            ToolStatus(key: ToolKey.priceGrid, count: 3),
          ],
        ),
      );
      await tester.pumpAndSettle();

      for (final t in const [
        '2 adresses',
        '4 destinataires',
        'À configurer',
        '1 modèle',
        'Configurée',
      ]) {
        final badge = find
            .ancestor(
              of: find.text(t),
              matching: find.byKey(const Key('tool-status-badge')),
            )
            .first;
        final card = find
            .ancestor(of: find.text(t), matching: find.byType(DonyCard))
            .first;
        final icon = find
            .descendant(of: card, matching: find.byType(DonyIconContainer))
            .first;

        // La pastille est sous la pastille d'icône, alignée à gauche sur elle,
        // et non plus à sa droite sur la même ligne.
        expect(
          tester.getTopLeft(badge).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(icon).dy),
          reason: t,
        );
        expect(
          tester.getTopLeft(badge).dx,
          closeTo(tester.getTopLeft(icon).dx, 0.5),
          reason: t,
        );

        // Elle reçoit donc toute la largeur intérieure de la carte. Sur la
        // ligne de l'icône, il ne lui restait que cette largeur moins la
        // pastille d'icône (32 px) et son gap, soit une cinquantaine de
        // pixels pour le libellé : « 4 destinataires » s'y coupait.
        final resteAncienLayout =
            tester.getSize(card).width -
            2 * DonySpacing.base -
            32 -
            DonySpacing.sm;
        expect(
          tester.getSize(badge).width,
          greaterThan(resteAncienLayout),
          reason: t,
        );
      }

      // Sous flutter_test, la police par défaut dessine chaque glyphe dans un
      // carré d'un cadratin, environ deux fois plus large que Plus Jakarta
      // Sans : à 360 px les chips de période débordent de leur Row, ce qui
      // n'arrive pas avec la vraie police (leurs trois libellés tiennent en
      // ~250 px sur 320). On consomme ce débordement, étranger aux pastilles.
      tester.takeException();
    });

    testWidgets('le CTA ouvre le premier outil manquant puis recharge', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      clearInteractions(_toolsRepoUnderTest);

      await tester.ensureVisible(find.byKey(const Key('tools-completion-cta')));
      await tester.tap(find.byKey(const Key('tools-completion-cta')));
      await tester.pumpAndSettle();
      expect(visited, ['/profile/recipients']);

      final analytics = getIt<AnalyticsService>();
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.activitesHubToolsCtaTapped,
          properties: {'tool': 'recipients'},
        ),
      ).called(1);

      // Retour : la carte doit refléter ce qui vient d'être ajouté.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      verify(() => _toolsRepoUnderTest.getToolsCompletion()).called(1);
    });

    testWidgets('une tuile-outil recharge aussi au retour', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      clearInteractions(_toolsRepoUnderTest);

      await tester.ensureVisible(find.text('Mes adresses'));
      await tester.tap(find.text('Mes adresses'));
      await tester.pumpAndSettle();
      expect(visited, ['/profile/addresses']);

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      verify(() => _toolsRepoUnderTest.getToolsCompletion()).called(1);
    });

    testWidgets('le pull-to-refresh recharge la complétion', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      clearInteractions(_toolsRepoUnderTest);

      // Amplitude > 25 % de la hauteur de la vue (450 px ici) : en deçà, le
      // RefreshIndicator ne s'arme pas.
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 800),
        1000,
      );
      await tester.pumpAndSettle();

      verify(() => _toolsRepoUnderTest.getToolsCompletion()).called(1);
    });
  });
}
