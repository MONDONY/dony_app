import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

const _emptyConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _socialConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [
    {
      "network": "whatsapp",
      "url": "https://community.example/whatsapp",
      "active": true
    },
    {
      "network": "instagram",
      "url": "https://instagram.com/yadony",
      "active": true
    },
    {
      "network": "tiktok",
      "url": "https://tiktok.com/@yadony",
      "active": false
    }
  ],
  "tutorials": []
}
''';

const _hubConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [
    {
      "network": "whatsapp",
      "url": "https://community.example/whatsapp",
      "active": true
    }
  ],
  "tutorials": [
    {
      "id": "payment",
      "title": "Accepter une offre et payer",
      "description": "Sécuriser le règlement dans Yadony.",
      "youtubeVideoId": "M7lc1UVf-VE",
      "order": 2,
      "active": true,
      "contexts": ["payment"]
    },
    {
      "id": "search_intro",
      "title": "Découvrir Yadony",
      "description": "Comprendre la recherche en quelques minutes.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["search"],
      "durationLabel": "2:30"
    }
  ]
}
''';

const _tutorialsOnlyConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "payment",
      "title": "Accepter une offre et payer",
      "description": "Sécuriser le règlement dans Yadony.",
      "youtubeVideoId": "M7lc1UVf-VE",
      "order": 2,
      "active": true,
      "contexts": ["payment"]
    },
    {
      "id": "search_intro",
      "title": "Découvrir Yadony",
      "description": "Comprendre la recherche en quelques minutes.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["search"],
      "durationLabel": "2:30"
    }
  ]
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json, {this.failRefresh = false});

  final String json;
  final bool failRefresh;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => failRefresh ? null : json;
}

SemanticsOwner _semanticsOwner(WidgetTester tester) =>
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!;

Widget _wrap({
  String configJson = _emptyConfigJson,
  AnalyticsService? analytics,
  MockAnalyticsBackend? backend,
  TextScaler textScaler = TextScaler.noScaling,
  bool failRefresh = false,
}) {
  final effectiveAnalytics =
      analytics ?? makeDisabledAnalytics(backend ?? MockAnalyticsBackend());
  return BlocProvider(
    create: (_) => HelpCenterBloc(
      HelpCenterRepository(
        _StaticHelpCenterSource(configJson, failRefresh: failRefresh),
        fallbackJsonLoader: () async => _emptyConfigJson,
      ),
      effectiveAnalytics,
    )..add(const HelpCenterLoadRequested()),
    child: MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const CommunityScreen()),
          GoRoute(
            path: '/profile/help/tutorial/:tutorialId',
            builder: (_, state) => Scaffold(
              body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('affiche le titre', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Réseaux sociaux et tutoriels'), findsOneWidget);
  });

  testWidgets('catalogue vide : affiche un état vide, pas les sections', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('community-empty-state')), findsOneWidget);
    expect(find.text('Tutoriels vidéo'), findsNothing);
    expect(find.text('Rejoindre la communauté'), findsNothing);
  });

  testWidgets(
    'réseaux actifs : affiche uniquement les réseaux actifs, pas l\'état vide',
    (tester) async {
      await tester.pumpWidget(_wrap(configJson: _socialConfigJson));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community-empty-state')), findsNothing);
      expect(find.text('Rejoindre la communauté'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('TikTok'), findsNothing);
    },
  );

  testWidgets('tutoriels seuls : affiche la section, pas les réseaux', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(configJson: _tutorialsOnlyConfigJson));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('community-empty-state')), findsNothing);
    expect(find.text('Tutoriels vidéo'), findsOneWidget);
    expect(find.text('Rejoindre la communauté'), findsNothing);
  });

  testWidgets('ordonne les tutoriels avant les réseaux', (tester) async {
    await tester.pumpWidget(_wrap(configJson: _hubConfigJson));
    await tester.pumpAndSettle();

    final tutorialsTop = tester.getTopLeft(find.text('Tutoriels vidéo')).dy;
    final communityTop = tester
        .getTopLeft(find.text('Rejoindre la communauté'))
        .dy;

    expect(tutorialsTop, lessThan(communityTop));
  });

  testWidgets('affiche les tutoriels selon leur ordre configuré', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(configJson: _hubConfigJson));
    await tester.pumpAndSettle();

    final searchTop = tester.getTopLeft(find.text('Découvrir Yadony')).dy;
    final paymentTop = tester
        .getTopLeft(find.text('Accepter une offre et payer'))
        .dy;

    expect(searchTop, lessThan(paymentTop));
  });

  testWidgets('ouvre le tutoriel et trace son identifiant depuis le hub', (
    tester,
  ) async {
    final backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();

    await tester.pumpWidget(
      _wrap(configJson: _hubConfigJson, analytics: analytics, backend: backend),
    );
    await tester.pumpAndSettle();

    final tutorial = find.text('Découvrir Yadony');
    await tester.ensureVisible(tutorial);
    await tester.tap(tutorial);
    await tester.pumpAndSettle();

    expect(find.text('TutorialStub:search_intro'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.helpTutorialOpened, {
        'tutorial_id': 'search_intro',
        'source': 'help_center',
      }),
    ).called(1);
  });

  testWidgets('active le tutoriel par l’action sémantique une seule fois', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();

    await tester.pumpWidget(
      _wrap(configJson: _hubConfigJson, analytics: analytics, backend: backend),
    );
    await tester.pumpAndSettle();

    final tutorial = find.bySemanticsLabel('Lire le tutoriel Découvrir Yadony');
    await tester.ensureVisible(tutorial);
    await tester.pumpAndSettle();
    final node = tester.getSemantics(tutorial);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    _semanticsOwner(tester).performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();

    expect(find.text('TutorialStub:search_intro'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.helpTutorialOpened, {
        'tutorial_id': 'search_intro',
        'source': 'help_center',
      }),
    ).called(1);
    semantics.dispose();
  });

  testWidgets('affiche la durée avec une taille minimale de 12 px', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(configJson: _hubConfigJson));
    await tester.pumpAndSettle();

    final duration = tester.widget<Text>(find.text('2:30'));
    expect(duration.style?.fontSize, greaterThanOrEqualTo(12));
  });

  testWidgets('fournit un fallback Yadony si la miniature échoue', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(configJson: _hubConfigJson));
    await tester.pumpAndSettle();

    final imageFinder = find.byType(DonyImage).first;
    final image = tester.widget<DonyImage>(imageFinder);
    expect(image.errorWidget, isNotNull);
    final fallback = image.errorWidget!(tester.element(imageFinder));

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: Scaffold(body: fallback)),
    );

    expect(
      find.byKey(const Key('help-tutorial-thumbnail-fallback')),
      findsOneWidget,
    );
  });

  testWidgets('conserve le catalogue dans HelpCenterError après refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(configJson: _hubConfigJson, failRefresh: true),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(CommunityScreen));
    expect(context.read<HelpCenterBloc>().state, isA<HelpCenterError>());
    expect(find.text('Découvrir Yadony'), findsOneWidget);
    expect(find.text('Rejoindre la communauté'), findsOneWidget);
  });

  testWidgets('reste sans overflow avec un facteur de texte 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(configJson: _hubConfigJson, textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
