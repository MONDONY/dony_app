// Tests de TripTemplateEditScreen — étapes Trajet, Lieux & capacité, Prix &
// conditions, et payload complet.
//
// La section "CE QUE J'ACCEPTE" (étape 2) utilise le combobox partagé
// ContentCategorySelector (même composant que la création de trajet et le
// wizard colis) : catalogue déroulant issu du repository, tags supprimables,
// saisie libre par la ligne « Ajouter ». La clé du champ est celle posée par
// PrixStep (`keyPrefix: 'accepted-content'`), pas une clé propre à
// l'écran modèle.

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/transport_mode_row.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_fields.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_step.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
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

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';
import '../../../../helpers/mock_recent_city_store.dart';

class _MockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

class _MockCityRepository extends Mock implements CityRepository {}

class _MockPriceGridRepository extends Mock implements PriceGridRepository {}

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _MockMobileMoneyAccountBloc
    extends MockBloc<MobileMoneyAccountEvent, MobileMoneyAccountState>
    implements MobileMoneyAccountBloc {}

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
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<TripTemplateBloc>.value(value: bloc),
            BlocProvider<AnnouncementFormBloc>(
              create: (_) => getIt<AnnouncementFormBloc>(),
            ),
            BlocProvider<MobileMoneyAccountBloc>(
              create: (_) =>
                  getIt<MobileMoneyAccountBloc>()
                    ..add(const MobileMoneyAccountsRequested()),
            ),
            // `.value` obligatoire : StripeAccountBloc est un lazySingleton
            // GetIt partagé par toute l'app (cf. create_trip_screen.dart).
            BlocProvider<StripeAccountBloc>.value(
              value: getIt<StripeAccountBloc>(),
            ),
          ],
          child: child,
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
}

