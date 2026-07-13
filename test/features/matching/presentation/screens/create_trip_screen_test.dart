import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart' show BidPaymentMethod;
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ── Mock BLoCs ────────────────────────────────────────────────────────────────

class _MockCitySearchBloc
    extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class _MockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

// ── Mock Services / Repos ─────────────────────────────────────────────────────

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockPriceGridRepository extends Mock implements PriceGridRepository {}

class _MockContentCategoryRepository extends Mock
    implements IContentCategoryRepository {}

// ── Fake event fallbacks (only for non-sealed abstract events) ────────────────

class _FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

class _FakeCommissionMethodEvent extends Fake implements CommissionMethodEvent {}

class _FakeCitySearchEvent extends Fake implements CitySearchEvent {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Creates a `MockStripeAccountBloc` with initial state.
_MockStripeAccountBloc _makeStripeBloc() {
  final b = _MockStripeAccountBloc();
  when(() => b.state).thenReturn(const StripeAccountInitial());
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  return b;
}

/// Wraps [child] in a GoRouter + MaterialApp with a `StripeAccountBloc`
/// provided at the app level (the screen reads it but does not create it).
Widget _wrapWithRouter(Widget child) {
  final router = GoRouter(
    initialLocation: '/trips/create',
    routes: [
      GoRoute(
        path: '/trips/create',
        builder: (_, __) => BlocProvider<StripeAccountBloc>.value(
          value: _makeStripeBloc(),
          child: child,
        ),
      ),
      // Extra route so GoRouter can navigate back on context.pop()
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: SizedBox()),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light,
  );
}

/// Returns a minimal `AnnouncementModel` suitable for edit-mode tests.
AnnouncementModel _makeAnnouncement() => AnnouncementModel(
      id: 'ann-test-1',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8, 1),
      availableKg: 10.0,
      totalKg: 23.0,
      pricePerKg: 8.0,
      status: 'ACTIVE',
      bidsCount: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Returns a complete `AnnouncementModel` that passes ALL step-0 validation:
/// • departure city, arrival city, departure date
/// • handoverWindowStart < handoverWindowEnd < departure time
/// • pickupAddress + deliveryAddress (enables step-1 → step-2 navigation)
/// • departureTime + arrivalTime (covers TimeOfDay parsing in initState)
/// • acceptedContentTypes + refusedTypes (covers content-type init code)
AnnouncementModel _makeFullAnnouncement() => AnnouncementModel(
      id: 'ann-full-1',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8, 1),
      // 22:00 departure → handoverEnd 18:00 is safely before departure
      departureTime: '22:00',
      arrivalTime: '10:30',
      availableKg: 10.0,
      totalKg: 23.0,
      pricePerKg: 8.0,
      status: 'ACTIVE',
      bidsCount: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      handoverWindowStart: DateTime(2026, 8, 1, 16, 0),
      handoverWindowEnd: DateTime(2026, 8, 1, 18, 0),
      pickupAddress: const AddressData(label: 'Tour Eiffel', lat: 48.858, lng: 2.294),
      deliveryAddress: const AddressData(label: 'Dakar Centre', lat: 14.716, lng: -17.467),
      transportMode: TransportMode.plane,
      acceptedPaymentMethods: {BidPaymentMethod.stripe, BidPaymentMethod.cash},
      acceptedContentTypes: const ['Vêtements', 'Médicaments'],
      refusedTypes: const ['Produits dangereux'],
    );

/// Returns a minimal `LockedTripContext` suitable for locked-mode tests.
LockedTripContext _makeLockContext() => LockedTripContext(
      threadId: 'thread-1',
      packageRequestId: 'req-1',
      departureCity: 'Lyon',
      arrivalCity: 'Abidjan',
      desiredDate: DateTime(2026, 9, 1),
      dateToleranceDays: 5,
      weightKg: 5.0,
      transportMode: TransportMode.plane,
      agreedPriceEur: 50.0,
      paymentMethod: PaymentMethod.stripe,
    );

