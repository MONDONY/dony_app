// Création et modification d'un trajet bateau (lot 3, tâche A2) : carte
// Bateau réservée aux transporteurs vérifiés, ports et arrivée estimée en
// fourchette, volume et prix au m³ (aucun kilo envoyé), versement au dépôt,
// brouillon, erreurs serveur, boutons à 360 dp en français et en anglais.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/recent_city_store.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/trip_legs_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/models/bid_model.dart'
    show BidPaymentMethod;
import 'package:dony/features/matching/data/models/trip_form_draft.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_step.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/currency_test_doubles.dart';
import '../../../helpers/form_draft_test_doubles.dart';
import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_recent_city_store.dart';
import '../../../helpers/plane_icon_expectations.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _MockMobileMoneyAccountBloc
    extends MockBloc<MobileMoneyAccountEvent, MobileMoneyAccountState>
    implements MobileMoneyAccountBloc {}

class _MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockPriceGridRepository extends Mock implements PriceGridRepository {}

class _MockContentCategoryRepository extends Mock
    implements IContentCategoryRepository {}

class _FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

class _FakeCommissionMethodEvent extends Fake
    implements CommissionMethodEvent {}

class _FakeCitySearchEvent extends Fake implements CitySearchEvent {}

_MockStripeAccountBloc _stripeBloc() {
  final b = _MockStripeAccountBloc();
  when(() => b.state).thenReturn(const StripeAccountInitial());
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  when(() => b.isClosed).thenReturn(false);
  return b;
}

/// Voyageur vérifié, statut déclaré : badge GP Pro selon [gpPro].
UserModel _traveler({bool gpPro = true}) => UserModel(
  id: 'user-boat-1',
  roles: const ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  travelerStatus: TravelerStatus.individual,
  gpPro: gpPro,
);

_MockAuthBloc _authBloc(UserModel user) {
  final b = _MockAuthBloc();
  when(() => b.isClosed).thenReturn(false);
  when(() => b.state).thenReturn(AuthAuthenticated(user));
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  return b;
}

_MockKycBloc _kycBloc() {
  final b = _MockKycBloc();
  when(() => b.state).thenReturn(const KycInitial());
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  return b;
}

