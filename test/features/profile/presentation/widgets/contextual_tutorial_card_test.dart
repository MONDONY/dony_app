import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class _MockHiveService extends Mock implements HiveService {}

class _MockBox extends Mock implements Box {}

const _emptyConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _negotiationConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "negotiation_basics",
      "title": "Négocier un prix",
      "description": "Comprendre les offres et contre-offres.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["negotiation"]
    },
    {
      "id": "payment_basics",
      "title": "Payer en sécurité",
      "description": "Le paiement séquestré Yadony.",
      "youtubeVideoId": "M7lc1UVf-VE",
      "order": 2,
      "active": true,
      "contexts": ["payment"]
    }
  ]
}
''';

Widget _wrap({
  required TutorialContext context,
  String configJson = _emptyConfigJson,
  MockAnalyticsBackend? backend,
  AnalyticsService? analytics,
}) {
  final effectiveBackend = backend ?? MockAnalyticsBackend();
  final effectiveAnalytics =
      analytics ?? makeEnabledAnalytics(effectiveBackend);

  return BlocProvider(
    create: (_) => HelpCenterBloc(
      HelpCenterRepository(
        _StaticHelpCenterSource(configJson),
        fallbackJsonLoader: () async => _emptyConfigJson,
      ),
      effectiveAnalytics,
    )..add(const HelpCenterLoadRequested()),
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(body: ContextualTutorialCard(context: context)),
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

/// Deux pompes réelles : la première laisse le BLoC charger puis
/// rafraîchir la config (Loading -> Success), la seconde laisse le timer
/// interne de flutter_animate (Future.delayed créé au montage de la carte)
/// s'exécuter avant toute assertion ou interaction.
Future<void> _settleCard(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('renders nothing when no active tutorial matches the context', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(context: TutorialContext.negotiation));
    await _settleCard(tester);

    expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsNothing);
    expect(find.byType(ContextualTutorialCard), findsOneWidget);
  });

  testWidgets(
    'renders nothing when the config only has a tutorial for another context',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          context: TutorialContext.tripPublish,
          configJson: _negotiationConfigJson,
        ),
      );
      await _settleCard(tester);

      expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsNothing);
    },
  );

  testWidgets(
    'renders the card with the expected title when a tutorial matches',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          context: TutorialContext.negotiation,
          configJson: _negotiationConfigJson,
        ),
      );
      await _settleCard(tester);

      expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsOneWidget);
    },
  );

  testWidgets('exposes a touch target of at least 44x44', (tester) async {
    await tester.pumpWidget(
      _wrap(
        context: TutorialContext.negotiation,
        configJson: _negotiationConfigJson,
      ),
    );
    await _settleCard(tester);

    final size = tester.getSize(
      find.text('Besoin d\'aide ? Voir le tutoriel').hitTestable().first,
    );
    // La cible tactile complète est celle de la carte, pas seulement du texte.
    final cardSize = tester.getSize(find.byType(ContextualTutorialCard));
    expect(cardSize.height, greaterThanOrEqualTo(44));
    expect(cardSize.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThan(0));
  });

  testWidgets('navigates to the matched tutorial id on tap', (tester) async {
    await tester.pumpWidget(
      _wrap(
        context: TutorialContext.negotiation,
        configJson: _negotiationConfigJson,
      ),
    );
    await _settleCard(tester);

    await tester.tap(find.text('Besoin d\'aide ? Voir le tutoriel'));
    await tester.pumpAndSettle();

    expect(find.text('TutorialStub:negotiation_basics'), findsOneWidget);
  });

  testWidgets('dispatches the analytics event with the contextual source', (
    tester,
  ) async {
    final backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    await tester.pumpWidget(
      _wrap(
        context: TutorialContext.negotiation,
        configJson: _negotiationConfigJson,
        backend: backend,
        analytics: analytics,
      ),
    );
    await _settleCard(tester);

    await tester.tap(find.text('Besoin d\'aide ? Voir le tutoriel'));
    await tester.pumpAndSettle();

    verify(
      () => backend.capture(AnalyticsEvents.helpTutorialOpened, {
        'tutorial_id': 'negotiation_basics',
        'source': 'negotiation',
      }),
    ).called(1);
  });

  group('fermeture de la carte', () {
    testWidgets(
      'le X la masque sans naviguer, même sans HiveService enregistré',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            context: TutorialContext.negotiation,
            configJson: _negotiationConfigJson,
          ),
        );
        await _settleCard(tester);

        await tester.tap(
          find.byKey(const Key('contextual-tutorial-card-dismiss')),
        );
        await tester.pump();

        expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsNothing);
        expect(find.text('TutorialStub:negotiation_basics'), findsNothing);
      },
    );

    group('avec HiveService', () {
      late _MockHiveService hive;
      late _MockBox box;

      setUp(() {
        box = _MockBox();
        when(() => box.put(any<String>(), any<bool>())).thenAnswer(
          (_) async {},
        );
        when(
          () => box.get(
            '${HiveService.kContextualTutorialDismissedPrefix}negotiation_basics',
            defaultValue: any<Object?>(named: 'defaultValue'),
          ),
        ).thenReturn(false);
        hive = _MockHiveService();
        when(() => hive.userPrefs).thenReturn(box);
        getIt.registerLazySingleton<HiveService>(() => hive);
      });

      tearDown(() => getIt.reset());

      testWidgets('le X persiste la fermeture dans Hive', (tester) async {
        await tester.pumpWidget(
          _wrap(
            context: TutorialContext.negotiation,
            configJson: _negotiationConfigJson,
          ),
        );
        await _settleCard(tester);

        await tester.tap(
          find.byKey(const Key('contextual-tutorial-card-dismiss')),
        );
        await tester.pump();

        expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsNothing);
        verify(
          () => box.put(
            '${HiveService.kContextualTutorialDismissedPrefix}negotiation_basics',
            true,
          ),
        ).called(1);
      });

      testWidgets('ouvrir le tutoriel (tap sur la carte) ne la ferme pas', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            context: TutorialContext.negotiation,
            configJson: _negotiationConfigJson,
          ),
        );
        await _settleCard(tester);

        await tester.tap(find.text('Besoin d\'aide ? Voir le tutoriel'));
        await tester.pumpAndSettle();

        expect(find.text('TutorialStub:negotiation_basics'), findsOneWidget);
        verifyNever(
          () => box.put(
            '${HiveService.kContextualTutorialDismissedPrefix}negotiation_basics',
            true,
          ),
        );
      });

      testWidgets('reste masquée si déjà fermée précédemment (Hive)', (
        tester,
      ) async {
        when(
          () => box.get(
            '${HiveService.kContextualTutorialDismissedPrefix}negotiation_basics',
            defaultValue: any<Object?>(named: 'defaultValue'),
          ),
        ).thenReturn(true);

        await tester.pumpWidget(
          _wrap(
            context: TutorialContext.negotiation,
            configJson: _negotiationConfigJson,
          ),
        );
        await _settleCard(tester);

        expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsNothing);
      });
    });
  });
}

final class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}
