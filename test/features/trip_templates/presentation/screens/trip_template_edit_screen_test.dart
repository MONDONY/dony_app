// Tests de TripTemplateEditScreen — section "CE QUE J'ACCEPTE".
//
// La section utilise le combobox partagé ContentCategorySelector (même
// composant que la création de trajet et le wizard colis) : catalogue
// déroulant issu du repository, tags supprimables, saisie libre par la ligne
// « Ajouter ».

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_fields.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_template_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/currency_test_doubles.dart';
import '../../../../helpers/mock_recent_city_store.dart';

class _MockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

class _MockCityRepository extends Mock implements CityRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

Widget _wrap(Widget child, TripTemplateBloc bloc) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            BlocProvider<TripTemplateBloc>.value(value: bloc, child: child),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
}

void main() {
  late _MockTripTemplateBloc bloc;

  setUpAll(registerCityFallbackValues);

  setUp(() {
    bloc = _MockTripTemplateBloc();
    when(() => bloc.state).thenReturn(const TripTemplateState());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    final cityRepo = _MockCityRepository();
    when(() => cityRepo.searchCities(any())).thenAnswer((_) async => []);
    when(() => cityRepo.getPopularCorridors()).thenAnswer((_) async => []);

    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));

    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    getIt.registerFactory<IContentCategoryRepository>(
      () => _FakeContentCategoryRepository(),
    );

    registerFakeRecentCityStore();
  });

  tearDown(() {
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    unregisterFakeRecentCityStore();
  });

  const field = Key('template-content-field');

  // Prix par kg et « Ce que j'accepte » ne vivent plus à l'étape 0
  // (Tâche 3) : ils rejoignent l'étape 2 « Prix & conditions » à la
  // Tâche 4, qui réécrira ces tests contre `_buildStep2`.
  group('prix et contenu (étape 2, Tâche 4)', skip: 'étape 2, Tâche 4', () {
    testWidgets('devise active XOF : chips 1 000 à 3 000 F CFA', skip: true, (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      registerCurrencyPreference('XOF');

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(formatPriceActive(1000)), findsOneWidget);
      expect(find.text(formatPriceActive(3000)), findsOneWidget);
      expect(find.text(formatPriceActive(5)), findsNothing);
      // Dernier chip sélectionné par défaut : 3 000 F CFA, pas 8 €.
      expect(
        find.textContaining('Vous touchez ${formatPriceActive(3000)}/kg'),
        findsOneWidget,
      );
    });

    testWidgets(
      'le combo affiche le catalogue fourni par le repository (pas une liste '
      'figée)',
      skip: true,
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
        await tester.pump(const Duration(milliseconds: 600));

        await tester.ensureVisible(find.byKey(field));
        await tester.tap(find.byKey(field));
        await tester.pumpAndSettle();

        for (final category in fallbackCatalog) {
          expect(
            find.byKey(Key('template-content-item-${category.label}')),
            findsOneWidget,
            reason: 'Item "${category.label}" doit être proposé',
          );
        }
      },
    );

    testWidgets(
      'choisir un item ajoute un tag et referme la liste',
      skip: true,
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
        await tester.pump(const Duration(milliseconds: 600));

        await tester.ensureVisible(find.byKey(field));
        await tester.tap(find.byKey(field));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('template-content-item-Livres')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('template-content-item-Livres')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('template-content-tag-Livres')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('template-content-dropdown')),
          findsNothing,
        );
      },
    );

    testWidgets('saisie libre ajoute une catégorie custom', skip: true, (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.ensureVisible(find.byKey(field));
      await tester.tap(find.byKey(field));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(field), 'Poissons');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('template-content-item-add')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('template-content-tag-Poissons')),
        findsOneWidget,
      );
    });
  });

  group('étape Trajet', () {
    testWidgets('stepper à 3 étapes, Continuer inactif sans nom ni villes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(CaStepperHeader), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      expect(find.text('Enregistrer le modèle'), findsNothing);
      final button = tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, 'Continuer'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('délai de remise : chips jour même, 1, 2, 3, 7 jours, aucun', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      for (final label in [
        'Aucun',
        'Le jour même',
        '1 jour avant',
        '2 jours avant',
        '3 jours avant',
        '7 jours avant',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.tap(find.text('2 jours avant'));
      await tester.pump(const Duration(milliseconds: 300));
      final state = tester.state<State<TripTemplateEditScreen>>(
        find.byType(TripTemplateEditScreen),
      );
      expect((state as dynamic).handoverLeadDaysForTest, 2);
    });

    testWidgets(
      'édition : préremplit nom, villes, heures, délai et transport',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        const template = TripTemplate(
          id: 't1',
          label: 'Abidjan-Paris',
          departureCity: 'Abidjan',
          arrivalCity: 'Paris',
          transportMode: 'CAR',
          capacityUnit: 'SUITCASE_23KG',
          availableKg: 23,
          pricePerKg: 2000,
          acceptedCategories: [],
          currency: 'XOF',
          departureTime: '22:00',
          arrivalTime: '06:30',
          handoverLeadDays: 1,
        );
        await tester.pumpWidget(
          _wrap(const TripTemplateEditScreen(template: template), bloc),
        );
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Modifier le modèle'), findsOneWidget);
        expect(find.text('Abidjan-Paris'), findsOneWidget);
        expect(find.text('Abidjan'), findsOneWidget);
        expect(find.text('22:00'), findsOneWidget);
        expect(find.text('06:30'), findsOneWidget);
        final fields =
            (tester.state<State<TripTemplateEditScreen>>(
                          find.byType(TripTemplateEditScreen),
                        )
                        as dynamic)
                    .fieldsForTest
                as TripFormFields;
        expect(fields.transportMode.value, TransportMode.car);
        expect(fields.currency.value, SupportedCurrency.xof);
      },
    );

    testWidgets(
      'flèche retour de l\'AppBar recule d\'une étape (pas un pop du routeur)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Étape 0 déjà valide (nom + villes + transport préremplis) pour
        // atteindre l'étape 1 via « Continuer » sans piloter le champ ville.
        const template = TripTemplate(
          id: 't1',
          label: 'Abidjan-Paris',
          departureCity: 'Abidjan',
          arrivalCity: 'Paris',
          transportMode: 'CAR',
          capacityUnit: 'SUITCASE_23KG',
          availableKg: 23,
          pricePerKg: 2000,
          acceptedCategories: [],
        );
        await tester.pumpWidget(
          _wrap(const TripTemplateEditScreen(template: template), bloc),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          tester
              .widget<CaStepperHeader>(find.byType(CaStepperHeader))
              .currentStep,
          1,
        );

        // Flèche visible de l'AppBar, pas le geste système (PopScope).
        await tester.tap(find.byType(DonyAppBarBackButton));
        // `pumpAndSettle` plutôt qu'un `pump` fixe : le retour à l'étape 0
        // rejoue le `.animate().fadeIn()` de `DonyTextField` (NOM DU
        // MODÈLE), dont le timer de démarrage doit se vider avant la fin du
        // test (sinon `A Timer is still pending` à la clôture du widget).
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<CaStepperHeader>(find.byType(CaStepperHeader))
              .currentStep,
          0,
        );
        // Toujours sur l'écran du modèle : la flèche a reculé d'une étape,
        // elle n'a pas fait sortir de l'écran (pas de pop du routeur).
        expect(find.byType(TripTemplateEditScreen), findsOneWidget);
        expect(find.text('Continuer'), findsOneWidget);
      },
    );
  });
}
