import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:hive/hive.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

class _FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

class MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class MockFavoriteIdsCubit extends MockCubit<FavoriteIdsState>
    implements FavoriteIdsCubit {}

class MockHiveService extends Mock implements HiveService {}

class MockCityRepository extends Mock implements CityRepository {}

/// Dépôt de trajets simulé : sert au compteur de l'autre mode, qui appelle
/// `countAnnouncements` directement via `getIt` (pas via un BLoC).
class MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

/// Dépôt de demandes simulé : sert au compteur de l'autre mode quand le mode
/// courant est « Trajets » (il compte alors les colis via `search(size: 1)`).
class MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockPackageRequestSearchBloc
    extends MockBloc<PackageRequestSearchEvent, PackageRequestSearchState>
    implements PackageRequestSearchBloc {}

class _MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 48.8566,
    longitude: 2.3522,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

// Simule un utilisateur qui a déjà publié → banner masqué pour tester la liste principale
// (le banner est testé séparément dans role_guidance_banner_test.dart)
class _FakeBox extends Fake implements Box<dynamic> {
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

UserModel _makeUser({List<String> roles = const ['ROLE_SENDER']}) => UserModel(
  id: 'uid-1',
  phoneNumber: '+33600000000',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  roles: roles,
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

AnnouncementModel _makeAnn({String id = 'a1', String travelerId = 'traveler-1'}) =>
    AnnouncementModel(
      id: id,
      travelerId: travelerId,
      departureCity: 'Paris · CDG, ORY',
      arrivalCity: 'Dakar · DKR',
      departureDate: DateTime(2026, 6, 15),
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 7,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

/// Trois trajets d'un autre voyageur : le feed n'est pas vide, donc l'état vide
/// (et sa tuile de découverte croisée) ne doit pas apparaître.
final troisTrajets = [_makeAnn(), _makeAnn(id: 'a2'), _makeAnn(id: 'a3')];

MockFavoriteIdsCubit _makeFavCubit({int count = 0}) {
  final cubit = MockFavoriteIdsCubit();
  final trips = count > 0
      ? Set<String>.from(List.generate(count, (i) => 'trip-$i'))
      : <String>{};
  when(() => cubit.state).thenReturn(FavoriteIdsState(trips, {}));
  when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => cubit.count).thenReturn(count);
  when(() => cubit.isTripFav(any())).thenReturn(false);
  when(() => cubit.isRequestFav(any())).thenReturn(false);
  when(() => cubit.toggleTrip(any())).thenAnswer((_) async {});
  when(() => cubit.toggleRequest(any())).thenAnswer((_) async {});
  return cubit;
}

Widget _buildHome({
  AnnouncementState? announcementState,
  ActiveRole role = ActiveRole.sender,
  UserModel? user,
  BidState? bidState,
  NotificationState? notificationState,
  MockBidBloc? bidBloc,
  MockFavoriteIdsCubit? favCubit,
}) {
  final announcementBloc = MockAnnouncementBloc();
  final authBloc = MockAuthBloc();
  final roleCubit = MockActiveRoleCubit();
  final notifBloc = MockNotificationBloc();
  final effectiveBidBloc = bidBloc ?? MockBidBloc();
  final effectiveFavCubit = favCubit ?? _makeFavCubit();

  when(
    () => announcementBloc.state,
  ).thenReturn(announcementState ?? AnnouncementInitial());
  when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => authBloc.state).thenReturn(AuthAuthenticated(user ?? _makeUser()));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => roleCubit.state).thenReturn(role);
  when(() => roleCubit.stream).thenAnswer((_) => const Stream.empty());
  when(
    () => notifBloc.state,
  ).thenReturn(notificationState ?? const NotificationInitial());
  when(() => notifBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => effectiveBidBloc.state).thenReturn(bidState ?? BidInitial());
  when(() => effectiveBidBloc.stream).thenAnswer((_) => const Stream.empty());

