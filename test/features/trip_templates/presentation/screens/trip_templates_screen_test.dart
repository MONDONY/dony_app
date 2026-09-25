import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class MockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

const _hubConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "tuto_modeles_trajet",
      "title": "Créer un modèle de trajet",
      "description": "Publier tes trajets récurrents en quelques secondes.",
      "youtubeVideoId": "JGwWNGJdvx8",
      "order": 1,
      "active": true,
      "contexts": ["tripTemplates"]
    }
  ]
}
''';

const _emptyConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
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

Widget _wrap(TripTemplateBloc bloc, {String configJson = _emptyConfigJson}) =>
    BlocProvider<HelpCenterBloc>(
      create: (_) => HelpCenterBloc(
        HelpCenterRepository(
          _StaticHelpCenterSource(configJson),
          fallbackJsonLoader: () async => _emptyConfigJson,
        ),
        makeDisabledAnalytics(MockAnalyticsBackend()),
      )..add(const HelpCenterLoadRequested()),
      child: BlocProvider<TripTemplateBloc>.value(
        value: bloc,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const TripTemplatesScreen(),
              ),
              GoRoute(
                path: '/trip-templates/edit',
                builder: (_, _) => const Scaffold(body: Text('Edit')),
              ),
            ],
          ),
        ),
      ),
    );

void main() {
  late MockTripTemplateBloc bloc;

  setUp(() {
    bloc = MockTripTemplateBloc();
    when(() => bloc.state).thenReturn(const TripTemplateState());
  });

  testWidgets('affiche la carte tutoriel quand le catalogue en propose un', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TripTemplateState(status: TripTemplateStatus.success));
    await tester.pumpWidget(_wrap(bloc, configJson: _hubConfigJson));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ContextualTutorialCard), findsOneWidget);
    expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsOneWidget);
  });

  testWidgets('pas de carte tutoriel sans tutoriel actif pour ce contexte', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TripTemplateState(status: TripTemplateStatus.success));
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ContextualTutorialCard), findsOneWidget);
    expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsNothing);
  });

  testWidgets('empty state s\'affiche toujours à côté de la carte tutoriel', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TripTemplateState(status: TripTemplateStatus.success));
    await tester.pumpWidget(_wrap(bloc, configJson: _hubConfigJson));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Aucun modèle'), findsOneWidget);
  });

  testWidgets('erreur : bouton Réessayer, jamais le message brut '
      '(ErrorPresenter résout un texte générique depuis l\'AppException)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const TripTemplateState(
        status: TripTemplateStatus.error,
        error: NetworkException('detail technique brut'),
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Réessayer'), findsOneWidget);
    expect(
      find.text('Une erreur est survenue. Vérifie ta connexion et réessaie.'),
      findsOneWidget,
    );
    expect(find.text('detail technique brut'), findsNothing);
  });

  testWidgets('anglais : titre et état vide traduits', (tester) async {
    useEnglish();
    when(
      () => bloc.state,
    ).thenReturn(const TripTemplateState(status: TripTemplateStatus.success));
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('My trip templates'), findsOneWidget);
    expect(find.text('No templates'), findsOneWidget);
  });

  testWidgets(
    'en anglais : erreur réseau affiche le texte du catalogue, jamais le '
    'message brut',
    (tester) async {
      useEnglish();
      when(() => bloc.state).thenReturn(
        const TripTemplateState(
          status: TripTemplateStatus.error,
          error: NetworkException('raw technical detail'),
        ),
      );
      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Something went wrong. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('raw technical detail'), findsNothing);
    },
  );
}