void main() {
  late _MockTripTemplateBloc bloc;

  setUpAll(() {
    registerCityFallbackValues();
    // Fallback requis par `verify(() => bloc.add(captureAny()))` du test de
    // payload (mocktail a besoin d'une instance factice de TripTemplateEvent).
    registerFallbackValue(const TripTemplateLoaded());
  });

  /// Enregistrements GetIt nécessaires au montage des étapes Lieux & capacité
  /// et Prix & conditions — mêmes blocs que la route `/trip-templates/edit`
  /// (cf. `test/features/matching/presentation/screens/create_trip_screen_test.dart`
  /// L400-450) : `AnnouncementFormBloc` est le vrai bloc (les étapes lisent
  /// et écrivent directement dedans), les autres sont mockés.
  void registerFormBlocs() {
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    getIt.registerSingleton<AnalyticsService>(analytics);

    getIt.registerSingleton<PriceGridRepository>(_MockPriceGridRepository());

    getIt.registerFactory<AnnouncementFormBloc>(
      () => AnnouncementFormBloc(
        priceGridRepository: getIt<PriceGridRepository>(),
        analytics: getIt<AnalyticsService>(),
      ),
    );

    getIt.registerFactory<StripeAccountBloc>(() {
      final b = _MockStripeAccountBloc();
      when(() => b.state).thenReturn(
        const StripeAccountReady(
          ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        ),
      );
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    });

    getIt.registerFactory<MobileMoneyAccountBloc>(() {
      final b = _MockMobileMoneyAccountBloc();
      // Compte inactif par défaut : mobileMoneyAccountActiveFrom(...) → false.
      when(() => b.state).thenReturn(const MobileMoneyAccountInitial());
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    });
  }

  void unregisterFormBlocs() {
    if (getIt.isRegistered<AnnouncementFormBloc>()) {
      getIt.unregister<AnnouncementFormBloc>();
    }
    if (getIt.isRegistered<StripeAccountBloc>()) {
      getIt.unregister<StripeAccountBloc>();
    }
    if (getIt.isRegistered<MobileMoneyAccountBloc>()) {
      getIt.unregister<MobileMoneyAccountBloc>();
    }
    if (getIt.isRegistered<PriceGridRepository>()) {
      getIt.unregister<PriceGridRepository>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  }

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
    registerFormBlocs();
  });

  tearDown(() {
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    unregisterFakeRecentCityStore();
    unregisterFormBlocs();
  });

  /// Amène le formulaire à l'étape [step] : nom + villes renseignés à
  /// l'étape 0, "Continuer" tapé [step] fois. Seul helper de navigation du
  /// fichier (constat #12) — `goToStep(tester, 2)` remplace l'ancien
  /// `goToStep2`.
  Future<void> goToStep(WidgetTester tester, int step) async {
    await tester.enterText(find.byType(DonyTextField).first, 'Abidjan-Paris');
    final fields =
        (tester.state<State<TripTemplateEditScreen>>(
                      find.byType(TripTemplateEditScreen),
                    )
                    as dynamic)
                .fieldsForTest
            as TripFormFields;
    fields.departureCity.value = 'Abidjan';
    fields.arrivalCity.value = 'Paris';
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < step; i++) {
      await tester.tap(find.widgetWithText(DonyButton, 'Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  group('prix et contenu (étape 2)', () {
    const field = Key('accepted-content-field');

    testWidgets('chips CFA quand la devise du modèle est XOF', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await goToStep(tester, 2);
      final fields =
          (tester.state<State<TripTemplateEditScreen>>(
                        find.byType(TripTemplateEditScreen),
                      )
                      as dynamic)
                  .fieldsForTest
              as TripFormFields;
      fields.currency.value = SupportedCurrency.xof;
      // En XOF la carte est indisponible : les espèces passent ON d'office
      // (post-frame) et leur encart animé entre. Plusieurs passes pour que
      // le Timer de flutter_animate se termine avant la fin du test.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(
        find.text(CurrencyFormatter.format(1000, SupportedCurrency.xof)),
        findsOneWidget,
      );
      expect(
        find.text(CurrencyFormatter.format(3000, SupportedCurrency.xof)),
        findsOneWidget,
      );
      expect(
        find.text(CurrencyFormatter.format(5, SupportedCurrency.xof)),
        findsNothing,
      );
    });

    testWidgets(
      'le combo affiche le catalogue fourni par le repository (pas une liste '
      'figée)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
        await tester.pump(const Duration(milliseconds: 600));

        await goToStep(tester, 2);
        await tester.ensureVisible(find.byKey(field));
        await tester.tap(find.byKey(field));
        await tester.pumpAndSettle();

        for (final category in fallbackCatalog) {
          expect(
            find.byKey(Key('accepted-content-item-${category.label}')),
            findsOneWidget,
            reason: 'Item "${category.label}" doit être proposé',
          );
        }
      },
    );

    testWidgets('choisir un item ajoute un tag et referme la liste', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await goToStep(tester, 2);
      await tester.ensureVisible(find.byKey(field));
      await tester.tap(find.byKey(field));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('accepted-content-item-Livres')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accepted-content-item-Livres')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('accepted-content-tag-Livres')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('accepted-content-dropdown')), findsNothing);
    });

    testWidgets('saisie libre ajoute une catégorie custom', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await goToStep(tester, 2);
      await tester.ensureVisible(find.byKey(field));
      await tester.tap(find.byKey(field));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(field), 'Poissons');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accepted-content-item-add')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('accepted-content-tag-Poissons')),
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
      // Les étapes du modèle regroupent lieux + capacité et prix +
      // conditions : l'en-tête garde ses libellés d'origine.
      for (final label in ['Trajet', 'Lieux & capacité', 'Prix & conditions']) {
        expect(
          find.descendant(
            of: find.byType(CaStepperHeader),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
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

    testWidgets('le mode de transport n\'est plus proposé', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('TRANSPORT'), findsNothing);
      for (final mode in TransportMode.values) {
        expect(find.byIcon(mode.icon), findsNothing, reason: mode.name);
      }
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
          arrivalDayOffset: 1,
        );
        await tester.pumpWidget(
          _wrap(const TripTemplateEditScreen(template: template), bloc),
        );
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Modifier le modèle'), findsOneWidget);
        expect(find.text('Abidjan-Paris'), findsOneWidget);
        expect(find.text('Abidjan'), findsOneWidget);
        // _TimeRow affiche désormais « Départ · 22:00 » / « Arrivée · 06:30 »
        // (le libellé reste visible une fois l'heure posée, constat #6).
        expect(find.textContaining('22:00'), findsOneWidget);
        expect(find.textContaining('06:30'), findsOneWidget);
        final fields =
            (tester.state<State<TripTemplateEditScreen>>(
                          find.byType(TripTemplateEditScreen),
                        )
                        as dynamic)
                    .fieldsForTest
                as TripFormFields;
        expect(fields.transportMode.value, TransportMode.car);
        expect(fields.currency.value, SupportedCurrency.xof);
        // Vol de nuit mémorisé : le jour d'arrivée n'est pas écrasé par le
        // préremplissage des heures (FLUTTER-4E).
        expect(find.byKey(const Key('arrival-day-chips')), findsOneWidget);
        expect(
          (tester.state<State<TripTemplateEditScreen>>(
                    find.byType(TripTemplateEditScreen),
                  )
                  as dynamic)
              .arrivalDayOffsetForTest,
          1,
        );
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
          tester.widget<CaStepperHeader>(find.byType(CaStepperHeader)).current,
          TripFormStep.capacite,
        );

        // Flèche visible de l'AppBar, pas le geste système (PopScope).
        await tester.tap(find.byType(DonyAppBarBackButton));
        // `pumpAndSettle` plutôt qu'un `pump` fixe : le retour à l'étape 0
        // rejoue le `.animate().fadeIn()` de `DonyTextField` (NOM DU
        // MODÈLE), dont le timer de démarrage doit se vider avant la fin du
        // test (sinon `A Timer is still pending` à la clôture du widget).
        await tester.pumpAndSettle();

        expect(
          tester.widget<CaStepperHeader>(find.byType(CaStepperHeader)).current,
          TripFormStep.trajet,
        );
        // Toujours sur l'écran du modèle : la flèche a reculé d'une étape,
        // elle n'a pas fait sortir de l'écran (pas de pop du routeur).
        expect(find.byType(TripTemplateEditScreen), findsOneWidget);
        expect(find.text('Continuer'), findsOneWidget);
      },
    );
  });

  group('étapes Lieux et Prix, payload', () {
    testWidgets(
      'étape 1 : LieuxCapaciteStep sans adresse obligatoire, Continuer actif',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
        await tester.pump(const Duration(milliseconds: 600));

        await goToStep(tester, 1);
        await tester.pumpAndSettle();

        expect(find.byType(LieuxCapaciteStep), findsOneWidget);
        final button = tester.widget<DonyButton>(
          find.widgetWithText(DonyButton, 'Continuer'),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'étape 1 : le lieu de remise choisi s\'affiche aussitôt dans le champ',
      (tester) async {
        // Bug remonté en recette : l'adresse partait dans le payload mais le
        // champ restait vide, faute de rebuild de l'étape.
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
        await tester.pump(const Duration(milliseconds: 600));

        await goToStep(tester, 1);
        await tester.pumpAndSettle();
        expect(find.text('Cocody'), findsNothing);

        final fields =
            (tester.state<State<TripTemplateEditScreen>>(
                          find.byType(TripTemplateEditScreen),
                        )
                        as dynamic)
                    .fieldsForTest
                as TripFormFields;
        fields.pickupAddress.value = const AddressData(
          label: 'Cocody',
          lat: 5.35,
          lng: -3.99,
        );
        fields.deliveryAddress.value = const AddressData(
          label: 'Gare de Lyon',
          lat: 48.84,
          lng: 2.37,
        );
        await tester.pumpAndSettle();

        expect(find.text('Cocody'), findsOneWidget);
        expect(find.text('Gare de Lyon'), findsOneWidget);
      },
    );

    testWidgets('étape 2 : PrixStep et bandeau devise, chips CFA en XOF', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await goToStep(tester, 2);
      final fields =
          (tester.state<State<TripTemplateEditScreen>>(
                        find.byType(TripTemplateEditScreen),
                      )
                      as dynamic)
                  .fieldsForTest
              as TripFormFields;
      fields.currency.value = SupportedCurrency.xof;
      // En XOF la carte est indisponible : les espèces passent ON d'office
      // (post-frame) et leur encart animé entre. Plusieurs passes pour que
      // le Timer de flutter_animate se termine avant la fin du test.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(find.byType(PrixStep), findsOneWidget);
      expect(
        find.byKey(const Key('trip-currency-selector-row')),
        findsOneWidget,
      );
      expect(
        find.text(CurrencyFormatter.format(1000, SupportedCurrency.xof)),
        findsOneWidget,
      );
      expect(find.text('Enregistrer le modèle'), findsOneWidget);
    });

    testWidgets('enregistrement : le payload contient tout le formulaire', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await goToStep(tester, 2);
      final fields =
          (tester.state<State<TripTemplateEditScreen>>(
                        find.byType(TripTemplateEditScreen),
                      )
                      as dynamic)
                  .fieldsForTest
              as TripFormFields;
      fields.currency.value = SupportedCurrency.xof;
      fields.selectPrice(1500);
      fields.cashEnabled.value = true;
      fields.negotiable.value = true;
      fields.refusedTypes.value = {'Hi-fi'};
      fields.descriptionCtrl.text = 'Pas de liquide';
      fields.pickupAddress.value = const AddressData(
        label: 'Cocody',
        lat: 5.35,
        lng: -3.99,
      );
      fields.departureTime.value = const TimeOfDay(hour: 22, minute: 0);
      // Arrivée plus tôt que le départ : vol de nuit, lendemain proposé.
      fields.arrivalTime.value = const TimeOfDay(hour: 6, minute: 30);
      // Capacité par défaut du bloc (SUITCASE_23KG, 23 kg) explicitement
      // posée : sans dispatch, `_fields.availableKg` ne serait jamais
      // synchronisé par le `BlocListener` (constat #1) et resterait au
      // défaut local de `TripFormFields` (15), qui ne correspond à rien de
      // métier — figer cette valeur cacherait le bug plutôt que de le
      // couvrir.
      BlocProvider.of<AnnouncementFormBloc>(
        tester.element(find.byType(PrixStep)),
      ).add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
      // `pumpAndSettle` plutôt qu'un `pump` fixe : le changement de devise
      // remonte `PrixStep` (ValueListenableBuilder), qui rejoue les
      // `.animate().fadeIn()` de l'étape — leurs timers de démarrage doivent
      // se vider avant la fin du test (même piège que le retour à l'étape 0,
      // cf. le test « flèche retour » du groupe étape Trajet).
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(DonyButton, 'Enregistrer le modèle'),
      );
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<TripTemplateCreated>().single;
      final data = captured.data;
      expect(data['label'], 'Abidjan-Paris');
      expect(data['currency'], 'XOF');
      expect(data['pricingMode'], 'KG');
      expect(data['pricePerKg'], 1500);
      expect(data['acceptedPaymentMethods'], ['CASH']); // pas de carte en XOF
      expect(data['cashAccepted'], isTrue);
      expect(data['negotiable'], isTrue);
      expect(data['refusedTypes'], ['Hi-fi']);
      expect(data['description'], 'Pas de liquide');
      expect(data['pickupAddress'], {
        'label': 'Cocody',
        'lat': 5.35,
        'lng': -3.99,
      });
      expect(data['deliveryAddress'], isNull);
      expect(data['departureTime'], '22:00');
      expect(data['handoverLeadDays'], isNull);
      expect(data['arrivalTime'], '06:30');
      expect(data['arrivalDayOffset'], 1);
      expect(data['capacityUnit'], 'SUITCASE_23KG');
      expect(data['availableKg'], 23);
      // Plus de sélecteur : le modèle part en avion, valeur exigée par l'API.
      expect(data['transportMode'], 'PLANE');
    });

    testWidgets(
      'nouveau modèle sans toucher la capacité : une valise de 23 kg dans '
      'le payload, pas 15 kg (YADONY-FLUTTER-PROD-18)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
        await tester.pump(const Duration(milliseconds: 600));
        final fields =
            (tester.state<State<TripTemplateEditScreen>>(
                          find.byType(TripTemplateEditScreen),
                        )
                        as dynamic)
                    .fieldsForTest
                as TripFormFields;
        expect(fields.availableKg.value, 23);
        fields.selectPrice(6.0);

        await goToStep(tester, 2);
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(DonyButton, 'Enregistrer le modèle'),
        );
        await tester.pump();

        final captured = verify(
          () => bloc.add(captureAny()),
        ).captured.whereType<TripTemplateCreated>().single;
        expect(captured.data['capacityUnit'], 'SUITCASE_23KG');
        expect(captured.data['availableKg'], 23);
      },
    );

    testWidgets(
      'changer la capacité à l\'étape 1 atteint le payload (constat #1 — '
      'CapacityControl écrivait dans le bloc sans jamais être relu)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
        await tester.pump(const Duration(milliseconds: 600));
        // Un prix doit être choisi pour que « Enregistrer le modèle » soit
        // actif à l'étape 2 (sinon le tap final ne fait rien et le test
        // échoue sur « No matching calls »).
        final fields =
            (tester.state<State<TripTemplateEditScreen>>(
                          find.byType(TripTemplateEditScreen),
                        )
                        as dynamic)
                    .fieldsForTest
                as TripFormFields;
        fields.selectPrice(6.0);

        await goToStep(tester, 1);
        await tester.pumpAndSettle();

        // Chip « 1 valise 32 kg » de `CapacityControl`.
        await tester.ensureVisible(find.text('1 valise 32 kg'));
        await tester.tap(find.text('1 valise 32 kg'));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.widgetWithText(DonyButton, 'Continuer'));
        await tester.pump(const Duration(milliseconds: 600));

        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(DonyButton, 'Enregistrer le modèle'),
        );
        await tester.pump();

        final captured = verify(
          () => bloc.add(captureAny()),
        ).captured.whereType<TripTemplateCreated>().single;
        expect(captured.data['capacityUnit'], 'SUITCASE_32KG');
        expect(captured.data['availableKg'], 32);
      },
    );

    testWidgets(
      'édition : prix hors chips sélectionne Autre prix, paiement et note '
      'préremplis',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        const template = TripTemplate(
          id: 't1',
          label: 'Paris-Dakar',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          transportMode: 'PLANE',
          capacityUnit: 'KG_FREE',
          availableKg: 10,
          pricePerKg: 9.5,
          acceptedCategories: ['Vêtements & tissus'],
          currency: 'EUR',
          acceptedPaymentMethods: ['STRIPE', 'CASH'],
          negotiable: true,
          description: 'Note',
        );
        await tester.pumpWidget(
          _wrap(const TripTemplateEditScreen(template: template), bloc),
        );
        await tester.pump(const Duration(milliseconds: 600));

        final fields =
            (tester.state<State<TripTemplateEditScreen>>(
                          find.byType(TripTemplateEditScreen),
                        )
                        as dynamic)
                    .fieldsForTest
                as TripFormFields;
        expect(fields.isCustomPrice, isTrue);
        expect(fields.customPrice.value, 9.5);
        expect(fields.cashEnabled.value, isTrue);
        expect(fields.negotiable.value, isTrue);
        expect(fields.descriptionCtrl.text, 'Note');
        expect(fields.availableKg.value, 10);
      },
    );

    testWidgets(
      'édition valise 32 kg / 64 kg : la capacité du modèle prime sur le '
      'maxKg de l\'unité, sans boucle de synchronisation',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        // Cas qui faisait tourner la suite indéfiniment : `_prefill` émet
        // `CapacityUnitChanged(SUITCASE_32KG)` (le bloc pose 32) puis
        // `AvailableKgChanged(64)`. Sans la garde d'écho de
        // `_syncKgToFormBloc`, les deux valeurs se renvoyaient l'une l'autre
        // en microtâches : le processus de test saturait un cœur sans que
        // `--timeout` puisse l'interrompre (aucun timer ne s'exécute).
        const template = TripTemplate(
          id: 't1',
          label: 'Abidjan-Paris',
          departureCity: 'Abidjan',
          arrivalCity: 'Paris',
          transportMode: 'PLANE',
          capacityUnit: 'SUITCASE_32KG',
          availableKg: 64,
          pricePerKg: 6,
          acceptedCategories: ['Vêtements & tissus'],
          currency: 'EUR',
        );
        await tester.pumpWidget(
          _wrap(const TripTemplateEditScreen(template: template), bloc),
        );
        // `pump` bornés : si la synchronisation reboucle, ce test pend ici.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        final fields =
            (tester.state<State<TripTemplateEditScreen>>(
                          find.byType(TripTemplateEditScreen),
                        )
                        as dynamic)
                    .fieldsForTest
                as TripFormFields;
        final formState = BlocProvider.of<AnnouncementFormBloc>(
          tester.element(find.byType(TripTemplateEditScreen)),
        ).state;
        expect(fields.availableKg.value, 64);
        expect(formState.availableKg, 64);
        expect(formState.capacityUnit, CapacityUnit.suitcase32kg);
      },
    );

    testWidgets('prix libre à 0 désactive Enregistrer le modèle (constat #5)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await goToStep(tester, 2);
      final fields =
          (tester.state<State<TripTemplateEditScreen>>(
                        find.byType(TripTemplateEditScreen),
                      )
                      as dynamic)
                  .fieldsForTest
              as TripFormFields;

      await tester.ensureVisible(find.text('Autre prix'));
      await tester.tap(find.text('Autre prix'));
      await tester.pump(const Duration(milliseconds: 300));

      final priceField = find.byWidgetPredicate(
        (w) => w is DonyTextField && w.controller == fields.customPriceCtrl,
      );
      await tester.ensureVisible(priceField);
      await tester.enterText(priceField, '0');
      await tester.pump(const Duration(milliseconds: 300));

      final button = tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, 'Enregistrer le modèle'),
      );
      expect(button.onPressed, isNull);
    });

    // FLUTTER-GK : plancher de 1 €/kg converti dans la devise du modèle.
    testWidgets('prix libre sous le plancher désactive Enregistrer le modèle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await goToStep(tester, 2);
      final fields =
          (tester.state<State<TripTemplateEditScreen>>(
                        find.byType(TripTemplateEditScreen),
                      )
                      as dynamic)
                  .fieldsForTest
              as TripFormFields;

      await tester.ensureVisible(find.text('Autre prix'));
      await tester.tap(find.text('Autre prix'));
      await tester.pump(const Duration(milliseconds: 300));

      final priceField = find.byWidgetPredicate(
        (w) => w is DonyTextField && w.controller == fields.customPriceCtrl,
      );
      await tester.ensureVisible(priceField);
      DonyButton save() => tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, 'Enregistrer le modèle'),
      );

      await tester.enterText(priceField, '0,99');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Prix trop bas : minimum'), findsOneWidget);
      expect(save().onPressed, isNull);

      await tester.enterText(priceField, '1');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Prix trop bas'), findsNothing);
      expect(save().onPressed, isNotNull);
    });
  });

  group('anglais', () {
    testWidgets('titre de création et bouton Continuer traduits', (
      tester,
    ) async {
      useEnglish();
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('New template'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets(
      'erreur réseau affiche le texte du catalogue, jamais le message brut',
      (tester) async {
        useEnglish();
        whenListen<TripTemplateState>(
          bloc,
          Stream.value(
            const TripTemplateState(
              status: TripTemplateStatus.error,
              error: NetworkException('raw technical detail'),
            ),
          ),
          initialState: const TripTemplateState(),
        );

        await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Something went wrong. Check your connection and try again.',
          ),
          findsOneWidget,
        );
        expect(find.text('raw technical detail'), findsNothing);
      },
    );
  });
  group('mode de transport du modèle', () {
    tearDown(resetTransportModesForTest);

    TripFormFields fieldsOf(WidgetTester tester) =>
        (tester.state<State<TripTemplateEditScreen>>(
                      find.byType(TripTemplateEditScreen),
                    )
                    as dynamic)
                .fieldsForTest
            as TripFormFields;

    const boatTemplate = TripTemplate(
      id: 't9',
      label: 'Dakar-Marseille',
      departureCity: 'Dakar',
      arrivalCity: 'Marseille',
      transportMode: 'BOAT',
      capacityUnit: 'SUITCASE_23KG',
      availableKg: 23,
      pricePerKg: 2000,
      acceptedCategories: [],
      currency: 'XOF',
    );

    testWidgets('modèle bateau rouvert : reste bateau, puce Bateau montrée', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(const TripTemplateEditScreen(template: boatTemplate), bloc),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(fieldsOf(tester).transportMode.value, TransportMode.boat);
      expect(find.byType(TransportModeRow), findsOneWidget);
      expect(find.byKey(const Key('mode-chip-boat')), findsOneWidget);
    });

    testWidgets('modèle bateau enregistré : le mode part tel quel', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(const TripTemplateEditScreen(template: boatTemplate), bloc),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await goToStep(tester, 2);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DonyButton, 'Enregistrer le modèle'),
      );
      await tester.pump();

      final updated = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<TripTemplateUpdated>().single;
      expect(updated.id, 't9');
      expect(updated.data['transportMode'], 'BOAT');
    });

    testWidgets('mode illisible : la valeur d\'origine est renvoyée', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const odd = TripTemplate(
        id: 't8',
        label: 'Ancien',
        departureCity: 'Dakar',
        arrivalCity: 'Marseille',
        transportMode: 'HOVERCRAFT',
        capacityUnit: 'SUITCASE_23KG',
        availableKg: 23,
        pricePerKg: 2000,
        acceptedCategories: [],
        currency: 'XOF',
      );
      await tester.pumpWidget(
        _wrap(const TripTemplateEditScreen(template: odd), bloc),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await goToStep(tester, 2);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DonyButton, 'Enregistrer le modèle'),
      );
      await tester.pump();

      final updated = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<TripTemplateUpdated>().single;
      expect(updated.data['transportMode'], 'HOVERCRAFT');
    });

    testWidgets('nouveau modèle, avion seul : aucune ligne de modes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TransportModeRow), findsNothing);
      expect(fieldsOf(tester).transportMode.value, TransportMode.plane);
    });

    testWidgets('nouveau modèle, route et bateau ouverts : jamais le bateau '
        '(refusé par le back, C16)', (tester) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: true),
      );
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byKey(const Key('mode-chip-plane')), findsOneWidget);
      expect(find.byKey(const Key('mode-chip-car')), findsOneWidget);
      expect(find.byKey(const Key('mode-chip-boat')), findsNothing);
    });

    testWidgets('nouveau modèle, route ouverte : choix du mode en tête', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TransportModeRow), findsOneWidget);
      expect(find.byKey(const Key('mode-chip-plane')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mode-chip-car')));
      await tester.pump();
      expect(fieldsOf(tester).transportMode.value, TransportMode.car);
    });
  });

  group('modèle en route (lot 2)', () {
    tearDown(resetTransportModesForTest);

    TripFormFields fieldsOf(WidgetTester tester) =>
        (tester.state<State<TripTemplateEditScreen>>(
                      find.byType(TripTemplateEditScreen),
                    )
                    as dynamic)
                .fieldsForTest
            as TripFormFields;

    int offsetOf(WidgetTester tester) =>
        (tester.state<State<TripTemplateEditScreen>>(
                      find.byType(TripTemplateEditScreen),
                    )
                    as dynamic)
                .arrivalDayOffsetForTest
            as int;

    TripTemplate roadTemplate({
      int arrivalDayOffset = 10,
      ItemSize? maxItemSize = ItemSize.l,
      double? maxParcelWeightKg = 50,
      int availableKg = 1200,
    }) => TripTemplate(
      id: 'r1',
      label: 'Dakar-Bamako',
      departureCity: 'Dakar',
      arrivalCity: 'Bamako',
      transportMode: 'CAR',
      capacityUnit: 'KG_EXACT',
      availableKg: availableKg,
      pricePerKg: 2000,
      acceptedCategories: const [],
      currency: 'XOF',
      arrivalDayOffset: arrivalDayOffset,
      maxItemSize: maxItemSize,
      maxParcelWeightKg: maxParcelWeightKg,
    );

    Future<void> open(WidgetTester tester, TripTemplate? template) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(TripTemplateEditScreen(template: template), bloc),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<Map<String, dynamic>> saveFrom(
      WidgetTester tester, {
      required int fromStep,
    }) async {
      for (var i = fromStep; i < 2; i++) {
        await tester.tap(find.widgetWithText(DonyButton, 'Continuer'));
        await tester.pump(const Duration(milliseconds: 600));
      }
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DonyButton, 'Enregistrer le modèle'),
      );
      await tester.pump();
      final events = verify(() => bloc.add(captureAny())).captured;
      final updated = events.whereType<TripTemplateUpdated>();
      if (updated.isNotEmpty) return updated.single.data;
      return events.whereType<TripTemplateCreated>().single.data;
    }

    testWidgets('modèle route : arrivée J+10 enregistrée avec '
        'arrivalDayOffset 10', (tester) async {
      await open(tester, roadTemplate());

      // Pas d'heure d'arrivée en route (C28), puces jusqu'à J+14 visibles.
      expect(find.byKey(const Key('trip-template-arrival-time')), findsNothing);
      expect(find.byKey(const Key('arrival-day-chips')), findsOneWidget);
      expect(find.byKey(const Key('arrival-day-other')), findsOneWidget);
      expect(offsetOf(tester), 10);

      final data = await saveFrom(tester, fromStep: 0);
      expect(data['transportMode'], 'CAR');
      expect(data['arrivalTime'], isNull);
      expect(data['arrivalDayOffset'], 10);
    });

    testWidgets('nouveau modèle route : « Autre date » sans date de départ '
        'choisit Dans N jours (D17)', (tester) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      await open(tester, null);
      await tester.tap(find.byKey(const Key('mode-chip-car')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('arrival-day-other')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arrival-offset-14')), findsOneWidget);
      expect(find.byKey(const Key('arrival-offset-15')), findsNothing);
      await tester.tap(find.byKey(const Key('arrival-offset-10')));
      await tester.pumpAndSettle();
      expect(offsetOf(tester), 10);

      await tester.enterText(find.byType(DonyTextField).first, 'Dakar-Bamako');
      fieldsOf(tester).departureCity.value = 'Dakar';
      fieldsOf(tester).arrivalCity.value = 'Bamako';
      // Nouveau modèle : aucun prix choisi par défaut, exigé pour enregistrer.
      fieldsOf(tester).selectPrice(10);
      await tester.pump(const Duration(milliseconds: 300));

      final data = await saveFrom(tester, fromStep: 0);
      expect(data['transportMode'], 'CAR');
      expect(data['arrivalDayOffset'], 10);
      expect(data['arrivalTime'], isNull);
    });

    testWidgets('modèle avion : puces 0 à 2 seulement, J+3 absent', (
      tester,
    ) async {
      await open(tester, null);
      fieldsOf(tester).arrivalTime.value = const TimeOfDay(hour: 6, minute: 0);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('trip-template-arrival-time')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('arrival-day-2')), findsOneWidget);
      expect(find.byKey(const Key('arrival-day-other')), findsNothing);
    });

    testWidgets('modèle route J+10 repassé en avion : décalage remis à 0', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      // 30 kg : enregistrable en avion (1 200 kg griserait l'étape capacité).
      await open(tester, roadTemplate(availableKg: 30));
      expect(offsetOf(tester), 10);

      await tester.tap(find.byKey(const Key('mode-chip-plane')));
      await tester.pump();

      expect(offsetOf(tester), 0);
      final data = await saveFrom(tester, fromStep: 0);
      expect(data['transportMode'], 'PLANE');
      expect(data['arrivalDayOffset'], 0);
      // Avion : taille et poids max effacés (sentinelles de modification).
      expect(data['maxItemSize'], 'NONE');
      expect(data['maxParcelWeightKg'], 0);
    });

    testWidgets('modèle route : 1 200 kg, taille et poids max envoyés', (
      tester,
    ) async {
      await open(tester, roadTemplate());
      await tester.tap(find.widgetWithText(DonyButton, 'Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Route : pas de valise, kilos saisis, taille et poids max proposés.
      expect(find.byKey(const Key('capacity-road-limits')), findsOneWidget);
      expect(find.byKey(const Key('capacity-kg-field')), findsOneWidget);
      expect(
        tester
            .widget<DonyButton>(find.widgetWithText(DonyButton, 'Continuer'))
            .onPressed,
        isNotNull,
      );

      final data = await saveFrom(tester, fromStep: 1);
      expect(data['capacityUnit'], 'KG_EXACT');
      expect(data['availableKg'], 1200);
      expect(data['maxItemSize'], 'L');
      expect(data['maxParcelWeightKg'], 50);
    });

    testWidgets('modèle route : éditer le nom garde taille et poids max', (
      tester,
    ) async {
      await open(tester, roadTemplate());
      await tester.enterText(find.byType(DonyTextField).first, 'Nouveau nom');
      await tester.pump(const Duration(milliseconds: 300));

      final data = await saveFrom(tester, fromStep: 0);
      expect(data['label'], 'Nouveau nom');
      expect(data['maxItemSize'], 'L');
      expect(data['maxParcelWeightKg'], 50);
      expect(data['availableKg'], 1200);
    });

    testWidgets('modèle route sans taille : enregistrable (C24)', (
      tester,
    ) async {
      await open(
        tester,
        roadTemplate(maxItemSize: null, maxParcelWeightKg: null),
      );
      final data = await saveFrom(tester, fromStep: 0);
      // Modification : « aucune limite » part en sentinelle d'effacement.
      expect(data['maxItemSize'], 'NONE');
      expect(data['maxParcelWeightKg'], 0);
    });

    testWidgets('nouveau modèle route sans taille : rien n\'est envoyé', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      await open(tester, null);
      await tester.tap(find.byKey(const Key('mode-chip-car')));
      await tester.pump();
      await tester.enterText(find.byType(DonyTextField).first, 'Dakar-Bamako');
      fieldsOf(tester).departureCity.value = 'Dakar';
      fieldsOf(tester).arrivalCity.value = 'Bamako';
      // Nouveau modèle : aucun prix choisi par défaut, exigé pour enregistrer.
      fieldsOf(tester).selectPrice(10);
      await tester.pump(const Duration(milliseconds: 300));

      final data = await saveFrom(tester, fromStep: 0);
      expect(data['transportMode'], 'CAR');
      expect(data.containsKey('maxItemSize'), isFalse);
      expect(data.containsKey('maxParcelWeightKg'), isFalse);
    });

    testWidgets('modèle route à 1 200 kg repassé en avion : Continuer grisé à '
        'l\'étape capacité', (tester) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      await open(tester, roadTemplate());
      await tester.tap(find.byKey(const Key('mode-chip-plane')));
      await tester.pump();
      await tester.tap(find.widgetWithText(DonyButton, 'Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('capacity-kg-error')), findsOneWidget);
      expect(
        tester
            .widget<DonyButton>(find.widgetWithText(DonyButton, 'Continuer'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('422 arrival-too-far à l\'enregistrement : message serveur, '
        'formulaire gardé', (tester) async {
      whenListen<TripTemplateState>(
        bloc,
        Stream.value(
          const TripTemplateState(
            status: TripTemplateStatus.error,
            error: ServerException(
              'L\'arrivée ne peut pas dépasser 14 jours après le départ.',
              'arrival-too-far',
            ),
          ),
        ),
        initialState: const TripTemplateState(),
      );
      await open(tester, roadTemplate());
      await tester.pumpAndSettle();

      expect(find.textContaining('14 jours après le départ'), findsOneWidget);
      expect(find.byType(TripTemplateEditScreen), findsOneWidget);
    });
  });
}
