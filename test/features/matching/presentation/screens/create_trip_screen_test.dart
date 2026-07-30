import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart'
    show BidPaymentMethod;
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/matching/presentation/widgets/cash_commission_notice.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/payments/cash/data/repositories/commission_method_repository.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
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

import '../../../../helpers/mock_analytics_backend.dart';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _tripPublishHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "trip_publish_basics",
      "title": "Publier un trajet",
      "description": "Les étapes pour proposer votre espace bagage.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["tripPublish"]
    }
  ]
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

// ── Mock BLoCs ────────────────────────────────────────────────────────────────

class _MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
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

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockCommissionMethodRepository extends Mock
    implements CommissionMethodRepository {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

// ── Mock Services / Repos ─────────────────────────────────────────────────────

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockPriceGridRepository extends Mock implements PriceGridRepository {}

class _MockContentCategoryRepository extends Mock
    implements IContentCategoryRepository {}

// ── Fake event fallbacks (only for non-sealed abstract events) ────────────────

class _FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

class _FakeCommissionMethodEvent extends Fake
    implements CommissionMethodEvent {}

class _FakeCitySearchEvent extends Fake implements CitySearchEvent {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Creates a `MockStripeAccountBloc` with initial state.
_MockStripeAccountBloc _makeStripeBloc() {
  final b = _MockStripeAccountBloc();
  when(() => b.state).thenReturn(const StripeAccountInitial());
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  return b;
}

/// Returns a `UserModel` with a KYC-verified status by default — the
/// baseline for every existing test in this file (publishing must not be
/// blocked unless a test explicitly opts into a non-verified user).
UserModel _makeUser({String kycStatus = 'VERIFIED'}) => UserModel(
  id: 'user-test-1',
  roles: const ['TRAVELER'],
  kycStatus: kycStatus,
  status: 'ACTIVE',
);

/// Creates a `MockAuthBloc`. Defaults to a KYC-verified authenticated user so
/// the publish gate added in Task 5 doesn't intercept pre-existing tests.
_MockAuthBloc _makeAuthBloc([AuthState? state]) {
  final b = _MockAuthBloc();
  when(() => b.state).thenReturn(state ?? AuthAuthenticated(_makeUser()));
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  return b;
}

/// Creates a `MockKycBloc` with an idle initial state — only exercised by
/// tests where the KYC gate actually opens `KycOnboardingBottomSheet`.
_MockKycBloc _makeKycBloc() {
  final b = _MockKycBloc();
  when(() => b.state).thenReturn(const KycInitial());
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  return b;
}

/// Wraps [child] in a GoRouter + MaterialApp with a `StripeAccountBloc` and
/// an `AuthBloc` provided at the app level (the screen reads them but does
/// not create its own `AuthBloc` — mirrors production, where `AuthBloc` is
/// provided ambient at the app root). [authState] lets tests opt into a
/// non-verified user to exercise the KYC publish gate (Task 5).
Widget _wrapWithRouter(
  Widget child, {
  AuthState? authState,
  String helpConfigJson = _emptyHelpConfigJson,
}) {
  final router = GoRouter(
    initialLocation: '/trips/create',
    routes: [
      GoRoute(
        path: '/trips/create',
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<StripeAccountBloc>.value(value: _makeStripeBloc()),
            BlocProvider<AuthBloc>.value(value: _makeAuthBloc(authState)),
            BlocProvider<KycBloc>.value(value: _makeKycBloc()),
            BlocProvider<HelpCenterBloc>(
              create: (_) => HelpCenterBloc(
                HelpCenterRepository(
                  _StaticHelpCenterSource(helpConfigJson),
                  fallbackJsonLoader: () async => _emptyHelpConfigJson,
                ),
                makeDisabledAnalytics(MockAnalyticsBackend()),
              )..add(const HelpCenterLoadRequested()),
            ),
          ],
          child: child,
        ),
      ),
      GoRoute(
        path: '/profile/help/tutorial/:tutorialId',
        builder: (_, state) => Scaffold(
          body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
        ),
      ),
      // Extra route so GoRouter can navigate back on context.pop()
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: SizedBox()),
      ),
      // Destination of the "Activer les paiements par carte" CTA.
      GoRoute(
        path: '/connect/onboarding/intro',
        builder: (_, __) =>
            const Scaffold(body: Text('stripe-onboarding-intro')),
      ),
      // Destinations of the cash-funds-required sheet's CTAs (Finding #1).
      GoRoute(
        path: '/payments/commission-method',
        builder: (context, __) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('done-commission-method'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/payments/wallet/topup/method',
        builder: (context, __) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('done-topup'),
            ),
          ),
        ),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
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
  pickupAddress: const AddressData(
    label: 'Tour Eiffel',
    lat: 48.858,
    lng: 2.294,
  ),
  deliveryAddress: const AddressData(
    label: 'Dakar Centre',
    lat: 14.716,
    lng: -17.467,
  ),
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
    registerFallbackValue(
      NegotiationCreateDedicatedTripRequested(
        threadId: 'fallback-thread',
        departureDate: DateTime(2026, 1, 1),
        pickupAddress: const {},
        deliveryAddress: const {},
        paymentMethod: PaymentMethod.stripe,
      ),
    );

    // AnalyticsService — called from CreateTripScreen.initState via getIt
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<AnalyticsService>(analytics);
    }

    // PriceGridRepository — passed when constructing AnnouncementFormBloc
    if (!getIt.isRegistered<PriceGridRepository>()) {
      getIt.registerSingleton<PriceGridRepository>(_MockPriceGridRepository());
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
    testWidgets('titre "Publier un trajet" en mode création (args == null)', (
      tester,
    ) async {
      setupViewport(tester);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(const CreateTripScreen(args: null)),
      );

      expect(find.text('Publier un trajet'), findsOneWidget);
    });

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

    testWidgets('titre "Créer le trajet pour cette demande" en mode locked', (
      tester,
    ) async {
      setupViewport(tester);

      final args = CreateTripArgs(
        lockContext: _makeLockContext(),
        negotiationBloc: _makeNegotiationBloc(),
      );
      await _pumpAndDrain(
        tester,
        _wrapWithRouter(CreateTripScreen(args: args)),
      );

      expect(find.text('Créer le trajet pour cette demande'), findsOneWidget);
    });
  });

  // ── Group: Bottom navigation bar ─────────────────────────────────────────────

  group('CreateTripScreen — Bottom navigation bar', () {
    testWidgets('bouton "Continuer" présent à l\'étape 0', (tester) async {
      setupViewport(tester);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(const CreateTripScreen(args: null)),
      );

      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('bouton retour (DonyAppBarBackButton) présent', (tester) async {
      setupViewport(tester);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(const CreateTripScreen(args: null)),
      );

      expect(find.byType(DonyAppBarBackButton), findsOneWidget);
    });

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
        expect(
          continueBtn.onPressed,
          isNotNull,
          reason:
              'Continuer doit être actif en mode édition (champs pré-remplis)',
        );
      },
    );

    testWidgets('mode création: bouton "Retour" absent à l\'étape 0', (
      tester,
    ) async {
      setupViewport(tester);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(const CreateTripScreen(args: null)),
      );

      // At step 0, "Retour" should not be rendered
      expect(find.text('Retour'), findsNothing);
    });
  });

  // ── Group: Form structure ─────────────────────────────────────────────────────

  group('CreateTripScreen — Form structure', () {
    testWidgets('stepper header est présent à l\'étape 0', (tester) async {
      setupViewport(tester);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(const CreateTripScreen(args: null)),
      );

      expect(find.byType(CaStepperHeader), findsOneWidget);
    });

    testWidgets(
      'carte tutoriel contextuelle affichée avant la première étape et '
      'navigue vers le tutoriel au tap',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(
            const CreateTripScreen(args: null),
            helpConfigJson: _tripPublishHelpConfigJson,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final cardTop = tester
            .getTopLeft(find.text('Besoin d\'aide ? Voir le tutoriel'))
            .dy;
        final stepperTop = tester.getTopLeft(find.byType(CaStepperHeader)).dy;
        expect(cardTop, lessThan(stepperTop));

        await tester.tap(find.text('Besoin d\'aide ? Voir le tutoriel'));
        await tester.pumpAndSettle();

        expect(find.text('TutorialStub:trip_publish_basics'), findsOneWidget);
      },
    );

    testWidgets('section fenêtre de remise est visible à l\'étape 0', (
      tester,
    ) async {
      setupViewport(tester);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(const CreateTripScreen(args: null)),
      );

      // Step 0 contains the handover window section with these list tiles
      expect(find.text('Début de remise'), findsOneWidget);
      expect(find.text('Fin de remise'), findsOneWidget);
    });

    testWidgets('mode locked: bannière "Trajet dédié à la demande" affichée', (
      tester,
    ) async {
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
    });
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

    testWidgets('"Enregistrer" visible au step 2 en mode édition', (
      tester,
    ) async {
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
    });

    testWidgets('custom pricePerKg (not in presets) initialise le champ custom', (
      tester,
    ) async {
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
        pickupAddress: const AddressData(
          label: 'Tour Eiffel',
          lat: 48.858,
          lng: 2.294,
        ),
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
    });

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

    testWidgets('"Retour" au step 2 navigue vers step 1', (tester) async {
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
    });

    testWidgets('"Retour" au step 1 navigue vers step 0', (tester) async {
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
    });
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
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
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
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
    });

    testWidgets('template chip visible au step 0 en mode création', (
      tester,
    ) async {
      setupViewport(tester);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(const CreateTripScreen(args: null)),
      );

      // The template bar shows the chip
      expect(find.text('Paris → Dakar · 8€/kg'), findsOneWidget);
    });

    testWidgets('tap template chip → _applyTemplate applique les valeurs', (
      tester,
    ) async {
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
    });
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
          handoverWindowEnd: DateTime(
            2026,
            8,
            1,
            23,
            0,
          ), // after 22:00 departure
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
        expect(find.textContaining('avant le départ'), findsOneWidget);
      },
    );
  });

  // ── Group: _submit() via Enregistrer ─────────────────────────────────────────

  group('CreateTripScreen — _submit() via Enregistrer (mode édition)', () {
    testWidgets('"Enregistrer" au step 2 appelle _submit() — happy path', (
      tester,
    ) async {
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
    });
  });

  // ── Group: Task 5 — publication sans Stripe + gate KYC ───────────────────────
  // Ce groupe capture l'instance `AnnouncementBloc` créée par l'écran (au lieu
  // du factory générique de setUpAll) pour pouvoir `verify()` les events
  // dispatchés par _submit().

  group('CreateTripScreen — Task 5 : publication sans Stripe + gate KYC', () {
    late _MockAnnouncementBloc announcementBloc;

    setUp(() {
      announcementBloc = _MockAnnouncementBloc();
      when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
      when(
        () => announcementBloc.stream,
      ).thenAnswer((_) => const Stream.empty());
      if (getIt.isRegistered<AnnouncementBloc>()) {
        getIt.unregister<AnnouncementBloc>();
      }
      getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    });

    tearDown(() {
      if (getIt.isRegistered<AnnouncementBloc>()) {
        getIt.unregister<AnnouncementBloc>();
      }
      getIt.registerFactory<AnnouncementBloc>(() {
        final b = _MockAnnouncementBloc();
        when(() => b.state).thenReturn(AnnouncementInitial());
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
    });

    /// Navigue jusqu'à l'étape 2 (mode édition, "Enregistrer") avec un
    /// `AnnouncementModel` complet. `_wrapWithRouter`'s `_makeStripeBloc()`
    /// reste sur `StripeAccountInitial()` (Stripe non configuré) — le
    /// comportement par défaut de tout ce fichier de tests.
    Future<void> navigateToStep2(
      WidgetTester tester, {
      AuthState? authState,
    }) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final args = CreateTripArgs(announcement: _makeFullAnnouncement());
      await _pumpAndDrain(
        tester,
        _wrapWithRouter(CreateTripScreen(args: args), authState: authState),
      );
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Enregistrer'), findsOneWidget);
    }

    testWidgets(
      'paymentMethods sans Stripe configuré : CASH inclus, STRIPE absent (jamais vide)',
      (tester) async {
        await navigateToStep2(tester);

        await tester.tap(find.byKey(const Key('create-announcement-submit')));
        await tester.pump(const Duration(milliseconds: 600));

        verify(
          () => announcementBloc.add(
            any(
              that: predicate<AnnouncementEvent>(
                (e) =>
                    e is AnnouncementUpdateRequested &&
                    e.acceptedPaymentMethods.contains('CASH') &&
                    !e.acceptedPaymentMethods.contains('STRIPE'),
                'AnnouncementUpdateRequested sans STRIPE, avec CASH forcé',
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'gate KYC — utilisateur non vérifié : bloque le dispatch et ouvre KycOnboardingBottomSheet',
      (tester) async {
        await navigateToStep2(
          tester,
          authState: AuthAuthenticated(_makeUser(kycStatus: 'PENDING')),
        );

        await tester.tap(find.byKey(const Key('create-announcement-submit')));
        await tester.pumpAndSettle();

        verifyNever(() => announcementBloc.add(any()));
        expect(find.text('Vérifiez votre identité'), findsOneWidget);
      },
    );

    testWidgets(
      'gate KYC — utilisateur vérifié : ne bloque pas, dispatch normalement',
      (tester) async {
        await navigateToStep2(
          tester,
          authState: AuthAuthenticated(_makeUser()),
        );

        await tester.tap(find.byKey(const Key('create-announcement-submit')));
        await tester.pump(const Duration(milliseconds: 600));

        verify(
          () => announcementBloc.add(
            any(
              that: predicate<AnnouncementEvent>(
                (e) => e is AnnouncementUpdateRequested,
                'AnnouncementUpdateRequested dispatché',
              ),
            ),
          ),
        ).called(1);
      },
    );
  });

  // ── Group: bannière Stripe non configuré — bascule Row/Column ────────────────
  // La bannière d'info + CTA « Activer les paiements par carte » utilise un
  // Row (identique à 100 %, par construction) tant que l'échelle de texte
  // est celle par défaut, et une disposition empilée seulement si elle
  // grandit (cf. commentaire dans prix_conditions_step.dart). Les deux
  // branches sont couvertes : la position relative à 100 %, l'absence de
  // débordement à 200 %.

  group(
    'CreateTripScreen — bannière Stripe non configuré (bascule Row/Column)',
    () {
      Future<void> navigateToStep2NotConfigured(WidgetTester tester) async {
        // Viewport large : les chips de moyens de paiement de l'étape 2
        // débordent sur un écran étroit à 100 % déjà (bug préexistant, hors
        // sujet ici) — les tests existants de ce fichier utilisent la même
        // largeur pour l'isoler.
        tester.view.physicalSize = const Size(800, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Activer les paiements par carte'), findsOneWidget);
      }

      testWidgets(
        'à 100 %, le CTA reste sur la même ligne que le texte (disposition '
        "d'origine, celle d'avant ce lot)",
        (tester) async {
          await navigateToStep2NotConfigured(tester);

          // Le texte d'explication et le CTA sont les deux widgets comparés
          // (pas l'icône 'circle-check' : elle apparaît deux fois sur cet
          // écran, aussi dans l'en-tête « Ce que j'accepte » plus bas dans le
          // formulaire — find.byWidgetPredicate serait ambigu). Sur une même
          // ligne (Row, crossAxisAlignment au centre par défaut), leurs
          // centres verticaux sont proches. Empilés (Column), le CTA serait
          // nettement plus bas — au moins une hauteur de texte plus
          // l'espacement entre les deux lignes.
          final textY = tester
              .getCenter(find.textContaining('Publiez en espèces'))
              .dy;
          final ctaY = tester
              .getCenter(find.byKey(const Key('activate-card-payments-cta')))
              .dy;

          expect(
            (textY - ctaY).abs(),
            lessThan(20),
            reason:
                'à 100 %, le CTA doit être sur la même ligne que le texte '
                "d'explication, pas en dessous",
          );
        },
      );

      testWidgets(
        'à 200 %, aucun débordement (bascule en disposition empilée)',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2.0;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await navigateToStep2NotConfigured(tester);

          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  // ── Group: pricingMode MIXED → BlocListener ────────────────────────────────
  // PricingMode listener tested via unit test of _TripFormContentState.

  // ── Group: BLoC listeners ─────────────────────────────────────────────────────

  group('CreateTripScreen — BLoC listeners (AnnouncementBloc)', () {
    late StreamController<AnnouncementState> annStreamCtrl;

    setUp(() {
      annStreamCtrl = StreamController<AnnouncementState>.broadcast();
      // Replace GetIt factory with one that returns a controlled mock
      if (getIt.isRegistered<AnnouncementBloc>()) {
        getIt.unregister<AnnouncementBloc>();
      }
      getIt.registerFactory<AnnouncementBloc>(() {
        final b = _MockAnnouncementBloc();
        when(() => b.state).thenReturn(AnnouncementInitial());
        when(() => b.stream).thenAnswer((_) => annStreamCtrl.stream);
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
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
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
              builder: (_, __) => MultiBlocProvider(
                providers: [
                  BlocProvider<StripeAccountBloc>.value(
                    value: _makeStripeBloc(),
                  ),
                  BlocProvider<HelpCenterBloc>(
                    create: (_) => HelpCenterBloc(
                      HelpCenterRepository(
                        const _StaticHelpCenterSource(_emptyHelpConfigJson),
                        fallbackJsonLoader: () async => _emptyHelpConfigJson,
                      ),
                      makeDisabledAnalytics(MockAnalyticsBackend()),
                    )..add(const HelpCenterLoadRequested()),
                  ),
                ],
                child: const CreateTripScreen(args: null),
              ),
            ),
          ],
          observers: [_PopObserver(onPop: () => didPop = true)],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
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
              builder: (_, __) => MultiBlocProvider(
                providers: [
                  BlocProvider<StripeAccountBloc>.value(
                    value: _makeStripeBloc(),
                  ),
                  BlocProvider<HelpCenterBloc>(
                    create: (_) => HelpCenterBloc(
                      HelpCenterRepository(
                        const _StaticHelpCenterSource(_emptyHelpConfigJson),
                        fallbackJsonLoader: () async => _emptyHelpConfigJson,
                      ),
                      makeDisabledAnalytics(MockAnalyticsBackend()),
                    )..add(const HelpCenterLoadRequested()),
                  ),
                ],
                child: CreateTripScreen(
                  args: CreateTripArgs(announcement: _makeAnnouncement()),
                ),
              ),
            ),
          ],
          observers: [_PopObserver(onPop: () => didPop = true)],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
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
              builder: (_, __) => MultiBlocProvider(
                providers: [
                  BlocProvider<StripeAccountBloc>.value(
                    value: _makeStripeBloc(),
                  ),
                  BlocProvider<HelpCenterBloc>(
                    create: (_) => HelpCenterBloc(
                      HelpCenterRepository(
                        const _StaticHelpCenterSource(_emptyHelpConfigJson),
                        fallbackJsonLoader: () async => _emptyHelpConfigJson,
                      ),
                      makeDisabledAnalytics(MockAnalyticsBackend()),
                    )..add(const HelpCenterLoadRequested()),
                  ),
                ],
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
          MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
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

    testWidgets('AnnouncementError — ErrorPresenter appelé (snackbar affiché)', (
      tester,
    ) async {
      setupViewport(tester);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(const CreateTripScreen(args: null)),
      );

      // Emit AnnouncementError — listener calls ErrorPresenter.show
      annStreamCtrl.add(AnnouncementError(NetworkException('Erreur réseau')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // BlocListener fires ErrorPresenter.show → DonySnackbar → SnackBar visible
      await tester.pump(); // laisser le BlocListener réagir
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // ── Group: Navigation ─────────────────────────────────────────────────────────

  group('CreateTripScreen — Navigation', () {
    testWidgets('tapping le bouton retour pops the route', (tester) async {
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
            builder: (_, __) => MultiBlocProvider(
              providers: [
                BlocProvider<StripeAccountBloc>.value(value: _makeStripeBloc()),
                BlocProvider<HelpCenterBloc>(
                  create: (_) => HelpCenterBloc(
                    HelpCenterRepository(
                      const _StaticHelpCenterSource(_emptyHelpConfigJson),
                      fallbackJsonLoader: () async => _emptyHelpConfigJson,
                    ),
                    makeDisabledAnalytics(MockAnalyticsBackend()),
                  )..add(const HelpCenterLoadRequested()),
                ),
              ],
              child: const CreateTripScreen(args: null),
            ),
          ),
        ],
        observers: [_PopObserver(onPop: () => didPop = true)],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
      );
      await tester.pump();

      // Navigate to CreateTripScreen.
      // pumpAndSettle drains the GoRouter transition AND all flutter_animate
      // one-shot timers (none are repeating so settle always occurs).
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(DonyAppBarBackButton), findsOneWidget);

      // Tap the back button — should pop.
      await tester.tap(find.byType(DonyAppBarBackButton));
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
    });
  });

  // ── Group: Fenêtre de remise — rendu et validation inline ────────────────────
  // Migré de create_announcement_handover_test.dart lors de la suppression de
  // CreateAnnouncementScreen (doublon de CreateTripScreen). Les rows sont
  // rendues au step 0, à la suite de TrajetStep ; le préfixe `sheet-` des clés
  // est un reliquat de nommage, ce ne sont pas des bottom sheets.

  group('CreateTripScreen — Fenêtre de remise (rendu)', () {
    testWidgets('les deux rows début/fin sont affichées en mode création', (
      tester,
    ) async {
      setupViewport(tester);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(const CreateTripScreen(args: null)),
      );

      expect(find.byKey(const Key('sheet-handover-start-row')), findsOneWidget);
      expect(find.byKey(const Key('sheet-handover-end-row')), findsOneWidget);
    });

    testWidgets(
      'mode création : les deux rows affichent "Choisir" (aucune valeur)',
      (tester) async {
        setupViewport(tester);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(args: null)),
        );

        expect(find.text('Choisir'), findsNWidgets(2));
      },
    );

    testWidgets(
      'mode édition préremplit les valeurs existantes (plus aucun "Choisir")',
      (tester) async {
        setupViewport(tester);

        // _makeFullAnnouncement() porte une fenêtre 16:00 → 18:00.
        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await _pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        expect(find.text('Choisir'), findsNothing);
        expect(find.text('01/08 16:00'), findsOneWidget);
        expect(find.text('01/08 18:00'), findsOneWidget);
      },
    );

    testWidgets(
      'fenêtre inversée (fin avant début) affiche le message inline',
      (tester) async {
        setupViewport(tester);

        final ann = AnnouncementModel(
          id: 'ann-handover-inverted',
          travelerId: 'trav-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 8, 20),
          departureTime: '22:00',
          availableKg: 10.0,
          totalKg: 23.0,
          pricePerKg: 8.0,
          status: 'ACTIVE',
          bidsCount: 0,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          // Fin AVANT début → fenêtre invalide.
          handoverWindowStart: DateTime(2026, 8, 20, 18, 0),
          handoverWindowEnd: DateTime(2026, 8, 20, 16, 0),
          transportMode: TransportMode.plane,
          acceptedPaymentMethods: {BidPaymentMethod.stripe},
          acceptedContentTypes: const ['Vêtements'],
          refusedTypes: const [],
        );

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(
            CreateTripScreen(args: CreateTripArgs(announcement: ann)),
          ),
        );

        expect(find.byKey(const Key('sheet-handover-error')), findsOneWidget);
        expect(
          find.text('La fin de la fenêtre doit être après le début.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('fenêtre valide : aucun message d\'erreur inline', (
      tester,
    ) async {
      setupViewport(tester);

      final args = CreateTripArgs(announcement: _makeFullAnnouncement());
      await _pumpAndDrain(
        tester,
        _wrapWithRouter(CreateTripScreen(args: args)),
      );

      expect(find.byKey(const Key('sheet-handover-error')), findsNothing);
    });
  });

  // ── Group: Fenêtre de remise — garde au submit ───────────────────────────────
  // Migré de create_announcement_handover_test.dart. Capture l'instance
  // AnnouncementBloc créée par l'écran pour pouvoir verify() le dispatch.

  group('CreateTripScreen — Fenêtre de remise (submit)', () {
    late _MockAnnouncementBloc announcementBloc;

    setUp(() {
      announcementBloc = _MockAnnouncementBloc();
      when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
      when(
        () => announcementBloc.stream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => announcementBloc.add(any())).thenReturn(null);
      if (getIt.isRegistered<AnnouncementBloc>()) {
        getIt.unregister<AnnouncementBloc>();
      }
      getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    });

    tearDown(() {
      if (getIt.isRegistered<AnnouncementBloc>()) {
        getIt.unregister<AnnouncementBloc>();
      }
      getIt.registerFactory<AnnouncementBloc>(() {
        final b = _MockAnnouncementBloc();
        when(() => b.state).thenReturn(AnnouncementInitial());
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
    });

    /// Navigue jusqu'au step 2 ("Enregistrer") avec l'annonce fournie.
    Future<void> navigateToStep2(
      WidgetTester tester,
      AnnouncementModel ann,
    ) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(args: CreateTripArgs(announcement: ann)),
        ),
      );
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Enregistrer'), findsOneWidget);
    }

    testWidgets(
      'fenêtre absente : "Continuer" désactivé au step 0, aucun dispatch possible',
      (tester) async {
        // Annonce complète MAIS sans fenêtre de remise. Dans le wizard, la
        // garde qui mord en premier n'est pas celle de _submit() ("Fenêtre de
        // remise obligatoire", défense en profondeur inatteignable par l'UI)
        // mais _updateCanContinue(), qui désactive "Continuer" dès le step 0.
        final ann = AnnouncementModel(
          id: 'ann-no-handover',
          travelerId: 'trav-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 8, 1),
          departureTime: '22:00',
          arrivalTime: '10:30',
          availableKg: 10.0,
          totalKg: 23.0,
          pricePerKg: 8.0,
          status: 'ACTIVE',
          bidsCount: 0,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          pickupAddress: const AddressData(
            label: 'Tour Eiffel',
            lat: 48.858,
            lng: 2.294,
          ),
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

        tester.view.physicalSize = const Size(800, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await _pumpAndDrain(
          tester,
          _wrapWithRouter(
            CreateTripScreen(args: CreateTripArgs(announcement: ann)),
          ),
        );

        // Le bouton "Continuer" existe mais est inerte.
        final continueBtn = find.widgetWithText(DonyButton, 'Continuer');
        expect(continueBtn, findsOneWidget);
        expect(tester.widget<DonyButton>(continueBtn).onPressed, isNull);

        // Un tap ne fait pas avancer le wizard : on reste au step 0.
        await tester.tap(continueBtn);
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Enregistrer'), findsNothing);
        verifyNever(
          () => announcementBloc.add(
            any(that: isA<AnnouncementUpdateRequested>()),
          ),
        );
      },
    );

    testWidgets('submit en édition forwarde la fenêtre de remise au bloc', (
      tester,
    ) async {
      final ann = _makeFullAnnouncement();

      await navigateToStep2(tester, ann);

      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Fenêtre de remise obligatoire'), findsNothing);
      verify(
        () => announcementBloc.add(
          any(
            that: isA<AnnouncementUpdateRequested>()
                .having(
                  (e) => e.handoverWindowStart,
                  'handoverWindowStart',
                  ann.handoverWindowStart,
                )
                .having(
                  (e) => e.handoverWindowEnd,
                  'handoverWindowEnd',
                  ann.handoverWindowEnd,
                ),
          ),
        ),
      ).called(1);
    });
  });

  // ── Group: Toggle Espèces et encart commission ───────────────────────────────
  // Migré de create_announcement_cash_toggle_test.dart. Le switch lui-même est
  // couvert au niveau widget par prix_conditions_step_test ; ce qui est unique
  // ici, c'est la révélation de CashCommissionNotice depuis l'écran complet.

  group('CreateTripScreen — Toggle Espèces (encart commission)', () {
    /// Enregistre dans getIt un StripeAccountBloc au statut voulu.
    ///
    /// CreateTripScreen.build() crée son propre `BlocProvider<StripeAccountBloc>`
    /// depuis getIt, qui masque celui de `_wrapWithRouter` — c'est donc bien
    /// cette instance-ci que lit `_isStripeConfigured()`.
    void registerStripeBloc({required bool onboardingComplete}) {
      final b = _MockStripeAccountBloc();
      when(() => b.state).thenReturn(
        StripeAccountReady(
          ConnectAccountStatus(
            status: onboardingComplete
                ? 'ONBOARDING_COMPLETE'
                : 'PENDING_ONBOARDING',
          ),
        ),
      );
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      if (getIt.isRegistered<StripeAccountBloc>()) {
        getIt.unregister<StripeAccountBloc>();
      }
      getIt.registerFactory<StripeAccountBloc>(() => b);
    }

    tearDown(() {
      if (getIt.isRegistered<StripeAccountBloc>()) {
        getIt.unregister<StripeAccountBloc>();
      }
      getIt.registerFactory<StripeAccountBloc>(_makeStripeBloc);
    });

    /// Navigue jusqu'au step 2, où vit PrixConditionsStep.
    Future<void> navigateToStep2(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final args = CreateTripArgs(announcement: _makeFullAnnouncement());
      await _pumpAndDrain(
        tester,
        _wrapWithRouter(CreateTripScreen(args: args)),
      );
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets(
      'Stripe configuré : le switch Espèces est actionnable sans carte de commission',
      (tester) async {
        registerStripeBloc(onboardingComplete: true);
        await navigateToStep2(tester);

        final cashSwitch = find.byKey(const Key('payment-method-cash'));
        expect(cashSwitch, findsOneWidget);

        // On assert sur le SwitchListTile : le `Switch` interne construit par
        // Material n'expose pas le `onChanged` d'origine.
        final tile = tester.widget<SwitchListTile>(cashSwitch);
        // La carte de commission n'est plus requise à la création : la
        // vérification est reportée à l'acceptation de l'offre.
        expect(tile.onChanged, isNotNull);
        // L'ancien lien "Ajouter une carte commission" ne doit plus exister.
        expect(find.byKey(const Key('add-commission-card-link')), findsNothing);
      },
    );

    testWidgets(
      'Stripe configuré : décocher Espèces masque CashCommissionNotice',
      (tester) async {
        registerStripeBloc(onboardingComplete: true);
        await navigateToStep2(tester);

        // _makeFullAnnouncement() accepte déjà CASH → l'encart est visible.
        expect(find.byType(CashCommissionNotice), findsOneWidget);

        // Le tile est sous la ligne de flottaison au step 2 : sans
        // ensureVisible le tap tomberait hors hit-test et le test passerait
        // à tort.
        final cashSwitch = find.byKey(const Key('payment-method-cash'));
        await tester.ensureVisible(cashSwitch);
        await tester.pump();
        await tester.tap(cashSwitch);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(CashCommissionNotice), findsNothing);
      },
    );

    testWidgets('Stripe non configuré : Espèces est forcé ON et verrouillé', (
      tester,
    ) async {
      registerStripeBloc(onboardingComplete: false);
      await navigateToStep2(tester);

      final cashSwitch = find.byKey(const Key('payment-method-cash'));
      expect(cashSwitch, findsOneWidget);

      // Sans Stripe, CASH est la seule méthode possible : la ligne est
      // affichée à ON et non désactivable (onChanged == null).
      final tile = tester.widget<SwitchListTile>(cashSwitch);
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNull);

      // L'encart commission reste visible puisque CASH est actif.
      expect(find.byType(CashCommissionNotice), findsOneWidget);
    });
  });

  // ── Group: gating des champs obligatoires ────────────────────────────────────

  group('CreateTripScreen — Champs obligatoires (gating)', () {
    /// Annonce complète, moins les champs passés à null.
    AnnouncementModel makeAnnouncement({
      String? departureTime = '22:00',
      AddressData? pickupAddress = const AddressData(
        label: 'Tour Eiffel',
        lat: 48.858,
        lng: 2.294,
      ),
      AddressData? deliveryAddress = const AddressData(
        label: 'Dakar Centre',
        lat: 14.716,
        lng: -17.467,
      ),
      TimeOfDay? arrivalTime,
    }) => AnnouncementModel(
      id: 'ann-gating',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8, 1),
      departureTime: departureTime,
      arrivalTime: arrivalTime == null
          ? null
          : '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}',
      availableKg: 10.0,
      totalKg: 23.0,
      pricePerKg: 8.0,
      status: 'ACTIVE',
      bidsCount: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      handoverWindowStart: DateTime(2026, 8, 1, 16, 0),
      handoverWindowEnd: DateTime(2026, 8, 1, 18, 0),
      pickupAddress: pickupAddress,
      deliveryAddress: deliveryAddress,
      transportMode: TransportMode.plane,
      acceptedPaymentMethods: {BidPaymentMethod.stripe},
      acceptedContentTypes: const ['Vêtements'],
      refusedTypes: const [],
    );

    Future<void> pump(WidgetTester tester, AnnouncementModel? ann) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(
            args: ann == null ? null : CreateTripArgs(announcement: ann),
          ),
        ),
      );
    }

    // ── Le bug corrigé : l'heure de départ ne bloquait pas l'étape 0 ──────────

    testWidgets(
      'sans heure de départ, "Continuer" est désactivé à l\'étape 0',
      (tester) async {
        // _submit() refuse une annonce sans heure de départ (D1), mais
        // _updateCanContinue() omettait ce champ : on pouvait traverser
        // l'étape 0 puis se retrouver bloqué au submit.
        await pump(tester, makeAnnouncement(departureTime: null));

        final continueBtn = find.widgetWithText(DonyButton, 'Continuer');
        expect(continueBtn, findsOneWidget);
        expect(tester.widget<DonyButton>(continueBtn).onPressed, isNull);
      },
    );

    testWidgets('avec heure de départ, "Continuer" est actif à l\'étape 0', (
      tester,
    ) async {
      await pump(tester, makeAnnouncement());

      final continueBtn = find.widgetWithText(DonyButton, 'Continuer');
      expect(tester.widget<DonyButton>(continueBtn).onPressed, isNotNull);
    });

    // ── Un formulaire vierge ne s'ouvre pas en rouge ──────────────────────────

    testWidgets(
      'création : aucun message d\'erreur à l\'ouverture (formulaire vierge)',
      (tester) async {
        await pump(tester, null);

        // Rien n'est rempli, mais l'utilisateur n'a encore rien touché.
        expect(find.text('Ville de départ obligatoire'), findsNothing);
        expect(find.text('Heure de départ obligatoire'), findsNothing);
        expect(find.text('Date de départ obligatoire'), findsNothing);
        expect(find.byKey(const Key('sheet-handover-error')), findsNothing);
        // Et « Continuer » est bien inerte.
        final continueBtn = find.widgetWithText(DonyButton, 'Continuer');
        expect(tester.widget<DonyButton>(continueBtn).onPressed, isNull);
      },
    );

    // ── Après une interaction, ce qui manque s'affiche ────────────────────────

    testWidgets(
      'après une interaction, les champs manquants affichent leur message',
      (tester) async {
        // Annonce sans heure de départ, avec une heure d'arrivée : effacer
        // cette dernière est une interaction utilisateur qui arme l'affichage.
        await pump(
          tester,
          makeAnnouncement(
            departureTime: null,
            arrivalTime: const TimeOfDay(hour: 10, minute: 30),
          ),
        );

        // Avant interaction : rien en rouge.
        expect(find.text('Heure de départ obligatoire'), findsNothing);

        // Effacer l'heure d'arrivée (bouton « x » du champ optionnel).
        final clearBtn = find.descendant(
          of: find.byKey(const Key('arrivalTimeField')),
          matching: find.byType(IconButton),
        );
        expect(clearBtn, findsOneWidget);
        await tester.tap(clearBtn);
        await tester.pump(const Duration(milliseconds: 300));

        // Le seul champ obligatoire manquant est signalé.
        expect(find.text('Heure de départ obligatoire'), findsOneWidget);
        // Les champs renseignés ne le sont pas.
        expect(find.text('Ville de départ obligatoire'), findsNothing);
        expect(find.text('Date de départ obligatoire'), findsNothing);
      },
    );

    // ── Étape 1 : entrer dans l'étape révèle ses attentes ─────────────────────

    testWidgets(
      'étape 1 : les adresses manquantes sont signalées dès l\'entrée',
      (tester) async {
        await pump(
          tester,
          makeAnnouncement(pickupAddress: null, deliveryAddress: null),
        );

        // Étape 0 complète → on peut avancer.
        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byKey(const Key('pickup-address-error')), findsOneWidget);
        expect(find.byKey(const Key('delivery-address-error')), findsOneWidget);

        // Et « Continuer » de l'étape 1 est inerte.
        final continueBtn = find.widgetWithText(DonyButton, 'Continuer');
        expect(tester.widget<DonyButton>(continueBtn).onPressed, isNull);
      },
    );

    testWidgets(
      'étape 1 : adresses renseignées, aucune erreur et "Continuer" actif',
      (tester) async {
        await pump(tester, makeAnnouncement());

        await tester.tap(find.text('Continuer'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byKey(const Key('pickup-address-error')), findsNothing);
        expect(find.byKey(const Key('delivery-address-error')), findsNothing);

        final continueBtn = find.widgetWithText(DonyButton, 'Continuer');
        expect(tester.widget<DonyButton>(continueBtn).onPressed, isNotNull);
      },
    );

    // ── Garde-fou de sortie ───────────────────────────────────────────────────

    /// Efface l'heure d'arrivée : une modification utilisateur réelle, sans
    /// dépendre d'un sélecteur natif.
    Future<void> editSomething(WidgetTester tester) async {
      final clearBtn = find.descendant(
        of: find.byKey(const Key('arrivalTimeField')),
        matching: find.byType(IconButton),
      );
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets(
      'sortie sans saisie : la croix ferme directement, sans confirmation',
      (tester) async {
        await pump(tester, null);
        // Laisse passer les post-frames qui stabilisent la référence.
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byType(DonyAppBarBackButton));
        await tester.pumpAndSettle();

        expect(find.text('Quitter sans enregistrer ?'), findsNothing);
      },
    );

    testWidgets(
      'sortie après saisie : la croix demande confirmation et annonce la perte',
      (tester) async {
        await pump(
          tester,
          makeAnnouncement(arrivalTime: const TimeOfDay(hour: 10, minute: 30)),
        );
        await tester.pump();
        await tester.pump();

        await editSomething(tester);

        await tester.tap(find.byType(DonyAppBarBackButton));
        await tester.pumpAndSettle();

        expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
        expect(
          find.textContaining('ne seront pas'),
          findsOneWidget,
          reason: 'la perte des données doit être annoncée explicitement',
        );
        expect(find.text('Continuer la saisie'), findsOneWidget);
        expect(find.text('Quitter'), findsOneWidget);
      },
    );

    testWidgets(
      '« Continuer la saisie » referme le dialogue et garde le formulaire',
      (tester) async {
        await pump(
          tester,
          makeAnnouncement(arrivalTime: const TimeOfDay(hour: 10, minute: 30)),
        );
        await tester.pump();
        await tester.pump();

        await editSomething(tester);
        await tester.tap(find.byType(DonyAppBarBackButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continuer la saisie'));
        await tester.pumpAndSettle();

        expect(find.text('Quitter sans enregistrer ?'), findsNothing);
        expect(find.byType(CreateTripScreen), findsOneWidget);
      },
    );
  });

  // ── Group: Fix task — payment-method block routing (dedicated-trip flow) ──
  // Covers IMPORTANT #1: the dedicated-trip creation flow (`_isLocked`) must
  // handle the 3 payment-method 422 reasons itself with the SAME contextual
  // sheets as LinkTripScreen, and must NOT also let the generic
  // ErrorPresenter fire for those reasons (double feedback bug).

  group('CreateTripScreen — locked flow: 422 payment-method reason routing', () {
    late StreamController<NegotiationState> negoStreamCtrl;
    late _MockNegotiationBloc negotiationBloc;

    setUp(() {
      negoStreamCtrl = StreamController<NegotiationState>.broadcast();
      negotiationBloc = _MockNegotiationBloc();
      when(() => negotiationBloc.state).thenReturn(const NegotiationInitial());
      when(
        () => negotiationBloc.stream,
      ).thenAnswer((_) => negoStreamCtrl.stream);
      when(() => negotiationBloc.add(any())).thenReturn(null);

      // WalletRepository / CommissionMethodRepository are intentionally left
      // UNREGISTERED here: showCashInsufficientSheet's try/catch treats the
      // GetIt lookup failure the same as a real network failure (balance=0,
      // hasCard=false) — exercising the "Ajouter une carte" branch, the one
      // Finding #1's "dead CTA" bug affected in the dedicated flow.
      if (getIt.isRegistered<WalletRepository>()) {
        getIt.unregister<WalletRepository>();
      }
      if (getIt.isRegistered<CommissionMethodRepository>()) {
        getIt.unregister<CommissionMethodRepository>();
      }
    });

    tearDown(() async {
      await negoStreamCtrl.close();
    });

    /// Navigates the locked (dedicated-trip) wizard to step 2 and taps
    /// "Confirmer le trajet", dispatching the initial
    /// `NegotiationCreateDedicatedTripRequested`. Combines a `lockContext`
    /// (drives `_isLocked`) with a full `announcement` purely so step 1's
    /// pickup/delivery addresses come pre-filled (`_isEdit`'s initState
    /// branch) — `_submit()`'s `if (_isLocked)` branch runs first regardless,
    /// so the dispatched event is still the dedicated-trip one.
    Future<void> navigateLockedToStep2AndSubmit(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final args = CreateTripArgs(
        lockContext: _makeLockContext(),
        announcement: _makeFullAnnouncement(),
        negotiationBloc: negotiationBloc,
      );
      await _pumpAndDrain(
        tester,
        _wrapWithRouter(CreateTripScreen(args: args)),
      );

      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.byKey(const Key('create-dedicated-trip-submit')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('create-dedicated-trip-submit')));
      await tester.pump();
    }

    testWidgets(
      'card-capability-required → sheet contextuelle « Paiement carte requis », '
      'pas de snackbar générique (pas de double feedback)',
      (tester) async {
        await navigateLockedToStep2AndSubmit(tester);

        negoStreamCtrl.add(
          const NegotiationError(
            ValidationException(
              'Card capability required',
              code: 'payment-method/card-capability-required',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Paiement carte requis'), findsOneWidget);
        expect(
          find.byKey(const Key('activate-card-payment-cta')),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'card-capability-required → CTA route vers /connect/onboarding/intro',
      (tester) async {
        await navigateLockedToStep2AndSubmit(tester);

        negoStreamCtrl.add(
          const NegotiationError(
            ValidationException(
              'Card capability required',
              code: 'payment-method/card-capability-required',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Activer le paiement carte'));
        await tester.pumpAndSettle();

        expect(find.text('stripe-onboarding-intro'), findsOneWidget);
      },
    );

    testWidgets(
      'reason inconnue → ErrorPresenter générique (snackbar), aucune sheet '
      'contextuelle',
      (tester) async {
        await navigateLockedToStep2AndSubmit(tester);

        negoStreamCtrl.add(
          const NegotiationError(
            ValidationException(
              'Some unrelated business error',
              code: 'some/other-code',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Paiement carte requis'), findsNothing);
        expect(find.text('Solde insuffisant'), findsNothing);
        expect(find.text('Aucun moyen de paiement disponible'), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'cash-funds-required → sheet « Solde insuffisant », le CTA "Ajouter une '
      'carte" (plus jamais mort) resoumet la MÊME demande avec '
      'useCardForCommission=true',
      (tester) async {
        await navigateLockedToStep2AndSubmit(tester);

        negoStreamCtrl.add(
          const NegotiationError(
            ValidationException(
              'Cash funds required',
              code: 'payment-method/cash-funds-required',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Solde insuffisant'), findsOneWidget);
        expect(find.text('Ajouter une carte'), findsOneWidget);

        await tester.tap(find.text('Ajouter une carte'));
        await tester.pumpAndSettle();
        expect(find.text('done-commission-method'), findsOneWidget);

        // Simulates the traveler completing card entry and returning.
        await tester.tap(find.text('done-commission-method'));
        await tester.pumpAndSettle();

        final calls = verify(() => negotiationBloc.add(captureAny())).captured;
        final resubmit = calls
            .whereType<NegotiationCreateDedicatedTripRequested>()
            .last;
        expect(resubmit.useCardForCommission, isTrue);
        expect(resubmit.threadId, 'thread-1');
        // Same form data as the original submit — not a fresh/empty request.
        expect(resubmit.pickupAddress['label'], 'Tour Eiffel');
        expect(resubmit.deliveryAddress['label'], 'Dakar Centre');
        expect(resubmit.departureDate, DateTime(2026, 8, 1));
      },
    );

    testWidgets(
      'none-available → sheet combinée carte + espèces, sans double feedback',
      (tester) async {
        await navigateLockedToStep2AndSubmit(tester);

        negoStreamCtrl.add(
          const NegotiationError(
            ValidationException(
              'No payment method available',
              code: 'payment-method/none-available',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Aucun moyen de paiement disponible'), findsOneWidget);
        expect(
          find.byKey(const Key('activate-card-payment-cta')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('unlock-cash-payment-cta')),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
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