  return MultiBlocProvider(
    providers: [
      BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
      BlocProvider<NotificationBloc>.value(value: notifBloc),
      BlocProvider<BidBloc>.value(value: effectiveBidBloc),
      BlocProvider<FavoriteIdsCubit>.value(value: effectiveFavCubit),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
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

/// Monte l'écran Rechercher et laisse passer le premier frame de dispatch.
///
/// [isTraveler] ne pilote plus l'affichage du sélecteur de mode (le rôle
/// voyageur est universel côté serveur), il reste utile pour les branches
/// dépendantes de la capacité réelle (bannière d'onboarding, favoris).
///
/// [tripResults] alimente le feed trajets (liste vide = état vide).
/// [otherModeCount] enregistre un `PackageRequestRepository` qui renvoie ce
/// total : c'est le nombre que `_dispatchOtherModeCount` annoncera pour l'autre
/// mode tant que le mode courant est « Trajets ».
Future<void> pumpHome(
  WidgetTester tester, {
  bool isTraveler = true,
  AnnouncementState? announcementState,
  List<AnnouncementModel>? tripResults,
  int? otherModeCount,
}) async {
  if (otherModeCount != null) {
    final prRepo = MockPackageRequestRepository();
    when(
      () => prRepo.search(
        departure: any(named: 'departure'),
        arrival: any(named: 'arrival'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        maxWeight: any(named: 'maxWeight'),
        parcelSize: any(named: 'parcelSize'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
        matchingMyTrips: any(named: 'matchingMyTrips'),
        // Le compteur ne demande qu'un élément : pagination figée volontairement
        // pour que le stub ne réponde qu'à ce cas d'appel.
        // ignore: avoid_redundant_argument_values
        page: 0,
        size: 1,
      ),
    ).thenAnswer(
      (_) async => PackageRequestSearchPage(
        content: const [],
        totalElements: otherModeCount,
        page: 0,
        size: 1,
      ),
    );
    getIt.registerSingleton<PackageRequestRepository>(prRepo);
  }

  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _buildHome(
      announcementState:
          announcementState ??
          (tripResults == null ? null : AnnouncementSearchLoaded(tripResults)),
      user: _makeUser(
        roles: isTraveler
            ? const ['SENDER', 'TRAVELER']
            : const ['SENDER'],
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1000));
}

/// Sélectionne une ville dans un [CityAutocompleteField] de la feuille de
/// filtres : saisie, attente du debounce (300 ms) du `CitySearchBloc`, puis tap
/// sur la suggestion. Le dépôt de villes est mocké pour renvoyer la ville
/// saisie, ce qui rend la suggestion déterministe.
Future<void> _choisirVille(
  WidgetTester tester,
  Key champ,
  String nom,
) async {
  await tester.enterText(find.byKey(champ), nom);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, nom).last);
  await tester.pumpAndSettle();
}

/// Ouvre la feuille de filtres depuis la barre corridor, y pose un corridor,
/// puis valide. Sert à vérifier que le corridor survit à la bascule de mode.
Future<void> ouvrirSheetEtSaisirCorridor(
  WidgetTester tester,
  String depart,
  String arrivee,
) async {
  await tester.tap(find.byKey(const Key('corridor-bar')));
  await tester.pumpAndSettle();

  await _choisirVille(tester, const Key('filter-departure-city'), depart);
  await _choisirVille(tester, const Key('filter-arrival-city'), arrivee);

  await tester.tap(find.text('Rechercher'));
  await tester.pumpAndSettle();
}

/// Monte le feed dans un vrai [GoRouter] avec une route stub
/// `/announcements/:id/trip` qui enregistre l'`id` visité. Permet de vérifier
/// qu'un tap sur une carte « Votre trajet » (annonce dont le `travelerId`
/// correspond à l'utilisateur courant) ouvre bien l'écran détail trajet.
Widget _buildHomeRouter({
  required AnnouncementState announcementState,
  required List<String> visitedTripIds,
  UserModel? user,
  BidState? bidState,
}) {
  final announcementBloc = MockAnnouncementBloc();
  final authBloc = MockAuthBloc();
  final roleCubit = MockActiveRoleCubit();
  final notifBloc = MockNotificationBloc();
  final bidBloc = MockBidBloc();

  when(() => announcementBloc.state).thenReturn(announcementState);
  when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => authBloc.state).thenReturn(AuthAuthenticated(user ?? _makeUser()));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => roleCubit.state).thenReturn(ActiveRole.sender);
  when(() => roleCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => notifBloc.state).thenReturn(const NotificationInitial());
  when(() => notifBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => bidBloc.state).thenReturn(bidState ?? BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());

  final providers = MultiBlocProvider(
    providers: [
      BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
      BlocProvider<NotificationBloc>.value(value: notifBloc),
      BlocProvider<BidBloc>.value(value: bidBloc),
      BlocProvider<FavoriteIdsCubit>.value(value: _makeFavCubit()),
    ],
    child: const HomeScreen(),
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => providers),
      GoRoute(
        path: '/announcements/:id/trip',
        builder: (_, state) {
          visitedTripIds.add(state.pathParameters['id']!);
          return const Scaffold(body: Text('STUB_TRIP_DETAIL'));
        },
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr'), Locale('en')],
    locale: const Locale('fr'),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockAnalyticsService analytics;

  /// Dernière instance de `PackageRequestSearchBloc` livrée par `getIt`.
  /// `HomeScreen` n'en résout qu'une (son `BlocProvider.create`), la capturer
  /// ici permet de vérifier le PAYLOAD réellement dispatché sans avoir à
  /// réenregistrer une factory dans chaque test.
  late MockPackageRequestSearchBloc prBloc;

  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(_FakeAnnouncementEvent());
    registerFallbackValue(const SearchFiltersChanged());
  });

  setUp(() {
    final hive = MockHiveService();
    final box = _FakeBox();
    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => hive.listenUserPrefs(keys: any(named: 'keys')),
    ).thenReturn(ValueNotifier<Box>(box));
    getIt.registerSingleton<HiveService>(hive);

    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<AnalyticsService>(analytics);

    // La feuille de filtres embarque deux champs de ville : le dépôt est mocké
    // pour renvoyer exactement la ville saisie (suggestion déterministe).
    final cityRepo = MockCityRepository();
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
      () => _FakeContentCategoryRepository(),
    );

