import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/bloc/residence_address_cubit.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/residence_address_screen.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/config/bloc/config_bloc.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/payments/presentation/screens/payment_screen.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/presentation/screens/scan_hub_screen.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/mock_analytics_backend.dart';

// Fournit un HelpCenterBloc minimal (catalogue vide) aux 4 harnais de ce
// fichier dont l'écran embarque désormais une ContextualTutorialCard
// (Task 7 du plan centre d'aide) : accueil, publication de trajet, paiement,
// scan. Sans ce provider, HelpCenterBloc n'est pas résolu dans l'arbre de
// widgets et context.select lève ProviderNotFoundException.
const _smokeEmptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

class _SmokeStaticHelpCenterSource implements HelpCenterConfigSource {
  const _SmokeStaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

BlocProvider<HelpCenterBloc> _smokeHelpCenterProvider() =>
    BlocProvider<HelpCenterBloc>(
      create: (_) => HelpCenterBloc(
        HelpCenterRepository(
          const _SmokeStaticHelpCenterSource(_smokeEmptyHelpConfigJson),
          fallbackJsonLoader: () async => _smokeEmptyHelpConfigJson,
        ),
        makeDisabledAnalytics(MockAnalyticsBackend()),
      )..add(const HelpCenterLoadRequested()),
    );

/// Monte un widget déjà entièrement câblé (MaterialApp/GoRouter compris,
/// c'est le rôle de chaque harnais spécifique à sa feature) à 200 % de
/// taille de texte et vérifie qu'aucune exception de mise en page
/// (`RenderFlex overflowed`, remontée par `FlutterError.reportError`) n'a été
/// levée.
///
/// WCAG 1.4.4 exige que le contenu reste utilisable jusqu'à 200 %. L'écran de
/// réglages expose désormais ce facteur, donc les parcours principaux doivent
/// le supporter.
///
/// `pumpAndSettle` n'est volontairement pas utilisé ici : certains de ces
/// écrans portent des animations `flutter_animate` ou des indicateurs qui ne
/// se stabilisent pas nécessairement dans la fenêtre par défaut, et un délai
/// fixe suffit à laisser les micro-tâches et les debounces se résoudre, comme
/// le font déjà les tests existants de chaque feature.
Future<void> pumpAt200(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
}

// ═══════════════════════════════════════════════════════════════════════════
// Accueil — harnais recopié de test/features/home/presentation/home_screen_test.dart
// ═══════════════════════════════════════════════════════════════════════════

class _HomeMockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _HomeMockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

class _HomeMockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _HomeMockBidBloc extends MockBloc<BidEvent, BidState>
    implements BidBloc {}

class _HomeMockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class _HomeMockFavoriteIdsCubit extends MockCubit<FavoriteIdsState>
    implements FavoriteIdsCubit {}

class _HomeMockHiveService extends Mock implements HiveService {}

class _HomeMockCityRepository extends Mock implements CityRepository {}

class _HomeFakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

class _HomeMockAnalyticsService extends Mock implements AnalyticsService {}

class _HomeMockPackageRequestSearchBloc
    extends MockBloc<PackageRequestSearchEvent, PackageRequestSearchState>
    implements PackageRequestSearchBloc {}

class _HomeMockTripsSummaryCubit extends MockCubit<TripsSummaryState>
    implements TripsSummaryCubit {}

class _HomeFakeBox extends Fake implements Box<dynamic> {
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    if (key == HiveService.kHasPublishedAsTraveler ||
        key == HiveService.kHasPublishedAsSender) {
      return true;
    }
    return defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {}
}

UserModel _homeMakeUser() => const UserModel(
  id: 'uid-1',
  phoneNumber: '+33600000000',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  roles: ['SENDER', 'TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

AnnouncementModel _homeMakeAnn(String id) => AnnouncementModel(
  id: id,
  travelerId: 'traveler-1',
  departureCity: 'Paris · CDG, ORY',
  arrivalCity: 'Dakar · DKR',
  departureDate: DateTime(2026, 6, 15),
  availableKg: 10,
  totalKg: 20,
  pricePerKg: 7,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

/// Les deux prédicats doivent pouvoir diverger : c'est précisément le cas
/// d'une session invitée (`hasSession` vrai, `hasRealSession` faux). Un stub
/// qui les confond rend le test aveugle au bug qu'il est censé attraper.
class _StubSessionProbe implements FirebaseSessionProbe {
  const _StubSessionProbe(this.hasSession, {bool? hasRealSession})
    : _hasRealSession = hasRealSession;

  @override
  final bool hasSession;
  final bool? _hasRealSession;
  @override
  bool get hasRealSession => _hasRealSession ?? hasSession;
  @override
  bool get isAnonymous => hasSession && !hasRealSession;
}

Widget _buildHomeHarness() {
  getIt.registerSingleton<FirebaseSessionProbe>(const _StubSessionProbe(true));

  final hive = _HomeMockHiveService();
  final box = _HomeFakeBox();
  when(() => hive.userPrefs).thenReturn(box);
  when(
    () => hive.listenUserPrefs(keys: any(named: 'keys')),
  ).thenReturn(ValueNotifier<Box>(box));
  getIt.registerSingleton<HiveService>(hive);

  final analytics = _HomeMockAnalyticsService();
  when(
    () => analytics.logEvent(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  getIt.registerSingleton<AnalyticsService>(analytics);

  final cityRepo = _HomeMockCityRepository();
  when(() => cityRepo.searchCities(any())).thenAnswer(
    (inv) async => [
      CityModel(
        name: inv.positionalArguments.first as String,
        countryCode: 'FR',
        countryName: 'France',
        lat: 48.85,
        lng: 2.35,
      ),
    ],
  );
  getIt.registerSingleton<CityRepository>(cityRepo);
  getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));
  getIt.registerFactory<IContentCategoryRepository>(
    () => _HomeFakeContentCategoryRepository(),
  );

  final summaryCubit = _HomeMockTripsSummaryCubit();
  const summaryState = TripsSummaryState.loaded(
    TripsSummaryModel(activeTrips: 2, kgSold: 0, revenue: 0),
  );
  when(() => summaryCubit.state).thenReturn(summaryState);
  whenListen(
    summaryCubit,
    const Stream<TripsSummaryState>.empty(),
    initialState: summaryState,
  );
  when(
    () => summaryCubit.load(period: any(named: 'period')),
  ).thenAnswer((_) async {});
  getIt.registerFactory<TripsSummaryCubit>(() => summaryCubit);

  const prSearchState = PackageRequestSearchState();
  getIt.registerFactory<PackageRequestSearchBloc>(() {
    final mock = _HomeMockPackageRequestSearchBloc();
    when(() => mock.state).thenReturn(prSearchState);
    whenListen(
      mock,
      Stream<PackageRequestSearchState>.fromIterable([prSearchState]),
      initialState: prSearchState,
    );
    return mock;
  });

  final announcementBloc = _HomeMockAnnouncementBloc();
  final authBloc = _HomeMockAuthBloc();
  final roleCubit = _HomeMockActiveRoleCubit();
  final notifBloc = _HomeMockNotificationBloc();
  final bidBloc = _HomeMockBidBloc();
  final favCubit = _HomeMockFavoriteIdsCubit();

  when(() => announcementBloc.state).thenReturn(
    AnnouncementSearchLoaded([_homeMakeAnn('a1'), _homeMakeAnn('a2')]),
  );
  when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => authBloc.state).thenReturn(AuthAuthenticated(_homeMakeUser()));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => roleCubit.state).thenReturn(ActiveRole.sender);
  when(() => roleCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => notifBloc.state).thenReturn(const NotificationInitial());
  when(() => notifBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => bidBloc.state).thenReturn(BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => favCubit.state).thenReturn(const FavoriteIdsState({}, {}));
  when(() => favCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => favCubit.count).thenReturn(0);
  when(() => favCubit.isTripFav(any())).thenReturn(false);
  when(() => favCubit.isRequestFav(any())).thenReturn(false);

  return MultiBlocProvider(
    providers: [
      BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
      BlocProvider<NotificationBloc>.value(value: notifBloc),
      BlocProvider<BidBloc>.value(value: bidBloc),
      BlocProvider<FavoriteIdsCubit>.value(value: favCubit),
      _smokeHelpCenterProvider(),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
      locale: const Locale('fr'),
      home: const HomeScreen(),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Publication de trajet — harnais recopié de
// test/features/matching/presentation/screens/create_trip_screen_test.dart
// ═══════════════════════════════════════════════════════════════════════════

class _TripMockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

class _TripMockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _TripMockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class _TripMockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

class _TripMockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _TripMockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _TripMockKycBloc extends MockBloc<KycEvent, KycState>
    implements KycBloc {}

class _TripMockAnalyticsService extends Mock implements AnalyticsService {}

class _TripMockPriceGridRepository extends Mock
    implements PriceGridRepository {}

class _TripMockContentCategoryRepository extends Mock
    implements IContentCategoryRepository {}

_TripMockStripeAccountBloc _tripMakeStripeBloc() {
  final b = _TripMockStripeAccountBloc();
  when(() => b.state).thenReturn(const StripeAccountInitial());
  when(() => b.stream).thenAnswer((_) => const Stream.empty());
  return b;
}

UserModel _tripMakeUser() => const UserModel(
  id: 'user-test-1',
  roles: ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

/// Reprend `_makeFullAnnouncement()` du test existant : une annonce complète
/// qui passe toute la validation de l'étape 0 et permet d'atteindre l'étape 2
/// (celle qui porte le plus de contenu — chips de moyens de paiement, etc.).
AnnouncementModel _tripMakeFullAnnouncement() => AnnouncementModel(
  id: 'ann-full-1',
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
  acceptedPaymentMethods: {BidPaymentMethod.stripe, BidPaymentMethod.cash},
  acceptedContentTypes: const ['Vêtements', 'Médicaments'],
  refusedTypes: const ['Produits dangereux'],
);

void _tripRegisterDependencies() {
  if (!getIt.isRegistered<AnalyticsService>()) {
    final analytics = _TripMockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<AnalyticsService>(analytics);
  }
  if (!getIt.isRegistered<PriceGridRepository>()) {
    getIt.registerSingleton<PriceGridRepository>(
      _TripMockPriceGridRepository(),
    );
  }
  if (!getIt.isRegistered<AnnouncementFormBloc>()) {
    getIt.registerFactory<AnnouncementFormBloc>(
      () => AnnouncementFormBloc(
        priceGridRepository: getIt<PriceGridRepository>(),
        analytics: getIt<AnalyticsService>(),
      ),
    );
  }
  if (!getIt.isRegistered<IContentCategoryRepository>()) {
    final repo = _TripMockContentCategoryRepository();
    when(() => repo.getCategories()).thenAnswer((_) async => const []);
    getIt.registerSingleton<IContentCategoryRepository>(repo);
  }
  if (!getIt.isRegistered<AnnouncementBloc>()) {
    getIt.registerFactory<AnnouncementBloc>(() {
      final b = _TripMockAnnouncementBloc();
      when(() => b.state).thenReturn(AnnouncementInitial());
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    });
  }
  if (!getIt.isRegistered<CommissionMethodBloc>()) {
    getIt.registerFactory<CommissionMethodBloc>(() {
      final b = _TripMockCommissionMethodBloc();
      when(() => b.state).thenReturn(CommissionMethodInitial());
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    });
  }
  if (!getIt.isRegistered<TripTemplateBloc>()) {
    getIt.registerFactory<TripTemplateBloc>(() {
      final b = _TripMockTripTemplateBloc();
      when(() => b.state).thenReturn(const TripTemplateState());
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    });
  }
  if (!getIt.isRegistered<CitySearchBloc>()) {
    getIt.registerFactory<CitySearchBloc>(() {
      final b = _TripMockCitySearchBloc();
      when(() => b.state).thenReturn(const CitySearchInitial());
      when(() => b.stream).thenAnswer((_) => const Stream.empty());
      return b;
    });
  }
  if (!getIt.isRegistered<StripeAccountBloc>()) {
    getIt.registerFactory<StripeAccountBloc>(_tripMakeStripeBloc);
  }
}

Widget _wrapCreateTripScreen(Widget child) {
  final router = GoRouter(
    initialLocation: '/trips/create',
    routes: [
      GoRoute(
        path: '/trips/create',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<StripeAccountBloc>.value(value: _tripMakeStripeBloc()),
            BlocProvider<AuthBloc>.value(
              value: () {
                final b = _TripMockAuthBloc();
                when(
                  () => b.state,
                ).thenReturn(AuthAuthenticated(_tripMakeUser()));
                when(() => b.stream).thenAnswer((_) => const Stream.empty());
                return b;
              }(),
            ),
            BlocProvider<KycBloc>.value(
              value: () {
                final b = _TripMockKycBloc();
                when(() => b.state).thenReturn(const KycInitial());
                when(() => b.stream).thenAnswer((_) => const Stream.empty());
                return b;
              }(),
            ),
            _smokeHelpCenterProvider(),
          ],
          child: child,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/connect/onboarding/intro',
        builder: (_, _) =>
            const Scaffold(body: Text('stripe-onboarding-intro')),
      ),
      GoRoute(
        path: '/payments/commission-method',
        builder: (_, _) => const Scaffold(body: Text('commission-method')),
      ),
      GoRoute(
        path: '/payments/wallet/topup/method',
        builder: (_, _) => const Scaffold(body: Text('topup')),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
}

// ═══════════════════════════════════════════════════════════════════════════
// Création d'offre — harnais recopié de
// test/features/matching/presentation/widgets/create_bid_bottom_sheet_success_test.dart
// ═══════════════════════════════════════════════════════════════════════════

class _BidMockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _BidMockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _BidMockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _BidMockBidPhotosCubit extends MockCubit<List<BidPhotoUpload>>
    implements BidPhotosCubit {}

class _BidMockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _BidMockLocalAuthService extends Mock implements LocalAuthService {}

class _BidMockBox extends Mock implements Box {}

class _BidMockPaymentGateway extends Mock implements PaymentGateway {}

class _BidMockPaymentRepository extends Mock implements PaymentRepository {}

class _BidFakeHiveService extends HiveService {
  _BidFakeHiveService(this._box);
  final Box _box;

  @override
  Box get userPrefs => _box;
}

class _BidFakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

AnnouncementModel _bidMakeAnnouncement() => AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8, 15),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 8,
  status: 'ACTIVE',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Widget _buildBidHarness(AnnouncementModel announcement) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => Scaffold(
          body: Builder(
            builder: (inner) => TextButton(
              onPressed: () => inner.push('/create'),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/create',
        builder: (_, state) => CreateBidScreen(announcement: announcement),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, state) => Scaffold(
          body: Center(child: Text('Bid détail ${state.uri.query}')),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Paiement — harnais recopié de
// test/features/payments/presentation/screens/payment_screen_test.dart
// ═══════════════════════════════════════════════════════════════════════════

class _PayMockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _PayMockConfigBloc extends MockBloc<ConfigEvent, ConfigState>
    implements ConfigBloc {}

class _PayMockLocalAuthService extends Mock implements LocalAuthService {}

class _PayMockBox extends Mock implements Box {}

final _paymentTestBid = BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 5.0,
  pricePerKg: 6.0,
  description: 'Vêtements',
  status: 'ACCEPTED',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2025, 6),
  createdAt: DateTime(2025, 5),
  updatedAt: DateTime(2025, 5),
);

Widget _wrapPaymentScreen(
  Widget child,
  PaymentBloc bloc,
  ConfigBloc configBloc,
) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<PaymentBloc>.value(value: bloc),
              BlocProvider<ConfigBloc>.value(value: configBloc),
              _smokeHelpCenterProvider(),
            ],
            child: child,
          ),
        ),
        GoRoute(
          path: '/auth/local',
          builder: (context, _) => const SizedBox.shrink(),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Scan — harnais recopié de
// test/features/tracking/presentation/scan_hub_screen_test.dart
// ═══════════════════════════════════════════════════════════════════════════

class _ScanMockScanHubCubit extends MockCubit<ScanHubState>
    implements ScanHubCubit {}

class _ScanFakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '.dart_tool/test_hive_a11y';
  @override
  Future<String?> getApplicationSupportPath() async =>
      '.dart_tool/test_hive_a11y';
  @override
  Future<String?> getApplicationCachePath() async =>
      '.dart_tool/test_hive_a11y';
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '.dart_tool/test_hive_a11y';
  @override
  Future<String?> getLibraryPath() async => '.dart_tool/test_hive_a11y';
  @override
  Future<String?> getExternalStoragePath() async => '.dart_tool/test_hive_a11y';
  @override
  Future<List<String>?> getExternalCachePaths() async => [
    '.dart_tool/test_hive_a11y',
  ];
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => ['.dart_tool/test_hive_a11y'];
  @override
  Future<String?> getDownloadsPath() async => '.dart_tool/test_hive_a11y';
}

AnnouncementModel _scanTrip(String id) => AnnouncementModel(
  id: id,
  travelerId: 'traveler-1',
  status: 'IN_PROGRESS',
  departureDate: DateTime(2026, 6, 22),
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  availableKg: 10,
  totalKg: 20,
  pricePerKg: 5,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

BidModel _scanBid(String id, String status, {String? recipientName}) =>
    BidModel(
      id: id,
      announcementId: 'trip-1',
      senderId: 's',
      status: status,
      recipientName: recipientName,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

GoRouter _scanRouter(ScanHubCubit cubit) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => MultiBlocProvider(
        providers: [
          BlocProvider<ScanHubCubit>.value(value: cubit),
          _smokeHelpCenterProvider(),
        ],
        child: const ScanHubView(),
      ),
    ),
    GoRoute(
      path: '/tracking/scan/identify',
      builder: (_, _) => const Scaffold(body: Text('identify')),
    ),
    GoRoute(
      path: '/tracking/offline-queue',
      builder: (_, _) => const Scaffold(body: Text('offline-queue')),
    ),
    GoRoute(
      path: '/announcements/trips',
      builder: (_, _) => const Scaffold(body: Text('mes-trajets')),
    ),
    GoRoute(
      path: '/bids/:id',
      builder: (_, state) =>
          Scaffold(body: Text('bid-${state.pathParameters['id']}')),
    ),
  ],
);

Widget _wrapScanHub(ScanHubCubit cubit) =>
    MaterialApp.router(routerConfig: _scanRouter(cubit));

// ═══════════════════════════════════════════════════════════════════════════
// Adresse de résidence — harnais recopié de
// test/features/auth/presentation/residence_address_screen_test.dart
// ═══════════════════════════════════════════════════════════════════════════

class _ResidenceMockCubit extends MockCubit<ResidenceAddressState>
    implements ResidenceAddressCubit {}

// Pays hors couverture Stripe : quatre segments, sans `OnboardingStep.payouts`
// — couvre la variante réduite de la jauge (spec §4.1, correction 4).
const _residenceProgress = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.address,
    OnboardingStep.identity,
  ],
  done: {OnboardingStep.consent, OnboardingStep.country},
  current: OnboardingStep.address,
);

Widget _wrapResidenceAddress(ResidenceAddressCubit cubit) => MaterialApp.router(
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<ResidenceAddressCubit>.value(
          value: cubit,
          // Code ISO, comme le fournit `BusinessPrefsBloc.state.country`
          // depuis la correction du lot 1 (le widget résout lui-même le nom
          // lisible via `CountryCatalog.byCode`) — pas le nom affiché.
          child: const ResidenceAddressScreen(
            country: 'SN',
            progress: _residenceProgress,
          ),
        ),
      ),
      GoRoute(
        path: '/auth/referral-code',
        builder: (_, _) => const Scaffold(body: Text('Parrainage')),
      ),
    ],
  ),
);

