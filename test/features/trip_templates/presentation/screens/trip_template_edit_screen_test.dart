// Tests de TripTemplateEditScreen — étapes Trajet, Lieux & capacité, Prix &
// conditions, et payload complet.
//
// La section "CE QUE J'ACCEPTE" (étape 2) utilise le combobox partagé
// ContentCategorySelector (même composant que la création de trajet et le
// wizard colis) : catalogue déroulant issu du repository, tags supprimables,
// saisie libre par la ligne « Ajouter ». La clé du champ est celle posée par
// PrixConditionsStep (`keyPrefix: 'accepted-content'`), pas une clé propre à
// l'écran modèle.

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_fields.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
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

class _MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

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
            BlocProvider<CommissionMethodBloc>(
              create: (_) => getIt<CommissionMethodBloc>(),
            ),
            BlocProvider<MobileMoneyAccountBloc>(
              create: (_) =>
                  getIt<MobileMoneyAccountBloc>()
                    ..add(const MobileMoneyAccountRequested()),
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

    getIt.registerFactory<CommissionMethodBloc>(() {
      final b = _MockCommissionMethodBloc();
      when(() => b.state).thenReturn(CommissionMethodInitial());
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
    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
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

  /// Amène le formulaire à l'étape 2 (Prix & conditions) : nom + villes
  /// renseignés à l'étape 0, "Continuer" tapé deux fois.
  Future<void> goToStep2(WidgetTester tester) async {
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
    for (var i = 0; i < 2; i++) {
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

      await goToStep2(tester);
      final fields =
          (tester.state<State<TripTemplateEditScreen>>(
                        find.byType(TripTemplateEditScreen),
                      )
                      as dynamic)
                  .fieldsForTest
              as TripFormFields;
      fields.currency.value = SupportedCurrency.xof;
      await tester.pump(const Duration(milliseconds: 600));

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

        await goToStep2(tester);
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

      await goToStep2(tester);
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

      await goToStep2(tester);
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

  group('étapes Lieux et Prix, payload', () {
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
      'étape 2 : PrixConditionsStep et bandeau devise, chips CFA en XOF',
      (tester) async {
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
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(PrixConditionsStep), findsOneWidget);
        expect(
          find.byKey(const Key('trip-currency-selector-row')),
          findsOneWidget,
        );
        expect(
          find.text(CurrencyFormatter.format(1000, SupportedCurrency.xof)),
          findsOneWidget,
        );
        expect(find.text('Enregistrer le modèle'), findsOneWidget);
      },
    );

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
      // `pumpAndSettle` plutôt qu'un `pump` fixe : le changement de devise
      // remonte `PrixConditionsStep` (ValueListenableBuilder), qui rejoue les
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
      expect(data['availableKg'], 15);
    });

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
  });
}
