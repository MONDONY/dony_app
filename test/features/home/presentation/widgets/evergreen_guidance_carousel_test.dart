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

// `PageView.builder` ne construit que la page courante (pas de cache large
// par défaut) : un swipe manuel est nécessaire pour atteindre une slide
// au-delà de l'index 0 avant de la chercher/taper.
Future<void> _swipeNext(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('evergreen-guidance-carousel')),
    const Offset(-800, 0),
  );
  await tester.pumpAndSettle();
}

Widget _wrap({
  required MockHiveService hive,
  bool isKycVerified = true,
  bool tutorialDismissed = true,
  String helpConfigJson = _emptyHelpConfigJson,
  bool disableAnimations = false,
  TextScaler? textScaler,
}) {
  final box = MockBox();
  when(() => hive.userPrefs).thenReturn(box);
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
            data: MediaQuery.of(context).copyWith(
              disableAnimations: disableAnimations,
              textScaler: textScaler,
            ),
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

  testWidgets(
    'trajet, colis et alerte restent toujours affichés (actions répétables)',
    (tester) async {
      await tester.pumpWidget(_wrap(hive: hive));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guidance-slide-trip')), findsOneWidget);
      expect(find.text('Publier mon trajet'), findsOneWidget);

      await _swipeNext(tester);
      expect(find.byKey(const Key('guidance-slide-parcel')), findsOneWidget);

      await _swipeNext(tester);
      expect(find.byKey(const Key('guidance-slide-alert')), findsOneWidget);
    },
  );

  testWidgets('affiche la slide KYC si pas vérifié', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, isKycVerified: false));
    await tester.pumpAndSettle();
    // Ordre fixe [trajet, colis, alerte, kyc] : kyc est en 4e position.
    await _swipeNext(tester);
    await _swipeNext(tester);
    await _swipeNext(tester);
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
      // Ordre fixe [trajet, colis, alerte, tuto] (KYC vérifié par défaut,
      // absent de la liste) : tuto est en 4e position.
      await _swipeNext(tester);
      await _swipeNext(tester);
      await _swipeNext(tester);
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
    await tester.pumpWidget(_wrap(hive: hive));
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
    await tester.pumpWidget(_wrap(hive: hive));
    await tester.pumpAndSettle();
    await _swipeNext(tester); // [trajet, colis, ...] : colis en 2e position.
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
    await tester.pumpWidget(_wrap(hive: hive));
    await tester.pumpAndSettle();
    // [trajet, colis, alerte, ...] : alerte en 3e position.
    await _swipeNext(tester);
    await _swipeNext(tester);
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
    // [trajet, colis, alerte, kyc] : kyc en 4e position.
    await _swipeNext(tester);
    await _swipeNext(tester);
    await _swipeNext(tester);
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
      // et faire avancer le PageView vers la slide suivante. Trajet/colis/
      // alerte sont toujours visibles, donc au moins 3 slides par défaut.
      await tester.pumpWidget(_wrap(hive: hive));
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

  testWidgets(
    'disableAnimations : le carousel ne tourne pas automatiquement après l\'intervalle',
    (tester) async {
      // Trajet/colis/alerte toujours visibles (≥ 3 slides par défaut), assez
      // pour que l'autoplay ait un intérêt à avancer. MediaQuery.
      // disableAnimations à true (réglage d'accessibilité « réduire les
      // animations » ou test) doit empêcher toute rotation.
      await tester.pumpWidget(_wrap(hive: hive, disableAnimations: true));
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

  testWidgets(
    'textScaler 2.0 : pas d\'overflow (régression hauteur PageView)',
    (tester) async {
      // Reproduit le bug historique de RenderFlex overflow à forte taille de
      // texte : le titre d'une slide ne doit jamais déborder de la hauteur
      // fixe du PageView.
      await tester.pumpWidget(
        _wrap(hive: hive, textScaler: const TextScaler.linear(2.0)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guidance-slide-trip')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'textScaler 0.85 (mini a11y) : pas d\'overflow ni d\'écrasement de '
    'l\'icône (régression hauteur plancher)',
    (tester) async {
      // 0.85 = kA11yMinTextScale, le minimum exposé dans Réglages ›
      // Accessibilité. En dessous de 1.0, ni le padding de DonyCard ni
      // DonyIconContainerSize.md (40 pt) ne rétrécissent : sans plancher à
      // 72, la hauteur calculée deviendrait plus petite que le contenu
      // incompressible et écraserait l'icône.
      await tester.pumpWidget(
        _wrap(hive: hive, textScaler: const TextScaler.linear(0.85)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guidance-slide-trip')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
