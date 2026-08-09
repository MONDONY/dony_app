import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/home/presentation/widgets/evergreen_guidance_carousel.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

const _emptyHelpConfigJson = '''
{"schemaVersion": 1, "socialLinks": [], "tutorials": []}
''';

const _searchHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "search_intro",
      "title": "Découvrir la recherche",
      "description": "Trouver un voyageur ou un colis compatible.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["search"]
    }
  ]
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);
  final String json;

  // HelpCenterRepository.load() lit `activatedJson` de façon synchrone avant
  // même d'appeler fetchAndActivate() (refresh) : les deux doivent renvoyer
  // le même fixture pour que le premier HelpCenterSuccess émis porte déjà le
  // tutoriel attendu par les tests.
  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

BlocProvider<HelpCenterBloc> _helpCenterProvider({
  String helpConfigJson = _emptyHelpConfigJson,
}) => BlocProvider<HelpCenterBloc>(
  create: (_) => HelpCenterBloc(
    HelpCenterRepository(
      _StaticHelpCenterSource(helpConfigJson),
      fallbackJsonLoader: () async => _emptyHelpConfigJson,
    ),
    makeDisabledAnalytics(MockAnalyticsBackend()),
  )..add(const HelpCenterLoadRequested()),
);

class MockAnalyticsService extends Mock implements AnalyticsService {}

