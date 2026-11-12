import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/recent_city_store.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/trip_legs_cubit.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart'
    show BidPaymentMethod;
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/trip_form_draft.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_preview_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/cash_commission_notice.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/arrival_day_chips.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/conditions_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/mode_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/transport_mode_row.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_step.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_active.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/repositories/commission_method_repository.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:dony/features/traveler_status/presentation/publish_blocked_screen.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/ai_form_draft_test_doubles.dart';
import '../../../../helpers/currency_test_doubles.dart';
import '../../../../helpers/form_draft_test_doubles.dart';
import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';
import '../../../../helpers/mock_recent_city_store.dart';
import '../../../video_modal/moment_test_support.dart';

const _emptyHelpConfigJson = '''
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

// ── Mock BLoCs ────────────────────────────────────────────────────────────────

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

class _MockTripTemplateRepository extends Mock
    implements TripTemplateRepository {}

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

class _MockMobileMoneyAccountBloc
    extends MockBloc<MobileMoneyAccountEvent, MobileMoneyAccountState>
    implements MobileMoneyAccountBloc {}

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

// ── Mock Services / Repos ─────────────────────────────────────────────────────

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockTravelerStatusRepository extends Mock
    implements TravelerStatusRepository {}

class _MockGpProRepository extends Mock implements GpProRepository {}

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
  when(() => b.isClosed).thenReturn(false);
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
  when(() => b.isClosed).thenReturn(false);
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
///
/// [locale] is left `null` by default: no `AppLocalizations` delegate is
/// mounted, and `context.l10n` falls back to `AppL10n.current` (driven by
/// `Intl.defaultLocale`, see `useEnglish()`) — the existing behavior of every
/// test in this file. Passing a [locale] mounts the real
/// `AppLocalizations.localizationsDelegates` instead, so `Localizations.of`
/// resolves for real: used by the language-reactivity test below, which
/// rebuilds with a different [locale] to prove the UI actually reacts to a
/// live language change, not just to the `Intl.defaultLocale` shortcut.
Widget _wrapWithRouter(
  Widget child, {
  AuthState? authState,
  String helpConfigJson = _emptyHelpConfigJson,
  Locale? locale,
  bool use24h = false,
}) {
  final router = GoRouter(
    initialLocation: '/trips/create',
    routes: [
      GoRoute(
        path: '/trips/create',
        builder: (_, _) => MultiBlocProvider(
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
      // Limite mensuelle de trajets : écran de blocage et formulaire GP Pro.
      GoRoute(
        path: '/trips/publish-blocked',
        builder: (_, state) {
          final args = state.extra! as PublishBlockedArgs;
          return PublishBlockedScreen(
            eligibility: args.eligibility,
            source: args.source,
          );
        },
      ),
      GoRoute(
        path: '/profile/gp-pro',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: context.pop,
            child: const Text('formulaire GP Pro'),
          ),
        ),
      ),
      // Extra route so GoRouter can navigate back on context.pop()
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: SizedBox()),
      ),
      // Destinations des boutons de l'écran de succès. Ici le formulaire est
      // SEUL dans la pile (initialLocation), comme en prod quand l'intro de
      // publication, atteinte par un `go`, le remplace par pushReplacement.
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home-stub')),
      ),
      GoRoute(
        path: '/announcements/trips',
        builder: (_, state) => Scaffold(
          body: Text('trips-list-${state.uri.queryParameters['filter']}'),
        ),
      ),
      GoRoute(
        path: '/announcements/:id/trip',
        builder: (_, state) =>
            Scaffold(body: Text('trip-detail-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/announcements/:id/affiche',
        builder: (_, state) =>
            Scaffold(body: Text('trip-poster-${state.pathParameters['id']}')),
      ),
      // Destination of the "Activer les paiements par carte" CTA.
      GoRoute(
        path: '/connect/onboarding/intro',
        builder: (_, _) =>
            const Scaffold(body: Text('stripe-onboarding-intro')),
      ),
      // Destinations of the cash-funds-required sheet's CTAs (Finding #1).
      GoRoute(
        path: '/payments/commission-method',
        builder: (context, _) => Scaffold(
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
        builder: (context, _) => Scaffold(
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

  // Téléphone réglé en 24 h, comme en France : le sélecteur d'heure en
  // saisie clavier n'accepte « 18 » qu'à cette condition.
  Widget force24h(BuildContext c, Widget? child) => MediaQuery(
    data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
    child: child!,
  );
  return locale == null
      ? MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          builder: use24h ? force24h : null,
        )
      : MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
}

/// Returns a minimal `AnnouncementModel` suitable for edit-mode tests.
AnnouncementModel _makeAnnouncement() => AnnouncementModel(
  id: 'ann-test-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8),
  availableKg: 10.0,
  totalKg: 23.0,
  pricePerKg: 8.0,
  status: 'ACTIVE',
  bidsCount: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Returns a complete `AnnouncementModel` that passes ALL step-0 validation:
/// • departure city, arrival city, departure date
/// • handoverDeadline < handoverDeadline < departure time
/// • pickupAddress + deliveryAddress (enables step-1 → step-2 navigation)
/// • departureTime + arrivalTime (covers TimeOfDay parsing in initState)
/// • acceptedContentTypes + refusedTypes (covers content-type init code)
AnnouncementModel _makeFullAnnouncement({
  TripStops? stops,
  String currency = 'EUR',
  String status = 'ACTIVE',
  double pricePerKg = 8.0,
  Set<BidPaymentMethod> acceptedPaymentMethods = const {
    BidPaymentMethod.stripe,
    BidPaymentMethod.cash,
  },
  bool? currencyEditable,
  DateTime? departureDate,
  DateTime? handoverDeadline,
  double availableKg = 10.0,
  String? capacityUnit,
  TransportMode transportMode = TransportMode.plane,
  ItemSize? maxItemSize,
  double? maxParcelWeightKg,
  DateTime? arrivalDate,
  String? arrivalTime = '10:30',
}) => AnnouncementModel(
  id: 'ann-full-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: departureDate ?? DateTime(2026, 8),
  // 22:00 departure → handoverEnd 18:00 is safely before departure
  departureTime: '22:00',
  arrivalTime: arrivalTime,
  arrivalDate: arrivalDate,
  availableKg: availableKg,
  totalKg: 23.0,
  pricePerKg: pricePerKg,
  status: status,
  bidsCount: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  handoverDeadline: handoverDeadline ?? DateTime(2026, 8, 1, 18),
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
  transportMode: transportMode,
  stops: stops,
  acceptedPaymentMethods: acceptedPaymentMethods,
  acceptedContentTypes: const ['Vêtements', 'Médicaments'],
  refusedTypes: const ['Produits dangereux'],
  currency: currency,
  currencyEditable: currencyEditable,
  capacityUnit: capacityUnit,
  maxItemSize: maxItemSize,
  maxParcelWeightKg: maxParcelWeightKg,
);

/// Returns a minimal `LockedTripContext` suitable for locked-mode tests.
LockedTripContext _makeLockContext() => LockedTripContext(
  threadId: 'thread-1',
  packageRequestId: 'req-1',
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  desiredDate: DateTime(2026, 9),
  dateToleranceDays: 5,
  weightKg: 5.0,
  transportMode: TransportMode.plane,
  agreedPriceEur: 50.0,
);

/// Minimal `NegotiationThread` fixture for `NegotiationLoaded`/`NegotiationError`
/// state pushes in tests that don't care about most fields — mirrors the
/// `_fakeThread` helper in negotiation_bloc_test.dart.
NegotiationThread _fakeThread({
  String id = 'thread-new-1',
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
}) => NegotiationThread(
  id: id,
  packageRequestId: 'req-1',
  travelerId: 'trav-1',
  travelerTravelDate: DateTime(2026, 9),
  travelerAvailableKg: 5,
  status: status,
  currentPriceEur: 50,
  roundsCount: 1,
  lastActivityAt: DateTime(2026, 8, 16),
  createdAt: DateTime(2026, 8, 16),
  messages: const [],
);

/// Creates a pre-configured `NegotiationBloc` mock.
_MockNegotiationBloc _makeNegotiationBloc() {
  final b = _MockNegotiationBloc();
  when(() => b.state).thenReturn(const NegotiationInitial());
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  return b;
}

/// Étape du brouillon pour un index de l'écran à trois étapes.
TripFormStep _stepIdAt(int step) => switch (step) {
  1 => TripFormStep.capacite,
  2 => TripFormStep.prix,
  _ => TripFormStep.trajet,
};

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
    registerFallbackValue(const StripeAccountStatusLoaded());
    registerFallbackValue(const MobileMoneyAccountsRequested());
    registerFallbackValue(const NegotiationFetchRequested('fallback-thread'));
    registerFallbackValue(
      NegotiationCreateDedicatedTripRequested(
        threadId: 'fallback-thread',
        departureDate: DateTime(2026),
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

    // TripLegsCubit — étapes d'un voyage (FLUTTER-4D), fourni par getIt.
    if (!getIt.isRegistered<TripLegsCubit>()) {
      registerTestFormDraftCubit();
      getIt.registerFactory<TripLegsCubit>(
        () => TripLegsCubit(getIt<AnalyticsService>()),
      );
    }

    // AnnouncementFormBloc — fourni par getIt depuis CreateTripScreen
    if (!getIt.isRegistered<AnnouncementFormBloc>()) {
      getIt.registerFactory<AnnouncementFormBloc>(
        () => AnnouncementFormBloc(
          priceGridRepository: getIt<PriceGridRepository>(),
          analytics: getIt<AnalyticsService>(),
        ),
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

    // TripSeriesCubit — carte « Vous faites ce trajet souvent ? » de l'écran
    // de succès d'une création.
    if (!getIt.isRegistered<TripSeriesCubit>()) {
      getIt.registerFactoryParam<TripSeriesCubit, AnnouncementModel, void>(
        (a, _) => TripSeriesCubit(
          a,
          _MockAnnouncementRepository(),
          _MockTripTemplateRepository(),
          getIt<AnalyticsService>(),
        ),
      );
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

    // RecentCityStore — CityAutocompleteField(recentRole:) lit/écrit ce store
    // à chaque frame, y compris en dehors des champs ville actifs.
    registerCityFallbackValues();
    if (!getIt.isRegistered<RecentCityStore>()) {
      registerFakeRecentCityStore();
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

    // MobileMoneyAccountBloc factory — CreateTripScreen.build() (Tâche 9)
    // ajoute désormais `BlocProvider<MobileMoneyAccountBloc>(create: (_) =>
    // getIt<MobileMoneyAccountBloc>()..add(const MobileMoneyAccountsRequested()))`
    // au MultiBlocProvider, inconditionnellement :
    // sans cet enregistrement, TOUT l'écran cesse de se construire.
    if (!getIt.isRegistered<MobileMoneyAccountBloc>()) {
      getIt.registerFactory<MobileMoneyAccountBloc>(() {
        final b = _MockMobileMoneyAccountBloc();
        when(() => b.state).thenReturn(const MobileMoneyAccountInitial());
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
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
  Future<void> pumpAndDrain(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  // ── Group: mobileMoneyAccountActiveFrom (fonction pure, Tâche 9) ──────────────

  group('mobileMoneyAccountActiveFrom', () {
    const row = MobileMoneyPayoutAccount(
      id: 'a1',
      provider: 'ORANGE_CIV',
      providerLabel: 'Orange Money',
      brand: 'ORANGE',
      country: 'CI',
      currency: 'XOF',
      msisdnMasked: '+225 •• 36',
    );
    const withAccount = MobileMoneyPayoutAccounts(accounts: [row]);

    test('Initial → false', () {
      expect(
        mobileMoneyAccountActiveFrom(const MobileMoneyAccountInitial()),
        isFalse,
      );
    });

    test('Loading → false', () {
      expect(
        mobileMoneyAccountActiveFrom(const MobileMoneyAccountLoading()),
        isFalse,
      );
    });

    test('Error sans liste connue → false', () {
      expect(
        mobileMoneyAccountActiveFrom(MobileMoneyAccountError(Exception('x'))),
        isFalse,
      );
    });

    test('Loaded avec un compte → true', () {
      expect(
        mobileMoneyAccountActiveFrom(
          const MobileMoneyAccountLoaded(withAccount),
        ),
        isTrue,
      );
    });

    test('Loaded sans compte → false', () {
      expect(
        mobileMoneyAccountActiveFrom(
          const MobileMoneyAccountLoaded(MobileMoneyPayoutAccounts()),
        ),
        isFalse,
      );
    });

    test('ActionFailed garde la liste d\'avant → true', () {
      expect(
        mobileMoneyAccountActiveFrom(
          MobileMoneyAccountActionFailed(withAccount, Exception('x')),
        ),
        isTrue,
      );
    });
  });

  // ── Group: AppBar titles ──────────────────────────────────────────────────────

  group('CreateTripScreen — AppBar titles', () {
    testWidgets('titre "Publier un trajet" en mode création (args == null)', (
      tester,
    ) async {
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(find.text('Publier un trajet'), findsOneWidget);
    });

    // Sentry FLUTTER-CS/D2 : le statut Stripe chargé au démarrage pouvait
    // manquer ou dater d'avant la fin de l'onboarding, et la carte restait
    // verrouillée sur un compte complet.
    testWidgets('redemande le statut Stripe à chaque ouverture, avec '
        'indicateur', (tester) async {
      setupViewport(tester);
      registerFallbackValue(const StripeAccountStatusLoaded());
      final stripe = _makeStripeBloc();
      getIt.unregister<StripeAccountBloc>();
      getIt.registerFactory<StripeAccountBloc>(() => stripe);
      addTearDown(() {
        getIt.unregister<StripeAccountBloc>();
        getIt.registerFactory<StripeAccountBloc>(_makeStripeBloc);
      });

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      final events = verify(() => stripe.add(captureAny())).captured;
      expect(
        events.whereType<StripeAccountStatusRefreshed>().single.showProgress,
        isTrue,
      );
    });

    testWidgets('bloc Stripe fermé (après déconnexion) : aucun envoi', (
      tester,
    ) async {
      setupViewport(tester);
      final stripe = _makeStripeBloc();
      when(() => stripe.isClosed).thenReturn(true);
      getIt.unregister<StripeAccountBloc>();
      getIt.registerFactory<StripeAccountBloc>(() => stripe);
      addTearDown(() {
        getIt.unregister<StripeAccountBloc>();
        getIt.registerFactory<StripeAccountBloc>(_makeStripeBloc);
      });

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      verifyNever(() => stripe.add(any()));
    });

    testWidgets(
      'titre "Modifier le trajet" en mode édition (args.announcement != null)',
      (tester) async {
        setupViewport(tester);

        final args = CreateTripArgs(announcement: _makeAnnouncement());
        await pumpAndDrain(
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
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

      expect(find.text('Créer le trajet pour cette demande'), findsOneWidget);
    });
  });

  // ── Group: Bottom navigation bar ─────────────────────────────────────────────

  group('CreateTripScreen — Bottom navigation bar', () {
    testWidgets('bouton "Continuer" présent à l\'étape 0', (tester) async {
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('bouton retour (DonyAppBarBackButton) présent', (tester) async {
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(find.byType(DonyAppBarBackButton), findsOneWidget);
    });

    testWidgets(
      'bouton "Continuer" désactivé quand les champs obligatoires sont vides (mode création)',
      (tester) async {
        setupViewport(tester);

        // Creation mode: _canContinueNotifier starts false (no pre-filled fields)
        await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

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
        // departureCity, arrivalCity, departureDate, handoverDeadline and
        // handoverDeadline are all set, and handoverEnd (18:00) < departure (22:00).
        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await pumpAndDrain(
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

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      // At step 0, "Retour" should not be rendered
      expect(find.text('Retour'), findsNothing);
    });
  });

  // ── Group: Form structure ─────────────────────────────────────────────────────

  group('CreateTripScreen — Form structure', () {
    // FLUTTER-RA : la devise se choisit en tête de l'étape Prix &
    // conditions, plus dès l'étape Trajet. L'encart est monté (étape masquée
    // par Offstage) mais invisible tant qu'on n'y est pas.
    testWidgets('bandeau devise absent de l\'étape Trajet, monté dans '
        'l\'étape Prix', (tester) async {
      setupViewport(tester);
      registerCurrencyPreference('EUR');

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(find.byKey(const Key('trip-currency-selector-row')), findsNothing);
      expect(
        find.byKey(
          const Key('trip-currency-selector-row'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.text('Publié en Euro (EUR)', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('bandeau devise lit CAD depuis Hive', (tester) async {
      setupViewport(tester);
      registerCurrencyPreference('CAD');

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(
        find.text('Publié en Dollar canadien (CAD)', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('bandeau devise absent en mode édition', (tester) async {
      setupViewport(tester);

      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(
            args: CreateTripArgs(announcement: _makeAnnouncement()),
          ),
        ),
      );

      expect(
        find.byKey(
          const Key('trip-currency-selector-row'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    });

    testWidgets('stepper header est présent à l\'étape 0', (tester) async {
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(find.byType(CaStepperHeader), findsOneWidget);
    });

    testWidgets('section dépôt des colis est visible à l\'étape 0', (
      tester,
    ) async {
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      // L'étape 0 porte la section « dépôt » avec sa ligne unique.
      expect(find.text('DÉPÔT DES COLIS'), findsOneWidget);
      expect(find.text('Date limite de dépôt'), findsOneWidget);
    });

    testWidgets('mode locked: bannière "Trajet dédié à la demande" affichée', (
      tester,
    ) async {
      setupViewport(tester);

      final args = CreateTripArgs(
        lockContext: _makeLockContext(),
        negotiationBloc: _makeNegotiationBloc(),
      );
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

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
        await pumpAndDrain(
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
      // Use a wider viewport — step-2 (PrixStep) has payment-method
      // chips that overflow on narrow 390pt screens.
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final args = CreateTripArgs(announcement: _makeFullAnnouncement());
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

      // Advance to step 1
      await _goToStep(tester, TripFormStep.conditions);

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
        departureDate: DateTime(2026, 8),
        departureTime: '22:00',
        arrivalTime: '10:30',
        availableKg: 10.0,
        totalKg: 23.0,
        pricePerKg: 9.5, // NOT in preset list
        status: 'ACTIVE',
        bidsCount: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        handoverDeadline: DateTime(2026, 8, 1, 18),
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
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

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
          departureDate: DateTime(2026, 8),
          departureTime: '22:00',
          availableKg: 10.0,
          totalKg: 23.0,
          pricePerKg: 8.0,
          status: 'ACTIVE',
          bidsCount: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          handoverDeadline: DateTime(2026, 8, 1, 18),
          transportMode: TransportMode.plane,
          acceptedPaymentMethods: {BidPaymentMethod.stripe},
          acceptedContentTypes: const ['Vêtements'],
          refusedTypes: const [],
          description: 'Colis fragile, à manipuler avec soin.',
        );

        final args = CreateTripArgs(announcement: ann);
        await pumpAndDrain(
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
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

      // Advance to step 2
      await _goToStep(tester, TripFormStep.conditions);

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
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

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

  // ── Group: modèle initial (args.template) + _applyTemplate ───────────────────

  group('CreateTripScreen — modèle initial (_applyTemplate)', () {
    const mockTemplate = TripTemplate(
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

    // Modèle complet (formulaire entier, tel qu'enregistré depuis Tâche 1) :
    // couvre chaque champ que _applyTemplate doit copier.
    const fullTemplate = TripTemplate(
      id: 'tmpl-2',
      label: 'Abidjan → Paris',
      departureCity: 'Abidjan',
      arrivalCity: 'Paris',
      transportMode: 'CAR',
      // SUITCASE_32KG (imposerait 32 kg fixes via CapacityUnitChanged) :
      // couvre le bug #2 — _applyTemplate doit émettre AvailableKgChanged
      // APRÈS CapacityUnitChanged pour que la valeur du modèle (30) prime.
      capacityUnit: 'SUITCASE_32KG',
      availableKg: 30,
      pricePerKg: 1500,
      acceptedCategories: ['Vêtements & tissus'],
      currency: 'XOF',
      acceptedPaymentMethods: ['CASH', 'MOBILE_MONEY'],
      negotiable: true,
      refusedTypes: ['Téléphone & électronique'],
      description: 'Pas de liquide',
      pickupAddress: AddressData(label: 'Cocody', lat: 5.35, lng: -3.99),
      deliveryAddress: AddressData(
        label: 'Gare de Lyon',
        lat: 48.84,
        lng: 2.37,
      ),
      departureTime: '22:00',
      arrivalTime: '06:30',
      handoverLeadDays: 2,
      departureCountryCode: 'CI',
      arrivalCountryCode: 'FR',
      arrivalDayOffset: 1,
    );

    /// Ouvre la création avec [template] : le modèle choisi dans la feuille
    /// « Partir d'un modèle ? » arrive par `args.template` et est appliqué
    /// après le premier frame. Sa confirmation (SnackBar) reste à l'écran.
    Future<void> pumpWithTemplate(
      WidgetTester tester,
      TripTemplate template,
    ) async {
      setupViewport(tester);
      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(args: CreateTripArgs(template: template)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    /// Lit la date limite de dépôt courante. `_TripFormContentState` est
    /// privé (comme son widget `_TripFormContent`) : atteint via le `Key`
    /// posé sur `_TripFormContent` dans `create_trip_screen.dart`, pas par
    /// son type. `handoverDeadlineForTest` est un nom public porté par une
    /// classe privée — accessible dynamiquement, comme `fieldsForTest` sur
    /// `_TripTemplateEditScreenState`.
    DateTime? handoverDeadlineOf(WidgetTester tester) {
      final state = tester.state<State<StatefulWidget>>(
        find.byKey(const Key('trip-form-content')),
      );
      return (state as dynamic).handoverDeadlineForTest.value as DateTime?;
    }

    testWidgets('création : aucune barre Mes modèles à l\'étape Trajet, même '
        'avec des modèles enregistrés', (tester) async {
      // Des modèles existent côté données : l'écran ne les propose plus, le
      // choix se fait avant le formulaire (feuille « Partir d'un modèle ? »).
      if (getIt.isRegistered<TripTemplateBloc>()) {
        getIt.unregister<TripTemplateBloc>();
      }
      getIt.registerFactory<TripTemplateBloc>(() {
        final b = _MockTripTemplateBloc();
        when(() => b.state).thenReturn(
          const TripTemplateState(
            status: TripTemplateStatus.success,
            templates: [mockTemplate, fullTemplate],
          ),
        );
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
      addTearDown(() {
        if (getIt.isRegistered<TripTemplateBloc>()) {
          getIt.unregister<TripTemplateBloc>();
        }
      });
      registerCurrencyPreference('EUR');
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(find.byType(TrajetStep), findsOneWidget);
      expect(find.text('Mes modèles'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.textContaining('Paris → Dakar'), findsNothing);
      expect(find.textContaining('Abidjan → Paris'), findsNothing);
    });

    testWidgets('modèle initial → _applyTemplate applique les valeurs', (
      tester,
    ) async {
      await pumpWithTemplate(tester, mockTemplate);

      // Aucune navigation déclenchée.
      expect(find.byType(CreateTripScreen), findsOneWidget);

      // _applyTemplate affiche une DonySnackbar avec « appliqué ».
      expect(find.textContaining('appliqué'), findsOneWidget);

      final step = tester.widget<TrajetStep>(find.byType(TrajetStep));
      expect(step.departureCityNotifier.value, 'Paris');
      expect(step.arrivalCityNotifier.value, 'Dakar');

      // Vide le minuteur de la SnackBar (~4 s) pour libérer l'arbre.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets(
      'FLUTTER-EH — un modèle initial porte ses codes pays jusqu\'au form bloc',
      (tester) async {
        registerCurrencyPreference('EUR');
        await pumpWithTemplate(tester, fullTemplate);

        final formBloc = BlocProvider.of<AnnouncementFormBloc>(
          tester.element(find.byType(TrajetStep)),
        );
        // Lu à la soumission : avant correctif, les villes étaient posées
        // avant les codes et le bloc restait sur null (trajet publié sans pays).
        expect(formBloc.state.departureCity, 'Abidjan');
        expect(formBloc.state.departureCountryCode, 'CI');
        expect(formBloc.state.arrivalCountryCode, 'FR');

        // Interversion : les codes suivent leur ville (avant correctif, le
        // bloc gardait CI au départ pour Paris).
        await tester.ensureVisible(
          find.byKey(const Key('swap-corridor-cities')),
        );
        await tester.tap(find.byKey(const Key('swap-corridor-cities')));
        await tester.pump(const Duration(milliseconds: 600));
        expect(formBloc.state.departureCity, 'Paris');
        expect(formBloc.state.departureCountryCode, 'FR');
        expect(formBloc.state.arrivalCity, 'Abidjan');
        expect(formBloc.state.arrivalCountryCode, 'CI');

        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'un modèle initial complet copie devise, conditions, adresses et heures',
      (tester) async {
        registerCurrencyPreference('EUR');
        await pumpWithTemplate(tester, fullTemplate);

        final step = tester.widget<TrajetStep>(find.byType(TrajetStep));
        expect(step.departureCityNotifier.value, 'Abidjan');
        expect(
          step.departureTimeNotifier.value,
          const TimeOfDay(hour: 22, minute: 0),
        );
        expect(
          step.arrivalTimeNotifier.value,
          const TimeOfDay(hour: 6, minute: 30),
        );
        expect(step.arrivalDayOffsetNotifier?.value, 1);
        expect(
          find.text('Publié en Franc CFA Ouest (XOF)', skipOffstage: false),
          findsOneWidget,
        );

        // Étape 1 : adresses de remise/livraison — LieuxCapaciteStep reste
        // monté en Offstage tant que le step 1 n'est pas affiché.
        final lieux = tester.widget<LieuxCapaciteStep>(
          find.byType(LieuxCapaciteStep, skipOffstage: false),
        );
        expect(lieux.initialPickupAddress?.label, 'Cocody');
        expect(lieux.initialDeliveryAddress?.label, 'Gare de Lyon');

        // Étape 2 : mêmes notifiers, lus via PrixStep et ConditionsStep — présents
        // dans l'arbre dès le premier build (Offstage), donc valide même si
        // la navigation ci-dessous ne fait qu'avancer réellement le stepper.
        // skipOffstage: false — les notifiers sont partagés, l'étape
        // affichée n'importe pas.
        final prix = tester.widget<PrixStep>(
          find.byType(PrixStep, skipOffstage: false),
        );
        final conditions = tester.widget<ConditionsStep>(
          find.byType(ConditionsStep, skipOffstage: false),
        );
        expect(prix.currency, SupportedCurrency.xof);
        expect(prix.priceOptionNotifier.value, 1); // 1 500 F CFA = 2e chip CFA
        expect(prix.cashEnabledNotifier.value, isTrue);
        expect(
          prix.mobileMoneyEnabledNotifier.value,
          isFalse,
        ); // compte mobile money inactif dans ce montage
        expect(prix.negotiableNotifier.value, isTrue);
        expect(conditions.refusedTypesNotifier.value, {
          'Téléphone & électronique',
        });
        expect(conditions.descriptionCtrl.text, 'Pas de liquide');
        expect(prix.availableKgNotifier.value, 30);

        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'délai de remise du modèle recalculé quand la date est choisie',
      (tester) async {
        await pumpWithTemplate(tester, fullTemplate);

        final step = tester.widget<TrajetStep>(find.byType(TrajetStep));
        step.departureDateNotifier.value = DateTime(2026, 10, 20);
        await tester.pump(const Duration(milliseconds: 300));

        // Le jour limite = départ - 2 jours (handoverLeadDays du modèle).
        expect(handoverDeadlineOf(tester), DateTime(2026, 10, 18));

        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'modèle initial sans délai de remise : pas de date limite héritée',
      (tester) async {
        await pumpWithTemplate(tester, mockTemplate);

        final step = tester.widget<TrajetStep>(find.byType(TrajetStep));
        step.departureDateNotifier.value = DateTime(2026, 10, 20);
        await tester.pump(const Duration(milliseconds: 300));

        // Champ nul du modèle = défaut du formulaire vierge.
        expect(handoverDeadlineOf(tester), isNull);

        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('ancien modèle sans nouveaux champs : formulaire vierge', (
      tester,
    ) async {
      registerCurrencyPreference('EUR');
      await pumpWithTemplate(tester, mockTemplate);

      // skipOffstage: false — les notifiers sont partagés, l'étape affichée
      // n'importe pas.
      final prix = tester.widget<PrixStep>(
        find.byType(PrixStep, skipOffstage: false),
      );
      final conditions = tester.widget<ConditionsStep>(
        find.byType(ConditionsStep, skipOffstage: false),
      );
      // Sans carte dans ce montage, PrixStep verrouille les espèces à ON
      // (post-frame, après l'application du modèle) : pas un champ du modèle.
      expect(prix.cashEnabledNotifier.value, isTrue);
      expect(prix.mobileMoneyEnabledNotifier.value, isFalse);
      expect(prix.negotiableNotifier.value, isFalse);
      expect(conditions.descriptionCtrl.text, isEmpty);
      expect(conditions.refusedTypesNotifier.value, isEmpty);
      expect(
        find.text('Publié en Euro (EUR)', skipOffstage: false),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 5));
    });
  });

  // ── Group: statut légal du voyageur (lot 2) ───────────────────────────────────
  // Création d'un NOUVEAU trajet : modèle appliqué, date posée, étape 2, puis
  // « Publier ». Rappel avant l'envoi, jamais pour un brouillon ; 403 du back
  // quand Yadony exige la déclaration.

  group('CreateTripScreen — statut légal du voyageur (lot 2)', () {
    const template = TripTemplate(
      id: 'tmpl-status',
      label: 'Abidjan → Paris',
      departureCity: 'Abidjan',
      arrivalCity: 'Paris',
      transportMode: 'CAR',
      capacityUnit: 'KG_FREE',
      availableKg: 30,
      pricePerKg: 1500,
      acceptedCategories: ['Vêtements & tissus'],
      currency: 'XOF',
      acceptedPaymentMethods: ['CASH'],
      negotiable: true,
      pickupAddress: AddressData(label: 'Cocody', lat: 5.35, lng: -3.99),
      deliveryAddress: AddressData(
        label: 'Gare de Lyon',
        lat: 48.84,
        lng: 2.37,
      ),
      departureTime: '22:00',
      arrivalTime: '06:30',
      handoverLeadDays: 2,
      departureCountryCode: 'CI',
      arrivalCountryCode: 'FR',
    );

    late _MockAnnouncementBloc announcementBloc;
    late _MockTravelerStatusRepository statusRepo;
    late _MockGpProRepository gpRepo;
    late StreamController<AnnouncementState> states;

    setUpAll(() {
      registerFallbackValue(TravelerStatus.individual);
    });

    setUp(() {
      states = StreamController<AnnouncementState>.broadcast();
      announcementBloc = _MockAnnouncementBloc();
      when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
      when(() => announcementBloc.stream).thenAnswer((_) => states.stream);
      if (getIt.isRegistered<AnnouncementBloc>()) {
        getIt.unregister<AnnouncementBloc>();
      }
      getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);

      gpRepo = _MockGpProRepository();
      when(
        () => gpRepo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.none));
      if (getIt.isRegistered<GpProRepository>()) {
        getIt.unregister<GpProRepository>();
      }
      getIt.registerSingleton<GpProRepository>(gpRepo);
      statusRepo = _MockTravelerStatusRepository();
      when(() => statusRepo.declareIndividual()).thenAnswer(
        (_) async => TravelerStatusDeclaration(
          status: TravelerStatus.individual,
          declaredAt: DateTime.utc(2026, 11),
        ),
      );
      // Limite atteinte à 4 trajets, aucune réponse : ce que l'écran de
      // blocage relit après un 403.
      when(() => statusRepo.checkEligibility()).thenAnswer(
        (_) async => (
          eligibility: const PublishingEligibility(
            allowed: false,
            reason: PublishingReason.statusRequired,
            limit: 4,
            used: 4,
          ),
          failureCode: null,
        ),
      );
      if (getIt.isRegistered<TravelerStatusRepository>()) {
        getIt.unregister<TravelerStatusRepository>();
      }
      getIt.registerSingleton<TravelerStatusRepository>(statusRepo);
      if (getIt.isRegistered<TravelerStatusCubit>()) {
        getIt.unregister<TravelerStatusCubit>();
      }
      getIt.registerFactory<TravelerStatusCubit>(
        () => TravelerStatusCubit(statusRepo, getIt<AnalyticsService>()),
      );
    });

    tearDown(() async {
      await states.close();
      if (getIt.isRegistered<AnnouncementBloc>()) {
        getIt.unregister<AnnouncementBloc>();
      }
      getIt.registerFactory<AnnouncementBloc>(() {
        final b = _MockAnnouncementBloc();
        when(() => b.state).thenReturn(AnnouncementInitial());
        when(() => b.stream).thenAnswer((_) => const Stream.empty());
        return b;
      });
      if (getIt.isRegistered<TravelerStatusCubit>()) {
        getIt.unregister<TravelerStatusCubit>();
      }
      if (getIt.isRegistered<TravelerStatusRepository>()) {
        getIt.unregister<TravelerStatusRepository>();
      }
      if (getIt.isRegistered<GpProRepository>()) {
        getIt.unregister<GpProRepository>();
      }
    });

    /// Formulaire de création ouvert avec le modèle (comme depuis la feuille
    /// « Partir d'un modèle ? »), date posée : prêt à
    /// publier à l'étape 2.
    Future<void> reachPublishStep(
      WidgetTester tester, {
      TravelerStatus? status,
      bool gpPro = false,
    }) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          const CreateTripScreen(args: CreateTripArgs(template: template)),
          authState: AuthAuthenticated(
            UserModel(
              id: 'user-test-1',
              roles: const ['TRAVELER'],
              kycStatus: 'VERIFIED',
              status: 'ACTIVE',
              travelerStatus: status,
              gpPro: gpPro,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      // La confirmation « modèle appliqué » recouvre les boutons du bas.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      tester
          .widget<TrajetStep>(find.byType(TrajetStep))
          .departureDateNotifier
          .value = DateTime.now().add(
        const Duration(days: 30),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _goToStep(tester, TripFormStep.conditions);
      await tester.pump(const Duration(seconds: 5));
    }

    /// « Aperçu » puis, dans la feuille d'aperçu, le bouton demandé.
    Future<void> tapInPreview(WidgetTester tester, String label) async {
      final preview = find.byKey(const Key('create-announcement-preview'));
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DonyButton, label));
      await tester.pumpAndSettle();
    }

    Future<void> tapPublish(WidgetTester tester) =>
        tapInPreview(tester, "Publier l'annonce");

    int createdCount() => verify(
      () => announcementBloc.add(any(that: isA<AnnouncementCreateRequested>())),
    ).callCount;

    Future<void> declareIndividual(WidgetTester tester) async {
      await tester.tap(find.text('Particulier'));
      await tester.pumpAndSettle();
    }

    testWidgets('statut absent : « Publier » ouvre la question, rien n\'est '
        'envoyé tant qu\'elle est ouverte', (tester) async {
      await reachPublishStep(tester);
      await tapPublish(tester);

      expect(find.text('Vous voyagez en tant que ?'), findsOneWidget);
      expect(find.widgetWithText(DonyButton, 'Plus tard'), findsOneWidget);
      verifyNever(
        () =>
            announcementBloc.add(any(that: isA<AnnouncementCreateRequested>())),
      );
    });

    testWidgets('« Plus tard » : le trajet est quand même publié, une seule '
        'fois', (tester) async {
      await reachPublishStep(tester);
      await tapPublish(tester);
      await tester.tap(find.widgetWithText(DonyButton, 'Plus tard'));
      await tester.pumpAndSettle();

      expect(find.text('Vous voyagez en tant que ?'), findsNothing);
      expect(createdCount(), 1);
    });

    testWidgets('« Particulier » : déclaré, puis le trajet part', (
      tester,
    ) async {
      await reachPublishStep(tester);
      await tapPublish(tester);
      await declareIndividual(tester);

      verify(() => statusRepo.declareIndividual()).called(1);
      expect(createdCount(), 1);
    });

    testWidgets('« GP Pro » puis demande envoyée : le trajet part '
        '(particulier pendant la validation)', (tester) async {
      await reachPublishStep(tester);
      await tapPublish(tester);
      await tester.tap(find.text('GP Pro'));
      await tester.pumpAndSettle();
      expect(find.text('formulaire GP Pro'), findsOneWidget);
      verifyNever(
        () =>
            announcementBloc.add(any(that: isA<AnnouncementCreateRequested>())),
      );

      // La demande part depuis le formulaire.
      when(
        () => gpRepo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.pending));
      await tester.tap(find.text('formulaire GP Pro'));
      await tester.pumpAndSettle();

      verifyNever(() => statusRepo.declareIndividual());
      expect(createdCount(), 1);
    });

    testWidgets('« GP Pro » puis formulaire quitté sans envoyer : rien ne '
        'part, aucun message, le formulaire du trajet reste', (tester) async {
      await reachPublishStep(tester);
      await tapPublish(tester);
      await tester.tap(find.text('GP Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('formulaire GP Pro'));
      await tester.pumpAndSettle();

      verifyNever(
        () =>
            announcementBloc.add(any(that: isA<AnnouncementCreateRequested>())),
      );
      expect(find.byType(CreateTripScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final state in [GpProState.pending, GpProState.awaitingKyc]) {
      testWidgets('demande GP Pro ouverte (${state.wire}) : la question ne '
          'revient pas, le trajet part', (tester) async {
        when(
          () => gpRepo.fetchStatus(),
        ).thenAnswer((_) async => GpProStatus(state: state));
        await reachPublishStep(tester);
        await tapPublish(tester);

        expect(find.text('Vous voyagez en tant que ?'), findsNothing);
        expect(createdCount(), 1);
      });
    }

    testWidgets('lecture de la demande GP Pro en échec : la question est '
        'posée', (tester) async {
      when(
        () => gpRepo.fetchStatus(),
      ).thenThrow(const GpProException('network'));
      await reachPublishStep(tester);
      await tapPublish(tester);

      expect(find.text('Vous voyagez en tant que ?'), findsOneWidget);
    });

    testWidgets('deux appuis sur « Publier » pendant la lecture de la '
        'demande : une seule feuille, une seule création', (tester) async {
      final gate = Completer<GpProStatus>();
      when(() => gpRepo.fetchStatus()).thenAnswer((_) => gate.future);
      await reachPublishStep(tester);
      await tapPublish(tester);
      await tapPublish(tester);
      gate.complete(const GpProStatus(state: GpProState.none));
      await tester.pumpAndSettle();

      expect(find.text('Vous voyagez en tant que ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(DonyButton, 'Plus tard'));
      await tester.pumpAndSettle();

      expect(find.text('Vous voyagez en tant que ?'), findsNothing);
      expect(createdCount(), 1);
    });

    testWidgets('formulaire GP Pro quitté sans envoyer : un second appui sur '
        '« Publier » rouvre la question (verrou relâché)', (tester) async {
      await reachPublishStep(tester);
      await tapPublish(tester);
      await tester.tap(find.text('GP Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('formulaire GP Pro'));
      await tester.pumpAndSettle();
      expect(find.text('Vous voyagez en tant que ?'), findsNothing);

      await tapPublish(tester);

      expect(find.text('Vous voyagez en tant que ?'), findsOneWidget);
    });

    testWidgets('statut déjà déclaré : aucune question', (tester) async {
      await reachPublishStep(tester, status: TravelerStatus.individual);
      await tapPublish(tester);

      expect(find.text('Vous voyagez en tant que ?'), findsNothing);
      expect(createdCount(), 1);
    });

    testWidgets('badge GP Pro déjà accordé : aucune question', (tester) async {
      await reachPublishStep(tester, gpPro: true);
      await tapPublish(tester);

      expect(find.text('Vous voyagez en tant que ?'), findsNothing);
      expect(createdCount(), 1);
    });

    testWidgets('brouillon : jamais de question', (tester) async {
      await reachPublishStep(tester);
      await tapInPreview(tester, 'Enregistrer comme brouillon');

      expect(find.text('Vous voyagez en tant que ?'), findsNothing);
      verify(
        () => announcementBloc.add(
          any(
            that: predicate<AnnouncementEvent>(
              (e) => e is AnnouncementCreateRequested && e.saveAsDraft,
              'brouillon',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('403 traveler-status-required : l\'écran de blocage s\'ouvre '
        'avec les deux choix, sans « Plus tard »', (tester) async {
      await reachPublishStep(tester, status: TravelerStatus.individual);
      await tapPublish(tester);
      expect(createdCount(), 1);

      states.add(
        AnnouncementPublishingBlocked(
          const ForbiddenException('x', 'traveler-status-required'),
          PublishingReason.statusRequired,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Limite de 4 trajets atteinte ce mois-ci'),
        findsOneWidget,
      );
      expect(find.text('Particulier'), findsOneWidget);
      expect(find.text('GP Pro'), findsOneWidget);
      expect(find.widgetWithText(DonyButton, 'Plus tard'), findsNothing);
    });

    testWidgets('403 monthly-limit-reached : « vous ne pouvez plus créer de '
        'trajet », « Fermer » ramène au formulaire sans republier', (
      tester,
    ) async {
      when(() => statusRepo.checkEligibility()).thenAnswer(
        (_) async => (
          eligibility: PublishingEligibility(
            allowed: false,
            reason: PublishingReason.limitReached,
            limit: 4,
            used: 4,
            resetsOn: DateTime(2026, 12),
            travelerStatus: TravelerStatus.individual,
          ),
          failureCode: null,
        ),
      );
      await reachPublishStep(tester, status: TravelerStatus.individual);
      await tapPublish(tester);

      states.add(
        AnnouncementPublishingBlocked(
          const ForbiddenException('x', 'monthly-limit-reached'),
          PublishingReason.limitReached,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Vous ne pouvez plus créer de trajet ce mois-ci'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(DonyButton, 'Fermer'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateTripScreen), findsOneWidget);
      expect(createdCount(), 1);
    });

    testWidgets('403 gp-pro-pending puis demande validée au retour : la '
        'publication reprend', (tester) async {
      when(() => statusRepo.checkEligibility()).thenAnswer(
        (_) async => (
          eligibility: const PublishingEligibility(
            allowed: false,
            reason: PublishingReason.gpProPending,
            limit: 4,
            used: 4,
          ),
          failureCode: null,
        ),
      );
      await reachPublishStep(tester, status: TravelerStatus.individual);
      await tapPublish(tester);
      expect(createdCount(), 1);

      states.add(
        AnnouncementPublishingBlocked(
          const ForbiddenException('x', 'gp-pro-pending'),
          PublishingReason.gpProPending,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text("Votre demande GP Pro est en cours d'examen"),
        findsOneWidget,
      );

      // La validation tombe pendant que le voyageur regarde sa demande.
      when(() => statusRepo.checkEligibility()).thenAnswer(
        (_) async => (eligibility: PublishingEligibility.ok, failureCode: null),
      );
      await tester.tap(find.widgetWithText(DonyButton, 'Voir ma demande'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('formulaire GP Pro'));
      await tester.pumpAndSettle();

      // Une seconde publication après la validation (mocktail ne recompte pas
      // l'appel déjà vérifié plus haut).
      expect(createdCount(), 1);
    });

    testWidgets('403 et lecture du droit de publier en échec (ancien back) : '
        'l\'écran se construit sur la raison du 403', (tester) async {
      when(() => statusRepo.checkEligibility()).thenAnswer(
        (_) async => (eligibility: PublishingEligibility.ok, failureCode: null),
      );
      await reachPublishStep(tester, status: TravelerStatus.individual);
      await tapPublish(tester);

      states.add(
        AnnouncementPublishingBlocked(
          const ForbiddenException('x', 'monthly-limit-reached'),
          PublishingReason.limitReached,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Vous ne pouvez plus créer de trajet ce mois-ci'),
        findsOneWidget,
      );
      expect(
        find
                .text('Vous pourrez de nouveau publier à partir du 1 décembre.')
                .evaluate()
                .isNotEmpty ||
            find
                .textContaining('Vous pourrez de nouveau publier')
                .evaluate()
                .isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Group: Handover deadline error display ────────────────────────────────────

  group('CreateTripScreen — Handover deadline validation', () {
    testWidgets('erreur affichée quand la date limite tombe après le départ', (
      tester,
    ) async {
      setupViewport(tester);

      // date limite (2 août) > date de départ (1er août) → _isHandoverDeadlineInvalid() vrai
      final ann = AnnouncementModel(
        id: 'ann-handover-err',
        travelerId: 'trav-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 8),
        departureTime: '22:00',
        availableKg: 10.0,
        totalKg: 23.0,
        pricePerKg: 8.0,
        status: 'ACTIVE',
        bidsCount: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        handoverDeadline: DateTime(2026, 8, 2), // après le départ du 1er août
        transportMode: TransportMode.plane,
        acceptedPaymentMethods: {BidPaymentMethod.stripe},
        acceptedContentTypes: const ['Vêtements'],
        refusedTypes: const [],
      );

      final args = CreateTripArgs(announcement: ann);
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

      expect(find.textContaining('précéder le départ'), findsOneWidget);
    });
  });

  // ── Group: _submit() via Enregistrer ─────────────────────────────────────────

  group('CreateTripScreen — _submit() via Enregistrer (mode édition)', () {
    testWidgets('"Enregistrer" au step 2 appelle _submit() — happy path', (
      tester,
    ) async {
      // Wide viewport: avoids overflow in step-2 PrixStep
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final args = CreateTripArgs(announcement: _makeFullAnnouncement());
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

      // Navigate to step 2
      await _goToStep(tester, TripFormStep.conditions);

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

    /// Guidage après KYC : après une création, l'écran de succès propose de
    /// configurer les paiements quand le compte Stripe reste à faire.
    Future<void> emitCreated(
      WidgetTester tester,
      ConnectAccountStatus stripeStatus, {
      String status = 'ACTIVE',
    }) async {
      final stripe = _MockStripeAccountBloc();
      when(() => stripe.state).thenReturn(StripeAccountReady(stripeStatus));
      when(() => stripe.stream).thenAnswer((_) => const Stream.empty());
      when(() => stripe.isClosed).thenReturn(false);
      getIt.unregister<StripeAccountBloc>();
      getIt.registerFactory<StripeAccountBloc>(() => stripe);
      addTearDown(() {
        getIt.unregister<StripeAccountBloc>();
        getIt.registerFactory<StripeAccountBloc>(_makeStripeBloc);
      });
      final states = StreamController<AnnouncementState>.broadcast();
      addTearDown(states.close);
      when(() => announcementBloc.stream).thenAnswer((_) => states.stream);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));
      states.add(AnnouncementCreated(_makeFullAnnouncement(status: status)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    // FLUTTER-FW : un brouillon n'est visible de personne, « Trajet publié !
    // … est en ligne » était faux.
    testWidgets('brouillon : « Brouillon enregistré » + « Voir mes '
        'brouillons », jamais « publié »', (tester) async {
      await emitCreated(
        tester,
        const ConnectAccountStatus(status: 'NOT_CREATED'),
        status: 'DRAFT',
      );
      expect(find.byKey(const Key('trip-draft-saved')), findsOneWidget);
      expect(find.text('Brouillon enregistré'), findsOneWidget);
      expect(find.text('Voir mes brouillons'), findsOneWidget);
      expect(find.text('Voir ce brouillon'), findsOneWidget);
      expect(find.textContaining('publié'), findsNothing);
      expect(find.textContaining('en ligne !'), findsNothing);
      // Ni partage ni configuration des paiements pour un brouillon.
      expect(find.byKey(const Key('success-screen-tertiary')), findsNothing);
    });

    testWidgets('trajet publié : écran « publié » inchangé', (tester) async {
      await emitCreated(
        tester,
        const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
      );
      expect(find.byKey(const Key('trip-draft-saved')), findsNothing);
      expect(find.text('Brouillon enregistré'), findsNothing);
    });

    testWidgets('trajet direct créé : carte « Vous faites ce trajet '
        'souvent ? » sur l\'écran de succès', (tester) async {
      await emitCreated(
        tester,
        const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
      );
      expect(find.byKey(const Key('trip-series-open')), findsOneWidget);
      expect(find.text('Vous faites ce trajet souvent ?'), findsOneWidget);
    });

    testWidgets('trajet avec escales : pas de carte de trajet récurrent', (
      tester,
    ) async {
      final states = StreamController<AnnouncementState>.broadcast();
      addTearDown(states.close);
      when(() => announcementBloc.stream).thenAnswer((_) => states.stream);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));
      states.add(
        AnnouncementTripCreated([
          _makeFullAnnouncement(),
          _makeFullAnnouncement(),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.byKey(const Key('trip-series-open')), findsNothing);
    });

    testWidgets('création avec paiements à configurer : bouton « Configurer '
        'mes paiements » sur l\'écran de succès', (tester) async {
      await emitCreated(
        tester,
        const ConnectAccountStatus(status: 'NOT_CREATED'),
      );
      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.byKey(const Key('success-screen-extra-0')), findsOneWidget);
      expect(find.text('Configurer mes paiements'), findsOneWidget);
      // Le partage de l'affiche garde sa place d'action tertiaire.
      expect(find.byKey(const Key('success-screen-tertiary')), findsOneWidget);
      expect(find.text('Partager mon affiche'), findsOneWidget);
    });

    testWidgets('création avec paiements déjà configurés : pas de bouton '
        'paiements', (tester) async {
      await emitCreated(
        tester,
        const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
      );
      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.byKey(const Key('success-screen-extra-0')), findsNothing);
      expect(find.text('Configurer mes paiements'), findsNothing);
    });

    // Même défaut que YADONY-FLUTTER-PROD-2Y/2Z côté demande : le formulaire
    // seul dans la pile, `Navigator.pop(true)` retirait la dernière page
    // (« You have popped the last page off of the stack », pile vide en
    // release). Le harness démarre sur /trips/create : rien derrière.
    group('formulaire seul dans la pile', () {
      Future<void> tapAndSettle(WidgetTester tester, String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      testWidgets('« Voir mon trajet » ouvre le trajet', (tester) async {
        await emitCreated(
          tester,
          const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        );

        await tapAndSettle(tester, 'Voir mon trajet');

        expect(tester.takeException(), isNull);
        expect(find.byType(CreateTripScreen), findsNothing);
        expect(find.text('trip-detail-ann-full-1'), findsOneWidget);
      });

      testWidgets('« Partager mon affiche » ouvre l\'affiche', (tester) async {
        await emitCreated(
          tester,
          const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        );

        await tapAndSettle(tester, 'Partager mon affiche');

        expect(tester.takeException(), isNull);
        expect(find.text('trip-poster-ann-full-1'), findsOneWidget);
      });

      testWidgets('« Voir les colis pour ce trajet » ouvre l\'accueil', (
        tester,
      ) async {
        final notifier = PendingSearchNotifier();
        getIt.registerSingleton<PendingSearchNotifier>(notifier);
        addTearDown(() => getIt.unregister<PendingSearchNotifier>());
        await emitCreated(
          tester,
          const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        );

        await tapAndSettle(tester, 'Voir les colis pour ce trajet');

        expect(tester.takeException(), isNull);
        expect(find.text('home-stub'), findsOneWidget);
      });

      testWidgets('« Configurer mes paiements » ouvre la configuration', (
        tester,
      ) async {
        await emitCreated(
          tester,
          const ConnectAccountStatus(status: 'NOT_CREATED'),
        );

        await tapAndSettle(tester, 'Configurer mes paiements');

        expect(tester.takeException(), isNull);
        expect(find.text('stripe-onboarding-intro'), findsOneWidget);
      });

      testWidgets('brouillon : « Voir mes brouillons » ouvre la liste', (
        tester,
      ) async {
        await emitCreated(
          tester,
          const ConnectAccountStatus(status: 'NOT_CREATED'),
          status: 'DRAFT',
        );

        await tapAndSettle(tester, 'Voir mes brouillons');

        expect(tester.takeException(), isNull);
        expect(find.text('trips-list-draft'), findsOneWidget);
      });

      testWidgets('brouillon : « Voir ce brouillon » ouvre le trajet', (
        tester,
      ) async {
        await emitCreated(
          tester,
          const ConnectAccountStatus(status: 'NOT_CREATED'),
          status: 'DRAFT',
        );

        await tapAndSettle(tester, 'Voir ce brouillon');

        expect(tester.takeException(), isNull);
        expect(find.text('trip-detail-ann-full-1'), findsOneWidget);
      });
    });

    testWidgets('création : « Voir les colis pour ce trajet » est le bouton '
        'principal, « Voir mon trajet » le secondaire', (tester) async {
      await emitCreated(
        tester,
        const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
      );
      expect(find.text('Voir les colis pour ce trajet'), findsOneWidget);
      expect(find.text('Voir mon trajet'), findsOneWidget);
    });

    /// Navigue jusqu'à l'étape 2 (mode édition, "Enregistrer") avec un
    /// `AnnouncementModel` complet. `_wrapWithRouter`'s `_makeStripeBloc()`
    /// reste sur `StripeAccountInitial()` (Stripe non configuré) — le
    /// comportement par défaut de tout ce fichier de tests.
    /// Jusqu'à la dernière étape (Conditions, bouton « Enregistrer ») ou,
    /// avec [to], jusqu'à l'étape Prix où vivent les moyens de paiement.
    Future<void> navigateToStep2(
      WidgetTester tester, {
      AuthState? authState,
      AnnouncementModel? announcement,
      TripFormStep to = TripFormStep.conditions,
    }) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final args = CreateTripArgs(
        announcement: announcement ?? _makeFullAnnouncement(),
      );
      await pumpAndDrain(
        tester,
        _wrapWithRouter(CreateTripScreen(args: args), authState: authState),
      );
      await _goToStep(tester, to);
      if (to == TripFormStep.conditions) {
        expect(find.text('Enregistrer'), findsOneWidget);
      }
    }

    // ── Devise modifiable en édition (FLUTTER-KV, yadony-back #515) ──────────
    group('devise en modification (FLUTTER-KV)', () {
      Future<void> pumpEdit(
        WidgetTester tester, {
        bool? currencyEditable,
      }) async {
        tester.view.physicalSize = const Size(800, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        await pumpAndDrain(
          tester,
          _wrapWithRouter(
            CreateTripScreen(
              args: CreateTripArgs(
                announcement: _makeFullAnnouncement(
                  currencyEditable: currencyEditable,
                ),
              ),
            ),
          ),
        );
      }

      // L'encart de devise est en tête de l'étape Prix (FLUTTER-RA) : on y
      // va avant de le chercher.
      Future<void> goToPriceStep(WidgetTester tester) async {
        await _goToStep(tester, TripFormStep.prix);
      }

      Future<void> submit(WidgetTester tester) async {
        await _goToStep(tester, TripFormStep.conditions);
        await tester.tap(find.byKey(const Key('create-announcement-submit')));
        await tester.pump(const Duration(milliseconds: 600));
      }

      AnnouncementUpdateRequested sentUpdate() => verify(
        () => announcementBloc.add(captureAny()),
      ).captured.whereType<AnnouncementUpdateRequested>().single;

      testWidgets('champ absent (ancien back) : devise figée, sans rien '
          'ajouter, PUT sans currency', (tester) async {
        await pumpEdit(tester);
        await goToPriceStep(tester);
        expect(
          find.byKey(const Key('trip-currency-selector-row')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('trip-edit-currency-locked-hint')),
          findsNothing,
        );
        await submit(tester);
        expect(sentUpdate().currency, isNull);
      });

      testWidgets('false : devise figée avec explication', (tester) async {
        await pumpEdit(tester, currencyEditable: false);
        await goToPriceStep(tester);
        expect(
          find.byKey(const Key('trip-currency-selector-row')),
          findsNothing,
        );
        expect(
          find.text(
            'La devise ne peut plus changer : ce trajet a déjà des demandes.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('true, devise inchangée : PUT sans currency', (tester) async {
        await pumpEdit(tester, currencyEditable: true);
        // Rien à l'étape Trajet, l'encart vient avec les prix (FLUTTER-RA).
        expect(
          find.byKey(const Key('trip-currency-selector-row')),
          findsNothing,
        );
        await goToPriceStep(tester);
        expect(
          find.byKey(const Key('trip-currency-selector-row')),
          findsOneWidget,
        );
        await submit(tester);
        expect(sentUpdate().currency, isNull);
      });

      testWidgets('true, devise changée : PUT avec currency', (tester) async {
        await pumpEdit(tester, currencyEditable: true);
        await goToPriceStep(tester);
        await tester.tap(find.byKey(const Key('trip-currency-selector-row')));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('(USD)'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('currency-selector-confirm')));
        await tester.pumpAndSettle();

        await submit(tester);
        expect(sentUpdate().currency, 'USD');
      });

      testWidgets('409 currency-locked : devise figée et expliquée', (
        tester,
      ) async {
        final states = StreamController<AnnouncementState>.broadcast();
        addTearDown(states.close);
        when(() => announcementBloc.stream).thenAnswer((_) => states.stream);

        await pumpEdit(tester, currencyEditable: true);
        await goToPriceStep(tester);
        expect(
          find.byKey(const Key('trip-currency-selector-row')),
          findsOneWidget,
        );
        states.add(
          AnnouncementError(
            const ConflictException('x', code: 'announcement/currency-locked'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          find.byKey(const Key('trip-currency-selector-row')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('trip-edit-currency-locked-hint')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 5));
      });
    });

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
      'paymentMethods : MOBILE_MONEY inclus pour un trajet en XOF déjà '
      'accepté au mobile money (préremplissage édition)',
      (tester) async {
        await navigateToStep2(
          tester,
          announcement: _makeFullAnnouncement(
            currency: 'XOF',
            // 8 F CFA/kg passerait sous le plancher de 656 (FLUTTER-GK).
            pricePerKg: 3000,
            acceptedPaymentMethods: {BidPaymentMethod.mobileMoney},
          ),
        );

        await tester.tap(find.byKey(const Key('create-announcement-submit')));
        await tester.pump(const Duration(milliseconds: 600));

        verify(
          () => announcementBloc.add(
            any(
              that: predicate<AnnouncementEvent>(
                (e) =>
                    e is AnnouncementUpdateRequested &&
                    e.acceptedPaymentMethods.contains('MOBILE_MONEY'),
                'AnnouncementUpdateRequested avec MOBILE_MONEY',
              ),
            ),
          ),
        ).called(1);
      },
    );

    /// Stripe Connect prêt : la carte devient un vrai choix (FLUTTER-FT).
    void stripeReady() {
      final stripe = _MockStripeAccountBloc();
      when(() => stripe.state).thenReturn(
        const StripeAccountReady(
          ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        ),
      );
      when(() => stripe.stream).thenAnswer((_) => const Stream.empty());
      when(() => stripe.isClosed).thenReturn(false);
      getIt.unregister<StripeAccountBloc>();
      getIt.registerFactory<StripeAccountBloc>(() => stripe);
      addTearDown(() {
        getIt.unregister<StripeAccountBloc>();
        getIt.registerFactory<StripeAccountBloc>(_makeStripeBloc);
      });
    }

    testWidgets('FLUTTER-FT : Stripe prêt, carte gardée → STRIPE envoyé', (
      tester,
    ) async {
      stripeReady();
      await navigateToStep2(tester);

      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        () => announcementBloc.add(
          any(
            that: predicate<AnnouncementEvent>(
              (e) =>
                  e is AnnouncementUpdateRequested &&
                  e.acceptedPaymentMethods.contains('STRIPE'),
              'AnnouncementUpdateRequested avec STRIPE',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('FLUTTER-FT : Stripe prêt, trajet sans carte → refus conservé, '
        'espèces envoyées', (tester) async {
      stripeReady();
      await navigateToStep2(
        tester,
        announcement: _makeFullAnnouncement(
          acceptedPaymentMethods: {BidPaymentMethod.cash},
        ),
        to: TripFormStep.prix,
      );
      expect(find.byKey(const Key('card-off-help')), findsOneWidget);

      await _goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        () => announcementBloc.add(
          any(
            that: predicate<AnnouncementEvent>(
              (e) =>
                  e is AnnouncementUpdateRequested &&
                  !e.acceptedPaymentMethods.contains('STRIPE') &&
                  e.acceptedPaymentMethods.contains('CASH'),
              'AnnouncementUpdateRequested sans STRIPE',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('FLUTTER-GE : les escales préremplies repartent à '
        'l\'enregistrement', (tester) async {
      await navigateToStep2(
        tester,
        announcement: _makeFullAnnouncement(stops: TripStops.one),
      );

      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        () => announcementBloc.add(
          any(
            that: predicate<AnnouncementEvent>(
              (e) =>
                  e is AnnouncementUpdateRequested && e.stops == TripStops.one,
              'AnnouncementUpdateRequested avec une escale',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets(
      'changer de devise resynchronise le prix du bloc : le même chip vaut '
      '1 500 F CFA en XOF puis 8 € en EUR (_onCurrencyChanged)',
      (tester) async {
        await navigateToStep2(
          tester,
          announcement: _makeFullAnnouncement(currency: 'XOF'),
          to: TripFormStep.prix,
        );

        await tester.ensureVisible(
          find.text(CurrencyFormatter.format(1500, SupportedCurrency.xof)),
        );
        await tester.tap(
          find.text(CurrencyFormatter.format(1500, SupportedCurrency.xof)),
        );
        await tester.pump(const Duration(milliseconds: 600));

        final stepFinder = find.byType(PrixStep);
        final formBloc = BlocProvider.of<AnnouncementFormBloc>(
          tester.element(stepFinder),
        );
        expect(formBloc.state.pricePerKg, 1500);
        expect(formBloc.state.priceWarning, isNull);

        // Même index de chip, autre devise : le bloc doit recevoir 8 €.
        tester.widget<PrixStep>(stepFinder).currencyNotifier.value =
            SupportedCurrency.eur;
        await tester.pump(const Duration(milliseconds: 600));

        expect(formBloc.state.pricePerKg, 8);
        expect(
          find.text(CurrencyFormatter.format(8, SupportedCurrency.eur)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'paymentMethods : MOBILE_MONEY retiré si la devise quitte la zone CFA '
      'après activation (_onCurrencyChanged)',
      (tester) async {
        await navigateToStep2(
          tester,
          announcement: _makeFullAnnouncement(
            currency: 'XOF',
            // 8 F CFA/kg passerait sous le plancher de 656 (FLUTTER-GK).
            pricePerKg: 3000,
            acceptedPaymentMethods: {BidPaymentMethod.mobileMoney},
          ),
          to: TripFormStep.prix,
        );

        // La bannière de devise est masquée en édition (currency verrouillée
        // côté UI) : le seul moyen d'exercer le listener réel
        // `_onCurrencyChanged` est de muter directement le currencyNotifier
        // partagé. `PrixStep.currencyNotifier` EST l'instance
        // `widget.currencyNotifier` de `_TripFormContentState` (même
        // référence, passée telle quelle dans `_buildStep2`) : la muter ici
        // déclenche donc le vrai listener de l'écran, pas une simulation.
        final step = tester.widget<PrixStep>(find.byType(PrixStep));
        step.currencyNotifier.value = SupportedCurrency.eur;
        await tester.pump(const Duration(milliseconds: 600));

        final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('payment-method-mobile-money')),
        );
        expect(
          tile.value,
          isFalse,
          reason: 'La bascule doit se remettre à false hors zone CFA',
        );

        await _goToStep(tester, TripFormStep.conditions);
        await tester.tap(find.byKey(const Key('create-announcement-submit')));
        await tester.pump(const Duration(milliseconds: 600));

        verify(
          () => announcementBloc.add(
            any(
              that: predicate<AnnouncementEvent>(
                (e) =>
                    e is AnnouncementUpdateRequested &&
                    !e.acceptedPaymentMethods.contains('MOBILE_MONEY'),
                'AnnouncementUpdateRequested sans MOBILE_MONEY après reset '
                'de devise',
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

  // ── Group: encart « Stripe Connect n'est pas activé » ──────────────────────
  // L'encart place toujours son lien « Activer les paiements par carte » SOUS
  // le texte d'explication, jamais à côté : c'est ce qui le garde lisible à
  // toute taille de police (l'ancienne bannière devait basculer de Row en
  // Column au-delà de 100 %). Couvert : la position relative, l'absence de
  // débordement à 200 %.

  group('CreateTripScreen — encart Stripe Connect non activé', () {
    Future<void> navigateToStep2NotConfigured(WidgetTester tester) async {
      // Viewport large : les chips de moyens de paiement de l'étape 2
      // débordent sur un écran étroit à 100 % déjà (bug préexistant, hors
      // sujet ici) — les tests existants de ce fichier utilisent la même
      // largeur pour l'isoler.
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final args = CreateTripArgs(announcement: _makeFullAnnouncement());
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));
      await _goToStep(tester, TripFormStep.prix);
      expect(find.text('Activer les paiements par carte'), findsOneWidget);
    }

    testWidgets("le lien d'activation est sous le texte d'explication", (
      tester,
    ) async {
      await navigateToStep2NotConfigured(tester);

      final text = tester.getRect(
        find.textContaining("Stripe Connect n'est pas activé"),
      );
      final cta = tester.getRect(
        find.byKey(const Key('activate-card-payments-cta')),
      );

      expect(
        cta.top,
        greaterThanOrEqualTo(text.bottom),
        reason: "le lien suit l'explication, il ne la côtoie pas",
      );
    });

    testWidgets('à 200 %, aucun débordement (bascule en disposition empilée)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await navigateToStep2NotConfigured(tester);

      expect(tester.takeException(), isNull);
    });
  });

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
              builder: (_, _) => Scaffold(
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
              builder: (_, _) => MultiBlocProvider(
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
                child: const CreateTripScreen(),
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
        expect(find.text('Partager mon affiche'), findsOneWidget);
        expect(didPop, isFalse);
      },
    );

    testWidgets(
      'voyage à étapes publié : succès avec l\'itinéraire complet (FLUTTER-4D)',
      (tester) async {
        setupViewport(tester);
        var didPop = false;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
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
              builder: (_, _) => MultiBlocProvider(
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
                child: const CreateTripScreen(),
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
        annStreamCtrl.add(
          AnnouncementTripCreated([
            _makeAnnouncement(),
            AnnouncementModel(
              id: 'leg-2',
              travelerId: 'trav-1',
              departureCity: 'Dakar',
              arrivalCity: 'Bamako',
              departureDate: DateTime(2026, 8, 5),
              availableKg: 10,
              totalKg: 10,
              status: 'ACTIVE',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ]),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(DonySuccessScreen), findsOneWidget);
        expect(
          find.textContaining('Votre voyage en 2 étapes est en ligne'),
          findsOneWidget,
        );
        expect(find.textContaining('Dakar → Bamako'), findsOneWidget);
        expect(didPop, isFalse);
      },
    );

    testWidgets(
      'backend sans voyages à étapes : avertissement, on reste sur le formulaire (FLUTTER-4D)',
      (tester) async {
        setupViewport(tester);
        var didPop = false;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
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
              builder: (_, _) => MultiBlocProvider(
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
                child: const CreateTripScreen(),
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

        annStreamCtrl.add(AnnouncementTripUnsupported());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(DonySuccessScreen), findsNothing);
        expect(find.byType(CreateTripScreen), findsOneWidget);
        expect(
          find.textContaining(
            'voyages à plusieurs étapes ne sont pas encore disponibles',
          ),
          findsOneWidget,
        );
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
              builder: (_, _) => Scaffold(
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
              builder: (_, _) => MultiBlocProvider(
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
        expect(find.text('Partager mon affiche'), findsNothing);
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
              builder: (_, _) => Scaffold(
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
              builder: (_, _) => MultiBlocProvider(
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
                child: const CreateTripScreen(),
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
        // task 4 feb86b71) et doit préserver le contrat bool de ses
        // appelants (announcement_list_screen.dart, trip_owner/trip_edit.dart
        // depuis l'écran du trajet). La carte du trajet récurrent
        // peut pousser le bouton sous la ligne de flottaison.
        await tester.ensureVisible(find.text('Voir mon trajet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voir mon trajet'));
        await tester.pumpAndSettle();

        expect(pushCompleted, isTrue);
        expect(pushResult, isTrue);
        expect(find.text('trip-detail-ann-test-1'), findsOneWidget);
      },
    );

    testWidgets(
      'le CTA principal « Voir les colis pour ce trajet » ferme le formulaire '
      'avec pop(true), pose l\'intention « colis pour mes trajets » et ouvre '
      'l\'accueil',
      (tester) async {
        setupViewport(tester);
        final notifier = PendingSearchNotifier();
        getIt.registerSingleton<PendingSearchNotifier>(notifier);
        addTearDown(() => getIt.unregister<PendingSearchNotifier>());
        bool? pushResult;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () async {
                      pushResult = await ctx.push<bool>('/trips/create');
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/trips/create',
              builder: (_, _) => MultiBlocProvider(
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
                child: const CreateTripScreen(),
              ),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('home-test')),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
        );
        await tester.pump();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        annStreamCtrl.add(AnnouncementCreated(_makeAnnouncement()));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(DonySuccessScreen), findsOneWidget);
        expect(notifier.hasParcelsForMyTrips, isFalse);

        await tester.ensureVisible(find.text('Voir les colis pour ce trajet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voir les colis pour ce trajet'));
        await tester.pumpAndSettle();

        expect(pushResult, isTrue);
        expect(notifier.hasParcelsForMyTrips, isTrue);
        expect(find.text('home-test'), findsOneWidget);
      },
    );

    testWidgets('AnnouncementError — ErrorPresenter appelé (snackbar affiché)', (
      tester,
    ) async {
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      // Emit AnnouncementError — listener calls ErrorPresenter.show
      annStreamCtrl.add(
        AnnouncementError(const NetworkException('Erreur réseau')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // BlocListener fires ErrorPresenter.show → DonySnackbar → SnackBar visible
      await tester.pump(); // laisser le BlocListener réagir
      expect(find.byType(SnackBar), findsOneWidget);
    });

    // Relecture finale du lot K, constat 1 : ces deux dialogues affichaient
    // le `detail` français brut du serveur (`error.message`), jamais traduit
    // en anglais. Ils passent désormais par `ErrorPresenter.resolve`, qui
    // route sur le code de l'exception et rend le texte du catalogue.
    testWidgets(
      'AnnouncementProLimitReached, anglais : texte du catalogue, jamais le detail serveur',
      (tester) async {
        setupViewport(tester);
        useEnglish();

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
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
              builder: (_, _) => MultiBlocProvider(
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
                child: const CreateTripScreen(),
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

        annStreamCtrl.add(
          AnnouncementProLimitReached(
            const ForbiddenException(
              'Vous avez atteint votre limite mensuelle de 2 annonces.',
              'pro-limit-reached',
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Monthly limit reached'), findsOneWidget);
        expect(
          find.text(
            "You've reached your listing limit for this month. Upgrade to "
            'Pro to post without limits.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Vous avez atteint votre limite mensuelle de 2 annonces.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'AnnouncementDraftLimitReached, anglais : texte du catalogue, jamais le detail serveur',
      (tester) async {
        setupViewport(tester);
        useEnglish();

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
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
              builder: (_, _) => MultiBlocProvider(
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
                child: const CreateTripScreen(),
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

        annStreamCtrl.add(
          AnnouncementDraftLimitReached(
            const ForbiddenException(
              'Limite de 2 brouillon(s) atteinte.',
              'draft-limit-reached',
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Draft limit reached'), findsOneWidget);
        expect(
          find.text('Upgrade to Pro to create more drafts.'),
          findsOneWidget,
        );
        expect(find.text('Limite de 2 brouillon(s) atteinte.'), findsNothing);
      },
    );
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
            builder: (_, _) => Scaffold(
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
            builder: (_, _) => MultiBlocProvider(
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
              child: const CreateTripScreen(),
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

  group('CreateTripScreen — Date limite de dépôt (rendu)', () {
    testWidgets('une seule row date limite est affichée en mode création', (
      tester,
    ) async {
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(
        find.byKey(const Key('sheet-handover-deadline-row')),
        findsOneWidget,
      );
      expect(find.text('Date limite de dépôt'), findsOneWidget);
    });

    testWidgets('mode création : la row affiche "Choisir" (aucune valeur)', (
      tester,
    ) async {
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(find.text('Choisir'), findsOneWidget);
    });

    testWidgets(
      'mode édition préremplit les valeurs existantes (plus aucun "Choisir")',
      (tester) async {
        setupViewport(tester);

        // _makeFullAnnouncement() porte une date limite au 1er août.
        final args = CreateTripArgs(announcement: _makeFullAnnouncement());
        await pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        expect(find.text('Choisir'), findsNothing);
        // L'heure enregistrée (18:00, avant le départ de 22:00) est gardée
        // telle quelle et s'affiche avec le jour (FLUTTER-MY, FLUTTER-PK).
        expect(find.text('1 août à 18:00'), findsOneWidget);
      },
    );

    testWidgets(
      'mode édition : une limite pile à l\'heure de départ suit le départ',
      (tester) async {
        setupViewport(tester);

        // Règle d'avant FLUTTER-PK : la limite du jour du départ valait
        // l'heure de départ. Elle redevient un jour sans heure.
        final args = CreateTripArgs(
          announcement: _makeFullAnnouncement(
            handoverDeadline: DateTime(2026, 8, 1, 22),
          ),
        );
        await pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        expect(find.text('1 août à 22:00'), findsOneWidget);
        expect(find.byKey(const Key('sheet-handover-error')), findsNothing);
      },
    );

    testWidgets(
      'date limite avant le jour du départ : fin de journée affichée',
      (tester) async {
        setupViewport(tester);

        final ann = AnnouncementModel(
          id: 'ann-handover-eod',
          travelerId: 'trav-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 8, 20),
          departureTime: '08:00',
          availableKg: 10.0,
          totalKg: 23.0,
          pricePerKg: 8.0,
          status: 'ACTIVE',
          bidsCount: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          handoverDeadline: DateTime(2026, 8, 18, 23, 59),
          transportMode: TransportMode.plane,
          acceptedPaymentMethods: {BidPaymentMethod.stripe},
          acceptedContentTypes: const ['Vêtements'],
          refusedTypes: const [],
        );

        await pumpAndDrain(
          tester,
          _wrapWithRouter(
            CreateTripScreen(args: CreateTripArgs(announcement: ann)),
          ),
        );

        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('sheet-handover-deadline-value')),
              )
              .data,
          '18 août à 23:59',
        );
      },
    );

    testWidgets('date limite après le départ affiche le message inline', (
      tester,
    ) async {
      setupViewport(tester);

      final ann = AnnouncementModel(
        id: 'ann-handover-late',
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
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        // Lendemain du départ → date limite impossible.
        handoverDeadline: DateTime(2026, 8, 21, 16),
        transportMode: TransportMode.plane,
        acceptedPaymentMethods: {BidPaymentMethod.stripe},
        acceptedContentTypes: const ['Vêtements'],
        refusedTypes: const [],
      );

      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(args: CreateTripArgs(announcement: ann)),
        ),
      );

      expect(find.byKey(const Key('sheet-handover-error')), findsOneWidget);
      expect(
        find.text('La date limite doit précéder le départ.'),
        findsOneWidget,
      );
    });

    testWidgets('date limite valide : aucun message d\'erreur inline', (
      tester,
    ) async {
      setupViewport(tester);

      final args = CreateTripArgs(announcement: _makeFullAnnouncement());
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

      expect(find.byKey(const Key('sheet-handover-error')), findsNothing);
    });
  });

  // ── Group: Date limite de dépôt — jour puis heure (FLUTTER-PK) ─────────────
  // Le calendrier enchaîne sur le sélecteur d'heure : l'heure de la limite
  // est choisie, plus seulement déduite.

  group('CreateTripScreen — Date limite de dépôt (jour puis heure)', () {
    final departure = _handoverPickDeparture();

    AnnouncementModel futureTrip() => _makeFullAnnouncement(
      departureDate: departure,
      handoverDeadline: DateTime(
        departure.year,
        departure.month,
        departure.day - 1,
        23,
        59,
      ),
    );

    String row(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('sheet-handover-deadline-value')))
        .data!;

    String expected(DateTime day, String hhmm) =>
        '${DateFormat.MMMd('fr').format(day)} à $hhmm';

    Future<void> openTrip(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(args: CreateTripArgs(announcement: futureTrip())),
          use24h: true,
        ),
      );
    }

    test('le départ de test laisse deux jours avant lui dans le mois', () {
      expect(departure.day, inInclusiveRange(4, 26));
    });

    test(
      'le départ de test tient pour chaque jour d\'une année bissextile',
      () {
        for (var i = 0; i < 366; i++) {
          final now = DateTime(2028, 1, 1 + i, 14, 30);
          final d = _handoverPickDeparture(now: now);
          final veille = DateTime(d.year, d.month, d.day - 1);
          final avantVeille = DateTime(d.year, d.month, d.day - 2);
          final reason = 'le $now';
          expect(d.day, inInclusiveRange(4, 26), reason: reason);
          expect(d.hour, 0, reason: reason);
          expect(veille.month, d.month, reason: reason);
          expect(avantVeille.month, d.month, reason: reason);
          expect(avantVeille.isAfter(now), isTrue, reason: reason);
          expect(
            d.isBefore(DateTime(now.year, now.month, now.day + 5)),
            isFalse,
            reason: reason,
          );
        }
      },
    );

    testWidgets('jour puis heure choisie : ligne et valeur envoyée', (
      tester,
    ) async {
      await openTrip(tester);
      final day = departure.subtract(const Duration(days: 1));

      await _pickHandover(tester, day, hour: '18', minute: '00');

      expect(row(tester), expected(day, '18:00'));
      expect(find.byKey(const Key('sheet-handover-error')), findsNothing);
      final continueBtn = find.widgetWithText(DonyButton, 'Continuer');
      expect(tester.widget<DonyButton>(continueBtn).onPressed, isNotNull);
    });

    testWidgets(
      'heure postérieure au départ le jour du départ : erreur et Continuer inactif',
      (tester) async {
        await openTrip(tester);

        await _pickHandover(tester, departure, hour: '23', minute: '00');

        expect(row(tester), expected(departure, '23:00'));
        expect(find.byKey(const Key('sheet-handover-error')), findsOneWidget);
        expect(
          find.text('La date limite doit précéder le départ.'),
          findsOneWidget,
        );
        final continueBtn = find.widgetWithText(DonyButton, 'Continuer');
        expect(tester.widget<DonyButton>(continueBtn).onPressed, isNull);
      },
    );

    testWidgets('heure annulée un autre jour : repli en fin de journée', (
      tester,
    ) async {
      await openTrip(tester);
      final day = departure.subtract(const Duration(days: 2));

      await _pickHandover(tester, day);

      expect(row(tester), expected(day, '23:59'));
    });

    testWidgets(
      'heure annulée le jour du départ : repli à l\'heure de départ',
      (tester) async {
        await openTrip(tester);

        await _pickHandover(tester, departure);

        expect(row(tester), expected(departure, '22:00'));
        expect(find.byKey(const Key('sheet-handover-error')), findsNothing);
      },
    );
  });

  // ── Group: Date limite de dépôt — garde au submit ────────────────────────────
  // Migré de create_announcement_handover_test.dart. Capture l'instance
  // AnnouncementBloc créée par l'écran pour pouvoir verify() le dispatch.

  group('CreateTripScreen — Date limite de dépôt (submit)', () {
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

      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(args: CreateTripArgs(announcement: ann)),
        ),
      );
      await _goToStep(tester, TripFormStep.conditions);
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
          departureDate: DateTime(2026, 8),
          departureTime: '22:00',
          arrivalTime: '10:30',
          availableKg: 10.0,
          totalKg: 23.0,
          pricePerKg: 8.0,
          status: 'ACTIVE',
          bidsCount: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
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

        await pumpAndDrain(
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

    testWidgets('submit en édition forwarde la date limite au bloc', (
      tester,
    ) async {
      final ann = _makeFullAnnouncement();

      await navigateToStep2(tester, ann);

      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Date limite de dépôt obligatoire'), findsNothing);
      // Une modification ne touche qu'une étape : pas de section « étapes ».
      expect(find.byKey(const Key('trip-legs-section')), findsNothing);
      verify(
        () => announcementBloc.add(
          any(
            that: isA<AnnouncementUpdateRequested>().having(
              (e) => e.handoverDeadline,
              'handoverDeadline',
              // Heure enregistrée (18:00, avant le départ) gardée telle
              // quelle (FLUTTER-PK).
              DateTime(2026, 8, 1, 18),
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('heure choisie au sélecteur : transmise telle quelle au bloc', (
      tester,
    ) async {
      final departure = _handoverPickDeparture();
      final day = DateTime(departure.year, departure.month, departure.day - 1);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(
            args: CreateTripArgs(
              // Une limite dans le mois du départ : le calendrier s'ouvre sur
              // ce mois, où se trouve le jour à toucher (sans elle, il
              // s'ouvrait sur le mois courant, sans ce jour à la fin du mois).
              announcement: _makeFullAnnouncement(
                departureDate: departure,
                handoverDeadline: DateTime(
                  departure.year,
                  departure.month,
                  departure.day - 1,
                  23,
                  59,
                ),
              ),
            ),
          ),
          use24h: true,
        ),
      );

      await _pickHandover(tester, day, hour: '18', minute: '00');
      await _goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        () => announcementBloc.add(
          any(
            that: isA<AnnouncementUpdateRequested>().having(
              (e) => e.handoverDeadline,
              'handoverDeadline',
              DateTime(day.year, day.month, day.day, 18),
            ),
          ),
        ),
      ).called(1);
    });
  });

  // ── Group: Toggle Espèces et encart commission ───────────────────────────────
  // Migré de create_announcement_cash_toggle_test.dart. Le switch lui-même est
  // couvert au niveau widget par prix_step_test ; ce qui est unique
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
      when(() => b.isClosed).thenReturn(false);
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

    /// Navigue jusqu'à l'étape Prix, où vit PrixStep.
    Future<void> navigateToStep2(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final args = CreateTripArgs(announcement: _makeFullAnnouncement());
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));
      await _goToStep(tester, TripFormStep.prix);
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

      // Sans Stripe, CASH est la seule méthode possible : la ligne reste à
      // ON. L'interrupteur n'est plus désactivé (grisé, il se lisait
      // « indisponible », Sentry FLUTTER-8M) : un toucher explique, sans
      // jamais le couper.
      final tile = tester.widget<SwitchListTile>(cashSwitch);
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNotNull);
      expect(
        find.textContaining('Toujours accepté sur ce trajet'),
        findsOneWidget,
      );

      await tester.ensureVisible(cashSwitch);
      await tester.pump();
      await tester.tap(cashSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('les espèces restent toujours acceptées'),
        findsOneWidget,
      );
      expect(tester.widget<SwitchListTile>(cashSwitch).value, isTrue);

      // L'encart commission reste visible puisque CASH est actif.
      expect(find.byType(CashCommissionNotice), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
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
      departureDate: DateTime(2026, 8),
      departureTime: departureTime,
      arrivalTime: arrivalTime == null
          ? null
          : '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}',
      availableKg: 10.0,
      totalKg: 23.0,
      pricePerKg: 8.0,
      status: 'ACTIVE',
      bidsCount: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      handoverDeadline: DateTime(2026, 8, 1, 18),
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

      await pumpAndDrain(
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
        final moments = useRecordingMoments();
        await pump(tester, null);
        // Laisse passer les post-frames qui stabilisent la référence.
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byType(DonyAppBarBackButton));
        await tester.pumpAndSettle();

        expect(find.text('Quitter sans enregistrer ?'), findsNothing);
        // Rien n'a été commencé : aucun formulaire abandonné.
        expect(moments.emitted, isEmpty);
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
      'modification d\'un trajet quittée : ce n\'est pas un formulaire abandonné',
      (tester) async {
        final moments = useRecordingMoments();
        await pump(
          tester,
          makeAnnouncement(arrivalTime: const TimeOfDay(hour: 10, minute: 30)),
        );
        await tester.pump();
        await tester.pump();

        await editSomething(tester);
        await tester.tap(find.byType(DonyAppBarBackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quitter'));
        await tester.pumpAndSettle();

        expect(moments.emitted, isEmpty);
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
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

      await _goToStep(tester, TripFormStep.conditions);

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

    for (final (code, reason, title) in [
      (
        'traveler-status-required',
        PublishingReason.statusRequired,
        'Limite de 4 trajets atteinte ce mois-ci',
      ),
      (
        'monthly-limit-reached',
        PublishingReason.limitReached,
        'Vous ne pouvez plus créer de trajet ce mois-ci',
      ),
      (
        'gp-pro-pending',
        PublishingReason.gpProPending,
        "Votre demande GP Pro est en cours d'examen",
      ),
    ]) {
      testWidgets('$code (403) → écran de blocage, pas de snackbar générique, '
          'le même envoi ne repart pas tant que rien ne se débloque', (
        tester,
      ) async {
        final statusRepo = _MockTravelerStatusRepository();
        when(() => statusRepo.checkEligibility()).thenAnswer(
          (_) async => (
            eligibility: PublishingEligibility(
              allowed: false,
              reason: reason,
              limit: 4,
              used: 4,
              resetsOn: DateTime(2026, 12),
            ),
            failureCode: null,
          ),
        );
        getIt.registerSingleton<TravelerStatusRepository>(statusRepo);
        getIt.registerFactory<TravelerStatusCubit>(
          () => TravelerStatusCubit(statusRepo, getIt<AnalyticsService>()),
        );
        addTearDown(() {
          if (getIt.isRegistered<TravelerStatusCubit>()) {
            getIt.unregister<TravelerStatusCubit>();
          }
          if (getIt.isRegistered<TravelerStatusRepository>()) {
            getIt.unregister<TravelerStatusRepository>();
          }
        });

        await navigateLockedToStep2AndSubmit(tester);
        verify(() => negotiationBloc.add(any())).called(1);

        negoStreamCtrl.add(NegotiationError(ForbiddenException('x', code)));
        await tester.pumpAndSettle();

        expect(find.text(title), findsOneWidget);
        expect(find.widgetWithText(DonyButton, 'Plus tard'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        verifyNever(() => negotiationBloc.add(any()));
      });
    }

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

    // Le solde du portefeuille ne conditionne plus la liaison d'un trajet : ces
    // deux reasons ne sont plus levées au trip-linking, et les feuilles de
    // blocage qui les traitaient ont été supprimées. Si elles remontent quand
    // même, le voyageur reçoit l'erreur générique, jamais une feuille morte.
    testWidgets(
      'cash-funds-required → aucune feuille de blocage, erreur générique',
      (tester) async {
        // DonySnackbar déduplique le même message pendant 5 s : sans ce reset,
        // le snackbar générique du test précédent avale celui-ci.
        DonySnackbar.clearDedup();
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

        expect(find.text('Solde insuffisant'), findsNothing);
        expect(find.text('Ajouter une carte'), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'none-available → aucune feuille de blocage, erreur générique',
      (tester) async {
        // Cf. le test précédent : la déduplication des snackbars est globale.
        DonySnackbar.clearDedup();
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

        expect(find.text('Aucun moyen de paiement disponible'), findsNothing);
        expect(find.byKey(const Key('unlock-cash-payment-cta')), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });

  // ── Group: threadId==null — offer + dedicated trip created atomically ────────

  group(
    'CreateTripScreen — locked flow without an existing thread (Task 9+10)',
    () {
      late _MockNegotiationBloc negotiationBloc;

      setUp(() {
        negotiationBloc = _makeNegotiationBloc();
        when(() => negotiationBloc.add(any())).thenReturn(null);
      });

      testWidgets('dispatches NegotiationStartWithDedicatedTripRequested when '
          'lockContext.threadId is null', (tester) async {
        tester.view.physicalSize = const Size(800, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final lockContext = LockedTripContext(
          packageRequestId: 'req-1',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          desiredDate: DateTime(2026, 9),
          dateToleranceDays: 5,
          weightKg: 5.0,
          transportMode: TransportMode.plane,
          agreedPriceEur: 50.0,
          // Capacité et message saisis par le voyageur dans la feuille
          // d'offre AVANT de créer le trajet dédié — distincts du poids de
          // la demande (weightKg) et absents par défaut.
          offerAvailableKg: 8.0,
          offerBody: 'Je peux prendre ce colis',
        );

        final args = CreateTripArgs(
          lockContext: lockContext,
          announcement: _makeFullAnnouncement(),
          negotiationBloc: negotiationBloc,
        );
        await pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        await _goToStep(tester, TripFormStep.conditions);

        expect(
          find.byKey(const Key('create-dedicated-trip-submit')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('create-dedicated-trip-submit')));
        await tester.pump();

        final captured = verify(
          () => negotiationBloc.add(captureAny()),
        ).captured;
        expect(
          captured.whereType<NegotiationStartWithDedicatedTripRequested>(),
          hasLength(1),
        );
        final event = captured
            .whereType<NegotiationStartWithDedicatedTripRequested>()
            .single;
        expect(event.packageRequestId, 'req-1');
        expect(event.proposedPriceEur, 50.0);
        // La capacité saisie dans l'offre (8 kg), pas lockContext.weightKg
        // (5 kg, le poids de la demande) — régression : ces deux valeurs
        // étaient confondues avant le fix.
        expect(event.travelerAvailableKg, 8.0);
        expect(event.body, 'Je peux prendre ce colis');
        expect(event.dedicatedTrip.pickupAddress['label'], 'Tour Eiffel');
        expect(event.dedicatedTrip.deliveryAddress['label'], 'Dakar Centre');
      });

      testWidgets(
        'falls back to lockContext.weightKg and null body when the offer '
        'form didn\'t carry them (defensive default)',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1024);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final lockContext = LockedTripContext(
            packageRequestId: 'req-1',
            departureCity: 'Lyon',
            arrivalCity: 'Abidjan',
            desiredDate: DateTime(2026, 9),
            dateToleranceDays: 5,
            weightKg: 5.0,
            transportMode: TransportMode.plane,
            agreedPriceEur: 50.0,
          );

          final args = CreateTripArgs(
            lockContext: lockContext,
            announcement: _makeFullAnnouncement(),
            negotiationBloc: negotiationBloc,
          );
          await pumpAndDrain(
            tester,
            _wrapWithRouter(CreateTripScreen(args: args)),
          );

          await _goToStep(tester, TripFormStep.conditions);
          await tester.tap(
            find.byKey(const Key('create-dedicated-trip-submit')),
          );
          await tester.pump();

          final event = verify(() => negotiationBloc.add(captureAny())).captured
              .whereType<NegotiationStartWithDedicatedTripRequested>()
              .single;
          expect(event.travelerAvailableKg, 5.0);
          expect(event.body, isNull);
        },
      );
    },
  );

  // ── Group: threadId==null — fix round 1 (resubmit + success feedback) ───────

  group(
    'CreateTripScreen — locked flow without an existing thread: fix round 1',
    () {
      late StreamController<NegotiationState> negoStreamCtrl;
      late _MockNegotiationBloc negotiationBloc;

      setUp(() {
        negoStreamCtrl = StreamController<NegotiationState>.broadcast();
        negotiationBloc = _MockNegotiationBloc();
        when(
          () => negotiationBloc.state,
        ).thenReturn(const NegotiationInitial());
        when(
          () => negotiationBloc.stream,
        ).thenAnswer((_) => negoStreamCtrl.stream);
        when(() => negotiationBloc.add(any())).thenReturn(null);

        // Same reasoning as the "422 payment-method reason routing" group:
        // left unregistered so showCashInsufficientSheet's try/catch exercises
        // the "Ajouter une carte" branch deterministically.
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
      /// "Confirmer le trajet" with a `lockContext.threadId == null`,
      /// dispatching the initial `NegotiationStartWithDedicatedTripRequested`.
      Future<void> navigateNullThreadToStep2AndSubmit(
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(800, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final lockContext = LockedTripContext(
          packageRequestId: 'req-1',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          desiredDate: DateTime(2026, 9),
          dateToleranceDays: 5,
          weightKg: 5.0,
          transportMode: TransportMode.plane,
          agreedPriceEur: 50.0,
        );

        final args = CreateTripArgs(
          lockContext: lockContext,
          announcement: _makeFullAnnouncement(),
          negotiationBloc: negotiationBloc,
        );
        await pumpAndDrain(
          tester,
          _wrapWithRouter(CreateTripScreen(args: args)),
        );

        await _goToStep(tester, TripFormStep.conditions);

        expect(
          find.byKey(const Key('create-dedicated-trip-submit')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('create-dedicated-trip-submit')));
        await tester.pump();
      }

      // Ce flux non plus ne se fait plus bloquer sur le solde : la demande part
      // une seule fois, aucune feuille ne propose de la resoumettre avec un
      // consentement carte, et l'erreur éventuelle reste générique.
      testWidgets(
        'cash-funds-required sur le flux sans thread : aucune feuille, aucune '
        'resoumission',
        (tester) async {
          await navigateNullThreadToStep2AndSubmit(tester);

          negoStreamCtrl.add(
            const NegotiationError(
              ValidationException(
                'Cash funds required',
                code: 'payment-method/cash-funds-required',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Solde insuffisant'), findsNothing);
          expect(find.text('Ajouter une carte'), findsNothing);

          final calls = verify(
            () => negotiationBloc.add(captureAny()),
          ).captured;
          final submits = calls
              .whereType<NegotiationStartWithDedicatedTripRequested>();
          expect(submits, hasLength(1));
        },
      );

      testWidgets(
        'success on the null-threadId flow: NegotiationLoaded (thread OPEN, '
        'no pre-existing thread awaited payment) pops with confirmation '
        'instead of silently doing nothing',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1024);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final lockContext = LockedTripContext(
            packageRequestId: 'req-1',
            departureCity: 'Lyon',
            arrivalCity: 'Abidjan',
            desiredDate: DateTime(2026, 9),
            dateToleranceDays: 5,
            weightKg: 5.0,
            transportMode: TransportMode.plane,
            agreedPriceEur: 50.0,
          );
          final args = CreateTripArgs(
            lockContext: lockContext,
            announcement: _makeFullAnnouncement(),
            negotiationBloc: negotiationBloc,
          );

          // CreateTripScreen pops on success (`context.pop()`, GoRouter) — a
          // real app always reaches this screen via a push (from the
          // package-request screen), so it needs somewhere to pop back TO.
          // Pushing it on top of a real '/' route (rather than using it as
          // `initialLocation` directly, as `_wrapWithRouter` does for the
          // other tests in this file) mirrors that.
          final router = GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
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
                builder: (_, _) => MultiBlocProvider(
                  providers: [
                    BlocProvider<StripeAccountBloc>.value(
                      value: _makeStripeBloc(),
                    ),
                    BlocProvider<AuthBloc>.value(value: _makeAuthBloc()),
                    BlocProvider<KycBloc>.value(value: _makeKycBloc()),
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
                  child: CreateTripScreen(args: args),
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

          await _goToStep(tester, TripFormStep.conditions);
          await tester.tap(
            find.byKey(const Key('create-dedicated-trip-submit')),
          );
          await tester.pump();

          negoStreamCtrl.add(NegotiationLoaded(_fakeThread()));
          await tester.pumpAndSettle();

          // Before the fix, the listener only reacted to `awaitingPayment` —
          // a freshly-created thread from `NegotiationStartWithDedicatedTripRequested`
          // is OPEN (pending the sender's response), so nothing happened at
          // all. It must now pop back to '/' with a success confirmation.
          expect(find.text('open'), findsOneWidget);
          expect(find.byType(CreateTripScreen), findsNothing);
          expect(
            find.text('Offre envoyée avec le trajet associé.'),
            findsOneWidget,
          );
        },
      );
    },
  );

  // ── Group: English (i18n) ─────────────────────────────────────────────────

  group('CreateTripScreen — English', () {
    testWidgets('mode création : titre et bouton "Continue" traduits', (
      tester,
    ) async {
      useEnglish();
      setupViewport(tester);

      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

      expect(find.text('Post a trip'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('mode édition : titre traduit', (tester) async {
      useEnglish();
      setupViewport(tester);

      final args = CreateTripArgs(announcement: _makeAnnouncement());
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));

      expect(find.text('Edit trip'), findsOneWidget);
    });
  });

  // ── Group: réactivité à la langue (délégués réellement montés) ──────────

  group('CreateTripScreen — réactivité à la langue', () {
    testWidgets(
      'le titre suit un changement de langue en direct, sans redémarrer '
      'l\'app',
      (tester) async {
        setupViewport(tester);

        await pumpAndDrain(
          tester,
          _wrapWithRouter(const CreateTripScreen(), locale: AppL10n.fr),
        );
        expect(find.text('Publier un trajet'), findsOneWidget);
        expect(find.text('Post a trip'), findsNothing);

        await tester.pumpWidget(
          _wrapWithRouter(const CreateTripScreen(), locale: AppL10n.en),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Post a trip'), findsOneWidget);
        expect(find.text('Publier un trajet'), findsNothing);
      },
    );
  });

  // ── Encart de devise à l'étape Prix & conditions (FLUTTER-RA) ────────────
  // La reprise d'un brouillon local ouvre le formulaire de création à
  // l'étape où il s'était arrêté : le moyen le plus court d'atteindre les
  // étapes 2 et 3 sans tout ressaisir.
  group('CreateTripScreen — encart de devise à l\'étape Prix (FLUTTER-RA)', () {
    setUp(() {
      if (getIt.isRegistered<FormDraftCubit>()) {
        getIt.unregister<FormDraftCubit>();
      }
      registerTestFormDraftCubit(
        store: testFormDraftStore(storage: InMemoryFormDraftStorage()),
      );
      DonySnackbar.clearDedup();
    });

    TripFormDraft draftAt(int step, {int priceOption = -1}) {
      final day = DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 30)),
      );
      return TripFormDraft(
        stepId: _stepIdAt(step),
        currency: 'EUR',
        departureCity: 'Paris',
        departureCountryCode: 'FR',
        arrivalCity: 'Dakar',
        arrivalCountryCode: 'SN',
        departureDate: day,
        departureTime: '10:00',
        handoverDeadline: day.subtract(const Duration(days: 1)),
        transportMode: 'PLANE',
        priceOption: priceOption,
        cashEnabled: priceOption >= 0,
        // Les deux adresses ouvrent l'étape 3 à la reprise.
        pickupAddress: const AddressData(
          label: 'Gare de Lyon',
          lat: 48.844,
          lng: 2.374,
        ),
        deliveryAddress: const AddressData(
          label: 'Plateau',
          lat: 14.67,
          lng: -17.43,
        ),
      );
    }

    Future<void> pumpAt(
      WidgetTester tester,
      int step, {
      int priceOption = -1,
    }) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      registerCurrencyPreference('EUR');
      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(
            args: CreateTripArgs(
              resumeDraft: draftAt(step, priceOption: priceOption),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    final row = find.byKey(const Key('trip-currency-selector-row'));

    testWidgets('étape 1 (Trajet) : pas d\'encart', (tester) async {
      await pumpAt(tester, 0);
      expect(find.byType(TrajetStep), findsOneWidget);
      expect(row, findsNothing);
    });

    testWidgets('étape 2 (Lieux & capacité) : pas d\'encart', (tester) async {
      await pumpAt(tester, 1);
      expect(find.text('Trajet ✓'), findsOneWidget);
      expect(find.byType(PrixStep), findsNothing);
      expect(row, findsNothing);
    });

    testWidgets('étape 3 (Prix & conditions) : encart en tête, avant les '
        'prix', (tester) async {
      await pumpAt(tester, 2);
      expect(find.byType(PrixStep), findsOneWidget);
      expect(row, findsOneWidget);
      expect(find.text('Publié en Euro (EUR)'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Devise de publication : Euro, EUR. Les utilisateurs dans une '
          'autre devise voient un prix converti. Le paiement reste dans '
          'cette devise. Bouton, modifier la devise.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(row).dy,
        lessThan(tester.getTopLeft(find.byType(PrixStep)).dy),
      );
    });

    testWidgets('« Modifier » de la devise dans l\'aperçu ramène à '
        'l\'encart de l\'étape Prix et ouvre le sélecteur', (tester) async {
      // Un prix choisi : l'aperçu ne s'ouvre qu'avec un prix valide.
      await pumpAt(tester, 2, priceOption: 0);
      // L'aperçu s'ouvre de la dernière étape, Conditions.
      await _goToStep(tester, TripFormStep.conditions);
      final preview = tester.widget<DonyButton>(
        find.byKey(const Key('create-announcement-preview')),
      );
      expect(preview.onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('create-announcement-preview')));
      await tester.pumpAndSettle();
      final change = find.byKey(const Key('preview-currency-change'));
      await tester.scrollUntilVisible(
        change,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(change);
      await tester.pumpAndSettle();

      expect(find.text('Choisir une devise'), findsOneWidget);
      expect(find.byType(PrixStep), findsOneWidget);
      expect(row, findsOneWidget);
    });

    testWidgets('étape 3 : encart lisible avec texte agrandi', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpAt(tester, 2);
      expect(row, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'étape 3 : le tap ouvre le sélecteur avec l\'avertissement sur les '
      'moyens de paiement, et le choix se répercute sur l\'encart',
      (tester) async {
        await pumpAt(tester, 2);

        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(find.text('Choisir une devise'), findsOneWidget);
        expect(
          find.byKey(const Key('currency-payment-methods-notice')),
          findsOneWidget,
        );

        await tester.tap(find.text('Dollar américain (USD)'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('currency-selector-confirm')));
        await tester.pumpAndSettle();

        expect(find.text('Publié en Dollar américain (USD)'), findsOneWidget);
        expect(find.text('Publié en Euro (EUR)'), findsNothing);
      },
    );
  });

  // ── Brouillon local (création) ────────────────────────────────────────────
  group('CreateTripScreen — brouillon local', () {
    late InMemoryFormDraftStorage storage;
    late FormDraftStore store;

    setUp(() {
      storage = InMemoryFormDraftStorage();
      store = testFormDraftStore(storage: storage);
      if (getIt.isRegistered<FormDraftCubit>()) {
        getIt.unregister<FormDraftCubit>();
      }
      registerTestFormDraftCubit(store: store);
      DonySnackbar.clearDedup();
    });

    TripFormDraft draft({int step = 1}) {
      final day = DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 30)),
      );
      return TripFormDraft(
        stepId: _stepIdAt(step),
        currency: 'EUR',
        departureCity: 'Paris',
        departureCountryCode: 'FR',
        arrivalCity: 'Dakar',
        arrivalCountryCode: 'SN',
        departureDate: day,
        departureTime: '10:00',
        handoverDeadline: day.subtract(const Duration(days: 1)),
        transportMode: 'PLANE',
        description: 'Valise rigide',
      );
    }

    Future<void> pumpScreen(WidgetTester tester, CreateTripArgs? args) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));
      // Post-frames : référence de saisie, puis reprise du brouillon.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('reprise : champs rechargés, étape où il s\'était arrêté', (
      tester,
    ) async {
      await pumpScreen(tester, CreateTripArgs(resumeDraft: draft()));

      // Étape 1 (« Lieux & capacité ») : « Retour » n'existe qu'au-delà de
      // l'étape 0, validée d'après la saisie rechargée.
      expect(find.text('Trajet ✓'), findsOneWidget);
      expect(find.widgetWithText(DonyButton, 'Retour'), findsOneWidget);

      await tester.tap(find.widgetWithText(DonyButton, 'Retour'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Paris'), findsWidgets);
      expect(find.text('Dakar'), findsWidgets);
    });

    testWidgets('ouvert depuis « Mes modèles » : le modèle est appliqué', (
      tester,
    ) async {
      registerCurrencyPreference('EUR');
      await pumpScreen(
        tester,
        const CreateTripArgs(
          template: TripTemplate(
            id: 'tpl-1',
            label: 'Navette',
            departureCity: 'Abidjan',
            departureCountryCode: 'CI',
            arrivalCity: 'Lyon',
            arrivalCountryCode: 'FR',
            transportMode: 'PLANE',
            capacityUnit: 'SUITCASE_23KG',
            availableKg: 23,
            pricePerKg: 8,
            acceptedCategories: [],
          ),
        ),
      );

      final formBloc = BlocProvider.of<AnnouncementFormBloc>(
        tester.element(find.byType(TrajetStep)),
      );
      expect(formBloc.state.departureCity, 'Abidjan');
      expect(formBloc.state.arrivalCity, 'Lyon');
      expect(formBloc.state.departureCountryCode, 'CI');
      // Les dates restent à choisir.
      expect(formBloc.state.departureDate, isNull);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('reprise à une étape dont les précédentes sont incomplètes : '
        'retour à l\'étape 0', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: TripFormDraft(
            stepId: TripFormStep.prix,
            departureCity: draft().departureCity,
          ),
        ),
      );

      expect(find.widgetWithText(DonyButton, 'Retour'), findsNothing);
    });

    testWidgets('sortie après saisie : « Enregistrer le brouillon » le garde', (
      tester,
    ) async {
      final moments = useRecordingMoments();
      await pumpScreen(tester, CreateTripArgs(resumeDraft: draft()));

      await tester.tap(find.byType(DonyAppBarBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Garder votre saisie ?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('draft-exit-save')));
      await tester.pumpAndSettle();

      // Formulaire commencé puis quitté sans publier : un moment, avec le
      // corridor déjà saisi.
      expect(moments.triggers, [VideoModalTrigger.formAbandoned]);
      expect(
        const VideoModalCorridor(
          from: 'Paris',
          to: 'dakar',
        ).matches(moments.emitted.single.corridor),
        isTrue,
      );

      final saved = await store.read(FormDraftKind.trip);
      expect(saved, isNotNull);
      final back = TripFormDraft.fromJson(saved!.data);
      expect(back.departureCity, 'Paris');
      expect(back.arrivalCity, 'Dakar');
      expect(back.description, 'Valise rigide');
      expect(back.stepId, TripFormStep.capacite);
      expect(find.byType(CreateTripScreen), findsNothing);
    });

    testWidgets('sortie : « Quitter sans enregistrer » efface le brouillon', (
      tester,
    ) async {
      final moments = useRecordingMoments();
      await store.save(FormDraftKind.trip, draft().toJson());
      await pumpScreen(tester, CreateTripArgs(resumeDraft: draft()));

      await tester.tap(find.byType(DonyAppBarBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('draft-exit-discard')));
      await tester.pumpAndSettle();

      expect(moments.triggers, [VideoModalTrigger.formAbandoned]);

      expect(await store.read(FormDraftKind.trip), isNull);
      expect(find.byType(CreateTripScreen), findsNothing);
    });

    testWidgets('sortie : « Continuer la saisie » ne change rien', (
      tester,
    ) async {
      final moments = useRecordingMoments();
      await pumpScreen(tester, CreateTripArgs(resumeDraft: draft()));

      await tester.tap(find.byType(DonyAppBarBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('draft-exit-stay')));
      await tester.pumpAndSettle();

      // Il reste sur sa saisie : rien n'est abandonné.
      expect(moments.emitted, isEmpty);
      expect(find.byType(CreateTripScreen), findsOneWidget);
      expect(await store.read(FormDraftKind.trip), isNull);
    });

    testWidgets('bouton « Brouillon » : enregistre et quitte', (tester) async {
      final moments = useRecordingMoments();
      await pumpScreen(tester, CreateTripArgs(resumeDraft: draft()));

      await tester.tap(find.byKey(const Key('trip-save-draft')));
      await tester.pumpAndSettle();

      expect(moments.triggers, [VideoModalTrigger.formAbandoned]);
      expect((await store.read(FormDraftKind.trip))?.step, 1);
      expect(find.byType(CreateTripScreen), findsNothing);
    });

    testWidgets(
      'bouton « Brouillon » sur un formulaire vierge : rien à garder',
      (tester) async {
        await pumpScreen(tester, null);

        await tester.tap(find.byKey(const Key('trip-save-draft')));
        await tester.pump();

        expect(
          find.text('Rien à enregistrer pour l\'instant.'),
          findsOneWidget,
        );
        expect(storage.values, isEmpty);
        expect(find.byType(CreateTripScreen), findsOneWidget);
      },
    );

    testWidgets('trousseau en panne : message, la saisie reste à l\'écran', (
      tester,
    ) async {
      storage.failWrites = true;
      await pumpScreen(tester, CreateTripArgs(resumeDraft: draft()));

      await tester.tap(find.byKey(const Key('trip-save-draft')));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Le brouillon n\'a pas pu être enregistré sur ce téléphone.'),
        findsOneWidget,
      );
      expect(find.byType(CreateTripScreen), findsOneWidget);
    });

    testWidgets('modification d\'un trajet : pas de bouton brouillon', (
      tester,
    ) async {
      final ann = AnnouncementModel(
        id: 'ann-1',
        travelerId: 'trav-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 8),
        availableKg: 10.0,
        totalKg: 23.0,
        pricePerKg: 8.0,
        status: 'ACTIVE',
        bidsCount: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        transportMode: TransportMode.plane,
        acceptedPaymentMethods: {BidPaymentMethod.stripe},
      );
      await pumpScreen(tester, CreateTripArgs(announcement: ann));

      expect(find.byKey(const Key('trip-save-draft')), findsNothing);
    });
  });

  // ── Group: Créer avec l'IA (formulaires IA) ───────────────────────────────

  // ── YADONY-FLUTTER-PROD-18 : valise de 23 kg envoyée à 15 kg ─────────────
  // Le compteur de valises affiche le bloc, la soumission lit le notifier de
  // l'écran : les deux doivent partir de la même valeur, et un préremplissage
  // (modèle, brouillon, édition) ne doit pas être écrasé par ce défaut.

  group('CreateTripScreen — capacité par défaut (PROD-18)', () {
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

    Future<void> pumpScreen(WidgetTester tester, CreateTripArgs? args) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await pumpAndDrain(tester, _wrapWithRouter(CreateTripScreen(args: args)));
      // Post-frames : modèle appliqué, brouillon repris, unité de l'édition.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    AnnouncementFormBloc formBlocOf(WidgetTester tester) =>
        BlocProvider.of<AnnouncementFormBloc>(
          tester.element(find.byType(TrajetStep, skipOffstage: false)),
        );

    double notifierKg(WidgetTester tester) => tester
        .widget<PrixStep>(find.byType(PrixStep, skipOffstage: false))
        .availableKgNotifier
        .value;

    /// Kg que la création enverrait (cf. `handoverDeadlineOf`).
    double kgToSubmit(WidgetTester tester) {
      final state = tester.state<State<StatefulWidget>>(
        find.byKey(const Key('trip-form-content')),
      );
      return (state as dynamic).availableKgToSubmitForTest as double;
    }

    Future<void> send(WidgetTester tester, AnnouncementFormEvent e) async {
      formBlocOf(tester).add(e);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('création sans toucher la capacité : une valise de 23 kg '
        'affichée, dans le bloc et envoyée', (tester) async {
      await pumpScreen(tester, null);

      final bloc = formBlocOf(tester);
      expect(bloc.state.capacityUnit, CapacityUnit.suitcase23kg);
      expect(bloc.state.availableKg, 23);
      expect(notifierKg(tester), 23);
      expect(kgToSubmit(tester), 23);
    });

    testWidgets('valise de 32 kg choisie : 32 kg envoyés', (tester) async {
      await pumpScreen(tester, null);

      await send(tester, const CapacityUnitChanged(CapacityUnit.suitcase32kg));

      expect(formBlocOf(tester).state.availableKg, 32);
      expect(notifierKg(tester), 32);
      expect(kgToSubmit(tester), 32);
    });

    testWidgets('deux valises au compteur : 46 kg envoyés', (tester) async {
      await pumpScreen(tester, null);

      await send(tester, const AvailableKgChanged(46));

      expect(kgToSubmit(tester), 46);
    });

    testWidgets('unité valise : un kg hors multiple est ramené à un nombre '
        'entier de valises', (tester) async {
      await pumpScreen(tester, null);

      await send(tester, const AvailableKgChanged(15));
      expect(kgToSubmit(tester), 23);

      await send(tester, const AvailableKgChanged(40));
      expect(kgToSubmit(tester), 46);

      await send(tester, const CapacityUnitChanged(CapacityUnit.suitcase32kg));
      await send(tester, const AvailableKgChanged(50));
      expect(kgToSubmit(tester), 64);
    });

    testWidgets('kg personnalisé puis kg libre : le kg saisi part tel quel', (
      tester,
    ) async {
      await pumpScreen(tester, null);

      await send(tester, const CapacityUnitChanged(CapacityUnit.custom));
      // Le champ personnalisé part du défaut, pas de 1 kg ni de 15 kg.
      expect(formBlocOf(tester).state.availableKg, 23);
      await send(tester, const AvailableKgChanged(17));
      expect(kgToSubmit(tester), 17);

      await send(tester, const CapacityUnitChanged(CapacityUnit.kgFree));
      expect(kgToSubmit(tester), 17);
    });

    testWidgets('modèle « valise 23 kg, 46 kg » : 46 kg, pas le défaut', (
      tester,
    ) async {
      registerCurrencyPreference('EUR');
      await pumpScreen(
        tester,
        const CreateTripArgs(
          template: TripTemplate(
            id: 'tpl-46',
            label: 'Deux valises',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            transportMode: 'PLANE',
            capacityUnit: 'SUITCASE_23KG',
            availableKg: 46,
            pricePerKg: 8,
            acceptedCategories: [],
          ),
        ),
      );

      expect(formBlocOf(tester).state.availableKg, 46);
      expect(notifierKg(tester), 46);
      expect(kgToSubmit(tester), 46);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('brouillon à 46 kg : 46 kg, pas le défaut', (tester) async {
      await pumpScreen(
        tester,
        const CreateTripArgs(
          resumeDraft: TripFormDraft(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            transportMode: 'PLANE',
            capacityUnit: 'SUITCASE_23KG',
            availableKg: 46,
          ),
        ),
      );

      expect(formBlocOf(tester).state.availableKg, 46);
      expect(notifierKg(tester), 46);
      expect(kgToSubmit(tester), 46);

      await tester.pump(const Duration(seconds: 5));
    });

    Future<AnnouncementUpdateRequested> submitEdit(
      WidgetTester tester,
      AnnouncementModel announcement,
    ) async {
      await pumpScreen(tester, CreateTripArgs(announcement: announcement));
      await _goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));
      return verify(
        () => announcementBloc.add(captureAny()),
      ).captured.whereType<AnnouncementUpdateRequested>().single;
    }

    testWidgets('édition d\'un trajet en partie réservé (10 kg restants sur '
        'une valise) : 10 kg renvoyés, ni le défaut ni une valise pleine', (
      tester,
    ) async {
      final sent = await submitEdit(
        tester,
        _makeFullAnnouncement(capacityUnit: 'SUITCASE_23KG'),
      );
      expect(sent.availableKg, 10);
      expect(sent.capacityUnit, 'SUITCASE_23KG');
    });

    testWidgets('édition d\'un trajet de deux valises : 46 kg renvoyés', (
      tester,
    ) async {
      final sent = await submitEdit(
        tester,
        _makeFullAnnouncement(availableKg: 46, capacityUnit: 'SUITCASE_23KG'),
      );
      expect(sent.availableKg, 46);
    });
  });

  // ── Modes de transport : formulaire en cinq étapes (lot 1, Tâche 8) ─────────
  group('CreateTripScreen — modes de transport (cinq étapes)', () {
    late _MockAnnouncementBloc announcementBloc;
    late StreamController<AnnouncementState> states;
    String? intlLocaleBefore;

    setUp(() {
      // `DateFormat('yyyy-MM-dd')` du payload d'arrivée fixe la langue d'`intl`
      // à `en_US` quand rien ne l'a fait : rétablie après chaque test.
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
      DonySnackbar.clearDedup();
    });

    tearDown(() async {
      Intl.defaultLocale = intlLocaleBefore;
      resetTransportModesForTest();
      await states.close();
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

    void roadOn() => setTransportModes(
      const TransportModesAvailability(road: true, boat: false),
    );

    /// Voyageur vérifié au statut déclaré : « Publier » part sans question.
    const readyTraveler = AuthAuthenticated(
      UserModel(
        id: 'user-test-1',
        roles: ['TRAVELER'],
        kycStatus: 'VERIFIED',
        status: 'ACTIVE',
        travelerStatus: TravelerStatus.individual,
      ),
    );

    /// Saisie complète, reprise à [stepId]. [transportMode] nul : brouillon
    /// sans mode.
    TripFormDraft fullDraft({
      TripFormStep stepId = TripFormStep.conditions,
      String? transportMode = 'PLANE',
      String? arrivalTime,
      int arrivalDayOffset = 0,
    }) {
      final day = DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 30)),
      );
      return TripFormDraft(
        stepId: stepId,
        currency: 'EUR',
        departureCity: 'Paris',
        departureCountryCode: 'FR',
        arrivalCity: 'Dakar',
        arrivalCountryCode: 'SN',
        departureDate: day,
        departureTime: '10:00',
        arrivalTime: arrivalTime,
        arrivalDayOffset: arrivalDayOffset,
        handoverDeadline: day.subtract(const Duration(days: 1)),
        transportMode: transportMode,
        priceOption: 0,
        cashEnabled: true,
        pickupAddress: const AddressData(
          label: 'Gare de Lyon',
          lat: 48.844,
          lng: 2.374,
        ),
        deliveryAddress: const AddressData(
          label: 'Plateau',
          lat: 14.67,
          lng: -17.43,
        ),
      );
    }

    Future<void> pumpScreen(
      WidgetTester tester,
      CreateTripArgs? args, {
      Size size = const Size(800, 1024),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      registerCurrencyPreference('EUR');
      await pumpAndDrain(
        tester,
        _wrapWithRouter(CreateTripScreen(args: args), authState: readyTraveler),
      );
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    CaStepperHeader header(WidgetTester tester) =>
        tester.widget<CaStepperHeader>(find.byType(CaStepperHeader));

    DonyButton continueButton(WidgetTester tester) =>
        tester.widget<DonyButton>(find.byKey(const Key('trip-form-continue')));

    Future<void> publish(WidgetTester tester) async {
      final preview = find.byKey(const Key('create-announcement-preview'));
      await tester.tap(preview);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DonyButton, "Publier l'annonce"));
      await tester.pumpAndSettle();
    }

    AnnouncementCreateRequested sentCreate() => verify(
      () => announcementBloc.add(captureAny()),
    ).captured.whereType<AnnouncementCreateRequested>().single;

    testWidgets("avion seul : 4 étapes, pas d'étape Mode", (tester) async {
      await pumpScreen(tester, null);

      expect(header(tester).steps, const [
        TripFormStep.trajet,
        TripFormStep.capacite,
        TripFormStep.prix,
        TripFormStep.conditions,
      ]);
      expect(header(tester).current, TripFormStep.trajet);
      expect(find.byType(ModeStep, skipOffstage: false), findsNothing);
      expect(find.byType(TransportModeRow, skipOffstage: false), findsNothing);
      for (final label in ['Trajet', 'Capacité', 'Prix', 'Conditions']) {
        expect(
          find.descendant(
            of: find.byType(CaStepperHeader),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('route allumée : étape Mode, Continuer grisé sans choix', (
      tester,
    ) async {
      roadOn();
      await pumpScreen(tester, null);

      expect(header(tester).steps, const [
        TripFormStep.mode,
        TripFormStep.trajet,
        TripFormStep.capacite,
        TripFormStep.prix,
        TripFormStep.conditions,
      ]);
      expect(header(tester).current, TripFormStep.mode);
      expect(find.byType(ModeStep), findsOneWidget);
      expect(find.text('Retour'), findsNothing);
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const Key('mode-card-car')));
      await tester.pump();
      expect(continueButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('trip-form-continue')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(header(tester).current, TripFormStep.trajet);
      expect(find.text('Retour'), findsOneWidget);
      // Choisir le mode n'est pas une saisie de Trajet : rien en rouge.
      expect(find.text('Ville de départ obligatoire'), findsNothing);
    });

    testWidgets('route choisie : payload transportMode CAR', (tester) async {
      roadOn();
      // Brouillon complet sans mode : il rouvre sur l'étape Mode, à choisir.
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: fullDraft(transportMode: null)),
      );
      expect(header(tester).current, TripFormStep.mode);

      await tester.tap(find.byKey(const Key('mode-card-car')));
      await tester.pump();
      await _goToStep(tester, TripFormStep.conditions);
      await publish(tester);

      expect(sentCreate().transportMode, TransportMode.car);
    });

    testWidgets('avion seul : payload transportMode PLANE sans rien choisir', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: fullDraft(transportMode: null)),
      );
      expect(header(tester).current, TripFormStep.conditions);
      await publish(tester);

      expect(sentCreate().transportMode, TransportMode.plane);
    });

    testWidgets('bateau allumé : pas de carte bateau en création', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: false, boat: true),
      );
      await pumpScreen(tester, null);
      // Bateau seul allumé : la création reste « avion seul » (C1).
      expect(header(tester).steps.first, TripFormStep.trajet);
      expect(find.byType(ModeStep, skipOffstage: false), findsNothing);
    });

    testWidgets('bateau et route allumés : cartes Avion et Route seulement', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: true),
      );
      await pumpScreen(tester, null);

      expect(find.byKey(const Key('mode-card-plane')), findsOneWidget);
      expect(find.byKey(const Key('mode-card-car')), findsOneWidget);
      expect(find.byKey(const Key('mode-card-boat')), findsNothing);
    });

    testWidgets("modification d'un trajet BOAT : mode gardé et renvoyé BOAT", (
      tester,
    ) async {
      roadOn();
      final boatTrip = _makeFullAnnouncement(transportMode: TransportMode.boat);
      await pumpScreen(tester, CreateTripArgs(announcement: boatTrip));

      expect(header(tester).steps.first, TripFormStep.trajet);
      expect(find.byType(ModeStep, skipOffstage: false), findsNothing);
      final row = tester.widget<TransportModeRow>(
        find.byType(TransportModeRow),
      );
      expect(row.readOnly, isFalse);
      expect(row.notifier.value, TransportMode.boat);
      // Le mode réel est affiché, même s'il n'est pas proposable.
      expect(find.byKey(const Key('mode-chip-boat')), findsOneWidget);

      await _goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      final sent = verify(
        () => announcementBloc.add(captureAny()),
      ).captured.whereType<AnnouncementUpdateRequested>().single;
      expect(sent.transportMode, TransportMode.boat);
    });

    testWidgets("avion seul, modification d'un trajet avion : pas de ligne du "
        'mode (rien à choisir)', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(announcement: _makeFullAnnouncement()),
      );

      expect(header(tester).steps.first, TripFormStep.trajet);
      expect(find.byType(TransportModeRow, skipOffstage: false), findsNothing);
    });

    testWidgets("avion seul, modification d'un trajet BOAT : ligne du mode "
        'montrée, BOAT sélectionné', (tester) async {
      final boatTrip = _makeFullAnnouncement(transportMode: TransportMode.boat);
      await pumpScreen(tester, CreateTripArgs(announcement: boatTrip));

      final row = tester.widget<TransportModeRow>(
        find.byType(TransportModeRow),
      );
      expect(row.notifier.value, TransportMode.boat);
      expect(find.byKey(const Key('mode-chip-boat')), findsOneWidget);
    });

    testWidgets('avion seul, trajet dédié sur demande avion : pas de ligne du '
        'mode', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(
          lockContext: _makeLockContext(),
          negotiationBloc: _makeNegotiationBloc(),
        ),
      );

      expect(find.byType(TransportModeRow, skipOffstage: false), findsNothing);
    });

    testWidgets('modification : la ligne du mode change le mode envoyé', (
      tester,
    ) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(announcement: _makeFullAnnouncement()),
      );
      await tester.tap(find.byKey(const Key('mode-chip-car')));
      await tester.pump();

      await _goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      final sent = verify(
        () => announcementBloc.add(captureAny()),
      ).captured.whereType<AnnouncementUpdateRequested>().single;
      expect(sent.transportMode, TransportMode.car);
    });

    testWidgets("trajet dédié : ligne du mode en lecture seule, pas d'étape "
        'Mode', (tester) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(
          lockContext: _makeLockContext(),
          negotiationBloc: _makeNegotiationBloc(),
        ),
      );

      expect(header(tester).steps.first, TripFormStep.trajet);
      expect(find.byType(ModeStep, skipOffstage: false), findsNothing);
      final row = tester.widget<TransportModeRow>(
        find.byType(TransportModeRow),
      );
      expect(row.readOnly, isTrue);
      expect(row.notifier.value, TransportMode.plane);

      // Toucher une autre puce ne change rien : le mode vient de la demande.
      await tester.tap(find.byKey(const Key('mode-chip-car')));
      await tester.pump();
      expect(row.notifier.value, TransportMode.plane);
    });

    /// Contexte d'une demande dont le mode est [mode] (null : « peu importe »),
    /// avec ([threadId]) ou sans fil de négociation.
    LockedTripContext lockedContext(
      TransportMode? mode, {
      String? threadId = 'thread-1',
    }) => LockedTripContext(
      threadId: threadId,
      packageRequestId: 'req-1',
      departureCity: 'Lyon',
      arrivalCity: 'Abidjan',
      desiredDate: DateTime(2026, 9),
      dateToleranceDays: 5,
      weightKg: 5.0,
      transportMode: mode,
      agreedPriceEur: 50.0,
    );

    /// Ouvre le trajet dédié de [ctx], renseigne l'heure de départ et les
    /// la date limite de dépôt et les deux lieux de remise (par les rappels des
    /// étapes, sans passer par le sélecteur d'adresse), puis rend le bloc de négociation simulé. [onModeStep]
    /// agit à l'étape Mode quand elle s'affiche.
    Future<_MockNegotiationBloc> openDedicated(
      WidgetTester tester,
      LockedTripContext ctx, {
      Future<void> Function()? onModeStep,
    }) async {
      final nego = _makeNegotiationBloc();
      await pumpScreen(
        tester,
        CreateTripArgs(lockContext: ctx, negotiationBloc: nego),
      );
      if (onModeStep != null) await onModeStep();
      tester
          .widget<TrajetStep>(find.byType(TrajetStep, skipOffstage: false))
          .departureTimeNotifier
          .value = const TimeOfDay(
        hour: 10,
        minute: 0,
      );
      // Date limite de dépôt : l'étape Trajet ne laisse pas continuer sans.
      final content = tester.state<State<StatefulWidget>>(
        find.byKey(const Key('trip-form-content')),
      );
      (content as dynamic).handoverDeadlineForTest.value = DateTime(
        2026,
        8,
        31,
      );
      final lieux = tester.widget<LieuxCapaciteStep>(
        find.byType(LieuxCapaciteStep, skipOffstage: false),
      );
      lieux.onPickupChanged(
        const AddressData(label: 'Gare de Lyon', lat: 48.844, lng: 2.374),
      );
      lieux.onDeliveryChanged(
        const AddressData(label: 'Plateau', lat: 14.67, lng: -17.43),
      );
      await tester.pump();
      await _goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-dedicated-trip-submit')));
      await tester.pump();
      return nego;
    }

    testWidgets('trajet dédié sur demande peu importe : étape Mode puis '
        'transportMode envoyé', (tester) async {
      roadOn();
      final ctx = lockedContext(null);
      final nego = await openDedicated(
        tester,
        ctx,
        onModeStep: () async {
          // Étape Mode ouverte d'elle-même, avion d'office, pas de ligne du
          // mode (l'étape la remplace).
          expect(header(tester).current, TripFormStep.mode);
          expect(header(tester).steps.first, TripFormStep.mode);
          expect(find.byType(ModeStep), findsOneWidget);
          expect(
            find.byType(TransportModeRow, skipOffstage: false),
            findsNothing,
          );
          expect(continueButton(tester).onPressed, isNotNull);
          await tester.tap(find.byKey(const Key('mode-card-car')));
          await tester.pump();
        },
      );

      final event = verify(
        () => nego.add(captureAny()),
      ).captured.whereType<NegotiationCreateDedicatedTripRequested>().single;
      expect(event.threadId, 'thread-1');
      expect(event.transportMode, TransportMode.car);
    });

    testWidgets('trajet dédié sur demande peu importe : avion d\'office si '
        'le voyageur ne change rien', (tester) async {
      roadOn();
      final nego = await openDedicated(tester, lockedContext(null));

      final event = verify(
        () => nego.add(captureAny()),
      ).captured.whereType<NegotiationCreateDedicatedTripRequested>().single;
      expect(event.transportMode, TransportMode.plane);
    });

    testWidgets('trajet dédié, offre atomique sur demande peu importe : '
        'transportMode dans le payload', (tester) async {
      roadOn();
      final nego = await openDedicated(
        tester,
        lockedContext(null, threadId: null),
        onModeStep: () async {
          await tester.tap(find.byKey(const Key('mode-card-car')));
          await tester.pump();
        },
      );

      final event = verify(
        () => nego.add(captureAny()),
      ).captured.whereType<NegotiationStartWithDedicatedTripRequested>().single;
      expect(event.dedicatedTrip.transportMode, TransportMode.car);
      expect(event.dedicatedTrip.toJson()['transportMode'], 'CAR');
    });

    testWidgets('trajet dédié sur demande à mode connu : transportMode non '
        'envoyé (le back prend celui de la demande)', (tester) async {
      roadOn();
      final nego = await openDedicated(
        tester,
        lockedContext(TransportMode.boat),
      );

      final event = verify(
        () => nego.add(captureAny()),
      ).captured.whereType<NegotiationCreateDedicatedTripRequested>().single;
      expect(event.transportMode, isNull);
    });

    testWidgets('trajet dédié, offre atomique à mode connu : payload sans '
        'transportMode', (tester) async {
      roadOn();
      final nego = await openDedicated(
        tester,
        lockedContext(TransportMode.car, threadId: null),
      );

      final event = verify(
        () => nego.add(captureAny()),
      ).captured.whereType<NegotiationStartWithDedicatedTripRequested>().single;
      expect(event.dedicatedTrip.transportMode, isNull);
      expect(
        event.dedicatedTrip.toJson().containsKey('transportMode'),
        isFalse,
      );
    });

    /// Modèle de trajet complet (sans date), au mode [wire].
    TripTemplate templateOf(String wire) => TripTemplate(
      id: 'tmpl-$wire',
      label: 'Paris → Dakar',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      transportMode: wire,
      capacityUnit: 'KG_FREE',
      availableKg: 20,
      pricePerKg: 8,
      acceptedCategories: const [],
      currency: 'EUR',
      acceptedPaymentMethods: const ['CASH'],
      pickupAddress: const AddressData(
        label: 'Gare de Lyon',
        lat: 48.844,
        lng: 2.374,
      ),
      deliveryAddress: const AddressData(
        label: 'Plateau',
        lat: 14.67,
        lng: -17.43,
      ),
      departureTime: '10:00',
      handoverLeadDays: 1,
      departureCountryCode: 'FR',
      arrivalCountryCode: 'SN',
    );

    /// Date de départ dans un mois : le modèle n'en porte pas.
    Future<void> setDepartureInAMonth(WidgetTester tester) async {
      tester
          .widget<TrajetStep>(find.byType(TrajetStep, skipOffstage: false))
          .departureDateNotifier
          .value = DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 30)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    TransportMode? currentMode(WidgetTester tester) => tester
        .widget<TrajetStep>(find.byType(TrajetStep, skipOffstage: false))
        .transportModeNotifier
        ?.value;

    testWidgets('modèle PLANE venu de la feuille, puis étape Mode → Route : '
        'le mode choisi est CAR et part en CAR', (tester) async {
      roadOn();
      await pumpScreen(tester, CreateTripArgs(template: templateOf('PLANE')));
      // La confirmation « modèle appliqué » recouvre les boutons du bas.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      // Le modèle n'a pas choisi le mode à la place du voyageur.
      expect(currentMode(tester), isNull);

      await tester.tap(find.byKey(const Key('mode-card-car')));
      await tester.pump();
      await _goToStep(tester, TripFormStep.trajet);
      expect(currentMode(tester), TransportMode.car);

      await setDepartureInAMonth(tester);
      await _goToStep(tester, TripFormStep.conditions);
      await publish(tester);

      expect(sentCreate().transportMode, TransportMode.car);
    });

    testWidgets('modèle BOAT, avion seul : le trajet part en PLANE', (
      tester,
    ) async {
      await pumpScreen(tester, CreateTripArgs(template: templateOf('BOAT')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(currentMode(tester), TransportMode.plane);

      await setDepartureInAMonth(tester);
      await _goToStep(tester, TripFormStep.conditions);
      await publish(tester);

      expect(sentCreate().transportMode, TransportMode.plane);
    });

    testWidgets('brouillon BOAT, route allumée : étape Mode sans sélection', (
      tester,
    ) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: fullDraft(transportMode: 'BOAT')),
      );

      expect(header(tester).current, TripFormStep.mode);
      expect(currentMode(tester), isNull);
      expect(find.byKey(const Key('mode-check-plane')), findsNothing);
      expect(find.byKey(const Key('mode-check-car')), findsNothing);
      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('brouillon BUS, route allumée : gardé (affiché Route)', (
      tester,
    ) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: fullDraft(transportMode: 'BUS')),
      );

      expect(header(tester).current, TripFormStep.conditions);
      expect(currentMode(tester), TransportMode.bus);
    });

    testWidgets('brouillon CAR, avion seul : ramené à PLANE', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: fullDraft(transportMode: 'CAR')),
      );
      await publish(tester);

      expect(sentCreate().transportMode, TransportMode.plane);
    });

    testWidgets("Passer ouvre l'aperçu", (tester) async {
      await pumpScreen(tester, CreateTripArgs(resumeDraft: fullDraft()));
      expect(header(tester).current, TripFormStep.conditions);

      final skip = find.byKey(const Key('trip-conditions-skip'));
      expect(skip, findsOneWidget);
      // Au-dessus des conditions.
      expect(
        tester.getTopLeft(skip).dy,
        lessThan(tester.getTopLeft(find.byType(ConditionsStep)).dy),
      );
      await tester.tap(skip);
      await tester.pumpAndSettle();

      expect(find.byType(AnnouncementPreviewSheet), findsOneWidget);
    });

    testWidgets('Passer : création seulement', (tester) async {
      await pumpScreen(
        tester,
        CreateTripArgs(announcement: _makeFullAnnouncement()),
      );
      await _goToStep(tester, TripFormStep.conditions);
      expect(
        find.byKey(const Key('trip-conditions-skip'), skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('brouillon step 2 rouvre à Prix', (tester) async {
      roadOn();
      // Brouillon enregistré par la version à trois étapes : `step: 2`
      // (« Prix & conditions »), sans `stepId`.
      final legacy = fullDraft().toJson()..remove('stepId');
      legacy['step'] = 2;
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: TripFormDraft.fromJson(legacy)),
      );

      expect(header(tester).current, TripFormStep.prix);
      expect(find.byType(PrixStep), findsOneWidget);
    });

    testWidgets('brouillon à Conditions, prix manquant : rouvre à Prix', (
      tester,
    ) async {
      final draft = fullDraft();
      final noPrice = draft.toJson()..['priceOption'] = -1;
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: TripFormDraft.fromJson(noPrice)),
      );

      expect(header(tester).current, TripFormStep.prix);
    });

    testWidgets("brouillon à l'étape Mode, avion seul : rouvre à Trajet", (
      tester,
    ) async {
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: fullDraft(stepId: TripFormStep.mode)),
      );

      expect(header(tester).current, TripFormStep.trajet);
    });

    testWidgets('422 transport-mode-disabled : message du serveur, saisie '
        'gardée', (tester) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: fullDraft(transportMode: 'CAR')),
      );
      expect(header(tester).current, TripFormStep.conditions);
      await publish(tester);
      expect(sentCreate().transportMode, TransportMode.car);

      states.add(
        AnnouncementError(
          const ValidationException(
            "La route n'est pas encore ouverte.",
            code: 'transport-mode-disabled',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text("La route n'est pas encore ouverte."), findsOneWidget);
      // Le formulaire reste ouvert, rempli, à la même étape.
      expect(find.byType(CreateTripScreen), findsOneWidget);
      expect(header(tester).current, TripFormStep.conditions);
      final trajet = tester.widget<TrajetStep>(
        find.byType(TrajetStep, skipOffstage: false),
      );
      expect(trajet.departureCityNotifier.value, 'Paris');
      expect(trajet.transportModeNotifier?.value, TransportMode.car);
      await tester.pump(const Duration(seconds: 5));
    });

    for (final english in [false, true]) {
      final lang = english ? 'en' : 'fr';
      testWidgets('360 dp $lang : barre Retour/Continuer et Passer sur une '
          'ligne', (tester) async {
        if (english) useEnglish();
        roadOn();
        await pumpScreen(
          tester,
          CreateTripArgs(resumeDraft: fullDraft(stepId: TripFormStep.trajet)),
          size: const Size(360, 780),
        );
        final back = english ? 'Back' : 'Retour';
        final cont = english ? 'Continue' : 'Continuer';
        final skip = english ? 'Skip' : 'Passer';

        /// Libellé sur une ligne, à sa taille : ni retour à la ligne, ni
        /// police rétrécie par le `FittedBox` du bouton.
        void expectOneLine(Finder text) {
          expect(text, findsOneWidget);
          final style = DefaultTextStyle.of(
            tester.element(text),
          ).style.merge(tester.widget<Text>(text).style);
          final laidOut = tester.getSize(text);
          expect(laidOut.height, lessThan((style.fontSize ?? 14) * 2));
          expect(tester.getRect(text).width, closeTo(laidOut.width, 0.5));
        }

        Finder buttonLabel(String label) => find.descendant(
          of: find.widgetWithText(DonyButton, label),
          matching: find.text(label),
        );

        expect(header(tester).current, TripFormStep.trajet);
        expect(tester.takeException(), isNull);
        final backHeight = tester
            .getSize(find.widgetWithText(DonyButton, back))
            .height;
        expect(
          tester.getSize(find.widgetWithText(DonyButton, cont)).height,
          backHeight,
        );
        expectOneLine(buttonLabel(back));
        expectOneLine(buttonLabel(cont));

        await _goToStep(tester, TripFormStep.conditions);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.widgetWithText(DonyButton, back)).height,
          backHeight,
        );
        expectOneLine(
          find.descendant(
            of: find.byKey(const Key('trip-conditions-skip')),
            matching: find.text(skip),
          ),
        );
        expectOneLine(buttonLabel(english ? 'Preview' : 'Aperçu'));
        await tester.pump(const Duration(seconds: 5));
      });
    }

    for (final english in [false, true]) {
      for (final dedicated in [false, true]) {
        final lang = english ? 'en' : 'fr';
        final kind = dedicated ? 'trajet dédié' : 'modification';
        testWidgets('360 dp $lang, $kind : Retour et bouton final sur une '
            'ligne', (tester) async {
          if (english) useEnglish();
          await pumpScreen(
            tester,
            dedicated
                ? CreateTripArgs(
                    lockContext: _makeLockContext(),
                    announcement: _makeFullAnnouncement(),
                    negotiationBloc: _makeNegotiationBloc(),
                  )
                : CreateTripArgs(announcement: _makeFullAnnouncement()),
            size: const Size(360, 780),
          );
          await _goToStep(tester, TripFormStep.conditions);
          expect(tester.takeException(), isNull);

          final back = english ? 'Back' : 'Retour';
          final last = switch ((english, dedicated)) {
            (false, false) => 'Enregistrer',
            (true, false) => 'Save',
            (false, true) => 'Confirmer le trajet',
            (true, true) => 'Confirm the trip',
          };
          for (final label in [back, last]) {
            final text = find.descendant(
              of: find.widgetWithText(DonyButton, label),
              matching: find.text(label),
            );
            expect(text, findsOneWidget);
            final laidOut = tester.getSize(text);
            // Ni rétréci par le FittedBox, ni sur deux lignes.
            expect(tester.getRect(text).width, closeTo(laidOut.width, 0.5));
            expect(laidOut.height, lessThan(30));
          }
        });
      }
    }

    // ── Route : capacité en tonnes, taille et poids max (T3) ──────────────

    /// Route choisie à l'étape Mode sur un brouillon complet sans mode, puis
    /// arrivée à l'étape Capacité.
    Future<void> roadAtCapacity(WidgetTester tester, {Size? size}) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(resumeDraft: fullDraft(transportMode: null)),
        size: size ?? const Size(800, 1024),
      );
      await tester.tap(find.byKey(const Key('mode-card-car')));
      await tester.pump();
      await _goToStep(tester, TripFormStep.capacite);
    }

    Future<void> backTo(WidgetTester tester, TripFormStep target) async {
      for (var i = 0; i < TripFormStep.values.length; i++) {
        if (header(tester).current == target) return;
        await tester.tap(find.widgetWithText(DonyButton, 'Retour'));
        await tester.pump(const Duration(milliseconds: 600));
      }
      fail('étape $target non atteinte');
    }

    Future<void> typeIn(WidgetTester tester, String key, String text) async {
      final field = find.byKey(Key(key));
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('route : pas de puce valise, taille max visible et '
        'facultative', (tester) async {
      await roadAtCapacity(tester);
      expect(find.text('1 valise 23 kg'), findsNothing);
      expect(find.text('Personnalisé'), findsOneWidget);
      expect(find.text("Taille max d'un colis (facultatif)"), findsOneWidget);
      expect(find.text('Poids max par colis (kg, facultatif)'), findsOneWidget);
      // Aucune taille choisie : « Continuer » reste actif (C24).
      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('route sans taille : Continuer actif, payload sans '
        'maxItemSize', (tester) async {
      await roadAtCapacity(tester);
      expect(continueButton(tester).onPressed, isNotNull);
      await _goToStep(tester, TripFormStep.conditions);
      await publish(tester);

      final sent = sentCreate();
      expect(sent.transportMode, TransportMode.car);
      expect(sent.maxItemSize, isNull);
      expect(sent.maxParcelWeightKg, isNull);
      // Valise par défaut du brouillon convertie : kg exact (C27).
      expect(sent.capacityUnit, 'KG_EXACT');
    });

    testWidgets('route publiée : payload maxItemSize L, maxParcelWeightKg 20, '
        'availableKg 1200', (tester) async {
      await roadAtCapacity(tester);
      await typeIn(tester, 'capacity-kg-field', '1200');
      await tester.ensureVisible(find.byKey(const Key('item-size-L')));
      await tester.tap(find.byKey(const Key('item-size-L')));
      await tester.pump();
      await typeIn(tester, 'max-parcel-weight-field', '20');
      expect(continueButton(tester).onPressed, isNotNull);

      await _goToStep(tester, TripFormStep.conditions);
      expect(
        find.text('Ex : meubles, électroménager, cartons…'),
        findsOneWidget,
      );
      await publish(tester);

      final sent = sentCreate();
      expect(sent.availableKg, 1200);
      expect(sent.capacityUnit, 'KG_EXACT');
      expect(sent.maxItemSize, ItemSize.l);
      expect(sent.maxParcelWeightKg, 20);
    });

    testWidgets('route : 2 500 kg acceptés, avion : 1 000 kg en erreur', (
      tester,
    ) async {
      await roadAtCapacity(tester);
      await typeIn(tester, 'capacity-kg-field', '2500');
      expect(find.byKey(const Key('capacity-kg-error')), findsNothing);
      expect(continueButton(tester).onPressed, isNotNull);

      await backTo(tester, TripFormStep.mode);
      await tester.tap(find.byKey(const Key('mode-card-plane')));
      await tester.pump();
      await _goToStep(tester, TripFormStep.capacite);
      await typeIn(tester, 'capacity-kg-field', '1000');
      expect(find.text('Au plus 999 kg pour ce mode'), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);
      await typeIn(tester, 'capacity-kg-field', '999');
      expect(find.byKey(const Key('capacity-kg-error')), findsNothing);
      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('route 1 200 kg puis avion : Continuer grisé, message « Au '
        'plus 999 kg »', (tester) async {
      await roadAtCapacity(tester);
      await typeIn(tester, 'capacity-kg-field', '1200');
      await backTo(tester, TripFormStep.mode);
      await tester.tap(find.byKey(const Key('mode-card-plane')));
      await tester.pump();
      await _goToStep(tester, TripFormStep.capacite);

      expect(find.text('Au plus 999 kg pour ce mode'), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);
      expect(find.byKey(const Key('capacity-road-limits')), findsNothing);
    });

    testWidgets('avion publié : payload sans maxItemSize ni '
        'maxParcelWeightKg', (tester) async {
      await roadAtCapacity(tester);
      await tester.ensureVisible(find.byKey(const Key('item-size-L')));
      await tester.tap(find.byKey(const Key('item-size-L')));
      await tester.pump();
      await typeIn(tester, 'max-parcel-weight-field', '20');
      await backTo(tester, TripFormStep.mode);
      await tester.tap(find.byKey(const Key('mode-card-plane')));
      await tester.pump();
      await _goToStep(tester, TripFormStep.conditions);
      await publish(tester);

      final sent = sentCreate();
      expect(sent.transportMode, TransportMode.plane);
      expect(sent.maxItemSize, isNull);
      expect(sent.maxParcelWeightKg, isNull);
    });

    testWidgets('poids max par colis hors bornes : Continuer grisé', (
      tester,
    ) async {
      await roadAtCapacity(tester);
      await typeIn(tester, 'capacity-kg-field', '100');
      await typeIn(tester, 'max-parcel-weight-field', '150');
      expect(
        find.text('Entre 0,5 kg et la capacité du trajet'),
        findsOneWidget,
      );
      expect(continueButton(tester).onPressed, isNull);
      await typeIn(tester, 'max-parcel-weight-field', '');
      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('modification route : taille et poids non touchés gardés, '
        'effacés envoyés', (tester) async {
      roadOn();
      final roadTrip = _makeFullAnnouncement(
        transportMode: TransportMode.car,
        capacityUnit: 'KG_EXACT',
        availableKg: 1200,
        maxItemSize: ItemSize.l,
        maxParcelWeightKg: 20,
      );
      await pumpScreen(tester, CreateTripArgs(announcement: roadTrip));
      await _goToStep(tester, TripFormStep.capacite);
      expect(find.text('1 valise 23 kg'), findsNothing);
      // Taille relue, poids max relu.
      final tile = tester.widget<Semantics>(
        find.byKey(const Key('item-size-L')),
      );
      expect(tile.properties.selected, isTrue);
      // Effacer le poids, garder la taille.
      await typeIn(tester, 'max-parcel-weight-field', '');

      await _goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      final sent = verify(
        () => announcementBloc.add(captureAny()),
      ).captured.whereType<AnnouncementUpdateRequested>().single;
      expect(sent.maxItemSize.isKeep, isTrue);
      expect(sent.maxParcelWeightKg.isClear, isTrue);
      expect(sent.availableKg, 1200);
    });

    testWidgets('modification avion : rien envoyé pour taille et poids', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        CreateTripArgs(announcement: _makeFullAnnouncement()),
      );
      await _goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));

      final sent = verify(
        () => announcementBloc.add(captureAny()),
      ).captured.whereType<AnnouncementUpdateRequested>().single;
      expect(sent.maxItemSize.isKeep, isTrue);
      expect(sent.maxParcelWeightKg.isKeep, isTrue);
    });

    testWidgets(
      'brouillon route J+10 rouvert en avion : arrivée bornée à J+3',
      (tester) async {
        final day = DateUtils.dateOnly(
          DateTime.now().add(const Duration(days: 30)),
        );
        final draft = TripFormDraft(
          currency: 'EUR',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: day,
          departureTime: '10:00',
          arrivalTime: '12:00',
          arrivalDayOffset: 10,
          // Route éteinte : le mode retombe sur l'avion (3 jours au plus).
          transportMode: 'CAR',
        );
        await pumpScreen(tester, CreateTripArgs(resumeDraft: draft));
        expect(
          tester
              .widget<ArrivalDayChips>(find.byType(ArrivalDayChips))
              .notifier
              .value,
          3,
        );
      },
    );

    // ── Route : arrivée « Autre date » jusqu'à J+14 (T4) ──────────────────

    /// Jour du départ des brouillons de [fullDraft], et son arrivée à +[n].
    DateTime draftDeparture() =>
        DateUtils.dateOnly(DateTime.now().add(const Duration(days: 30)));
    // Sans `DateFormat` : le premier appel fixerait `Intl.defaultLocale`
    // à `en_US` pour les tests suivants.
    String wireDay(DateTime d, int n) {
      final day = DateTime(d.year, d.month, d.day + n);
      String two(int v) => v.toString().padLeft(2, '0');
      return '${day.year}-${two(day.month)}-${two(day.day)}';
    }

    testWidgets('route sans heure d\'arrivée, J+5 : payload arrivalDate = '
        'départ + 5', (tester) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: fullDraft(transportMode: 'CAR', arrivalDayOffset: 5),
        ),
      );
      await publish(tester);

      final sent = sentCreate();
      expect(sent.transportMode, TransportMode.car);
      expect(sent.arrivalTime, isNull);
      expect(sent.arrivalDate, wireDay(draftDeparture(), 5));
    });

    testWidgets('route J+5 puis avion : décalage 0, aucun arrivalDate', (
      tester,
    ) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: fullDraft(
            stepId: TripFormStep.mode,
            transportMode: 'CAR',
            arrivalDayOffset: 5,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('mode-card-plane')));
      await tester.pump();
      await _goToStep(tester, TripFormStep.conditions);
      await publish(tester);

      final sent = sentCreate();
      expect(sent.transportMode, TransportMode.plane);
      expect(sent.arrivalDate, isNull);
    });

    testWidgets('avion J+3 avec heure puis route : J+3 gardé (borne 14)', (
      tester,
    ) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: fullDraft(
            stepId: TripFormStep.mode,
            arrivalTime: '12:00',
            arrivalDayOffset: 3,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('mode-card-car')));
      await tester.pump();
      await _goToStep(tester, TripFormStep.conditions);
      await publish(tester);

      expect(sentCreate().arrivalDate, wireDay(draftDeparture(), 3));
    });

    testWidgets('étape Trajet en route : pas d\'heure d\'arrivée, Autre date '
        'ouvre le sélecteur J+3..J+14', (tester) async {
      roadOn();
      await pumpScreen(
        tester,
        CreateTripArgs(
          resumeDraft: fullDraft(
            stepId: TripFormStep.trajet,
            transportMode: 'CAR',
          ),
        ),
      );
      expect(find.byKey(const Key('arrivalTimeField')), findsNothing);
      final other = find.byKey(const Key('arrival-day-other'));
      await tester.ensureVisible(other);
      await tester.tap(other);
      await tester.pumpAndSettle();

      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      final dep = draftDeparture();
      expect(picker.firstDate, DateTime(dep.year, dep.month, dep.day + 3));
      expect(picker.lastDate, DateTime(dep.year, dep.month, dep.day + 14));
    });

    for (final english in [false, true]) {
      final lang = english ? 'en' : 'fr';
      testWidgets('360 dp $lang : étape Trajet route, quatre puces d\'arrivée '
          'sur une ligne chacune', (tester) async {
        if (english) useEnglish();
        roadOn();
        await pumpScreen(
          tester,
          CreateTripArgs(
            resumeDraft: fullDraft(
              stepId: TripFormStep.trajet,
              transportMode: 'CAR',
              arrivalDayOffset: 6,
            ),
          ),
          size: const Size(360, 780),
        );
        await tester.ensureVisible(find.byKey(const Key('arrival-day-other')));
        await tester.pump();
        expect(tester.takeException(), isNull);

        final heights = <double>{};
        for (final k in [
          'arrival-day-0',
          'arrival-day-1',
          'arrival-day-2',
          'arrival-day-other',
        ]) {
          final chip = find.byKey(Key(k));
          expect(chip, findsOneWidget);
          final label = find.descendant(of: chip, matching: find.byType(Text));
          expect(tester.getSize(label.first).height, lessThan(24));
          heights.add(tester.getSize(chip).height);
        }
        expect(heights.length, 1);
        final other = english ? 'Other date' : 'Autre date';
        expect(find.text(other), findsOneWidget);
        expect(find.byKey(const Key('arrival-date-row')), findsOneWidget);
      });
    }

    testWidgets('modification d\'un trajet route à J+10 : ouvert à J+10, '
        'renvoyé tel quel', (tester) async {
      roadOn();
      final dep = draftDeparture();
      final roadTrip = _makeFullAnnouncement(
        transportMode: TransportMode.car,
        capacityUnit: 'KG_EXACT',
        departureDate: dep,
        handoverDeadline: dep.subtract(const Duration(days: 1)),
        arrivalTime: null,
        arrivalDate: DateTime(dep.year, dep.month, dep.day + 10),
      );
      await pumpScreen(tester, CreateTripArgs(announcement: roadTrip));

      final chips = tester.widget<ArrivalDayChips>(
        find.byType(ArrivalDayChips, skipOffstage: false),
      );
      expect(chips.notifier.value, 10);
      expect(chips.maxDays, 14);

      await _goToStep(tester, TripFormStep.conditions);
      await tester.tap(find.byKey(const Key('create-announcement-submit')));
      await tester.pump(const Duration(milliseconds: 600));
      final sent = verify(
        () => announcementBloc.add(captureAny()),
      ).captured.whereType<AnnouncementUpdateRequested>().single;
      expect(sent.arrivalDate, wireDay(dep, 10));
    });

    testWidgets('modification d\'un trajet avion à J+3 : borné à 3, pas 2', (
      tester,
    ) async {
      final dep = draftDeparture();
      final trip = _makeFullAnnouncement(
        departureDate: dep,
        handoverDeadline: dep.subtract(const Duration(days: 1)),
        arrivalDate: DateTime(dep.year, dep.month, dep.day + 3),
      );
      await pumpScreen(tester, CreateTripArgs(announcement: trip));

      final chips = tester.widget<ArrivalDayChips>(
        find.byType(ArrivalDayChips, skipOffstage: false),
      );
      expect(chips.notifier.value, 3);
    });

    for (final english in [false, true]) {
      final lang = english ? 'en' : 'fr';
      testWidgets('360 dp $lang : étape Capacité route et barre '
          'Retour/Continuer', (tester) async {
        if (english) useEnglish();
        await roadAtCapacity(tester, size: const Size(360, 780));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const Key('max-parcel-weight-field')),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final back = english ? 'Back' : 'Retour';
        final cont = english ? 'Continue' : 'Continuer';
        final backHeight = tester
            .getSize(find.widgetWithText(DonyButton, back))
            .height;
        expect(
          tester.getSize(find.widgetWithText(DonyButton, cont)).height,
          backHeight,
        );
        for (final label in [back, cont]) {
          final text = find.descendant(
            of: find.widgetWithText(DonyButton, label),
            matching: find.text(label),
          );
          final laidOut = tester.getSize(text);
          // Ni rétréci par le FittedBox, ni sur deux lignes.
          expect(tester.getRect(text).width, closeTo(laidOut.width, 0.5));
          expect(laidOut.height, lessThan(30));
        }
      });
    }
  });

  group('CreateTripScreen — Créer avec l’IA', () {
    final departure = isoDate(DateTime.now().add(const Duration(days: 30)));

    AiResolvedDraft outcome() => AiResolvedDraft(
      draft: {
        'departureCity': 'Paris',
        'departureCountryCode': 'FR',
        'arrivalCity': 'Abidjan',
        'arrivalCountryCode': 'CI',
        'departureDate': departure,
        'departureTime': '15:00',
        'transportMode': 'PLANE',
        'direct': true,
        'availableKg': 23,
        'capacityUnit': 'SUITCASE_23KG',
        'pricingMode': 'KG',
        'pricePerKg': 10,
        'currency': 'EUR',
        'cardEnabled': true,
        'cashEnabled': true,
      },
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('carte visible en création quand formDraftEnabled', (
      tester,
    ) async {
      setupViewport(tester);
      useAiFormDraft(enabled: true);
      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));
      expect(find.byKey(const Key('ai-entry-cta')), findsOneWidget);
    });

    testWidgets('carte absente si formDraftEnabled est faux ou absent', (
      tester,
    ) async {
      setupViewport(tester);
      useAiFormDraft(enabled: false);
      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));
      expect(find.byKey(const Key('ai-entry-cta')), findsNothing);
    });

    testWidgets('carte absente en modification', (tester) async {
      setupViewport(tester);
      useAiFormDraft(enabled: true);
      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          CreateTripScreen(
            args: CreateTripArgs(announcement: _makeAnnouncement()),
          ),
        ),
      );
      expect(find.byKey(const Key('ai-entry-cta')), findsNothing);
    });

    testWidgets('carte absente en reprise de brouillon', (tester) async {
      setupViewport(tester);
      useAiFormDraft(enabled: true);
      await pumpAndDrain(
        tester,
        _wrapWithRouter(
          const CreateTripScreen(
            args: CreateTripArgs(resumeDraft: TripFormDraft()),
          ),
        ),
      );
      expect(find.byKey(const Key('ai-entry-cta')), findsNothing);
    });

    testWidgets(
      '« Créer avec l’IA » remplit le formulaire : bandeau, marques',
      (tester) async {
        setupViewport(tester);
        final launcher = useAiFormDraft(enabled: true, outcome: outcome());
        await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));

        await tester.tap(find.byKey(const Key('ai-entry-cta')));
        await settle(tester);

        expect(launcher.calls.single.kind, AiFormKind.trip);
        expect(launcher.calls.single.defaultCurrency, isNotNull);
        expect(find.byKey(const Key('ai-filled-banner')), findsOneWidget);
        expect(find.byKey(const Key('ai-entry-cta')), findsNothing);
        // Heure de départ remplie dans son champ, marque « IA » posée.
        expect(find.text('15:00'), findsOneWidget);
        expect(find.byKey(const Key('ai-field-mark')), findsWidgets);
      },
    );

    testWidgets('« Reparler » rouvre le dialogue', (tester) async {
      setupViewport(tester);
      final launcher = useAiFormDraft(enabled: true, outcome: outcome());
      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));
      await tester.tap(find.byKey(const Key('ai-entry-cta')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('ai-talk-again')));
      await settle(tester);

      expect(launcher.calls, hasLength(2));
      expect(find.byKey(const Key('ai-filled-banner')), findsOneWidget);
    });

    testWidgets('« Reparler » qui ne remplit que l’heure garde les marques', (
      tester,
    ) async {
      setupViewport(tester);
      final launcher = useAiFormDraft(enabled: true, outcome: outcome());
      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));
      await tester.tap(find.byKey(const Key('ai-entry-cta')));
      await settle(tester);
      final marks = find.byKey(const Key('ai-field-mark')).evaluate().length;
      expect(marks, greaterThan(1));

      launcher.outcome = const AiResolvedDraft(
        draft: {'departureTime': '16:00'},
      );
      await tester.tap(find.byKey(const Key('ai-talk-again')));
      await settle(tester);

      expect(find.text('16:00'), findsOneWidget);
      expect(find.byKey(const Key('ai-field-mark')), findsNWidgets(marks));
    });

    testWidgets('grille + 10 €/kg : le prix au kilo dicté est gardé', (
      tester,
    ) async {
      setupViewport(tester);
      useAiFormDraft(
        enabled: true,
        outcome: AiResolvedDraft(
          draft: {...outcome().draft, 'pricingMode': 'MIXED'},
        ),
      );
      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));
      await tester.tap(find.byKey(const Key('ai-entry-cta')));
      await settle(tester);
      await settle(tester);

      final formBloc = BlocProvider.of<AnnouncementFormBloc>(
        tester.element(find.byType(TrajetStep)),
      );
      expect(formBloc.state.pricingMode, PricingMode.mixed);
      expect(formBloc.state.pricePerKg, 10);
    });

    testWidgets('feuille fermée sans remplir : le formulaire ne change pas', (
      tester,
    ) async {
      setupViewport(tester);
      useAiFormDraft(enabled: true);
      await pumpAndDrain(tester, _wrapWithRouter(const CreateTripScreen()));
      await tester.tap(find.byKey(const Key('ai-entry-cta')));
      await settle(tester);

      expect(find.byKey(const Key('ai-filled-banner')), findsNothing);
      expect(find.byKey(const Key('ai-entry-cta')), findsOneWidget);
      expect(find.byKey(const Key('ai-field-mark')), findsNothing);
    });
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

/// Départ dans quelques jours, avec la veille et l'avant-veille dans la même
/// grille du calendrier (le calendrier s'ouvre sur le mois de la limite : le
/// scénario doit poser une limite dans le mois du départ). Arithmétique de
/// calendrier, jamais `Duration` : un changement d'heure décalerait minuit.
DateTime _handoverPickDeparture({DateTime? now}) {
  final today = now ?? DateTime.now();
  var d = DateTime(today.year, today.month, today.day + 5);
  while (d.day > 26 || d.day < 4) {
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return d;
}

/// Avance par « Continuer » jusqu'à l'étape [target] (lue dans l'en-tête).
Future<void> _goToStep(WidgetTester tester, TripFormStep target) async {
  for (var i = 0; i < TripFormStep.values.length; i++) {
    final current = tester
        .widget<CaStepperHeader>(find.byType(CaStepperHeader))
        .current;
    if (current == target) return;
    await tester.tap(find.byKey(const Key('trip-form-continue')));
    await tester.pump(const Duration(milliseconds: 600));
  }
  fail('étape $target non atteinte');
}

/// Touche la ligne « Date limite de dépôt », choisit [day] au calendrier puis,
/// au sélecteur d'heure enchaîné, saisit [hour]:[minute] au clavier, ou
/// annule l'heure quand [hour] est nul.
Future<void> _pickHandover(
  WidgetTester tester,
  DateTime day, {
  String? hour,
  String? minute,
}) async {
  Future<void> settle() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  final rowFinder = find.byKey(const Key('sheet-handover-deadline-row'));
  await tester.ensureVisible(rowFinder);
  await settle();
  await tester.tap(rowFinder);
  await settle();
  expect(find.byType(DatePickerDialog), findsOneWidget);
  await tester.tap(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('${day.day}'),
    ),
  );
  await tester.tap(find.text('OK'));
  await settle();

  expect(find.byType(TimePickerDialog), findsOneWidget);
  if (hour == null) {
    await tester.tap(find.text('Cancel'));
    await settle();
    return;
  }
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await settle();
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute ?? '00');
  await tester.tap(find.text('OK'));
  await settle();
  expect(find.byType(TimePickerDialog), findsNothing);
}
