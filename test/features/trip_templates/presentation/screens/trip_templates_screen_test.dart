import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_templates_screen.dart';
import 'package:dony/l10n/l10n.dart';
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

Widget _wrap(
  TripTemplateBloc bloc, {
  String configJson = _emptyConfigJson,
}) => BlocProvider<HelpCenterBloc>(
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
          GoRoute(path: '/', builder: (_, _) => const TripTemplatesScreen()),
          GoRoute(
            path: '/trip-templates/edit',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  Text(
                    'Edit ${(state.extra as TripTemplate?)?.label ?? 'new'}',
                  ),
                  TextButton(
                    onPressed: () => context.pop(true),
                    child: const Text('save'),
                  ),
                  TextButton(
                    onPressed: () => context.pop(false),
                    child: const Text('discard'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/trip-recurrences/new',
            builder: (_, state) => Scaffold(
              body: Text('Recurrence ${(state.extra! as TripTemplate).label}'),
            ),
          ),
        ],
      ),
    ),
  ),
);

const _paris = TripTemplate(
  id: 'tpl-1',
  label: 'Paris – Dakar mensuel',
  emoji: '✈️',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  transportMode: 'PLANE',
  capacityUnit: 'KG',
  availableKg: 20,
  pricePerKg: 8,
  acceptedCategories: [],
);

const _grid = TripTemplate(
  id: 'tpl-2',
  label: 'Lyon grille',
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  transportMode: 'PLANE',
  capacityUnit: 'KG',
  availableKg: 10,
  pricePerKg: null,
  pricingMode: 'MIXED',
  acceptedCategories: [],
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late MockTripTemplateBloc bloc;
  final fr = lookupAppLocalizations(AppL10n.fr);

  setUpAll(() => registerFallbackValue(const TripTemplateLoaded()));

  setUp(() {
    bloc = MockTripTemplateBloc();
    when(() => bloc.state).thenReturn(const TripTemplateState());
  });

  void withTemplates() => when(() => bloc.state).thenReturn(
    const TripTemplateState(
      status: TripTemplateStatus.success,
      templates: [_paris, _grid],
    ),
  );

  testWidgets('chargement sans modèle : indicateur, ni liste ni état vide', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TripTemplateState(status: TripTemplateStatus.loading));
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump();

    expect(find.text(fr.tripTemplateEmptyTitle), findsNothing);
    expect(find.text(_paris.label), findsNothing);
  });

  testWidgets('liste : libellé, emoji, trajet et prix ou mention de grille', (
    tester,
  ) async {
    withTemplates();
    await tester.pumpWidget(_wrap(bloc));
    await _settle(tester);

    expect(find.text(_paris.label), findsOneWidget);
    expect(find.text('✈️'), findsOneWidget);
    expect(find.textContaining('Paris → Dakar · '), findsOneWidget);
    expect(find.textContaining('/kg'), findsOneWidget);
    expect(
      find.text('Lyon → Abidjan · ${fr.tripTemplateGridPriceLabel}'),
      findsOneWidget,
    );
  });

  testWidgets('erreur avec des modèles déjà chargés : la liste reste', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const TripTemplateState(
        status: TripTemplateStatus.error,
        templates: [_paris],
        error: NetworkException('x'),
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await _settle(tester);

    expect(find.text(_paris.label), findsOneWidget);
    expect(find.text(fr.tripTemplateLoadErrorTitle), findsNothing);
  });

  testWidgets('erreur sans détail : texte de repli, Réessayer recharge', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TripTemplateState(status: TripTemplateStatus.error));
    await tester.pumpWidget(_wrap(bloc));
    await _settle(tester);

    expect(find.text(fr.tripTemplateLoadErrorFallback), findsOneWidget);
    await tester.tap(find.text(fr.commonRetry));
    verify(() => bloc.add(const TripTemplateLoaded())).called(1);
  });

  testWidgets('tap sur une carte : éditeur du modèle, recharge si modifié', (
    tester,
  ) async {
    withTemplates();
    await tester.pumpWidget(_wrap(bloc));
    await _settle(tester);

    await tester.tap(find.text(_paris.label));
    await tester.pumpAndSettle();
    expect(find.text('Edit ${_paris.label}'), findsOneWidget);

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    verify(() => bloc.add(const TripTemplateLoaded())).called(1);
  });

  testWidgets('éditeur fermé sans modification : aucun rechargement', (
    tester,
  ) async {
    withTemplates();
    await tester.pumpWidget(_wrap(bloc));
    await _settle(tester);

    await tester.tap(find.byTooltip(fr.tripTemplateNewLabel));
    await tester.pumpAndSettle();
    expect(find.text('Edit new'), findsOneWidget);

    await tester.tap(find.text('discard'));
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('état vide : « Créer » ouvre un éditeur vierge', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TripTemplateState(status: TripTemplateStatus.success));
    await tester.pumpWidget(_wrap(bloc));
    await _settle(tester);

    await tester.tap(find.text(fr.tripTemplateCreateAction));
    await tester.pumpAndSettle();
    expect(find.text('Edit new'), findsOneWidget);
  });

  group('menu « … » d\'un modèle', () {
    Future<void> openMenu(WidgetTester tester) async {
      // La police de test (Ahem) donne à chaque glyphe la largeur de la
      // taille de police : « Programmer une récurrence » déborderait des
      // 280 px d'un menu contextuel, ce que la police réelle ne fait pas.
      tester.platformDispatcher.textScaleFactorTestValue = 0.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      withTemplates();
      await tester.pumpWidget(_wrap(bloc));
      await _settle(tester);
      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuButton).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Modifier ouvre l\'éditeur du modèle', (tester) async {
      await openMenu(tester);
      await tester.tap(find.text(fr.commonEdit));
      await tester.pumpAndSettle();
      expect(find.text('Edit ${_paris.label}'), findsOneWidget);
    });

    testWidgets('Programmer une récurrence ouvre l\'écran dédié', (
      tester,
    ) async {
      await openMenu(tester);
      await tester.tap(find.text(fr.tripTemplateScheduleRecurrenceAction));
      await tester.pumpAndSettle();
      expect(find.text('Recurrence ${_paris.label}'), findsOneWidget);
    });

    testWidgets('Supprimer confirmé envoie TripTemplateDeleted', (
      tester,
    ) async {
      await openMenu(tester);
      await tester.tap(find.text(fr.commonDelete));
      await tester.pumpAndSettle();

      expect(find.text(fr.tripTemplateDeleteDialogTitle), findsOneWidget);
      expect(
        find.text(fr.tripTemplateDeleteDialogMessage(_paris.label)),
        findsOneWidget,
      );
      await tester.tap(find.text(fr.commonDelete).last);
      await tester.pumpAndSettle();

      final added = verify(() => bloc.add(captureAny())).captured;
      expect((added.single as TripTemplateDeleted).id, _paris.id);
    });

    testWidgets('Supprimer annulé : rien n\'est envoyé', (tester) async {
      await openMenu(tester);
      await tester.tap(find.text(fr.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
    });
  });

  testWidgets('aucune carte tutoriel, même quand le catalogue en propose un', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TripTemplateState(status: TripTemplateStatus.success));
    await tester.pumpWidget(_wrap(bloc, configJson: _hubConfigJson));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsNothing);
  });

  testWidgets('empty state s\'affiche avec un catalogue de tutoriels', (
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
      find.text(
        'Une erreur est survenue. Vérifiez votre connexion et réessayez.',
      ),
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