void main() {
  setUpAll(() async {
    // Requis par MockTripsSummaryCubit.load(period: any(named: 'period'))
    // dans le harnais accueil (mocktail exige un fallback pour tout type
    // non primitif utilisé avec `any()`).
    registerFallbackValue(StatsPeriod.thirtyDays);
    // Requis par DateFormat(..., 'fr') dans TrajetStep et ScanHubView.
    await initializeDateFormatting('fr');
  });

  // ── Accueil ──────────────────────────────────────────────────────────────
  group('Taille de texte à 200 %', () {
    testWidgets('accueil', (tester) async {
      await pumpAt200(tester, _buildHomeHarness());
      expect(tester.takeException(), isNull);
    });

    testWidgets('publication de trajet', (tester) async {
      _tripRegisterDependencies();
      // Annonce complète (comme _makeFullAnnouncement() dans le test existant)
      // pour pouvoir avancer jusqu'à l'étape 2 (Prix & conditions), la plus
      // chargée en contenu (chips de moyens de paiement).
      final args = CreateTripArgs(announcement: _tripMakeFullAnnouncement());
      await pumpAt200(
        tester,
        _wrapCreateTripScreen(CreateTripScreen(args: args)),
      );
      // Étape 0 (Trajet + fenêtre de remise).
      expect(tester.takeException(), isNull);

      // Étape 1 (Lieux & capacité).
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      // Étape 2 (Prix & conditions) — la plus riche en contenu.
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('création d\'offre', (tester) async {
      final bidBloc = _BidMockBidBloc();
      when(() => bidBloc.state).thenReturn(BidInitial());
      when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => bidBloc.close()).thenAnswer((_) async {});

      final paymentBloc = _BidMockPaymentBloc();
      when(() => paymentBloc.state).thenReturn(const PaymentInitial());
      when(() => paymentBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => paymentBloc.close()).thenAnswer((_) async {});

      final walletBloc = _BidMockWalletBloc();
      when(() => walletBloc.state).thenReturn(WalletInitial());
      when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => walletBloc.close()).thenAnswer((_) async {});

      final photosCubit = _BidMockBidPhotosCubit();
      when(() => photosCubit.state).thenReturn(const <BidPhotoUpload>[]);
      when(() => photosCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => photosCubit.close()).thenAnswer((_) async {});
      when(() => photosCubit.readyKeys).thenReturn(const <String>[]);

      final recipientBloc = _BidMockRecipientBloc();
      when(() => recipientBloc.state).thenReturn(const RecipientState());
      when(() => recipientBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => recipientBloc.close()).thenAnswer((_) async {});

      final authService = _BidMockLocalAuthService();
      final userPrefsBox = _BidMockBox();
      when(
        () => userPrefsBox.get(
          HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(true);
      when(
        () => authService.isBiometricAvailable(),
      ).thenAnswer((_) async => true);
      when(
        () => authService.authenticateWithBiometric(),
      ).thenAnswer((_) async => true);

      final paymentGateway = _BidMockPaymentGateway();
      when(
        () => paymentGateway.isPlatformPaySupported(),
      ).thenAnswer((_) async => false);

      final paymentRepository = _BidMockPaymentRepository();

      void register<T extends Object>(T Function() factory) {
        if (getIt.isRegistered<T>()) {
          getIt.unregister<T>();
        }
        getIt.registerFactory<T>(factory);
      }

      register<BidBloc>(() => bidBloc);
      register<PaymentBloc>(() => paymentBloc);
      register<WalletBloc>(() => walletBloc);
      register<BidPhotosCubit>(() => photosCubit);
      register<RecipientBloc>(() => recipientBloc);
      register<IContentCategoryRepository>(
        _BidFakeContentCategoryRepository.new,
      );
      register<LocalAuthService>(() => authService);
      register<HiveService>(() => _BidFakeHiveService(userPrefsBox));
      register<PaymentGateway>(() => paymentGateway);
      register<PaymentRepository>(() => paymentRepository);
      addTearDown(getIt.reset);

      await initializeDateFormatting('fr');

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_buildBidHarness(_bidMakeAnnouncement()));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('paiement', (tester) async {
      final mockBloc = _PayMockPaymentBloc();
      final mockConfigBloc = _PayMockConfigBloc();
      final mockLocalAuth = _PayMockLocalAuthService();
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(const PaymentInitial()),
        initialState: const PaymentInitial(),
      );
      whenListen<ConfigState>(
        mockConfigBloc,
        Stream.value(const ConfigLoaded(0.12)),
        initialState: const ConfigLoaded(0.12),
      );
      when(
        () => mockLocalAuth.isBiometricAvailable(),
      ).thenAnswer((_) async => true);
      when(mockLocalAuth.isPinSet).thenAnswer((_) async => true);

      final userPrefsBox = _PayMockBox();
      when(
        () => userPrefsBox.get(
          HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(true);

      await pumpAt200(
        tester,
        _wrapPaymentScreen(
          PaymentScreen(
            bid: _paymentTestBid,
            localAuthService: mockLocalAuth,
            userPrefs: userPrefsBox,
          ),
          mockBloc,
          mockConfigBloc,
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('scan', (tester) async {
      // Écriture disque Hive réelle : doit tourner dans la vraie zone async
      // (runAsync), sinon le testWidgets hang jusqu'au timeout sous
      // l'horloge fake (cf. le même piège documenté dans
      // scan_hub_screen_test.dart).
      PathProviderPlatform.instance = _ScanFakePathProviderPlatform();
      await tester.runAsync(() async {
        Hive.init('.dart_tool/test_hive_a11y');
        if (getIt.isRegistered<HiveService>()) {
          getIt.unregister<HiveService>();
        }
        getIt.registerLazySingleton<HiveService>(() => HiveService());
        await getIt<HiveService>().init();
        await getIt<HiveService>().offlineQueue.clear();
      });
      addTearDown(() async {
        await tester.runAsync(() async {
          await Hive.deleteFromDisk();
        });
        if (getIt.isRegistered<HiveService>()) {
          getIt.unregister<HiveService>();
        }
      });

      final cubit = _ScanMockScanHubCubit();
      when(() => cubit.selectTrip(any())).thenAnswer((_) async {});

      final trip = _scanTrip('trip-1');
      when(() => cubit.state).thenReturn(
        ScanHubLoaded(
          trips: [trip],
          selectedTripId: trip.id,
          bidsByTrip: {
            trip.id: [
              _scanBid('bid-1', 'ACCEPTED', recipientName: 'Awa Ndiaye'),
            ],
          },
          scanHistory: const [],
        ),
      );

      await pumpAt200(tester, _wrapScanHub(cubit));

      expect(tester.takeException(), isNull);
    });

    testWidgets('adresse de résidence', (tester) async {
      final cubit = _ResidenceMockCubit();
      when(() => cubit.state).thenReturn(const ResidenceAddressInitial());
      whenListen(
        cubit,
        const Stream<ResidenceAddressState>.empty(),
        initialState: const ResidenceAddressInitial(),
      );

      await pumpAt200(tester, _wrapResidenceAddress(cubit));
      expect(tester.takeException(), isNull);
    });
  });
}