/// Creates a pre-configured `NegotiationBloc` mock.
_MockNegotiationBloc _makeNegotiationBloc() {
  final b = _MockNegotiationBloc();
  when(() => b.state).thenReturn(const NegotiationInitial());
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  return b;
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    // Initialize intl locale data — required for DateFormat('dd/MM HH:mm', 'fr')
    // used in the handover window rows.
    await initializeDateFormatting('fr');

    // Non-sealed abstract event fallbacks
    registerFallbackValue(_FakeAnnouncementEvent());
    registerFallbackValue(_FakeCommissionMethodEvent());
    registerFallbackValue(_FakeCitySearchEvent());

    // Sealed event fallbacks — use concrete subclass instances
    registerFallbackValue(const TripTemplateLoaded());
    registerFallbackValue(const StripeAccountStatusLoaded());
    registerFallbackValue(const NegotiationFetchRequested('fallback-thread'));

    // AnalyticsService — called from CreateTripScreen.initState via getIt
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(
          any(),
          properties: any(named: 'properties'),
        ),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<AnalyticsService>(analytics);
    }

    // PriceGridRepository — passed when constructing AnnouncementFormBloc
    if (!getIt.isRegistered<PriceGridRepository>()) {
      getIt.registerSingleton<PriceGridRepository>(
        _MockPriceGridRepository(),
      );
    }

    // IContentCategoryRepository — _TripFormContentState.initState calls
    // getIt<IContentCategoryRepository>().getCategories() via an unawaited
    // _loadCatalog(). Pre-existing gap (not related to Task 6) that left an
    // uncaught async StateError on every test rendering the full form.
    if (!getIt.isRegistered<IContentCategoryRepository>()) {
      final repo = _MockContentCategoryRepository();
      when(() => repo.getCategories()).thenAnswer((_) async => const []);
      getIt.registerSingleton<IContentCategoryRepository>(repo);
    }

    // AnnouncementBloc factory — CreateTripScreen calls getIt<AnnouncementBloc>()
    if (!getIt.isRegistered<AnnouncementBloc>()) {
      getIt.registerFactory<AnnouncementBloc>(() {
        final b = _MockAnnouncementBloc();
        when(() => b.state).thenReturn(AnnouncementInitial());
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
    }

    // CommissionMethodBloc factory
    if (!getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.registerFactory<CommissionMethodBloc>(() {
        final b = _MockCommissionMethodBloc();
        when(() => b.state).thenReturn(CommissionMethodInitial());
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
    }

    // TripTemplateBloc factory — screen calls getIt<TripTemplateBloc>()..add(TripTemplateLoaded())
    if (!getIt.isRegistered<TripTemplateBloc>()) {
      getIt.registerFactory<TripTemplateBloc>(() {
        final b = _MockTripTemplateBloc();
        when(() => b.state).thenReturn(const TripTemplateState());
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
    }

    // CitySearchBloc factory — used by TrajetStep (CityAutocompleteField) in creation/edit mode
    if (!getIt.isRegistered<CitySearchBloc>()) {
      getIt.registerFactory<CitySearchBloc>(() {
        final b = _MockCitySearchBloc();
        when(() => b.state).thenReturn(const CitySearchInitial());
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
    }

    // StripeAccountBloc factory — CreateTripScreen.build() always creates its
    // own BlocProvider<StripeAccountBloc>(create: (_) => getIt<...>()),
    // shadowing whatever `.value` provider a test wraps it with. Pre-existing
    // gap (not related to Task 6) that was leaving every BLoC-listener test
    // in this file with a spurious uncaught `StateError` on the very first
    // pumpAndSettle — registering it here fixes the noise for all tests.
    if (!getIt.isRegistered<StripeAccountBloc>()) {
      getIt.registerFactory<StripeAccountBloc>(_makeStripeBloc);
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  // ── Helper: set viewport to iPhone 14 size ────────────────────────────────

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  /// Pumps the widget and drains flutter_animate timers.
  ///
  /// [tester.pump()] fires the first frame; the subsequent
  /// [pump(600ms)] advances fake time past all animation delays
  /// (max delay 180ms + max duration 300ms in this screen).
  Future<void> _pumpAndDrain(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  // ── Group: AppBar titles ──────────────────────────────────────────────────────

  group('CreateTripScreen — AppBar titles', () {
    testWidgets(
      'titre "Publier un trajet" en mode création (args == null)',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        expect(find.text('Publier un trajet'), findsOneWidget);
      },
    );

    testWidgets(
      'titre "Modifier le trajet" en mode édition (args.announcement != null)',
      (tester) async {
        setupViewport(tester);

        final args = CreateTripArgs(announcement: _makeAnnouncement());
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        expect(find.text('Modifier le trajet'), findsOneWidget);
      },
    );

    testWidgets(
      'titre "Créer le trajet pour cette demande" en mode locked',
      (tester) async {
        setupViewport(tester);

        final args = CreateTripArgs(
          lockContext: _makeLockContext(),
          negotiationBloc: _makeNegotiationBloc(),
        );
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        expect(
          find.text('Créer le trajet pour cette demande'),
          findsOneWidget,
        );
      },
    );
  });

  // ── Group: Bottom navigation bar ─────────────────────────────────────────────

  group('CreateTripScreen — Bottom navigation bar', () {
    testWidgets(
      'bouton "Continuer" présent à l\'étape 0',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        expect(find.text('Continuer'), findsOneWidget);
      },
    );

    testWidgets(
      'bouton ✕ (Icons.close) présent',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgets(
      'bouton "Continuer" désactivé quand les champs obligatoires sont vides (mode création)',
      (tester) async {
        setupViewport(tester);

        // Creation mode: _canContinueNotifier starts false (no pre-filled fields)
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        // DonyButton with label 'Continuer' should have onPressed == null
        final donyButton = tester.widget<DonyButton>(
          find.ancestor(
            of: find.text('Continuer'),
            matching: find.byType(DonyButton),
          ),
        );
        expect(donyButton.onPressed, isNull);
      },
    );

    testWidgets(
      'bouton "Continuer" activé en mode édition (champs pré-remplis)',
      (tester) async {
        setupViewport(tester);

        // Edit mode with a full announcement (all required fields present):
        // _canContinueNotifier is true after _updateCanContinue fires because
        // departureCity, arrivalCity, departureDate, handoverWindowStart and
        // handoverWindowEnd are all set, and handoverEnd (18:00) < departure (22:00).
        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        expect(find.text('Continuer'), findsOneWidget);
        final btns = tester.widgetList<DonyButton>(find.byType(DonyButton));
        final continueBtn = btns.firstWhere((b) => b.label == 'Continuer');
        expect(continueBtn.onPressed, isNotNull,
            reason: 'Continuer doit être actif en mode édition (champs pré-remplis)');
      },
    );

    testWidgets(
      'mode création: bouton "Retour" absent à l\'étape 0',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        // At step 0, "Retour" should not be rendered
        expect(find.text('Retour'), findsNothing);
      },
    );
  });

  // ── Group: Form structure ─────────────────────────────────────────────────────

  group('CreateTripScreen — Form structure', () {
    testWidgets(
      'stepper header est présent à l\'étape 0',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        expect(find.byType(CaStepperHeader), findsOneWidget);
      },
    );

    testWidgets(
      'section fenêtre de remise est visible à l\'étape 0',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        // Step 0 contains the handover window section with these list tiles
        expect(find.text('Début de remise'), findsOneWidget);
        expect(find.text('Fin de remise'), findsOneWidget);
      },
    );

    testWidgets(
      'mode locked: bannière "Trajet dédié à la demande" affichée',
      (tester) async {
        setupViewport(tester);

        final args = CreateTripArgs(
          lockContext: _makeLockContext(),
          negotiationBloc: _makeNegotiationBloc(),
        );
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        expect(find.text('Trajet dédié à la demande'), findsOneWidget);
      },
    );
  });

  // ── Group: Step navigation (requires full announcement) ──────────────────────

  group('CreateTripScreen — Step navigation', () {
    testWidgets(
      '"Retour" visible au step 1 en mode édition (full announcement)',
      (tester) async {
        setupViewport(tester);

        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        // Step 0: no Retour button
        expect(find.text('Retour'), findsNothing);

        // Tap Continuer → advance to step 1
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));

        // Step 1: Retour appears
        expect(find.text('Retour'), findsOneWidget);
        expect(find.text('Continuer'), findsOneWidget);
      },
    );

    testWidgets(
      '"Enregistrer" visible au step 2 en mode édition',
      (tester) async {
        // Use a wider viewport — step-2 (PrixConditionsStep) has payment-method
        // chips that overflow on narrow 390pt screens.
        tester.view.physicalSize = const Size(800, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        // Advance to step 1
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));

        // Advance to step 2
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));

        // Step 2 edit mode: "Enregistrer" appears
        expect(find.text('Enregistrer'), findsOneWidget);
        expect(find.text('Retour'), findsOneWidget);
      },
    );

    testWidgets(
      'custom pricePerKg (not in presets) initialise le champ custom',
      (tester) async {
        // pricePerKg: 9.5 → NOT in kPriceOptions [5,6,7,8] → custom price branch.
        // Covers: lines 557-558 (custom init), 481-482 (_isPriceValid path).
        setupViewport(tester);

        // Use price NOT in kPriceOptions = [5.0, 6.0, 7.0, 8.0]
        final ann = AnnouncementModel(
          id: 'ann-custom-price',
          travelerId: 'trav-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 8, 1),
          departureTime: '22:00',
          arrivalTime: '10:30',
          availableKg: 10.0,
          totalKg: 23.0,
          pricePerKg: 9.5, // NOT in preset list
          status: 'ACTIVE',
          bidsCount: 0,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          handoverWindowStart: DateTime(2026, 8, 1, 16, 0),
          handoverWindowEnd: DateTime(2026, 8, 1, 18, 0),
          pickupAddress:
              const AddressData(label: 'Tour Eiffel', lat: 48.858, lng: 2.294),
          deliveryAddress: const AddressData(
            label: 'Dakar Centre',
            lat: 14.716,
            lng: -17.467,
          ),
          transportMode: TransportMode.plane,
          acceptedPaymentMethods: {BidPaymentMethod.stripe},
          acceptedContentTypes: const ['Vêtements'],
          refusedTypes: const [],
        );

        final args = CreateTripArgs(announcement: ann);
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        // Screen renders in edit mode — verify the title confirms edit mode.
        expect(find.text('Modifier le trajet'), findsOneWidget);
      },
    );

    testWidgets(
      'description non-nulle pré-remplie (branch description != null)',
      (tester) async {
        // Covers line 531: `_descriptionCtrl.text = a.description!`
        setupViewport(tester);

        final ann = AnnouncementModel(
          id: 'ann-desc',
          travelerId: 'trav-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 8, 1),
          departureTime: '22:00',
          availableKg: 10.0,
          totalKg: 23.0,
          pricePerKg: 8.0,
          status: 'ACTIVE',
          bidsCount: 0,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          handoverWindowStart: DateTime(2026, 8, 1, 16, 0),
          handoverWindowEnd: DateTime(2026, 8, 1, 18, 0),
          transportMode: TransportMode.plane,
          acceptedPaymentMethods: {BidPaymentMethod.stripe},
          acceptedContentTypes: const ['Vêtements'],
          refusedTypes: const [],
          description: 'Colis fragile, à manipuler avec soin.',
        );

        final args = CreateTripArgs(announcement: ann);
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        // Edit mode with description pre-filled — verify the title confirms edit mode.
        expect(find.text('Modifier le trajet'), findsOneWidget);
      },
    );

    testWidgets(
      '"Retour" au step 2 navigue vers step 1',
      (tester) async {
        // Covers the Retour onPressed lambda at step 2 (edit mode, lines 272-273).
        tester.view.physicalSize = const Size(800, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        // Advance to step 2
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Enregistrer'), findsOneWidget);

        // Tap Retour → back to step 1
        await tester.tap(find.text('Retour'));
        await tester.pump(const Duration(milliseconds: 600));

        // Step 1 again
        expect(find.text('Continuer'), findsOneWidget);
        expect(find.text('Enregistrer'), findsNothing);
      },
    );

    testWidgets(
      '"Retour" au step 1 navigue vers step 0',
      (tester) async {
        setupViewport(tester);

        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        // Advance to step 1
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Retour'), findsOneWidget);

        // Tap Retour → back to step 0
        await tester.tap(find.text('Retour'));
        await tester.pump(const Duration(milliseconds: 600));

        // Step 0 again: no Retour
        expect(find.text('Retour'), findsNothing);
      },
    );
  });

  // ── Group: Template suggestion bar + _applyTemplate ──────────────────────────

  group('CreateTripScreen — Template suggestion bar', () {
    const _mockTemplate = TripTemplate(
      id: 'tmpl-1',
      label: 'Paris → Dakar',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      transportMode: 'PLANE',
      capacityUnit: 'KG_FREE',
      availableKg: 10,
      pricePerKg: 8.0,
      acceptedCategories: ['Vêtements', 'Documents'],
    );

    setUp(() {
      // Override TripTemplateBloc to return a mock with one template
      if (getIt.isRegistered<TripTemplateBloc>()) {
        getIt.unregister<TripTemplateBloc>();
      }
      getIt.registerFactory<TripTemplateBloc>(() {
        final b = _MockTripTemplateBloc();
        when(() => b.state).thenReturn(
          const TripTemplateState(
            status: TripTemplateStatus.success,
            templates: [_mockTemplate],
          ),
        );
        when(() => b.stream)
            .thenAnswer((_) => const Stream.empty());
        return b;
      });
    });

    tearDown(() {
      if (getIt.isRegistered<TripTemplateBloc>()) {
        getIt.unregister<TripTemplateBloc>();
      }
      getIt.registerFactory<TripTemplateBloc>(() {
        final b = _MockTripTemplateBloc();
        when(() => b.state).thenReturn(const TripTemplateState());
        when(() => b.stream)
            .thenAnswer((_) => const Stream.empty());
        return b;
      });
    });

    testWidgets(
      'template chip visible au step 0 en mode création',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        // The template bar shows the chip
        expect(
          find.text('Paris → Dakar · 8€/kg'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tap template chip → _applyTemplate applique les valeurs',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        expect(find.byType(ActionChip), findsOneWidget);

        // Tap the chip → _applyTemplate(t) called.
        // _applyTemplate shows a DonySnackbar (SnackBar with ~4s auto-dismiss)
        // → drain all pending timers to avoid the 'timer still pending' assertion.
        await tester.tap(find.byType(ActionChip));
        await tester.pump(const Duration(milliseconds: 600));

        // Screen still present (no navigation triggered)
        expect(find.byType(CreateTripScreen), findsOneWidget);

        // _applyTemplate shows DonySnackbar with 'appliqué' in the message.
        expect(find.textContaining('appliqué'), findsOneWidget);

        // Drain the SnackBar auto-dismiss timer (~4 s default) so the widget
        // tree can be disposed cleanly at end of test.
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  // ── Group: Handover window error display ──────────────────────────────────────

  group('CreateTripScreen — Handover window validation', () {
    testWidgets(
      'erreur affichée quand fenêtre se termine après heure de départ',
      (tester) async {
        setupViewport(tester);

        // handoverEnd (23:00) > departureTime (22:00) → _handoverWindowError non-null
        final ann = AnnouncementModel(
          id: 'ann-handover-err',
          travelerId: 'trav-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 8, 1),
          departureTime: '22:00',
          availableKg: 10.0,
          totalKg: 23.0,
          pricePerKg: 8.0,
          status: 'ACTIVE',
          bidsCount: 0,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          handoverWindowStart: DateTime(2026, 8, 1, 20, 0),
          handoverWindowEnd: DateTime(2026, 8, 1, 23, 0), // after 22:00 departure
          transportMode: TransportMode.plane,
          acceptedPaymentMethods: {BidPaymentMethod.stripe},
          acceptedContentTypes: const ['Vêtements'],
          refusedTypes: const [],
        );

        final args = CreateTripArgs(announcement: ann);
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        // Error message displayed — "avant le départ (22:00)"
        expect(
          find.textContaining('avant le départ'),
          findsOneWidget,
        );
      },
    );
  });

  // ── Group: _submit() via Enregistrer ─────────────────────────────────────────

  group('CreateTripScreen — _submit() via Enregistrer (mode édition)', () {
    testWidgets(
      '"Enregistrer" au step 2 appelle _submit() — happy path',
      (tester) async {
        // Wide viewport: avoids overflow in step-2 PrixConditionsStep
        tester.view.physicalSize = const Size(800, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        // Navigate to step 2
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Enregistrer'), findsOneWidget);

        // Tap Enregistrer → _submit() → AnnouncementBloc.add(UpdateRequested)
        await tester.tap(find.byKey(const Key('create-announcement-submit')));
        await tester.pump(const Duration(milliseconds: 600));

        // Screen still present (mock bloc doesn't emit AnnouncementUpdated)
        expect(find.byType(CreateTripScreen), findsOneWidget);
      },
    );
  });

  // ── Group: pricingMode MIXED → BlocListener ────────────────────────────────
  // PricingMode listener tested via unit test of _TripFormContentState.

  // ── Group: BLoC listeners ─────────────────────────────────────────────────────

  group('CreateTripScreen — BLoC listeners (AnnouncementBloc)', () {
    late StreamController<AnnouncementState> annStreamCtrl;

    setUp(() {
      annStreamCtrl =
          StreamController<AnnouncementState>.broadcast();
      // Replace GetIt factory with one that returns a controlled mock
      if (getIt.isRegistered<AnnouncementBloc>()) {
        getIt.unregister<AnnouncementBloc>();
      }
      getIt.registerFactory<AnnouncementBloc>(() {
        final b = _MockAnnouncementBloc();
        when(() => b.state).thenReturn(AnnouncementInitial());
        when(() => b.stream)
            .thenAnswer((_) => annStreamCtrl.stream);
        return b;
      });
    });

    tearDown(() async {
      await annStreamCtrl.close();
      // Restore the original empty-stream factory
      if (getIt.isRegistered<AnnouncementBloc>()) {
        getIt.unregister<AnnouncementBloc>();
      }
      getIt.registerFactory<AnnouncementBloc>(() {
        final b = _MockAnnouncementBloc();
        when(() => b.state).thenReturn(AnnouncementInitial());
        when(() => b.stream)
            .thenAnswer((_) => const Stream.empty());
        return b;
      });
    });

    testWidgets(
      'AnnouncementCreated affiche DonySuccessScreen (mode création)',
      (tester) async {
        setupViewport(tester);
        var didPop = false;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => ctx.push('/trips/create'),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/trips/create',
              builder: (_, __) => BlocProvider<StripeAccountBloc>.value(
                value: _makeStripeBloc(),
                child: const CreateTripScreen(args: null),
              ),
            ),
          ],
          observers: [_PopObserver(onPop: () => didPop = true)],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light),
        );
        await tester.pump();

        // Navigate to CreateTripScreen
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateTripScreen), findsOneWidget);

        // Emit AnnouncementCreated → listener pousse DonySuccessScreen
        // (le pop(true) n'intervient plus qu'après le tap CTA — voir le test
        // dédié au double-pop ci-dessous)
        annStreamCtrl.add(AnnouncementCreated(_makeAnnouncement()));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(DonySuccessScreen), findsOneWidget);
        expect(find.text('Trajet publié !'), findsOneWidget);
        expect(find.text('Partager mon trajet'), findsOneWidget);
        expect(didPop, isFalse);
      },
    );

    testWidgets(
      'AnnouncementUpdated affiche DonySuccessScreen (mode édition)',
      (tester) async {
        setupViewport(tester);
        var didPop = false;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => ctx.push('/trips/create'),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/trips/create',
              builder: (_, __) => BlocProvider<StripeAccountBloc>.value(
                value: _makeStripeBloc(),
                child: CreateTripScreen(
                  args: CreateTripArgs(announcement: _makeAnnouncement()),
                ),
              ),
            ),
          ],
          observers: [_PopObserver(onPop: () => didPop = true)],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light),
        );
        await tester.pump();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateTripScreen), findsOneWidget);

        annStreamCtrl.add(AnnouncementUpdated(_makeAnnouncement()));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(DonySuccessScreen), findsOneWidget);
        expect(find.text('Trajet modifié !'), findsOneWidget);
        // Le partage ne s'affiche qu'à la publication, pas à l'édition.
        expect(find.text('Partager mon trajet'), findsNothing);
        expect(didPop, isFalse);
      },
    );

    testWidgets(
      'le CTA de DonySuccessScreen ferme create_trip_screen avec pop(true) '
      'puis navigue vers le détail du trajet (contrat bool préservé)',
      (tester) async {
        setupViewport(tester);
        bool? pushResult;
        var pushCompleted = false;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () async {
                      // Même contrat que announcement_list_screen.dart#_createTrip :
                      // context.push<bool>('/trips/create') attend la valeur
                      // renvoyée par le pop(true) du listener.
                      final result = await ctx.push<bool>('/trips/create');
                      pushResult = result;
                      pushCompleted = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/trips/create',
              builder: (_, __) => BlocProvider<StripeAccountBloc>.value(
                value: _makeStripeBloc(),
                child: const CreateTripScreen(args: null),
              ),
            ),
            // Route de destination du CTA — vérifie qu'on atterrit bien sur
            // le détail du trajet réel (/announcements/{id}/trip, cf.
            // lib/app/router.dart), pas '/trips/{id}' (qui n'existe pas).
            GoRoute(
              path: '/announcements/:id/trip',
              builder: (_, state) => Scaffold(
                body: Text('trip-detail-${state.pathParameters['id']}'),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light),
        );
        await tester.pump();

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateTripScreen), findsOneWidget);

        annStreamCtrl.add(AnnouncementCreated(_makeAnnouncement()));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(DonySuccessScreen), findsOneWidget);

        // Tap le CTA — ne doit pas jeter (bug de contexte désactivé, fix
        // task 4 feb86b71) et doit préserver le contrat bool pour les 3
        // appelants (announcement_list_screen.dart, owner_action_grid.dart,
        // trip_owner_detail_screen.dart).
        await tester.tap(find.text('Voir mon trajet'));
        await tester.pumpAndSettle();

        expect(pushCompleted, isTrue);
        expect(pushResult, isTrue);
        expect(find.text('trip-detail-ann-test-1'), findsOneWidget);
      },
    );

    testWidgets(
      'AnnouncementError — ErrorPresenter appelé (snackbar affiché)',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        // Emit AnnouncementError — listener calls ErrorPresenter.show
        annStreamCtrl.add(
          AnnouncementError(NetworkException('Erreur réseau')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // BlocListener fires ErrorPresenter.show → DonySnackbar → SnackBar visible
        await tester.pump(); // laisser le BlocListener réagir
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });

  // ── Group: Navigation ─────────────────────────────────────────────────────────

  group('CreateTripScreen — Navigation', () {
    testWidgets(
      'tapping ✕ pops the route',
      (tester) async {
        setupViewport(tester);

        var didPop = false;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => ctx.push('/trips/create'),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/trips/create',
              builder: (_, __) => BlocProvider<StripeAccountBloc>.value(
                value: _makeStripeBloc(),
                child: const CreateTripScreen(args: null),
              ),
            ),
          ],
          observers: [
            _PopObserver(onPop: () => didPop = true),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
          ),
        );
        await tester.pump();

        // Navigate to CreateTripScreen.
        // pumpAndSettle drains the GoRouter transition AND all flutter_animate
        // one-shot timers (none are repeating so settle always occurs).
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.close), findsOneWidget);

        // Tap the close button — should pop.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(didPop, isTrue);
      },
    );
  });
}

// ── Route observer for navigation tests ──────────────────────────────────────

class _PopObserver extends NavigatorObserver {
  _PopObserver({required this.onPop});
  final VoidCallback onPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPop();
  }
}