Widget _app(Widget child, {required UserModel user, required Locale locale}) {
  final router = GoRouter(
    initialLocation: '/trips/create',
    routes: [
      GoRoute(
        path: '/trips/create',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<StripeAccountBloc>.value(value: _stripeBloc()),
            BlocProvider<AuthBloc>.value(value: _authBloc(user)),
            BlocProvider<KycBloc>.value(value: _kycBloc()),
          ],
          child: child,
        ),
      ),
      GoRoute(
        path: '/profile/gp-pro',
        builder: (_, _) => const Scaffold(body: Text('gp-pro-stub')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home-stub')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

DateTime _inDays(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

/// Brouillon bateau complet, repris à [stepId]. [arrivalMax] et
/// [arrivalMin] nuls : arrivée estimée à saisir.
TripFormDraft _boatDraft({
  TripFormStep stepId = TripFormStep.conditions,
  BoatPriceUnit unit = BoatPriceUnit.m3,
  DateTime? arrivalMin,
  DateTime? arrivalMax,
  bool withRange = true,
  double? volume = 12.5,
  double? pricePerM3 = 150,
  int priceOption = -1,
}) {
  final departure = _inDays(30);
  return TripFormDraft(
    stepId: stepId,
    currency: 'EUR',
    departureCity: 'Paris',
    departureCountryCode: 'FR',
    arrivalCity: 'Dakar',
    arrivalCountryCode: 'SN',
    departureDate: departure,
    departureTime: '10:00',
    handoverDeadline: departure.subtract(const Duration(days: 1)),
    transportMode: 'BOAT',
    priceOption: priceOption,
    cashEnabled: true,
    pickupAddress: const AddressData(
      label: 'Entrepôt Gennevilliers',
      lat: 48.93,
      lng: 2.29,
    ),
    deliveryAddress: const AddressData(
      label: 'Port de Dakar',
      lat: 14.67,
      lng: -17.43,
    ),
    arrivalDate: withRange ? (arrivalMin ?? _inDays(50)) : null,
    arrivalDateMax: withRange ? (arrivalMax ?? _inDays(65)) : null,
    volumeM3: volume,
    pricePerM3: pricePerM3,
    boatPriceUnit: unit,
    availableKg: unit == BoatPriceUnit.kg ? 300 : null,
    capacityUnit: unit == BoatPriceUnit.kg ? 'KG_EXACT' : null,
  );
}

void main() {
  late _MockAnnouncementBloc announcementBloc;
  late StreamController<AnnouncementState> states;
  String? intlLocaleBefore;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    registerFallbackValue(_FakeAnnouncementEvent());
    registerFallbackValue(_FakeCommissionMethodEvent());
    registerFallbackValue(_FakeCitySearchEvent());
    registerFallbackValue(const StripeAccountStatusLoaded());
    registerFallbackValue(const MobileMoneyAccountsRequested());

    final analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<AnalyticsService>(analytics);
    getIt.registerSingleton<PriceGridRepository>(_MockPriceGridRepository());
    getIt.registerFactory<TripLegsCubit>(
      () => TripLegsCubit(getIt<AnalyticsService>()),
    );
    getIt.registerFactory<AnnouncementFormBloc>(
      () => AnnouncementFormBloc(
        priceGridRepository: getIt<PriceGridRepository>(),
        analytics: getIt<AnalyticsService>(),
      ),
    );
    final categories = _MockContentCategoryRepository();
    when(() => categories.getCategories()).thenAnswer((_) async => const []);
    getIt.registerSingleton<IContentCategoryRepository>(categories);
    getIt.registerFactory<CommissionMethodBloc>(() {
      final b = _MockCommissionMethodBloc();
      when(() => b.state).thenReturn(CommissionMethodInitial());
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    });
    getIt.registerFactory<CitySearchBloc>(() {
      final b = _MockCitySearchBloc();
      when(() => b.state).thenReturn(const CitySearchInitial());
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    });
    registerCityFallbackValues();
    if (!getIt.isRegistered<RecentCityStore>()) registerFakeRecentCityStore();
    getIt.registerFactory<StripeAccountBloc>(_stripeBloc);
    getIt.registerFactory<MobileMoneyAccountBloc>(() {
      final b = _MockMobileMoneyAccountBloc();
      when(() => b.state).thenReturn(const MobileMoneyAccountInitial());
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    });
  });

  tearDownAll(GetIt.instance.reset);

  setUp(() {
    intlLocaleBefore = Intl.defaultLocale;
    states = StreamController<AnnouncementState>.broadcast();
    announcementBloc = _MockAnnouncementBloc();
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream).thenAnswer((_) => states.stream);
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    if (getIt.isRegistered<FormDraftCubit>()) {
      getIt.unregister<FormDraftCubit>();
    }
    registerTestFormDraftCubit(
      store: testFormDraftStore(storage: InMemoryFormDraftStorage()),
    );
    setTransportModes(const TransportModesAvailability(road: true, boat: true));
    DonySnackbar.clearDedup();
  });

  tearDown(() async {
    Intl.defaultLocale = intlLocaleBefore;
    resetTransportModesForTest();
    await states.close();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    CreateTripArgs? args, {
    UserModel? user,
    Locale locale = AppL10n.fr,
    Size size = const Size(800, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    if (!getIt.isRegistered<HiveService>()) registerCurrencyPreference('EUR');
    await tester.pumpWidget(
      _app(
        CreateTripScreen(args: args),
        user: user ?? _traveler(),
        locale: locale,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  TripFormStep currentStep(WidgetTester tester) =>
      tester.widget<CaStepperHeader>(find.byType(CaStepperHeader)).current;

  DonyButton continueButton(WidgetTester tester) =>
      tester.widget<DonyButton>(find.byKey(const Key('trip-form-continue')));

  Future<void> goToStep(WidgetTester tester, TripFormStep target) async {
    for (var i = 0; i < TripFormStep.values.length; i++) {
      if (currentStep(tester) == target) return;
      await tester.tap(find.byKey(const Key('trip-form-continue')));
      await tester.pump(const Duration(milliseconds: 600));
    }
    fail('étape $target non atteinte');
  }

  Future<void> publish(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('create-announcement-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DonyButton, "Publier l'annonce"));
    await tester.pumpAndSettle();
  }

  AnnouncementCreateRequested sentCreate() => verify(
    () => announcementBloc.add(captureAny()),
  ).captured.whereType<AnnouncementCreateRequested>().single;

  TrajetStep trajet(WidgetTester tester) =>
      tester.widget<TrajetStep>(find.byType(TrajetStep, skipOffstage: false));

  group('étape Mode : carte Bateau', () {
    testWidgets('boatCard_disabledForKycOnly : grisée, non choisie, lien vers '
        'le badge GP Pro', (tester) async {
      await pumpScreen(tester, null, user: _traveler(gpPro: false));

      expect(find.text('Voie maritime'), findsOneWidget);
      expect(find.text('Bateau, groupage en conteneur'), findsOneWidget);
      expect(find.text('Plusieurs semaines'), findsOneWidget);
      expect(find.text('Volume en m³'), findsOneWidget);
      expect(find.text('Réservé aux transporteurs vérifiés'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mode-card-boat')));
      await tester.pump();
      expect(find.byKey(const Key('mode-check-boat')), findsNothing);
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const Key('mode-badge-link-boat')));
      await tester.pumpAndSettle();
      expect(find.text('gp-pro-stub'), findsOneWidget);
    });

    testWidgets('voyageur GP Pro : la carte Bateau se choisit', (tester) async {
      await pumpScreen(tester, null);

      expect(find.text('Réservé aux transporteurs vérifiés'), findsNothing);
      expect(find.byKey(const Key('mode-badge-link-boat')), findsNothing);
      await tester.tap(find.byKey(const Key('mode-card-boat')));
      await tester.pump();
      expect(find.byKey(const Key('mode-check-boat')), findsOneWidget);
      expect(continueButton(tester).onPressed, isNotNull);
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('bateau éteint : aucune carte Bateau', (tester) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      await pumpScreen(tester, null);
      expect(find.byKey(const Key('mode-card-boat')), findsNothing);
    });

    testWidgets(
      'brouillon bateau d\'un voyageur non vérifié : mode à choisir',
      (tester) async {
        await pumpScreen(
          tester,
          CreateTripArgs(resumeDraft: _boatDraft()),
          user: _traveler(gpPro: false),
        );
        expect(currentStep(tester), TripFormStep.mode);
        expect(find.byKey(const Key('mode-check-boat')), findsNothing);
      },
    );
  });

  group('étape Trajet en bateau', () {
    testWidgets('boatTrip_noIataCodes : ports, noms de villes, pas d\'escales '
        'ni d\'avion', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: _boatDraft(stepId: TripFormStep.trajet)),
      );
      expect(currentStep(tester), TripFormStep.trajet);

      // Champs du corridor « connectés » : libellés en capitales.
      expect(
        find.textContaining('PORT DE DÉPART', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining("PORT D'ARRIVÉE", findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('VILLE DE DÉPART', findRichText: true),
        findsNothing,
      );
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.textContaining('CDG'), findsNothing);
      expect(find.textContaining('DSS'), findsNothing);
      // Ni escales, ni heure ni jour d'arrivée : la fourchette.
      expect(find.byKey(const Key('arrival-day-chips')), findsNothing);
      expect(find.byKey(const Key('arrivalTimeField')), findsNothing);
      expect(find.text('Arrivée estimée'), findsOneWidget);
      expect(
        find.text(
          'Les expéditeurs voient une fourchette : les retards au port sont '
          'fréquents.',
        ),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    testWidgets('boatTrip_requiresArrivalRange : deux dates, la seconde après '
        'la première, au plus 120 jours après le départ', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: _boatDraft(
            stepId: TripFormStep.trajet,
            withRange: false,
          ),
        ),
      );
      expect(currentStep(tester), TripFormStep.trajet);
      expect(continueButton(tester).onPressed, isNull);

      final step = trajet(tester);
      step.boatArrivalMinNotifier!.value = _inDays(50);
      await tester.pump();
      expect(continueButton(tester).onPressed, isNull);
      expect(
        find.text("Indiquez l'arrivée au plus tôt et au plus tard"),
        findsOneWidget,
      );

      step.boatArrivalMaxNotifier!.value = _inDays(40);
      await tester.pump();
      expect(continueButton(tester).onPressed, isNull);
      expect(
        find.text(
          "L'arrivée au plus tard ne peut pas précéder l'arrivée au plus tôt",
        ),
        findsOneWidget,
      );

      step.boatArrivalMaxNotifier!.value = _inDays(30 + 121);
      await tester.pump();
      expect(continueButton(tester).onPressed, isNull);
      expect(
        find.text(
          "L'arrivée au plus tard doit tomber dans les 120 jours qui suivent "
          'le départ',
        ),
        findsOneWidget,
      );

      step.boatArrivalMinNotifier!.value = _inDays(20);
      step.boatArrivalMaxNotifier!.value = _inDays(60);
      await tester.pump();
      expect(
        find.text("L'arrivée estimée ne peut pas précéder le départ"),
        findsOneWidget,
      );

      step.boatArrivalMinNotifier!.value = _inDays(45);
      await tester.pump();
      expect(find.byKey(const Key('boat-arrival-error')), findsNothing);
      expect(continueButton(tester).onPressed, isNotNull);
    });
  });

  group('étape Capacité en bateau', () {
    testWidgets('volume au m³ : bornes, entrepôt et retrait, pas de valise', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: _boatDraft(stepId: TripFormStep.capacite, volume: null),
        ),
      );
      expect(currentStep(tester), TripFormStep.capacite);

      expect(find.text('Volume disponible (m³)'), findsOneWidget);
      expect(find.text("Adresse de l'entrepôt"), findsOneWidget);
      expect(find.text('Adresse de retrait'), findsOneWidget);
      expect(find.byKey(const Key('capacity-boat-limits')), findsOneWidget);
      expect(find.byKey(const Key('capacity-road-limits')), findsNothing);
      expect(continueButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('boat-volume-field')), '0');
      await tester.pump();
      expect(
        find.text('Indiquez un volume entre 0,1 et 9 999 m³'),
        findsOneWidget,
      );
      expect(continueButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('boat-volume-field')),
        '12.5',
      );
      await tester.pump();
      expect(find.byKey(const Key('boat-volume-error')), findsNothing);
      expect(continueButton(tester).onPressed, isNotNull);

      // Au kilo : les kilos, jamais de valise en bateau.
      await tester.tap(find.byKey(const Key('boat-unit-kg')));
      await tester.pump();
      expect(find.byKey(const Key('boat-volume-field')), findsNothing);
      expect(find.textContaining('Valise'), findsNothing);
      expectNoPlaneIcon(tester);
    });
  });

  group('étape Prix en bateau', () {
    testWidgets('boatPrix_showsDepositNotice : prix au m³ sans grille, '
        'estimation et versement au dépôt', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: _boatDraft(stepId: TripFormStep.prix, pricePerM3: null),
        ),
      );
      expect(currentStep(tester), TripFormStep.prix);

      expect(
        find.text(
          'Par bateau, vous êtes payé dès que l\'expéditeur dépose son colis '
          'à l\'entrepôt, sans attendre la livraison.',
        ),
        findsOneWidget,
      );
      // Pas de grille de prix en bateau.
      expect(find.text('Articles + kilo'), findsNothing);
      expect(find.text('Prix par m³'), findsWidgets);
      expect(continueButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('trip-price-per-m3')), '150');
      await tester.pump();
      expect(find.textContaining('Vous touchez 150'), findsOneWidget);
      expect(
        find.textContaining('par m³ · l\'expéditeur paie'),
        findsOneWidget,
      );
      expect(continueButton(tester).onPressed, isNotNull);
      expectNoPlaneIcon(tester);
    });

    testWidgets('au kilo : puces de prix au kilo, toujours le versement au '
        'dépôt', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: _boatDraft(
            stepId: TripFormStep.prix,
            unit: BoatPriceUnit.kg,
            priceOption: 0,
          ),
        ),
      );
      expect(currentStep(tester), TripFormStep.prix);
      expect(find.byKey(const Key('boat-deposit-notice')), findsOneWidget);
      expect(find.byKey(const Key('trip-price-per-m3')), findsNothing);
      expect(find.text('Articles + kilo'), findsNothing);
      expect(find.text('Prix par kg'), findsWidgets);
    });
  });

  group('envoi', () {
    testWidgets('boatTrip_payloadHasVolumeAndPricePerM3 : aucun kilo envoyé', (
      tester,
    ) async {
      await pumpScreen(tester, CreateTripArgs(resumeDraft: _boatDraft()));
      expect(currentStep(tester), TripFormStep.conditions);
      // Ni escales ni étapes en bateau.
      expect(find.text('Ajouter une étape'), findsNothing);
      await publish(tester);

      final sent = sentCreate();
      expect(sent.transportMode, TransportMode.boat);
      expect(sent.availableKg, isNull);
      expect(sent.pricePerKg, isNull);
      expect(sent.capacityUnit, isNull);
      expect(sent.pricingMode, 'KG');
      expect(sent.volumeCapacityM3, 12.5);
      expect(sent.pricePerM3, 150);
      expect(sent.arrivalDate, DateFormat('yyyy-MM-dd').format(_inDays(50)));
      expect(sent.arrivalDateMax, DateFormat('yyyy-MM-dd').format(_inDays(65)));
      expect(sent.stops, isNull);

      final json = AnnouncementPayload(
        departureCity: sent.departureCity,
        arrivalCity: sent.arrivalCity,
        departureDate: sent.departureDate,
        arrivalDate: sent.arrivalDate,
        pickupAddress: sent.pickupAddress,
        deliveryAddress: sent.deliveryAddress,
        availableKg: sent.availableKg,
        pricePerKg: sent.pricePerKg,
        transportMode: sent.transportMode,
        arrivalDateMax: sent.arrivalDateMax,
        volumeCapacityM3: sent.volumeCapacityM3,
        pricePerM3: sent.pricePerM3,
        capacityUnit: sent.capacityUnit,
        handoverDeadline: sent.handoverDeadline,
      ).toJson();
      expect(json.containsKey('availableKg'), isFalse);
      expect(json.containsKey('pricePerKg'), isFalse);
      expect(json.containsKey('capacityUnit'), isFalse);
      expect(json['volumeCapacityM3'], 12.5);
      expect(json['pricePerM3'], 150);
      expect(json['transportMode'], 'BOAT');
    });

    testWidgets('aperçu au m³ : volume et prix au m³, aucun kilo', (
      tester,
    ) async {
      await pumpScreen(tester, CreateTripArgs(resumeDraft: _boatDraft()));
      await tester.tap(find.byKey(const Key('create-announcement-preview')));
      await tester.pumpAndSettle();

      expect(find.text('12,5 m³'), findsOneWidget);
      expect(find.textContaining('/m³'), findsOneWidget);
      expect(find.textContaining('/kg'), findsNothing);
      expectNoPlaneIcon(tester);
    });

    testWidgets('au kilo : kilos et prix au kilo, ni volume ni prix au m³', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: _boatDraft(unit: BoatPriceUnit.kg, priceOption: 0),
        ),
      );
      await publish(tester);

      final sent = sentCreate();
      expect(sent.transportMode, TransportMode.boat);
      expect(sent.availableKg, 300);
      expect(sent.pricePerKg, isNotNull);
      expect(sent.capacityUnit, 'KG_EXACT');
      expect(sent.volumeCapacityM3, isNull);
      expect(sent.pricePerM3, isNull);
      expect(sent.arrivalDateMax, isNotNull);
    });

    testWidgets('serverForbidden_keepsForm : 403 bateau réservé, message '
        'affiché, formulaire gardé', (tester) async {
      await pumpScreen(tester, CreateTripArgs(resumeDraft: _boatDraft()));
      await publish(tester);

      states.add(
        AnnouncementError(
          const ForbiddenException('Forbidden', 'boat-carrier-not-verified'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('réservé aux professionnels'), findsOneWidget);
      expect(find.byType(CreateTripScreen), findsOneWidget);
      expect(currentStep(tester), TripFormStep.conditions);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('422 arrivée estimée refusée : message du catalogue, '
        'formulaire gardé', (tester) async {
      await pumpScreen(tester, CreateTripArgs(resumeDraft: _boatDraft()));
      await publish(tester);

      states.add(
        AnnouncementError(
          const ValidationException('raw', code: 'arrival-range-invalid'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.textContaining("Indiquez l'arrivée au plus tôt et au plus tard ;"),
        findsOneWidget,
      );
      expect(find.byType(CreateTripScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('succès : pas d\'offre de trajet récurrent en bateau', (
      tester,
    ) async {
      await pumpScreen(tester, CreateTripArgs(resumeDraft: _boatDraft()));
      await publish(tester);

      states.add(
        AnnouncementCreated(
          AnnouncementModel(
            id: 'boat-1',
            travelerId: 'user-boat-1',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureDate: _inDays(30),
            availableKg: 0,
            totalKg: 0,
            status: 'ACTIVE',
            bidsCount: 0,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            transportMode: TransportMode.boat,
            volumeCapacityM3: 12.5,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trajet publié !'), findsOneWidget);
      expect(find.textContaining('récurrent'), findsNothing);
    });
  });

  group('modification d\'un trajet bateau', () {
    AnnouncementModel boatTrip({double? maxParcelWeightKg = 30}) =>
        AnnouncementModel(
          id: 'boat-edit-1',
          travelerId: 'user-boat-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: _inDays(30),
          departureTime: '10:00',
          arrivalDate: _inDays(50),
          arrivalDateMax: _inDays(65),
          availableKg: 0,
          totalKg: 0,
          status: 'ACTIVE',
          bidsCount: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          handoverDeadline: _inDays(29),
          pickupAddress: const AddressData(
            label: 'Entrepôt',
            lat: 48.93,
            lng: 2.29,
          ),
          deliveryAddress: const AddressData(
            label: 'Port de Dakar',
            lat: 14.67,
            lng: -17.43,
          ),
          transportMode: TransportMode.boat,
          acceptedPaymentMethods: const {BidPaymentMethod.cash},
          capacityUnit: 'KG_EXACT',
          volumeCapacityM3: 20,
          availableVolumeM3: 20,
          pricePerM3: 120,
          maxParcelWeightKg: maxParcelWeightKg,
        );

    testWidgets('PUT au m³ : fourchette, volume, prix au m³, poids max par '
        'colis gardé', (tester) async {
      await pumpScreen(tester, CreateTripArgs(announcement: boatTrip()));
      expect(trajet(tester).boatArrivalMaxNotifier!.value, _inDays(65));

      await goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      final sent = verify(
        () => announcementBloc.add(captureAny()),
      ).captured.whereType<AnnouncementUpdateRequested>().single;
      expect(sent.transportMode, TransportMode.boat);
      expect(sent.availableKg, isNull);
      expect(sent.pricePerKg, isNull);
      expect(sent.volumeCapacityM3, 20);
      expect(sent.pricePerM3, 120);
      expect(sent.arrivalDate, DateFormat('yyyy-MM-dd').format(_inDays(50)));
      expect(sent.arrivalDateMax, DateFormat('yyyy-MM-dd').format(_inDays(65)));
      // Inchangé : absent du corps, jamais effacé par erreur.
      expect(sent.maxParcelWeightKg.isClear, isFalse);
      expect(sent.maxParcelWeightKg.value, isNull);
    });
  });

  group('boutons à 360 dp', () {
    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets('buttons_360dp_fr_en : ${locale.languageCode}', (
        tester,
      ) async {
        if (locale == AppL10n.en) enableEnglish();
        // Carte grisée et son lien, à 360 dp.
        await pumpScreen(
          tester,
          null,
          user: _traveler(gpPro: false),
          locale: locale,
          size: const Size(360, 1400),
        );
        expect(tester.takeException(), isNull);
        final link = find.descendant(
          of: find.byKey(const Key('mode-badge-link-boat')),
          matching: find.byType(Text),
        );
        expect(link, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: link, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse);

        // Capacité puis Prix d'un bateau : segment et boutons du bas.
        await tester.pumpWidget(const SizedBox());
        await pumpScreen(
          tester,
          CreateTripArgs(
            resumeDraft: _boatDraft(stepId: TripFormStep.capacite),
          ),
          locale: locale,
          size: const Size(360, 1400),
        );
        expect(tester.takeException(), isNull);
        for (final key in ['boat-unit-m3', 'boat-unit-kg']) {
          final label = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(RichText),
            ),
          );
          expect(label.didExceedMaxLines, isFalse, reason: key);
        }
        final heightCapacity = tester
            .getSize(find.byKey(const Key('trip-form-continue')))
            .height;
        await goToStep(tester, TripFormStep.prix);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const Key('trip-form-continue'))).height,
          heightCapacity,
        );
        expectNoPlaneIcon(tester);
      });
    }
  });

  group('brouillon local', () {
    test('boatDraft_roundTrip : clés bateau relues telles quelles', () {
      final draft = _boatDraft();
      final json = draft.toJson();
      expect(json['arrivalDate'], isNotNull);
      expect(json['arrivalDateMax'], isNotNull);
      expect(json['volumeM3'], 12.5);
      expect(json['pricePerM3'], 150);
      expect(json['boatPriceUnit'], 'M3');

      final back = TripFormDraft.fromJson(json);
      expect(back, draft);
      expect(back.arrivalDateMax, draft.arrivalDateMax);
      expect(back.volumeM3, 12.5);
      expect(back.pricePerM3, 150);
      expect(back.boatPriceUnit, BoatPriceUnit.m3);
    });

    test('ancienne forme sans clés bateau : lue sans erreur, champs nuls', () {
      final old = TripFormDraft.fromJson(const {
        'stepId': 'trajet',
        'transportMode': 'PLANE',
        'arrivalDayOffset': 1,
      });
      expect(old.arrivalDate, isNull);
      expect(old.arrivalDateMax, isNull);
      expect(old.volumeM3, isNull);
      expect(old.pricePerM3, isNull);
      expect(old.boatPriceUnit, isNull);
    });

    test('valeurs illisibles et départ passé : écartées', () {
      final read = TripFormDraft.fromJson(const {
        'departureDate': '2020-01-01',
        'arrivalDate': '2020-01-20',
        'arrivalDateMax': '2020-02-01',
        'volumeM3': 'beaucoup',
        'pricePerM3': -3,
        'boatPriceUnit': 'LITRE',
      });
      expect(read.departureDate, isNull);
      expect(read.arrivalDate, isNull);
      expect(read.arrivalDateMax, isNull);
      expect(read.volumeM3, isNull);
      expect(read.pricePerM3, isNull);
      expect(read.boatPriceUnit, isNull);
    });
  });
}
