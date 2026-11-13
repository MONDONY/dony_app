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
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/trip_legs_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/models/bid_model.dart'
    show BidPaymentMethod;
import 'package:dony/features/matching/data/models/boat_price_unit.dart';
import 'package:dony/features/matching/data/models/trip_form_draft.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/stops_chips.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/transport_mode_row.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_step.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
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
import '../../../helpers/label_fit_expectations.dart';
import '../../../helpers/mock_recent_city_store.dart';
import '../../../helpers/plane_icon_expectations.dart';
import 'widgets/trip_owner/trip_card_harness.dart' show loadAppFonts;

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

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

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

AnnouncementModel _editedBoatTrip({double? maxParcelWeightKg = 30}) =>
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
  bool modeChosen = true,
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
    transportMode: modeChosen ? 'BOAT' : null,
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
    boatPriceUnit: modeChosen ? unit : null,
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
    registerFallbackValue(const NegotiationFetchRequested('thread-1'));
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

  group('trajet dédié à une demande par bateau', () {
    LockedTripContext boatContext({
      TransportMode? mode = TransportMode.boat,
      String? threadId = 'thread-1',
      double? volume = 0.5,
    }) => LockedTripContext(
      threadId: threadId,
      packageRequestId: 'req-1',
      departureCity: 'Marseille',
      arrivalCity: 'Abidjan',
      desiredDate: _inDays(30),
      dateToleranceDays: 10,
      weightKg: 12,
      volumeM3: volume,
      transportMode: mode,
      agreedPriceEur: 80,
    );

    _MockNegotiationBloc nego() {
      final b = _MockNegotiationBloc();
      when(() => b.state).thenReturn(const NegotiationInitial());
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    }

    testWidgets('dedicatedBoat_volumeLocked : le volume de la demande en '
        'lecture seule, aucun kilo, aucune valise ni avion', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(lockContext: boatContext(), negotiationBloc: nego()),
      );

      // Mode connu : pas d'étape Mode, la fourchette d'arrivée s'ouvre.
      expect(currentStep(tester), TripFormStep.trajet);
      expect(trajet(tester).boatArrivalMinNotifier, isNotNull);
      expect(trajet(tester).boatArrivalMaxNotifier, isNotNull);

      final capacity = tester.widget<LieuxCapaciteStep>(
        find.byType(LieuxCapaciteStep, skipOffstage: false),
      );
      expect(capacity.lockedVolumeM3, 0.5);
      expect(capacity.transportMode, TransportMode.boat);

      final locked = find.byKey(
        const Key('locked-capacity-display'),
        skipOffstage: false,
      );
      expect(locked, findsOneWidget);
      expect(
        find.descendant(
          of: locked,
          matching: find.text('0,50 m³', skipOffstage: false),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: locked,
          matching: find.byWidgetPredicate(
            (w) => w is DonyIcon && w.name == 'luggage',
            skipOffstage: false,
          ),
          skipOffstage: false,
        ),
        findsNothing,
      );
      // Seule la puce « avion » de la ligne du mode (un choix parmi les modes,
      // en lecture seule) dessine un avion : jamais l'écran du trajet.
      expect(
        findPlaneDonyIcons().evaluate().length,
        find
            .descendant(
              of: find.byType(TransportModeRow),
              matching: findPlaneDonyIcons(),
            )
            .evaluate()
            .length,
      );
      expect(findMaterialFlightIcons(), findsNothing);
      expect(findPlaneEmojiTexts(), findsNothing);
    });

    testWidgets('dedicatedBoat_requiresArrivalRange : « Continuer » grisé '
        'sans fourchette', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(lockContext: boatContext(), negotiationBloc: nego()),
      );

      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('dedicatedBoat_unverified_disabled : mode connu, voyageur sans '
        'badge : bandeau, lien GP Pro, « Continuer » grisé', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(lockContext: boatContext(), negotiationBloc: nego()),
        user: _traveler(gpPro: false),
      );

      expect(find.byKey(const Key('locked-boat-blocked-note')), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);
      // Même avec la fourchette renseignée.
      trajet(tester).boatArrivalMinNotifier!.value = _inDays(50);
      trajet(tester).boatArrivalMaxNotifier!.value = _inDays(60);
      await tester.pump();
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(find.text('Demander le badge GP Pro'));
      await tester.pumpAndSettle();
      expect(find.text('gp-pro-stub'), findsOneWidget);
      verify(
        () => getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.tripBoatBadgeRequestTapped,
        ),
      ).called(1);
      // Le double d'analytics est partagé : un autre test compte le même événement.
      clearInteractions(getIt<AnalyticsService>());
    });

    testWidgets('dedicatedBoat_verified_noBlockedNote', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(lockContext: boatContext(), negotiationBloc: nego()),
      );

      expect(find.byKey(const Key('locked-boat-blocked-note')), findsNothing);
    });

    testWidgets('demande « peu importe », voyageur sans badge : la carte '
        'Bateau est grisée à l\'étape Mode', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          lockContext: boatContext(mode: null),
          negotiationBloc: nego(),
        ),
        user: _traveler(gpPro: false),
      );

      expect(currentStep(tester), TripFormStep.mode);
      expect(find.byKey(const Key('mode-card-boat')), findsOneWidget);
      expect(find.text('Réservé aux transporteurs vérifiés'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mode-card-boat')));
      await tester.pump();
      expect(find.byKey(const Key('mode-check-boat')), findsNothing);
      // Le bandeau du mode connu n'apparaît pas : le voyageur peut choisir
      // un autre mode.
      expect(find.byKey(const Key('locked-boat-blocked-note')), findsNothing);
    });

    testWidgets('demande « peu importe », voyageur GP Pro : la carte Bateau '
        'se choisit', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          lockContext: boatContext(mode: null),
          negotiationBloc: nego(),
        ),
      );

      await tester.tap(find.byKey(const Key('mode-card-boat')));
      await tester.pump();
      expect(find.byKey(const Key('mode-check-boat')), findsOneWidget);
    });

    testWidgets('demande par avion : aucun changement (ni fourchette ni '
        'volume)', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          lockContext: boatContext(mode: TransportMode.plane),
          negotiationBloc: nego(),
        ),
      );

      expect(trajet(tester).boatArrivalMinNotifier, isNull);
      final capacity = tester.widget<LieuxCapaciteStep>(
        find.byType(LieuxCapaciteStep, skipOffstage: false),
      );
      expect(capacity.lockedVolumeM3, isNull);
      expect(capacity.lockedCapacityKg, 12);
    });

    testWidgets('dedicatedBoat_sendsArrivalRange : fil existant et offre '
        'atomique', (tester) async {
      for (final threadId in const ['thread-1', null]) {
        final bloc = nego();
        await pumpScreen(
          tester,
          CreateTripArgs(
            lockContext: boatContext(threadId: threadId),
            negotiationBloc: bloc,
          ),
        );
        trajet(tester).departureTimeNotifier.value = const TimeOfDay(
          hour: 10,
          minute: 0,
        );
        final content = tester.state<State<StatefulWidget>>(
          find.byKey(const Key('trip-form-content')),
        );
        (content as dynamic).handoverDeadlineForTest.value = _inDays(25);
        trajet(tester).boatArrivalMinNotifier!.value = _inDays(50);
        trajet(tester).boatArrivalMaxNotifier!.value = _inDays(60);
        final lieux = tester.widget<LieuxCapaciteStep>(
          find.byType(LieuxCapaciteStep, skipOffstage: false),
        );
        lieux.onPickupChanged(
          const AddressData(label: 'Entrepôt', lat: 43.3, lng: 5.37),
        );
        lieux.onDeliveryChanged(
          const AddressData(label: 'Port', lat: 5.3, lng: -4.0),
        );
        await tester.pump();
        await goToStep(tester, TripFormStep.conditions);
        await tester.tap(find.byKey(const Key('create-dedicated-trip-submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final fmt = DateFormat('yyyy-MM-dd');
        if (threadId != null) {
          final event = captured
              .whereType<NegotiationCreateDedicatedTripRequested>()
              .single;
          expect(event.arrivalDate, fmt.format(_inDays(50)));
          expect(event.arrivalDateMax, fmt.format(_inDays(60)));
        } else {
          final event = captured
              .whereType<NegotiationStartWithDedicatedTripRequested>()
              .single;
          expect(event.dedicatedTrip.arrivalDate, fmt.format(_inDays(50)));
          expect(event.dedicatedTrip.arrivalDateMax, fmt.format(_inDays(60)));
          expect(
            event.dedicatedTrip.toJson()['arrivalDateMax'],
            fmt.format(_inDays(60)),
          );
        }
      }
    });
  });

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
      // Mesure : combien de voyageurs non vérifiés butent sur le bateau.
      verify(
        () => getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.tripBoatBadgeRequestTapped,
        ),
      ).called(1);
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
      expect(find.byType(StopsChips), findsNothing);
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

  group('calendrier de l\'arrivée estimée', () {
    CalendarDatePicker picker(WidgetTester tester) =>
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));

    Future<void> open(WidgetTester tester, String key) async {
      final field = find.byKey(Key(key));
      await tester.ensureVisible(field);
      await tester.pump();
      await tester.tap(field);
      await tester.pumpAndSettle();
    }

    testWidgets('au plus tôt : du jour du départ à départ + 120 jours', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: _boatDraft(
            stepId: TripFormStep.trajet,
            withRange: false,
          ),
        ),
      );
      await open(tester, 'boatArrivalMinField');
      expect(picker(tester).firstDate, _inDays(30));
      expect(picker(tester).lastDate, _inDays(30 + 120));
    });

    testWidgets(
      'au plus tard : de l\'arrivée au plus tôt à départ + 120 jours',
      (tester) async {
        await pumpScreen(
          tester,
          CreateTripArgs(resumeDraft: _boatDraft(stepId: TripFormStep.trajet)),
        );
        await open(tester, 'boatArrivalMaxField');
        expect(picker(tester).firstDate, _inDays(50));
        expect(picker(tester).lastDate, _inDays(30 + 120));
        expect(picker(tester).initialDate, _inDays(65));
      },
    );
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

      // Une seule décimale : la seconde est refusée à la frappe.
      await tester.enterText(
        find.byKey(const Key('boat-volume-field')),
        '12.55',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('boat-volume-field')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        isNot('12.55'),
      );
      await tester.enterText(
        find.byKey(const Key('boat-volume-field')),
        '12.5',
      );
      await tester.pump();

      // Au kilo : les kilos, jamais de valise en bateau.
      await tester.tap(find.byKey(const Key('boat-unit-kg')));
      await tester.pump();
      expect(find.byKey(const Key('boat-volume-field')), findsNothing);
      expect(find.textContaining('Valise'), findsNothing);
      expectNoPlaneIcon(tester);
    });
  });

  group('étape Mode puis Capacité', () {
    testWidgets('boatChosenAtModeStep_defaultsToM3 : le m³ est l\'unité par '
        'défaut, sans kilos ni valise', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: _boatDraft(
            stepId: TripFormStep.mode,
            modeChosen: false,
            volume: null,
          ),
        ),
      );
      expect(currentStep(tester), TripFormStep.mode);
      await tester.tap(find.byKey(const Key('mode-card-boat')));
      await tester.pump();
      await goToStep(tester, TripFormStep.capacite);

      expect(find.byKey(const Key('boat-volume-field')), findsOneWidget);
      expect(find.byKey(const Key('capacity-kg-field')), findsNothing);
      expect(find.textContaining('Valise'), findsNothing);
      // Titre de la capacité : le colis, pas la valise.
      expect(findDonyIcon('luggage'), findsNothing);
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

    testWidgets('prix au m³ : plafond 99 999 999,99, message et « Continuer » '
        'grisé', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: _boatDraft(stepId: TripFormStep.prix, pricePerM3: null),
        ),
      );
      final field = find.byKey(const Key('trip-price-per-m3'));
      await tester.enterText(field, '99999999.99');
      await tester.pump();
      await tester.pump();
      expect(continueButton(tester).onPressed, isNotNull);
      expect(find.textContaining('ne peut pas dépasser'), findsNothing);

      await tester.enterText(field, '100000000');
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('ne peut pas dépasser'), findsOneWidget);
      expect(find.textContaining('Vous touchez'), findsNothing);
      expect(continueButton(tester).onPressed, isNull);

      await tester.enterText(field, '0.001');
      await tester.pump();
      await tester.pump();
      expect(continueButton(tester).onPressed, isNull);
      expect(find.textContaining('ne peut pas dépasser'), findsNothing);
    });

    testWidgets('encadré « payé au dépôt » : absent pour un trajet bateau '
        'd\'un voyageur sans badge', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(announcement: _editedBoatTrip()),
        user: _traveler(gpPro: false),
      );
      await goToStep(tester, TripFormStep.prix);
      expect(find.byKey(const Key('trip-price-per-m3')), findsOneWidget);
      expect(find.byKey(const Key('boat-deposit-notice')), findsNothing);
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
      // Ni escales ni étapes en bateau, ni avion sur l'étape Conditions.
      expect(find.text('Ajouter une étape'), findsNothing);
      expectNoPlaneIcon(tester);
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

    testWidgets('422 arrivée estimée refusée : detail du serveur relayé, '
        'formulaire gardé', (tester) async {
      await pumpScreen(tester, CreateTripArgs(resumeDraft: _boatDraft()));
      await publish(tester);

      states.add(
        AnnouncementError(
          const ValidationException(
            "L'arrivée estimée au plus tard ne peut pas être antérieure à "
            "aujourd'hui.",
            code: 'arrival-range-invalid',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.textContaining("ne peut pas être antérieure à aujourd'hui"),
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
    testWidgets('PUT au m³ : fourchette, volume, prix au m³, poids max par '
        'colis gardé', (tester) async {
      await pumpScreen(tester, CreateTripArgs(announcement: _editedBoatTrip()));
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

  group('modification : du m³ au kilo', () {
    testWidgets('kilos exigés : « Continuer » grisé tant qu\'aucun kilo n\'est '
        'saisi (jamais un PUT à 0 kg)', (tester) async {
      await pumpScreen(tester, CreateTripArgs(announcement: _editedBoatTrip()));
      await goToStep(tester, TripFormStep.capacite);
      expect(find.byKey(const Key('boat-volume-field')), findsOneWidget);
      expect(continueButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('boat-unit-kg')));
      await tester.pump();
      expect(find.byKey(const Key('capacity-kg-field')), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('capacity-kg-field')), '40');
      await tester.pump();
      await tester.pump();
      expect(continueButton(tester).onPressed, isNotNull);
    });
  });

  group('boutons à 360 dp', () {
    // Vraies polices : celle de repli des tests (carrés pleins) fausserait la
    // largeur des libellés mesurés.
    setUpAll(loadAppFonts);

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
        expectPlainLabelFits(tester, link, reason: 'lien GP Pro');

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
          expectPlainLabelFits(tester, find.byKey(Key(key)), reason: key);
        }
        final heightCapacity = tester
            .getSize(find.byKey(const Key('trip-form-continue')))
            .height;
        expectButtonLabelNominal(
          tester,
          find.byKey(const Key('trip-form-continue')),
          reason: 'Continuer (Capacité)',
        );
        await goToStep(tester, TripFormStep.prix);
        expect(tester.takeException(), isNull);
        expectButtonLabelNominal(
          tester,
          find.byKey(const Key('trip-form-continue')),
          reason: 'Continuer (Prix)',
        );
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
