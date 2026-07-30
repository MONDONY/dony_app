import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/faq_bloc.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/screens/faq_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/mock_analytics_backend.dart';

const _emptyConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
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

Widget _wrap({
  String configJson = _emptyConfigJson,
  AnalyticsService? analytics,
  MockAnalyticsBackend? backend,
  TextScaler textScaler = TextScaler.noScaling,
  bool failRefresh = false,
}) {
  final effectiveAnalytics =
      analytics ?? makeDisabledAnalytics(backend ?? MockAnalyticsBackend());
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => FaqBloc(effectiveAnalytics)),
      BlocProvider(
        create: (_) => HelpCenterBloc(
          HelpCenterRepository(
            _StaticHelpCenterSource(configJson, failRefresh: failRefresh),
            fallbackJsonLoader: () async => _emptyConfigJson,
          ),
          effectiveAnalytics,
        )..add(const HelpCenterLoadRequested()),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const FaqScreen()),
          GoRoute(
            path: '/profile/help/contact',
            builder: (_, _) => const Scaffold(body: Text('SupportContactStub')),
          ),
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
  tearDown(() => setDonyReimbursementCap(kDonyReimbursementCapDefault));

  testWidgets('renders title and all section headers', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('FAQ & aide'), findsOneWidget);
    expect(find.text('Compte & identité'), findsOneWidget);
    expect(find.text('Annonces & demandes'), findsOneWidget);
    expect(find.text('Paiements & remboursements'), findsOneWidget);
    expect(find.text('Suivi & livraison'), findsOneWidget);
    expect(find.text('Sécurité & données'), findsOneWidget);
  });

  testWidgets('first section questions are visible as collapsed items', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Pourquoi la vérification d\'identité est-elle obligatoire ?'),
      findsOneWidget,
    );
  });

  testWidgets('tapping on a question expands its answer', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    final question = find.text(
      'Pourquoi la vérification d\'identité est-elle obligatoire ?',
    );
    expect(question, findsOneWidget);

    await tester.tap(question);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('lutter contre la fraude'), findsOneWidget);
  });

  testWidgets('subtitle is rendered', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Recherche une réponse ou parcours les catégories.'),
      findsOneWidget,
    );
  });

  testWidgets('rebuilds a visible reimbursement answer when the cap changes', (
    tester,
  ) async {
    setDonyReimbursementCap(50);
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    final question = find.text('Que se passe-t-il si mon colis est perdu ?');
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('jusqu\'à 50 €'), findsOneWidget);

    setDonyReimbursementCap(75);
    await tester.pump();

    expect(find.textContaining('jusqu\'à 75 €'), findsOneWidget);
    expect(find.textContaining('jusqu\'à 50 €'), findsNothing);
  });

  testWidgets('filters questions and answers from the search field', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      find.byKey(const Key('faq-search-field')),
      'remboursement',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Comment se passe le remboursement en cas d\'annulation ?'),
      findsOneWidget,
    );
    expect(
      find.text('Pourquoi la vérification d\'identité est-elle obligatoire ?'),
      findsNothing,
    );
  });

  testWidgets(
    'search ignores accents and restores all categories when cleared',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(const Duration(milliseconds: 600));

      final searchField = find.byKey(const Key('faq-search-field'));
      await tester.enterText(searchField, 'identite');
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Pourquoi la vérification d\'identité est-elle obligatoire ?',
        ),
        findsOneWidget,
      );
      expect(find.text('Paiements & remboursements'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(find.text('Compte & identité'), findsOneWidget);
      expect(find.text('Paiements & remboursements'), findsOneWidget);
      expect(find.text('Sécurité & données'), findsOneWidget);
    },
  );

  testWidgets('shows an empty state for a search without result', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      find.byKey(const Key('faq-search-field')),
      'question inexistante xyz',
    );
    await tester.pump();

    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(
      find.text('Essaie avec d\'autres mots-clés ou contacte notre équipe.'),
      findsOneWidget,
    );
  });

  testWidgets('opens support from the contact card', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    final contact = find.text('Contacter le support');
    await tester.ensureVisible(contact);
    await tester.tap(contact);
    await tester.pumpAndSettle();

    expect(find.text('SupportContactStub'), findsOneWidget);
  });

  testWidgets(
    'ne montre jamais tutoriels ni communauté (déplacés vers Réseaux sociaux et tutoriels)',
    (tester) async {
      await tester.pumpWidget(_wrap(configJson: _hubConfigJson));
      await tester.pumpAndSettle();

      expect(find.text('Trouver une réponse'), findsOneWidget);
      expect(find.text('Tutoriels vidéo'), findsNothing);
      expect(find.text('Rejoindre la communauté'), findsNothing);
    },
  );

  testWidgets('reste sans overflow avec un facteur de texte 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

final class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json, {this.failRefresh = false});

  final String json;
  final bool failRefresh;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => failRefresh ? null : json;
}