    getIt.registerFactory<PackageRequestSearchBloc>(() {
      final mock = MockPackageRequestSearchBloc();
      when(() => mock.state).thenReturn(const PackageRequestSearchState());
      whenListen(
        mock,
        Stream<PackageRequestSearchState>.fromIterable(const [
          PackageRequestSearchState(),
        ]),
        initialState: const PackageRequestSearchState(),
      );
      prBloc = mock;
      return mock;
    });
  });

  tearDown(getIt.reset);

  group('HomeScreen — Map sender view', () {
    testWidgets('shows corridor label in search bar', (tester) async {
      await tester.pumpWidget(_buildHome());
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('Tous les corridors'), findsWidgets);
    });

    testWidgets(
      'régression : initState dispatche BidMyListAutoRefreshRequested '
      '(jamais BidMyListRequested qui écraserait l\'état partagé)',
      (tester) async {
        final bidBloc = MockBidBloc();
        await tester.pumpWidget(_buildHome(bidBloc: bidBloc));
        await tester.pump(const Duration(milliseconds: 1000));

        verify(
          () => bidBloc.add(any(that: isA<BidMyListAutoRefreshRequested>())),
        ).called(1);
        verifyNever(() => bidBloc.add(any(that: isA<BidMyListRequested>())));
      },
    );

    testWidgets('shows sender-specific filter chips when role is sender', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHome());
      await tester.pump(const Duration(milliseconds: 1000));

      // 'Note' est un chip sender uniquement (absent de _PackageRequestFilterChipsRow).
      // Sa présence confirme que le rôle sender affiche les bons filtres.
      expect(find.text('Note'), findsOneWidget);
    });

    testWidgets(
      'le chip Urgent déclenche une recherche avec urgent=true',
      (tester) async {
        final announcementBloc = MockAnnouncementBloc();
        final authBloc = MockAuthBloc();
        final roleCubit = MockActiveRoleCubit();
        final notifBloc = MockNotificationBloc();
        final bidBloc = MockBidBloc();

        when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
        when(() => announcementBloc.stream)
            .thenAnswer((_) => const Stream.empty());
        when(() => authBloc.state).thenReturn(AuthAuthenticated(_makeUser()));
        when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
        when(() => roleCubit.state).thenReturn(ActiveRole.sender);
        when(() => roleCubit.stream).thenAnswer((_) => const Stream.empty());
        when(() => notifBloc.state).thenReturn(const NotificationInitial());
        when(() => notifBloc.stream).thenAnswer((_) => const Stream.empty());
        when(() => bidBloc.state).thenReturn(BidInitial());
        when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
              BlocProvider<NotificationBloc>.value(value: notifBloc),
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<FavoriteIdsCubit>.value(value: _makeFavCubit()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('fr'), Locale('en')],
              locale: const Locale('fr'),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));

        // L'appel dispatché au montage (initState) ne doit pas porter urgent.
        verify(
          () => announcementBloc.add(
            any(
              that: isA<AnnouncementSearchRequested>().having(
                (e) => e.urgent,
                'urgent',
                isNull,
              ),
            ),
          ),
        ).called(1);

        await tester.tap(find.text('🔥 Urgent'));
        await tester.pumpAndSettle();

        verify(
          () => analytics.logEvent(
            AnalyticsEvents.urgentFilterToggled,
            properties: {'active': true},
          ),
        ).called(1);

        verify(
          () => announcementBloc.add(
            any(
              that: isA<AnnouncementSearchRequested>().having(
                (e) => e.urgent,
                'urgent',
                true,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('shows TravelerCards when announcements loaded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(
          announcementState: AnnouncementSearchLoaded([
            _makeAnn(),
            _makeAnn(id: 'a2'),
          ]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.byType(TravelerCard), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'ses propres trajets sont exclus du feed de recherche',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildHomeRouter(
            // travelerId == id de _makeUser ('uid-1') : l'utilisateur ne doit
            // pas voir ses propres trajets dans la recherche.
            announcementState: AnnouncementSearchLoaded([
              _makeAnn(id: 'a-own', travelerId: 'uid-1'),
            ]),
            visitedTripIds: <String>[],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));

        // Déplier le sheet en plein écran.
        await tester.tap(find.textContaining('Tirer pour voir'));
        await tester.pumpAndSettle();

        // Aucune carte trajet ni pill « Votre trajet » : l'annonce propre est
        // filtrée du feed (elle reste accessible via « Mes trajets »).
        expect(find.byKey(const Key('own-trip-pill')), findsNothing);
        expect(find.byType(TravelerCard), findsNothing);
      },
    );

    testWidgets('shows empty message when search loaded with no results', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded(const [])),
      );
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('Aucun voyageur sur ce corridor'), findsOneWidget);
    });

    testWidgets('shows DraggableScrollableSheet by default (regression)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.byType(NearMeCarousel), findsNothing);
      // Indication de drag (peek) avec le compteur d'éléments.
      expect(find.textContaining('Tirer pour voir'), findsOneWidget);
    });

    testWidgets('tap sur l\'indication peek agrandit le sheet en plein écran', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.textContaining('Tirer pour voir'));
      await tester.pumpAndSettle();

      // En plein écran, l'indication bascule sur « voir la carte ».
      expect(find.textContaining('voir la carte'), findsOneWidget);
    });

    testWidgets(
      'shows NearMeCarousel and hides sheet when near-me FAB activated',
      (tester) async {
        GeolocatorPlatform.instance = _MockGeolocatorPlatform();

        await tester.pumpWidget(
          _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('near-me-fab')));
        await tester.pumpAndSettle();

        expect(find.byType(NearMeCarousel), findsOneWidget);
        expect(find.byType(DraggableScrollableSheet), findsNothing);
      },
    );

    testWidgets('2e tap sur le FAB désactive le filtre Près de moi', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _MockGeolocatorPlatform();

      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump();

      // 1er tap : active → carousel.
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      expect(find.byType(NearMeCarousel), findsOneWidget);

      // 2e tap : le FAB doit rester tappable (au-dessus du carousel) et
      // désactiver → retour à la liste + carte.
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      expect(find.byType(NearMeCarousel), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('radius pill re-opens the slider without losing the filter', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _MockGeolocatorPlatform();

      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump();

      // Activate near-me.
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      expect(find.byType(NearMeCarousel), findsOneWidget);

      // The radius pill is shown while active.
      expect(find.byKey(const Key('near-me-radius-pill')), findsOneWidget);

      // Tapping it re-opens the slider with the in-place "Appliquer" CTA.
      await tester.tap(find.byKey(const Key('near-me-radius-pill')));
      await tester.pumpAndSettle();
      expect(find.text('Appliquer'), findsOneWidget);

      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      // Filter is still on — the carousel never went away.
      expect(find.byType(NearMeCarousel), findsOneWidget);
      expect(find.byKey(const Key('near-me-radius-pill')), findsOneWidget);
    });

    testWidgets(
      'en mode Colis, près de moi dispatche la recherche de demandes avec un rayon',
      (tester) async {
        registerFallbackValue(const SearchFiltersChanged());
        GeolocatorPlatform.instance = _MockGeolocatorPlatform();

        // Capture the exact PackageRequestSearchBloc instance HomeScreen creates,
        // so we can assert it receives the radius-filtered search.
        late MockPackageRequestSearchBloc prBloc;
        getIt.unregister<PackageRequestSearchBloc>();
        getIt.registerFactory<PackageRequestSearchBloc>(() {
          prBloc = MockPackageRequestSearchBloc();
          when(
            () => prBloc.state,
          ).thenReturn(const PackageRequestSearchState());
          whenListen(
            prBloc,
            Stream<PackageRequestSearchState>.fromIterable(const [
              PackageRequestSearchState(),
            ]),
            initialState: const PackageRequestSearchState(),
          );
          return prBloc;
        });

        await tester.pumpWidget(
          _buildHome(
            role: ActiveRole.traveler,
            user: _makeUser(roles: const ['SENDER', 'TRAVELER']),
          ),
        );
        await tester.pump();

        // La recherche suit le mode : « près de moi » ne touche les demandes
        // que si c'est bien la liste affichée.
        await tester.tap(find.text('Colis'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('near-me-fab')));
        await tester.pumpAndSettle();

        verify(
          () => prBloc.add(
            any(
              that: isA<SearchFiltersChanged>().having(
                (e) => e.radiusKm,
                'radiusKm',
                isNotNull,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'en mode Colis, le chip Urgent ne déclenche que la recherche de demandes',
      (tester) async {
        registerFallbackValue(const SearchFiltersChanged());

        late MockPackageRequestSearchBloc prBloc;
        getIt.unregister<PackageRequestSearchBloc>();
        getIt.registerFactory<PackageRequestSearchBloc>(() {
          prBloc = MockPackageRequestSearchBloc();
          when(
            () => prBloc.state,
          ).thenReturn(const PackageRequestSearchState());
          whenListen(
            prBloc,
            Stream<PackageRequestSearchState>.fromIterable(const [
              PackageRequestSearchState(),
            ]),
            initialState: const PackageRequestSearchState(),
          );
          return prBloc;
        });

        final announcementBloc = MockAnnouncementBloc();
        final authBloc = MockAuthBloc();
        final roleCubit = MockActiveRoleCubit();
        final notifBloc = MockNotificationBloc();
        final bidBloc = MockBidBloc();

        when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
        when(() => announcementBloc.stream)
            .thenAnswer((_) => const Stream.empty());
        when(() => authBloc.state).thenReturn(
          AuthAuthenticated(_makeUser(roles: const ['SENDER', 'TRAVELER'])),
        );
        when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
        when(() => roleCubit.state).thenReturn(ActiveRole.traveler);
        when(() => roleCubit.stream).thenAnswer((_) => const Stream.empty());
        when(() => notifBloc.state).thenReturn(const NotificationInitial());
        when(() => notifBloc.stream).thenAnswer((_) => const Stream.empty());
        when(() => bidBloc.state).thenReturn(BidInitial());
        when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
              BlocProvider<NotificationBloc>.value(value: notifBloc),
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<FavoriteIdsCubit>.value(value: _makeFavCubit()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('fr'), Locale('en')],
              locale: const Locale('fr'),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));

        await tester.tap(find.text('Colis'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('🔥 Urgent').first);
        await tester.pumpAndSettle();

        verify(
          () => analytics.logEvent(
            AnalyticsEvents.urgentFilterToggled,
            properties: {'active': true},
          ),
        ).called(1);

        // Le filtre urgent est commun, mais la recherche suit le mode : en
        // mode Colis, seules les demandes sont rechargées.
        verify(
          () => prBloc.add(
            any(
              that: isA<SearchFiltersChanged>().having(
                (e) => e.urgent,
                'urgent',
                true,
              ),
            ),
          ),
        ).called(1);
        verifyNever(
          () => announcementBloc.add(
            any(
              that: isA<AnnouncementSearchRequested>().having(
                (e) => e.urgent,
                'urgent',
                true,
              ),
            ),
          ),
        );
      },
    );
  });

  group('modes de recherche', () {
    testWidgets('ouvre en mode Trajets', (tester) async {
      await pumpHome(tester);

      expect(find.text('Trajets'), findsOneWidget);
      expect(find.text('VOYAGEURS DISPONIBLES'), findsOneWidget);
    });

    testWidgets('le mode Colis est proposé à tout utilisateur', (tester) async {
      // Anciennement conditionné à isTraveler. Le rôle voyageur est universel.
      await pumpHome(tester, isTraveler: false);

      expect(find.text('Colis'), findsOneWidget);
    });

    testWidgets('basculer sur Colis change le header de la liste', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();

      expect(find.text("DEMANDES D'ENVOI"), findsOneWidget);
      expect(find.text('VOYAGEURS DISPONIBLES'), findsNothing);
    });

    testWidgets('le corridor survit à la bascule de mode', (tester) async {
      await pumpHome(tester);
      // Poser Paris → Dakar via la sheet de filtres en mode trajets.
      await ouvrirSheetEtSaisirCorridor(tester, 'Paris', 'Dakar');

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();

      expect(find.text('Paris → Dakar'), findsOneWidget);

      // L'étiquette de la barre corridor ne prouve que l'affichage. La
      // garantie du chantier porte sur le PAYLOAD : le corridor doit repartir
      // au serveur dans la recherche de demandes, pas seulement rester à
      // l'écran. Sans ces deux assertions, mettre `departure`/`arrival` à null
      // dans `_dispatchPackageRequestSearch` laisserait la suite verte.
      // Un seul `verify` pour les deux villes : `verify` consomme les appels
      // qu'il apparie, deux verifies successifs sur le même unique dispatch
      // échoueraient sur le second.
      verify(
        () => prBloc.add(
          any(
            that: isA<SearchFiltersChanged>()
                .having((e) => e.departure, 'departure', 'Paris')
                .having((e) => e.arrival, 'arrival', 'Dakar'),
          ),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('la date survit à la bascule de mode et part au serveur', (
      tester,
    ) async {
      await pumpHome(tester);

      // Poser « Aujourd'hui » en mode Trajets via le chip de date commun.
      await tester.tap(find.byKey(const Key('chip-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aujourd\'hui').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final jour = DateTime(now.year, now.month, now.day);
      verify(
        () => prBloc.add(
          any(
            that: isA<SearchFiltersChanged>()
                .having((e) => e.dateFrom, 'dateFrom', jour)
                .having((e) => e.dateTo, 'dateTo', jour),
          ),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('la bascule dispatche la recherche du nouveau mode', (
      tester,
    ) async {
      registerFallbackValue(const SearchFiltersChanged());
      late MockPackageRequestSearchBloc packageRequestSearchBloc;
      getIt.unregister<PackageRequestSearchBloc>();
      getIt.registerFactory<PackageRequestSearchBloc>(() {
        packageRequestSearchBloc = MockPackageRequestSearchBloc();
        when(
          () => packageRequestSearchBloc.state,
        ).thenReturn(const PackageRequestSearchState());
        whenListen(
          packageRequestSearchBloc,
          Stream<PackageRequestSearchState>.fromIterable(const [
            PackageRequestSearchState(),
          ]),
          initialState: const PackageRequestSearchState(),
        );
        return packageRequestSearchBloc;
      });

      await pumpHome(tester);

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();

      verify(
        () => packageRequestSearchBloc.add(any(that: isA<SearchFiltersChanged>())),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('les chips spécifiques changent avec le mode', (tester) async {
      await pumpHome(tester);
      expect(find.text('Kilo Pro'), findsOneWidget);

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();

      expect(find.text('Kilo Pro'), findsNothing);
      expect(find.text('Taille'), findsOneWidget);
    });

    testWidgets('compteur de l\'autre mode absent sans filtre commun', (
      tester,
    ) async {
      await pumpHome(tester);

      // `mode-other-count` est porté par le BADGE lui-même (dans
      // `SearchModeSelector`), pas par un wrapper du sélecteur : son absence
      // prouve donc bien l'absence du nombre. Le sélecteur, lui, garde une clé
      // stable et reste monté.
      expect(find.byKey(const Key('search-mode-selector')), findsOneWidget);
      expect(find.byKey(const Key('mode-other-count')), findsNothing);
    });

    testWidgets(
      'le compteur de l\'autre mode utilise le payload de la vraie recherche : '
      '« près de moi » neutralise le corridor',
      (tester) async {
        // Le compteur ne passe pas par un BLoC : il appelle le dépôt depuis
        // `getIt`. Sans cet enregistrement, `_dispatchOtherModeCount` lève et
        // son `catch` avale tout — aucune assertion ne pourrait échouer.
        GeolocatorPlatform.instance = _MockGeolocatorPlatform();

        final annRepo = MockAnnouncementRepository();
        final appels = <Map<Symbol, dynamic>>[];
        when(
          () => annRepo.countAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            maxAvailableKg: any(named: 'maxAvailableKg'),
            maxPricePerKg: any(named: 'maxPricePerKg'),
            kiloProOnly: any(named: 'kiloProOnly'),
            minRating: any(named: 'minRating'),
            weekendOnly: any(named: 'weekendOnly'),
            transportMode: any(named: 'transportMode'),
            kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
            contentType: any(named: 'contentType'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            urgent: any(named: 'urgent'),
          ),
        ).thenAnswer((invocation) async {
          appels.add(invocation.namedArguments);
          return 8;
        });
        getIt.registerSingleton<AnnouncementRepository>(annRepo);

        await pumpHome(tester);

        // Mode courant Colis → le compteur annoncé est celui des trajets.
        await tester.tap(find.text('Colis'));
        await tester.pumpAndSettle();

        await ouvrirSheetEtSaisirCorridor(tester, 'Paris', 'Dakar');

        // Corridor seul : il part tel quel dans le compte.
        expect(appels, isNotEmpty);
        expect(appels.last[#departureCity], 'Paris');
        expect(appels.last[#arrivalCity], 'Dakar');

        final avantNearMe = appels.length;
        await tester.tap(find.byKey(const Key('near-me-fab')));
        await tester.pumpAndSettle();

        // « Près de moi » neutralise le corridor dans la vraie recherche : le
        // compteur doit annoncer ce que la bascule produira, donc compter sans
        // corridor et avec le rayon. Lire `_filters` en direct au lieu de
        // `toAnnouncementQuery()` remonterait ici la ville de départ.
        expect(
          appels.length,
          greaterThan(avantNearMe),
          reason: 'activer « près de moi » doit recompter l\'autre mode',
        );
        expect(appels.last[#departureCity], isNull);
        expect(appels.last[#arrivalCity], isNull);
        expect(appels.last[#radiusKm], isNotNull);
        expect(appels.last[#userLat], isNotNull);
      },
    );

    testWidgets(
      '« Pour mes trajets » part au serveur, et rien quand la pastille est off',
      (tester) async {
        await pumpHome(tester);

        await tester.tap(find.text('Colis'));
        await tester.pumpAndSettle();

        // Pastille inactive : le filtre ne doit pas être envoyé du tout.
        verify(
          () => prBloc.add(
            any(
              that: isA<SearchFiltersChanged>().having(
                (e) => e.matchingMyTrips,
                'matchingMyTrips',
                isNull,
              ),
            ),
          ),
        ).called(greaterThanOrEqualTo(1));

        // Activer la pastille depuis la feuille de filtres colis.
        await tester.tap(find.byKey(const Key('corridor-bar')));
        await tester.pumpAndSettle();
        await tester.dragUntilVisible(
          find.text('Pour mes trajets'),
          find.byType(SingleChildScrollView).last,
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pour mes trajets'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rechercher'));
        await tester.pumpAndSettle();

        verify(
          () => prBloc.add(
            any(
              that: isA<SearchFiltersChanged>().having(
                (e) => e.matchingMyTrips,
                'matchingMyTrips',
                isTrue,
              ),
            ),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );
  });

  group('découverte croisée', () {
    /// Le texte réellement porté par la tuile. Sert aux assertions sur le
    /// libellé complet (accord, corridor) sans dépendre de `find.text`.
    String labelTuile(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('cross-discovery')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    testWidgets('0 résultat et autre mode non vide : la ligne est proposée', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 5);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      expect(find.byKey(const Key('cross-discovery')), findsOneWidget);
      expect(labelTuile(tester), '5 colis cherchent un voyageur sur Lyon → Bamako');
      // Jamais de tiret cadratin dans un texte affiché.
      expect(labelTuile(tester), isNot(contains('—')));
    });

    testWidgets('la cible tactile fait au moins 44 points de haut', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 5);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      expect(
        tester.getSize(find.byKey(const Key('cross-discovery'))).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('taper la ligne bascule en conservant le corridor', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 5);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      await tester.tap(find.byKey(const Key('cross-discovery')));
      await tester.pumpAndSettle();

      expect(find.text("DEMANDES D'ENVOI"), findsOneWidget);
      expect(find.text('Lyon → Bamako'), findsOneWidget);

      // L'étiquette affichée ne prouve que le rendu. La garantie porte sur le
      // PAYLOAD : la recherche de demandes doit repartir au serveur avec le
      // corridor. Sans ce `verify`, une bascule qui perdrait le corridor côté
      // requête laisserait le test vert.
      verify(
        () => prBloc.add(
          any(
            that: isA<SearchFiltersChanged>()
                .having((e) => e.departure, 'departure', 'Lyon')
                .having((e) => e.arrival, 'arrival', 'Bamako'),
          ),
        ),
      ).called(greaterThanOrEqualTo(1));

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.homeCrossDiscoveryTapped,
          properties: {'from_mode': 'trips', 'count': 5},
        ),
      ).called(1);
    });

    testWidgets('0 résultat des deux côtés : aucune ligne', (tester) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 0);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      expect(find.byKey(const Key('cross-discovery')), findsNothing);
      expect(find.textContaining('cherche'), findsNothing);
    });

    testWidgets('résultats présents : aucune ligne, le compteur suffit', (
      tester,
    ) async {
      // Corridor posé ET autre mode à 5 : seule la présence de résultats dans
      // le mode courant doit supprimer la tuile.
      await pumpHome(tester, tripResults: troisTrajets, otherModeCount: 5);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      expect(find.byKey(const Key('cross-discovery')), findsNothing);
    });

    testWidgets('un seul résultat de l\'autre côté : accord au singulier', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 1);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      expect(labelTuile(tester), '1 colis cherche un voyageur sur Lyon → Bamako');
    });

    testWidgets(
      'ville de départ seule : suffixe « au départ de Lyon »',
      (tester) async {
        await pumpHome(tester, tripResults: const [], otherModeCount: 5);

        await tester.tap(find.byKey(const Key('corridor-bar')));
        await tester.pumpAndSettle();
        await _choisirVille(tester, const Key('filter-departure-city'), 'Lyon');
        await tester.tap(find.text('Rechercher'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cross-discovery')), findsOneWidget);
        expect(
          labelTuile(tester),
          '5 colis cherchent un voyageur au départ de Lyon',
        );
        // Jamais de tiret cadratin dans un texte affiché.
        expect(labelTuile(tester), isNot(contains('—')));
      },
    );

    testWidgets(
      'ville d\'arrivée seule : suffixe « vers Bamako »',
      (tester) async {
        await pumpHome(tester, tripResults: const [], otherModeCount: 5);

        await tester.tap(find.byKey(const Key('corridor-bar')));
        await tester.pumpAndSettle();
        await _choisirVille(tester, const Key('filter-arrival-city'), 'Bamako');
        await tester.tap(find.text('Rechercher'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cross-discovery')), findsOneWidget);
        expect(labelTuile(tester), '5 colis cherchent un voyageur vers Bamako');
        // Jamais de tiret cadratin dans un texte affiché.
        expect(labelTuile(tester), isNot(contains('—')));
      },
    );

    testWidgets(
      'sans corridor, le libellé n\'affiche ni flèche orpheline ni corridor vide',
      (tester) async {
        await pumpHome(tester, tripResults: const [], otherModeCount: 5);

        // Date seule : le compteur devient significatif sans qu'un corridor
        // soit posé.
        await tester.tap(find.byKey(const Key('chip-date')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aujourd\'hui').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Appliquer'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cross-discovery')), findsOneWidget);
        expect(labelTuile(tester), '5 colis cherchent un voyageur');
        expect(labelTuile(tester), isNot(contains('→')));
        expect(labelTuile(tester), isNot(contains('Tous les corridors')));
      },
    );

    testWidgets('en mode Colis, la ligne propose les voyageurs', (
      tester,
    ) async {
      final annRepo = MockAnnouncementRepository();
      when(
        () => annRepo.countAnnouncements(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          departureDateFrom: any(named: 'departureDateFrom'),
          departureDateTo: any(named: 'departureDateTo'),
          minAvailableKg: any(named: 'minAvailableKg'),
          maxAvailableKg: any(named: 'maxAvailableKg'),
          maxPricePerKg: any(named: 'maxPricePerKg'),
          kiloProOnly: any(named: 'kiloProOnly'),
          minRating: any(named: 'minRating'),
          weekendOnly: any(named: 'weekendOnly'),
          transportMode: any(named: 'transportMode'),
          kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
          contentType: any(named: 'contentType'),
          userLat: any(named: 'userLat'),
          userLng: any(named: 'userLng'),
          radiusKm: any(named: 'radiusKm'),
          urgent: any(named: 'urgent'),
        ),
      ).thenAnswer((_) async => 12);
      getIt.registerSingleton<AnnouncementRepository>(annRepo);

      await pumpHome(tester);

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      expect(labelTuile(tester), '12 voyageurs passent sur Lyon → Bamako');
    });

    testWidgets(
      'en mode Colis, un seul voyageur de l\'autre côté : accord au singulier',
      (tester) async {
        final annRepo = MockAnnouncementRepository();
        when(
          () => annRepo.countAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            maxAvailableKg: any(named: 'maxAvailableKg'),
            maxPricePerKg: any(named: 'maxPricePerKg'),
            kiloProOnly: any(named: 'kiloProOnly'),
            minRating: any(named: 'minRating'),
            weekendOnly: any(named: 'weekendOnly'),
            transportMode: any(named: 'transportMode'),
            kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
            contentType: any(named: 'contentType'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            urgent: any(named: 'urgent'),
          ),
        ).thenAnswer((_) async => 1);
        getIt.registerSingleton<AnnouncementRepository>(annRepo);

        await pumpHome(tester);

        await tester.tap(find.text('Colis'));
        await tester.pumpAndSettle();
        await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

        expect(labelTuile(tester), '1 voyageur passe sur Lyon → Bamako');
      },
    );
  });

  group('découverte croisée — bouton "Effacer les filtres"', () {
    testWidgets(
      'filtres actifs, autre mode vide : le bouton est visible et efface '
      'les filtres au tap',
      (tester) async {
        final annRepo = MockAnnouncementRepository();
        when(
          () => annRepo.countAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            maxAvailableKg: any(named: 'maxAvailableKg'),
            maxPricePerKg: any(named: 'maxPricePerKg'),
            kiloProOnly: any(named: 'kiloProOnly'),
            minRating: any(named: 'minRating'),
            weekendOnly: any(named: 'weekendOnly'),
            transportMode: any(named: 'transportMode'),
            kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
            contentType: any(named: 'contentType'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            urgent: any(named: 'urgent'),
          ),
        ).thenAnswer((_) async => 0);
        getIt.registerSingleton<AnnouncementRepository>(annRepo);

        await pumpHome(tester);

        // Mode Colis : autre mode (Trajets) à 0 via le mock ci-dessus →
        // aucune tuile de découverte croisée, donc rien ne masque le bouton.
        await tester.tap(find.text('Colis'));
        await tester.pumpAndSettle();
        await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

        expect(find.byKey(const Key('cross-discovery')), findsNothing);
        expect(find.text('Effacer les filtres'), findsOneWidget);

        await tester.tap(find.text('Effacer les filtres'));
        await tester.pumpAndSettle();

        // L'effet : les filtres retombent (corridor effacé) et une nouvelle
        // recherche part avec ce payload vidé.
        verify(
          () => prBloc.add(
            any(
              that: isA<SearchFiltersChanged>()
                  .having((e) => e.departure, 'departure', null)
                  .having((e) => e.arrival, 'arrival', null),
            ),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );
  });

  group('HomeScreen — _FavoritesButton', () {
    testWidgets('renders favorites button in the overlay', (tester) async {
      await tester.pumpWidget(_buildHome());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('favorites-button')), findsOneWidget);
    });

    testWidgets('no badge when favorites count is 0', (tester) async {
      await tester.pumpWidget(_buildHome(favCubit: _makeFavCubit(count: 0)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('favorites-badge')), findsNothing);
    });

    testWidgets('shows badge with count when favorites count > 0',
        (tester) async {
      await tester.pumpWidget(_buildHome(favCubit: _makeFavCubit(count: 3)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('favorites-badge')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('favorites-badge')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows 99+ badge when count exceeds 99', (tester) async {
      await tester.pumpWidget(_buildHome(favCubit: _makeFavCubit(count: 120)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('favorites-badge')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('favorites-badge')),
          matching: find.text('99+'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tap navigates to /favoris via GoRouter', (tester) async {
      final visited = <String>[];
      final favCubit = _makeFavCubit(count: 2);
      final announcementBloc = MockAnnouncementBloc();
      final authBloc = MockAuthBloc();
      final roleCubit = MockActiveRoleCubit();
      final notifBloc = MockNotificationBloc();
      final bidBloc = MockBidBloc();

      when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
      when(() => announcementBloc.stream)
          .thenAnswer((_) => const Stream.empty());
      when(() => authBloc.state)
          .thenReturn(AuthAuthenticated(_makeUser()));
      when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => roleCubit.state).thenReturn(ActiveRole.sender);
      when(() => roleCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => notifBloc.state).thenReturn(const NotificationInitial());
      when(() => notifBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => bidBloc.state).thenReturn(BidInitial());
      when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());

      final providers = MultiBlocProvider(
        providers: [
          BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
          BlocProvider<NotificationBloc>.value(value: notifBloc),
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<FavoriteIdsCubit>.value(value: favCubit),
        ],
        child: const HomeScreen(),
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => providers),
          GoRoute(
            path: '/favoris',
            builder: (_, _) {
              visited.add('/favoris');
              return const Scaffold(body: Text('STUB_FAVORIS'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr'), Locale('en')],
          locale: const Locale('fr'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('favorites-button')));
      await tester.pumpAndSettle();

      expect(visited, contains('/favoris'));
      expect(find.text('STUB_FAVORIS'), findsOneWidget);
    });
  });

  group('HomeScreen — Traveler view', () {
    testWidgets('renders MapTravelerView when role is traveler', (
      tester,
    ) async {
      // Since the new MapTravelerView embeds GoogleMap + creates its own
      // PackageRequestSearchBloc via getIt, we just assert it builds without
      // throwing — the inner GoogleMap widget rendering needs a platform mock
      // not worth the cost in this widget test.
      await tester.pumpWidget(_buildHome(role: ActiveRole.traveler));
      await tester.pump();

      // The traveler header text appears in the floating overlay.
      expect(find.text('Demandes à transporter'), findsOneWidget);
    }, skip: true);
    // NOTE: skipped — GoogleMap requires platform channel mock. Covered by
    // manual device testing per CLAUDE.md UI rule. Re-enable when a stub for
    // GoogleMapsFlutterPlatform.instance is added to test infra.
  });

  group('HomeScreen — _NotificationBell', () {
    testWidgets('shows outlined bell icon when no unread notifications', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(
          notificationState: const NotificationLoaded(
            notifications: [],
            unreadCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cloche = DonyIcon('bell') unique ; l'état lu/non-lu est porté par la
      // couleur + le badge (présent seulement si unread > 0).
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bell'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notification-badge')), findsNothing);
    });

    testWidgets('shows filled bell icon and badge count when unread > 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(
          notificationState: const NotificationLoaded(
            notifications: [],
            unreadCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bell'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('notification-badge')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows 99+ badge when unread count exceeds 99', (tester) async {
      await tester.pumpWidget(
        _buildHome(
          notificationState: const NotificationLoaded(
            notifications: [],
            unreadCount: 150,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('shows outlined bell icon when notification state is initial', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(
          // notificationState non fourni → NotificationInitial par défaut
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bell'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notification-badge')), findsNothing);
    });
  });
}