Widget _wrap({
  required MockHiveService hive,
  bool isKycVerified = true,
  bool hasPublishedTrip = true,
  bool hasPublishedParcel = true,
  bool hasActiveCorridorAlert = true,
  bool tutorialDismissed = true,
  String helpConfigJson = _emptyHelpConfigJson,
  bool disableAnimations = false,
}) {
  final box = MockBox();
  when(() => hive.userPrefs).thenReturn(box);
  when(
    () => box.get(HiveService.kHasPublishedAsTraveler, defaultValue: false),
  ).thenReturn(hasPublishedTrip);
  when(
    () => box.get(HiveService.kHasPublishedAsSender, defaultValue: false),
  ).thenReturn(hasPublishedParcel);
  when(
    () => box.get(HiveService.kHasActiveCorridorAlert, defaultValue: false),
  ).thenReturn(hasActiveCorridorAlert);
  // Id fixe du seul tutoriel du fixture _searchHelpConfigJson ("search_intro") :
  // clé littérale, pas de matcher générique (évite le mélange matcher/valeur
  // brute que mocktail refuse sur un même appel).
  when(
    () => box.get(
      '${HiveService.kContextualTutorialDismissedPrefix}search_intro',
      defaultValue: false,
    ),
  ).thenReturn(tutorialDismissed);
  when(
    () => hive.listenUserPrefs(keys: any(named: 'keys')),
  ).thenReturn(ValueNotifier<Box>(box));

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, __) => Scaffold(
          body: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: EvergreenGuidanceCarousel(
              hiveService: hive,
              isKycVerified: isKycVerified,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/trips/publish-intro',
        builder: (_, __) => const Scaffold(body: Text('publish-intro-trip')),
      ),
      GoRoute(
        path: '/parcels/send-intro',
        builder: (_, __) => const Scaffold(body: Text('send-intro-parcel')),
      ),
      GoRoute(
        path: '/corridor-alerts',
        builder: (_, __) => const Scaffold(body: Text('corridor-alerts')),
      ),
      GoRoute(
        path: '/kyc/verify',
        builder: (_, __) => const Scaffold(body: Text('kyc-verify')),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [_helpCenterProvider(helpConfigJson: helpConfigJson)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    getIt.registerSingleton<AnalyticsService>(MockAnalyticsService());
    when(
      () => getIt<AnalyticsService>().logEvent(
        any(),
        properties: any(named: 'properties'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDownAll(() => getIt.reset());

  late MockHiveService hive;
  setUp(() => hive = MockHiveService());

  testWidgets('disparaît quand toutes les actions sont déjà faites', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(hive: hive));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evergreen-guidance-carousel')), findsNothing);
  });

  testWidgets('affiche la slide trajet si pas encore publié', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedTrip: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-trip')), findsOneWidget);
    expect(find.text('Publier mon trajet'), findsOneWidget);
  });

  testWidgets('masque la slide trajet si déjà publié', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedTrip: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-trip')), findsNothing);
  });

  testWidgets('affiche la slide colis si pas encore envoyé', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedParcel: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-parcel')), findsOneWidget);
  });

  testWidgets('affiche la slide alerte si aucune alerte active', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(hive: hive, hasActiveCorridorAlert: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-alert')), findsOneWidget);
  });

  testWidgets('affiche la slide KYC si pas vérifié', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, isKycVerified: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-kyc')), findsOneWidget);
  });

  testWidgets('masque la slide KYC si déjà vérifié', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, isKycVerified: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-kyc')), findsNothing);
  });

  testWidgets(
    'affiche la slide tuto si un tutoriel search existe et non fermé',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          hive: hive,
          helpConfigJson: _searchHelpConfigJson,
          tutorialDismissed: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guidance-slide-tutorial')), findsOneWidget);
    },
  );

  testWidgets('masque la slide tuto si déjà fermée via la croix historique', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        hive: hive,
        helpConfigJson: _searchHelpConfigJson,
        tutorialDismissed: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-tutorial')), findsNothing);
  });

  testWidgets('tap CTA trajet pousse /trips/publish-intro et logue l\'event', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedTrip: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guidance-slide-trip')));
    await tester.pumpAndSettle();
    expect(find.text('publish-intro-trip'), findsOneWidget);
    verify(
      () => getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeGuidanceCarouselCtaTapped,
        properties: {'slide': 'trip'},
      ),
    ).called(1);
  });

  testWidgets('tap CTA colis pousse /parcels/send-intro et logue l\'event', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedParcel: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guidance-slide-parcel')));
    await tester.pumpAndSettle();
    expect(find.text('send-intro-parcel'), findsOneWidget);
    verify(
      () => getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeGuidanceCarouselCtaTapped,
        properties: {'slide': 'parcel'},
      ),
    ).called(1);
  });

  testWidgets('tap CTA alerte pousse /corridor-alerts et logue l\'event', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(hive: hive, hasActiveCorridorAlert: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guidance-slide-alert')));
    await tester.pumpAndSettle();
    expect(find.text('corridor-alerts'), findsOneWidget);
    verify(
      () => getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeGuidanceCarouselCtaTapped,
        properties: {'slide': 'alert'},
      ),
    ).called(1);
  });

  testWidgets('tap CTA identité pousse /kyc/verify et logue l\'event', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(hive: hive, isKycVerified: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guidance-slide-kyc')));
    await tester.pumpAndSettle();
    expect(find.text('kyc-verify'), findsOneWidget);
    verify(
      () => getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeGuidanceCarouselCtaTapped,
        properties: {'slide': 'kyc'},
      ),
    ).called(1);
  });

  testWidgets(
    'autoplay actif (2 slides) : avance automatiquement après l\'intervalle',
    (tester) async {
      // disableAnimations reste à false (défaut) : contrairement au test
      // « ne tourne pas automatiquement », ici le minuteur doit se déclencher
      // et faire avancer le PageView vers la slide suivante.
      await tester.pumpWidget(
        _wrap(hive: hive, hasPublishedTrip: false, hasPublishedParcel: false),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DonyStepIndicator>(find.byType(DonyStepIndicator))
            .current,
        0,
      );

      // Dépasse l'intervalle d'autoplay (4 s) puis laisse l'animation de
      // page (DonyDuration.page = 480 ms) se terminer.
      await tester.pump(EvergreenGuidanceCarousel.autoplayInterval);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DonyStepIndicator>(find.byType(DonyStepIndicator))
            .current,
        1,
      );
    },
  );

  testWidgets('une seule slide visible : pas de dots affichés', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedTrip: false));
    await tester.pumpAndSettle();
    // trip est la seule slide visible (tout le reste "déjà fait" par défaut) :
    // la Row de dots n'est construite que si slides.length > 1.
    expect(find.byKey(const Key('guidance-slide-trip')), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets(
    'disableAnimations : le carousel ne tourne pas automatiquement après l\'intervalle',
    (tester) async {
      // 2 slides visibles (trip + parcel) pour que l'autoplay ait un intérêt à
      // avancer, MediaQuery.disableAnimations à true (réglage d'accessibilité
      // « réduire les animations » ou test) doit empêcher toute rotation.
      await tester.pumpWidget(
        _wrap(
          hive: hive,
          hasPublishedTrip: false,
          hasPublishedParcel: false,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DonyStepIndicator>(find.byType(DonyStepIndicator))
            .current,
        0,
      );

      // Dépasse l'intervalle d'autoplay (4 s) sans laisser tester.pump déclencher
      // pumpAndSettle, pour observer l'absence de rotation programmée.
      await tester.pump(const Duration(seconds: 5));

      expect(
        tester
            .widget<DonyStepIndicator>(find.byType(DonyStepIndicator))
            .current,
        0,
      );
    },
  );
}
