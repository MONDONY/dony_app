import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
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
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/data/home_matching_default_store.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/home/presentation/home_sheet_session.dart';
import 'package:dony/features/home/presentation/screens/search_composer_screen.dart';
import 'package:dony/features/home/presentation/widgets/home_filter_chips_row.dart';
import 'package:dony/features/home/presentation/widgets/search_mode_selector.dart';
import 'package:dony/features/home/presentation/widgets/search_period.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/similar_announcement.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
// `intl` exporte son propre TextDirection (LTR/RTL/UNKNOWN) qui masquerait
// celui de dart:ui (TextDirection.ltr) déjà utilisé plus bas dans ce fichier.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_analytics_backend.dart';
import '../../../helpers/mock_recent_city_store.dart';

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

BlocProvider<HelpCenterBloc> _helpCenterProvider({
  String helpConfigJson = _emptyHelpConfigJson,
}) => BlocProvider<HelpCenterBloc>(
  create: (_) => HelpCenterBloc(
    HelpCenterRepository(
      _StaticHelpCenterSource(helpConfigJson),
      fallbackJsonLoader: () async => _emptyHelpConfigJson,
    ),
    makeDisabledAnalytics(MockAnalyticsBackend()),
  )..add(const HelpCenterLoadRequested()),
);

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

/// Ces tests ne montent jamais Firebase : `_mode` par défaut dépend de
/// `FirebaseSessionProbe`, dont le fake par défaut ci-dessous (`true`) suit
/// les mocks `AuthAuthenticated` déjà utilisés partout dans ce fichier.
/// Les deux prédicats doivent pouvoir diverger : c'est précisément le cas
/// d'une session invitée (`hasSession` vrai, `hasRealSession` faux). Un stub
/// qui les confond rend le test aveugle au bug qu'il est censé attraper.
class _StubSessionProbe implements FirebaseSessionProbe {
  const _StubSessionProbe(this.hasSession, {bool? hasRealSession})
    : _hasRealSession = hasRealSession;

  /// Session invitée : le SDK a bien une session, mais sans compte derrière.
  const _StubSessionProbe.guest() : hasSession = true, _hasRealSession = false;

  @override
  final bool hasSession;
  final bool? _hasRealSession;
  @override
  bool get hasRealSession => _hasRealSession ?? hasSession;
  @override
  bool get isAnonymous => hasSession && !hasRealSession;
}

class _FakeBidEvent extends Fake implements BidEvent {}

class _FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

class MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class MockFavoriteIdsCubit extends MockCubit<FavoriteIdsState>
    implements FavoriteIdsCubit {}

class MockActivationCubit extends MockCubit<ActivationState>
    implements ActivationCubit {}

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

/// Dépôt de parsing simulé, requis par `SearchComposerBloc` — voir
/// `_composerRoute`. Jamais stubé ici : aucun test de ce fichier ne saisit de
/// phrase, seule `search_composer_screen_test.dart` couvre ce chemin.
class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockPackageRequestSearchBloc
    extends MockBloc<PackageRequestSearchEvent, PackageRequestSearchState>
    implements PackageRequestSearchBloc {}

/// Résumé d'activité simulé : c'est lui qui porte le nombre de trajets actifs,
/// dont dépendent la pastille « Pour mes trajets » et l'en-tête de la liste.
class MockTripsSummaryCubit extends MockCubit<TripsSummaryState>
    implements TripsSummaryCubit {}

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

/// Mémoire en RAM du refus de la valeur par défaut « Pour mes trajets » : le
/// vrai magasin lit une box Hive, ici factice et muette.
class _FakeMatchingStore extends Fake implements HomeMatchingDefaultStore {
  bool out = false;

  @override
  bool get optedOut => out;

  @override
  Future<void> setOptedOut({required bool value}) async => out = value;
}

class _FakeBox extends Fake implements Box<dynamic> {
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) => defaultValue;

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

AnnouncementModel _makeAnn({
  String id = 'a1',
  String travelerId = 'traveler-1',
}) => AnnouncementModel(
  id: id,
  travelerId: travelerId,
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

/// Trois trajets d'un autre voyageur : le feed n'est pas vide, donc l'état vide
/// (et sa tuile de découverte croisée) ne doit pas apparaître.
final troisTrajets = [_makeAnn(), _makeAnn(id: 'a2'), _makeAnn(id: 'a3')];

/// (Re)enregistre le résumé d'activité dans l'état [state] et rend le mock,
/// pour vérifier les rechargements. `HomeScreen` le résout via `getIt`, comme
/// en production.
MockTripsSummaryCubit _registerTripsSummaryState(TripsSummaryState state) {
  if (getIt.isRegistered<TripsSummaryCubit>()) {
    getIt.unregister<TripsSummaryCubit>();
  }
  // Le mock est stubé MAINTENANT, pas dans la fabrique : `HomeScreen` la
  // résout depuis un `create` de BlocProvider, et appeler `when` là-dedans
  // tomberait au milieu d'une réponse stubée (« Cannot call `when` within a
  // stub response »).
  final cubit = MockTripsSummaryCubit();
  when(() => cubit.state).thenReturn(state);
  whenListen(
    cubit,
    const Stream<TripsSummaryState>.empty(),
    initialState: state,
  );
  when(() => cubit.load(period: any(named: 'period'))).thenAnswer((_) async {});
  getIt.registerFactory<TripsSummaryCubit>(() => cubit);
  return cubit;
}

/// (Re)enregistre le résumé d'activité avec [activeTrips] trajets actifs.
MockTripsSummaryCubit _registerTripsSummary(int activeTrips) =>
    _registerTripsSummaryState(
      TripsSummaryState.loaded(
        TripsSummaryModel(activeTrips: activeTrips, kgSold: 0, revenue: 0),
      ),
    );

/// Demande d'envoi minimale pour peupler l'état du bloc de recherche colis.
/// L'expéditeur n'est jamais l'utilisateur courant : sinon `_visibleRequests`
/// la retirerait du feed.
PackageRequestSearchItem _makeRequest(String id) => PackageRequestSearchItem(
  id: id,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 8, 15),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  categories: const ['Vêtements'],
  sender: const SenderPublicProfile(
    id: 'autre-expediteur',
    displayName: 'Fatou',
    averageRating: 4.8,
    totalRatings: 3,
    kycVerified: true,
  ),
);

/// Variante de [_makeRequest] dont l'expéditeur EST l'utilisateur courant
/// (`uid-1`, cf. `_makeUser`) : `_visibleRequests` doit la retirer du feed.
PackageRequestSearchItem _makeOwnRequest(String id) => PackageRequestSearchItem(
  id: id,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 8, 15),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  categories: const ['Vêtements'],
  sender: const SenderPublicProfile(
    id: 'uid-1',
    displayName: 'Moi',
    averageRating: 4.8,
    totalRatings: 3,
    kycVerified: true,
  ),
);

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

/// Route `/recherche/composer` de test — même contrat que la route réelle de
/// `lib/app/router.dart`, mais `SearchComposerBloc` est construit directement
/// avec des mocks non stubés plutôt que résolu via `getIt` : les dépôts de
/// comptage (`AnnouncementRepository`, `PackageRequestRepository`) sont déjà
/// enregistrés dans `getIt` par certains tests de ce fichier au coup par
/// coup (corridor, découverte croisée…), et une résolution `getIt` ici
/// entrerait en conflit avec ces enregistrements.
///
/// Sans stub, un appel déclenche un `MissingStubError` — avalé sans effet de
/// bord par `SearchComposerBloc._refreshCount`, dont c'est justement le
/// contrat (le compteur est une aide, jamais un bloquant). Le bouton
/// « Rechercher » reste donc actif, simplement sans le nombre entre
/// parenthèses.
GoRoute _composerRoute() => GoRoute(
  path: '/recherche/composer',
  builder: (context, state) {
    final extra = state.extra as Map? ?? {};
    final mode = (extra['mode'] as SearchMode?) ?? SearchMode.trips;
    final filters =
        (extra['filters'] as HomeSearchFilters?) ?? const HomeSearchFilters();
    return BlocProvider(
      create: (_) => SearchComposerBloc(
        MockAnnouncementRepository(),
        MockPackageRequestRepository(),
        getIt<AnalyticsService>(),
        mode: mode,
        initialFilters: filters,
      ),
      child: SearchComposerScreen(
        mode: mode,
        initialFilters: filters,
        activeTrips: extra['activeTrips'] as int?,
        onPublishTrip: extra['onPublishTrip'] as VoidCallback?,
      ),
    );
  },
);

Widget _buildHome({
  AnnouncementState? announcementState,
  ActiveRole role = ActiveRole.sender,
  UserModel? user,
  AuthState? authState,
  BidState? bidState,
  NotificationState? notificationState,
  MockBidBloc? bidBloc,
  MockFavoriteIdsCubit? favCubit,
  String helpConfigJson = _emptyHelpConfigJson,
  MockAnnouncementBloc? announcementBlocOverride,
}) {
  final announcementBloc = announcementBlocOverride ?? MockAnnouncementBloc();
  final authBloc = MockAuthBloc();
  final roleCubit = MockActiveRoleCubit();
  final notifBloc = MockNotificationBloc();
  final effectiveBidBloc = bidBloc ?? MockBidBloc();
  final effectiveFavCubit = favCubit ?? _makeFavCubit();

  when(
    () => announcementBloc.state,
  ).thenReturn(announcementState ?? AnnouncementInitial());
  when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());
  when(
    () => authBloc.state,
  ).thenReturn(authState ?? AuthAuthenticated(user ?? _makeUser()));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => roleCubit.state).thenReturn(role);
  when(() => roleCubit.stream).thenAnswer((_) => const Stream.empty());
  when(
    () => notifBloc.state,
  ).thenReturn(notificationState ?? const NotificationInitial());
  when(() => notifBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => effectiveBidBloc.state).thenReturn(bidState ?? BidInitial());
  when(() => effectiveBidBloc.stream).thenAnswer((_) => const Stream.empty());

  final providers = MultiBlocProvider(
    providers: [
      BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
      BlocProvider<NotificationBloc>.value(value: notifBloc),
      BlocProvider<BidBloc>.value(value: effectiveBidBloc),
      BlocProvider<FavoriteIdsCubit>.value(value: effectiveFavCubit),
      _helpCenterProvider(helpConfigJson: helpConfigJson),
    ],
    child: const HomeScreen(),
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => providers),
      _composerRoute(),
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
    supportedLocales: const [Locale('fr'), Locale('en')],
    locale: const Locale('fr'),
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
/// [summaryState] remplace l'état du résumé d'activité (par défaut : chargé
/// avec [activeTrips]). Sert au cas « résumé en échec », où le nombre de
/// trajets est INCONNU et non nul.
/// Titre de l'en-tête de liste (« 4 voyageurs pour Lyon → Bamako »). Il porte
/// une clé stable : les tests ne s'accrochent pas à un texte en capitales qui
/// change avec le mode, le corridor et le nombre.
String titreListe(WidgetTester tester) => tester
    .widget<Text>(
      // La liste reste construite hors affichage tant qu'on est sur la carte :
      // son en-tête se lit sans l'ouvrir.
      find.byKey(const Key('results-header-title'), skipOffstage: false),
    )
    .data!;

/// Sous-titre de l'en-tête de liste, `null` quand il n'est pas affiché (une
/// phrase qui répète le titre est retirée, voir `homeListSubtitle`).
String? sousTitreListe(WidgetTester tester) {
  final finder = find.byKey(
    const Key('results-header-subtitle'),
    skipOffstage: false,
  );
  return finder.evaluate().isEmpty ? null : tester.widget<Text>(finder).data;
}

Future<void> pumpHome(
  WidgetTester tester, {
  bool isTraveler = true,
  AnnouncementState? announcementState,
  List<AnnouncementModel>? tripResults,
  int? otherModeCount,
  int activeTrips = 2,
  TripsSummaryState? summaryState,
  AuthState? authState,
  MockFavoriteIdsCubit? favCubit,
}) async {
  if (summaryState != null) {
    _registerTripsSummaryState(summaryState);
  } else {
    _registerTripsSummary(activeTrips);
  }
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
        roles: isTraveler ? const ['SENDER', 'TRAVELER'] : const ['SENDER'],
      ),
      authState: authState,
      favCubit: favCubit,
    ),
  );
  await tester.pump(const Duration(milliseconds: 1000));
}

/// L'écran s'ouvre sur la carte plein écran, sans panneau de résultats : il
/// n'y a plus rien à replier. Le helper laisse l'écran se poser, pour les tests
/// qui partent de la vue carte.
Future<void> replierFeuille(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

/// Touche la pastille « Liste » : la liste prend tout l'écran.
Future<void> ouvrirListe(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('home-list-pill')));
  await tester.pumpAndSettle();
}

/// Touche le bouton de localisation, puis « Activer le filtre » dans la
/// feuille de rayon : « Près de moi » est actif au rayon proposé.
Future<void> activerPresDeMoi(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('near-me-fab')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Activer le filtre'));
  await tester.pumpAndSettle();
}

/// Sélectionne une ville dans un [CityAutocompleteField] de la feuille de
/// filtres : saisie, attente du debounce (300 ms) du `CitySearchBloc`, puis tap
/// sur la suggestion. Le dépôt de villes est mocké pour renvoyer la ville
/// saisie, ce qui rend la suggestion déterministe.
Future<void> _choisirVille(WidgetTester tester, Key champ, String nom) async {
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
  // Sur la carte la barre s'appelle `corridor-bar`, dans la liste plein écran
  // `corridor-bar-sheet`.
  final surCarte = find.byKey(const Key('corridor-bar'));
  await tester.tap(
    surCarte.evaluate().isNotEmpty
        ? surCarte
        : find.byKey(const Key('corridor-bar-sheet')),
  );
  await tester.pumpAndSettle();

  await _choisirVille(tester, const Key('composer-departure-city'), depart);
  await _choisirVille(tester, const Key('composer-arrival-city'), arrivee);

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
  String helpConfigJson = _emptyHelpConfigJson,
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
      _helpCenterProvider(helpConfigJson: helpConfigJson),
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
      GoRoute(
        path: '/profile/help/tutorial/:tutorialId',
        builder: (_, state) => Scaffold(
          body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
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
    supportedLocales: const [Locale('fr'), Locale('en')],
    locale: const Locale('fr'),
  );
}

/// Monte l'écran dans un vrai [GoRouter] avec des routes stub pour la création
/// de trajet et les réglages : c'est là que mènent les deux garde-fous du
/// filtre « Pour mes trajets ».
Widget _buildHomeStubRoutes({
  required List<String> visited,
  required UserModel user,
}) {
  final announcementBloc = MockAnnouncementBloc();
  final authBloc = MockAuthBloc();
  final roleCubit = MockActiveRoleCubit();
  final notifBloc = MockNotificationBloc();
  final bidBloc = MockBidBloc();

  when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
  when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => authBloc.state).thenReturn(AuthAuthenticated(user));
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
      BlocProvider<FavoriteIdsCubit>.value(value: _makeFavCubit()),
      _helpCenterProvider(),
    ],
    child: const HomeScreen(),
  );

  // L'écran stub porte un bouton de retour : c'est le retour de navigation qui
  // doit rafraîchir le résumé des trajets côté écran Rechercher.
  Widget stub(String path) {
    visited.add(path);
    return Scaffold(
      body: Builder(
        builder: (ctx) =>
            TextButton(onPressed: () => ctx.pop(), child: Text('STUB $path')),
      ),
    );
  }

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => providers),
      GoRoute(path: '/trips/create', builder: (_, _) => stub('/trips/create')),
      GoRoute(path: '/settings', builder: (_, _) => stub('/settings')),
      _composerRoute(),
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
    supportedLocales: const [Locale('fr'), Locale('en')],
    locale: const Locale('fr'),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockAnalyticsService analytics;
  late _FakeMatchingStore matchingStore;

  /// Dernière instance de `PackageRequestSearchBloc` livrée par `getIt`.
  /// `HomeScreen` n'en résout qu'une (son `BlocProvider.create`), la capturer
  /// ici permet de vérifier le PAYLOAD réellement dispatché sans avoir à
  /// réenregistrer une factory dans chaque test.
  late MockPackageRequestSearchBloc prBloc;

  /// État servi par le mock de `PackageRequestSearchBloc`. Les tests qui
  /// vérifient un rendu dépendant des résultats (en-tête de liste) le
  /// remplacent AVANT de monter l'écran.
  late PackageRequestSearchState prSearchState;

  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(_FakeAnnouncementEvent());
    registerFallbackValue(const SearchFiltersChanged());
    registerFallbackValue(StatsPeriod.thirtyDays);
    registerCityFallbackValues();
  });

  setUp(() {
    // La plupart des tests supposent l'ouverture d'avant (feuille repliée puis
    // montée à mi-hauteur) : l'ouverture à 100 % se rallume dans les tests
    // qui la vérifient.
    HomeSheetSession.reset(enabled: false);
    matchingStore = _FakeMatchingStore();
    getIt.registerSingleton<HomeMatchingDefaultStore>(matchingStore);
    getIt.registerSingleton<FirebaseSessionProbe>(
      const _StubSessionProbe(true),
    );

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
    registerFakeRecentCityStore();

    // Résumé d'activité par défaut : deux trajets actifs. Les tests qui
    // s'intéressent au cas « aucun trajet » passent `activeTrips: 0` à
    // `pumpHome`.
    _registerTripsSummary(2);

    prSearchState = const PackageRequestSearchState();
    getIt.registerFactory<PackageRequestSearchBloc>(() {
      final mock = MockPackageRequestSearchBloc();
      final etat = prSearchState;
      when(() => mock.state).thenReturn(etat);
      whenListen(
        mock,
        Stream<PackageRequestSearchState>.fromIterable([etat]),
        initialState: etat,
      );
      prBloc = mock;
      return mock;
    });
  });

  tearDown(getIt.reset);

  group("HomeScreen — mode d'ouverture selon l'intention", () {
    late MockActivationCubit activation;
    late StreamController<ActivationState> activationStream;

    Future<void> pumpAvec(WidgetTester tester, ActivationState initial) async {
      activation = MockActivationCubit();
      activationStream = StreamController<ActivationState>.broadcast();
      addTearDown(activationStream.close);
      whenListen(activation, activationStream.stream, initialState: initial);
      when(() => activation.load()).thenAnswer((_) async {});
      getIt.registerSingleton<ActivationCubit>(activation);
      await tester.pumpWidget(_buildHome());
      await tester.pump(const Duration(milliseconds: 1000));
    }

    SearchMode modeAffiche(WidgetTester tester) =>
        tester.widget<SearchModeSelector>(find.byType(SearchModeSelector)).mode;

    Future<void> emettre(WidgetTester tester, ActivationState state) async {
      activationStream.add(state);
      await tester.pumpAndSettle();
    }

    ActivationLoaded charge(UserIntent? intent) =>
        ActivationLoaded(ActivationStatus(intent: intent));

    testWidgets('voyageur : « Je voyage » est actif', (tester) async {
      await pumpAvec(tester, charge(UserIntent.traveler));
      expect(modeAffiche(tester), SearchMode.parcels);
    });

    for (final etat in <String, ActivationState>{
      'les deux': charge(UserIntent.both),
      'expéditeur': charge(UserIntent.sender),
      'indisponible': const ActivationUnavailable(),
      'erreur': const ActivationError(),
      'initial': const ActivationInitial(),
    }.entries) {
      testWidgets("${etat.key} : « J'envoie un colis » est actif", (
        tester,
      ) async {
        await pumpAvec(tester, etat.value);
        expect(modeAffiche(tester), SearchMode.trips);
      });
    }

    testWidgets("un changement d'intention applique le nouveau mode", (
      tester,
    ) async {
      await pumpAvec(tester, const ActivationInitial());
      expect(modeAffiche(tester), SearchMode.trips);

      await emettre(tester, charge(UserIntent.traveler));
      expect(modeAffiche(tester), SearchMode.parcels);

      await emettre(tester, charge(UserIntent.sender));
      expect(modeAffiche(tester), SearchMode.trips);
    });

    testWidgets(
      'un rechargement avec la même intention ne réinitialise pas un mode '
      'choisi à la main',
      (tester) async {
        await pumpAvec(tester, charge(UserIntent.traveler));
        expect(modeAffiche(tester), SearchMode.parcels);

        tester
            .widget<SearchModeSelector>(find.byType(SearchModeSelector))
            .onChanged(SearchMode.trips);
        await tester.pumpAndSettle();
        expect(modeAffiche(tester), SearchMode.trips);

        await emettre(
          tester,
          const ActivationLoaded(
            ActivationStatus(intent: UserIntent.traveler, kycVerified: true),
          ),
        );
        expect(modeAffiche(tester), SearchMode.trips);
      },
    );

    testWidgets("le mode automatique n'émet pas home_search_mode_changed", (
      tester,
    ) async {
      await pumpAvec(tester, const ActivationInitial());
      await emettre(tester, charge(UserIntent.traveler));
      expect(modeAffiche(tester), SearchMode.parcels);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.homeSearchModeChanged,
          properties: any(named: 'properties'),
        ),
      );
    });
  });

  group('HomeScreen — Map sender view', () {
    testWidgets('shows corridor label in search bar', (tester) async {
      await tester.pumpWidget(_buildHome());
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('Tous les trajets'), findsWidgets);
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

    testWidgets('le chip Urgent déclenche une recherche avec urgent=true', (
      tester,
    ) async {
      final announcementBloc = MockAnnouncementBloc();
      final authBloc = MockAuthBloc();
      final roleCubit = MockActiveRoleCubit();
      final notifBloc = MockNotificationBloc();
      final bidBloc = MockBidBloc();

      when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
      when(
        () => announcementBloc.stream,
      ).thenAnswer((_) => const Stream.empty());
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
            _helpCenterProvider(),
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
        () => analytics.logEvent(
          AnalyticsEvents.searchFilterApplied,
          properties: {'filter': 'urgent', 'mode': 'trips'},
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
    });

    testWidgets(
      'la puce Valise 23 kg cherche les trajets avec au moins 23 kg (PROD-Z)',
      (tester) async {
        final announcementBloc = MockAnnouncementBloc();
        final authBloc = MockAuthBloc();
        final roleCubit = MockActiveRoleCubit();
        final notifBloc = MockNotificationBloc();
        final bidBloc = MockBidBloc();

        when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
        when(
          () => announcementBloc.stream,
        ).thenAnswer((_) => const Stream.empty());
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
              _helpCenterProvider(),
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
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));

        // Au montage, aucun minimum de kilos.
        verify(
          () => announcementBloc.add(
            any(
              that: isA<AnnouncementSearchRequested>().having(
                (e) => e.minAvailableKg,
                'minAvailableKg',
                isNull,
              ),
            ),
          ),
        ).called(1);

        await tester.tap(find.byKey(const Key('chip-suitcase-23')));
        await tester.pumpAndSettle();

        verify(
          () => analytics.logEvent(
            AnalyticsEvents.searchFilterApplied,
            properties: {'filter': 'suitcase_23', 'mode': 'trips'},
          ),
        ).called(1);
        verify(
          () => announcementBloc.add(
            any(
              that: isA<AnnouncementSearchRequested>().having(
                (e) => e.minAvailableKg,
                'minAvailableKg',
                23,
              ),
            ),
          ),
        ).called(1);

        // Second toucher : la puce se retire, le filtre aussi.
        await tester.tap(find.byKey(const Key('chip-suitcase-23')));
        await tester.pumpAndSettle();
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.searchFilterCleared,
            properties: {'filter': 'suitcase_23', 'mode': 'trips'},
          ),
        ).called(1);
      },
    );

    testWidgets('shows TravelerCards when announcements loaded', (
      tester,
    ) async {
      // Fenêtre agrandie pour que TravelerCard reste dans la zone de cache
      // initiale de la sheet en position "peek".
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildHome(
          announcementState: AnnouncementSearchLoaded([
            _makeAnn(),
            _makeAnn(id: 'a2'),
          ]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      await ouvrirListe(tester);

      expect(find.byType(TravelerCard), findsAtLeastNWidgets(1));
    });

    // FLUTTER-43 : l'utilisateur voit ses propres trajets dans le fil, avec
    // les autres, marqués « Votre trajet », pour vérifier qu'ils sont publiés.
    testWidgets('ses propres trajets apparaissent dans le fil, marqués', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHomeRouter(
          // travelerId == id de _makeUser ('uid-1') : trajet de l'utilisateur.
          announcementState: AnnouncementSearchLoaded([
            _makeAnn(id: 'a-own', travelerId: 'uid-1'),
            _makeAnn(id: 'a-other', travelerId: 'uid-2'),
          ]),
          visitedTripIds: <String>[],
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));

      await ouvrirListe(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TravelerCard), findsNWidgets(2));
      expect(find.byKey(const Key('own-trip-pill')), findsOneWidget);
    });

    // Sentry FLUTTER-6P/6Q : titre 19 (hors soi), indication 20 (chargés),
    // recherche 22 (total serveur). Un seul nombre désormais : le total.
    testWidgets('titre et indication : même total serveur, soi compris', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHomeRouter(
          announcementState: AnnouncementSearchLoaded([
            _makeAnn(id: 'a-own', travelerId: 'uid-1'),
            _makeAnn(id: 'a-other', travelerId: 'uid-2'),
          ], totalElements: 22),
          visitedTripIds: <String>[],
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));

      await ouvrirListe(tester);
      expect(titreListe(tester), startsWith('22 '));
    });

    testWidgets('shows empty message when search loaded with no results', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded(const [])),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      await ouvrirListe(tester);

      expect(find.text('Aucun voyageur sur ce trajet'), findsOneWidget);
    });

    group('bloc « Autres annonces sur ce trajet »', () {
      SimilarAnnouncement proche(String id) => SimilarAnnouncement(
        announcement: _makeAnn(id: id, travelerId: 'traveler-$id'),
        unmet: const [
          UnmetCriterion(
            code: 'DATE',
            requested: '2026-06-13',
            actual: '2026-06-15',
          ),
        ],
      );

      testWidgets('zero_exact_with_similar_shows_block_not_full_empty_state', (
        tester,
      ) async {
        await pumpHome(
          tester,
          announcementState: AnnouncementSearchLoaded(
            const [],
            similar: [proche('s1')],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await ouvrirListe(tester);

        expect(find.text('Aucun voyageur sur ce trajet'), findsNothing);
        expect(find.byKey(const Key('similar-trips-section')), findsOneWidget);
        // L'en-tête ne dit plus « personne » au-dessus des cartes proches, et
        // la phrase n'est dite qu'une fois (pas de doublon dans le bloc).
        expect(
          sousTitreListe(tester),
          'Aucun trajet ne correspond exactement à votre recherche.',
        );
        expect(
          find.text('Aucun trajet ne correspond exactement à votre recherche.'),
          findsOneWidget,
        );
        expect(
          find.text("Personne ne propose ce trajet pour l'instant"),
          findsNothing,
        );
        expect(find.byType(TravelerCard), findsOneWidget);
        // La carte proche dit pourquoi elle ne correspond pas.
        expect(
          find.byKey(const ValueKey('traveler-card-unmet-0')),
          findsOneWidget,
        );
      });

      testWidgets('zero_exact_with_similar_and_filter_shows_clear_action', (
        tester,
      ) async {
        await pumpHome(
          tester,
          announcementState: AnnouncementSearchLoaded(
            const [],
            similar: [proche('s1')],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await ouvrirListe(tester);
        expect(
          find.byKey(const Key('similar-trips-clear-filters')),
          findsNothing,
        );

        await tester.tap(find.text('🔥 Urgent'));
        await tester.pumpAndSettle();

        final action = find.byKey(const Key('similar-trips-clear-filters'));
        expect(action, findsOneWidget);
        expect(find.text('Effacer les filtres'), findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));

        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(action, findsNothing);
      });

      testWidgets('exact_results_with_filter_hide_clear_action', (
        tester,
      ) async {
        await pumpHome(
          tester,
          announcementState: AnnouncementSearchLoaded(
            [_makeAnn()],
            similar: [proche('s1')],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await ouvrirListe(tester);
        await tester.tap(find.text('🔥 Urgent'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('similar-trips-section')), findsOneWidget);
        expect(
          find.byKey(const Key('similar-trips-clear-filters')),
          findsNothing,
        );
      });

      testWidgets('similar_without_unmet_shows_generic_reason', (tester) async {
        await pumpHome(
          tester,
          announcementState: AnnouncementSearchLoaded(
            const [],
            similar: [
              SimilarAnnouncement(
                announcement: _makeAnn(id: 's9', travelerId: 'traveler-s9'),
                unmet: const [],
              ),
            ],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await ouvrirListe(tester);

        final card = tester.widget<TravelerCard>(find.byType(TravelerCard));
        expect(card.unmetReasons, ["Ne correspond pas à l'un de vos critères"]);
      });

      testWidgets('exact_results_and_similar_show_block_below_list', (
        tester,
      ) async {
        await pumpHome(
          tester,
          announcementState: AnnouncementSearchLoaded(
            [_makeAnn()],
            similar: [proche('s1')],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await ouvrirListe(tester);

        expect(find.byKey(const Key('similar-trips-section')), findsOneWidget);
        expect(
          find.text('Aucun trajet ne correspond exactement à votre recherche.'),
          findsNothing,
        );
        expect(sousTitreListe(tester), isNull);
        final cards = find.byType(TravelerCard);
        expect(cards, findsNWidgets(2));
        // La carte exacte n'a aucun avertissement, la carte proche en a un,
        // et le bloc vient après la liste exacte.
        final exacte = tester.widget<TravelerCard>(cards.first);
        final prochaine = tester.widget<TravelerCard>(cards.last);
        expect(exacte.announcement.id, 'a1');
        expect(exacte.unmetReasons, isEmpty);
        expect(prochaine.announcement.id, 's1');
        expect(prochaine.unmetReasons, hasLength(1));
        expect(
          tester.getTopLeft(find.text('Autres annonces sur ce trajet')).dy,
          greaterThan(tester.getTopLeft(cards.first).dy),
        );
      });

      testWidgets('similar_card_tap_opens_same_trip_sheet_as_exact_card', (
        tester,
      ) async {
        await pumpHome(
          tester,
          announcementState: AnnouncementSearchLoaded(
            [_makeAnn()],
            similar: [proche('s1')],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await ouvrirListe(tester);

        // Identifiants des trajets dont la feuille « Détail du trajet » s'est
        // ouverte (recordTripView, appelé par showTravelerAnnouncementSheet).
        List<String> vus() => verify(
          () => analytics.logEvent(
            AnalyticsEvents.announcementViewed,
            properties: captureAny(named: 'properties'),
          ),
        ).captured.map((p) => (p as Map)['announcement_id'] as String).toList();

        Future<void> ouvrirPuisFermer(String id) async {
          final carte = find.byWidgetPredicate(
            (w) => w is TravelerCard && w.announcement.id == id,
          );
          await tester.ensureVisible(carte);
          await tester.pumpAndSettle();
          await tester.tap(carte);
          await tester.pumpAndSettle();
          expect(find.text('Détail du trajet'), findsOneWidget);
          await tester.tapAt(const Offset(500, 20));
          await tester.pumpAndSettle();
          expect(find.text('Détail du trajet'), findsNothing);
        }

        await ouvrirPuisFermer('a1');
        expect(vus(), ['a1']);
        await ouvrirPuisFermer('s1');
        expect(vus(), ['s1']);
      });

      testWidgets('block_hidden_for_parcels_mode', (tester) async {
        await pumpHome(
          tester,
          announcementState: AnnouncementSearchLoaded(
            const [],
            similar: [proche('s1')],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await ouvrirListe(tester);
        expect(find.byKey(const Key('similar-trips-section')), findsOneWidget);

        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('similar-trips-section')), findsNothing);
        expect(find.byType(TravelerCard), findsNothing);
      });

      testWidgets('erreur après des résultats : aucun bloc inventé', (
        tester,
      ) async {
        await pumpHome(
          tester,
          announcementState: AnnouncementError(
            const NetworkException('boom'),
            previousResults: [_makeAnn()],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));

        expect(find.byKey(const Key('similar-trips-section')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('état vide et en-tête de liste traduits en anglais', (
      tester,
    ) async {
      useEnglish();
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded(const [])),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      await ouvrirListe(tester);

      expect(find.text('No travelers on this route'), findsOneWidget);
      expect(find.text('0 travelers · All routes'), findsOneWidget);
      expect(find.text('Aucun voyageur sur ce trajet'), findsNothing);
    });

    testWidgets(
      'scarabée : posé à gauche sur la carte, à la hauteur de la pastille '
      '« Liste » ; absent de la liste plein écran',
      (tester) async {
        await pumpHome(tester);
        await tester.pump(const Duration(milliseconds: 1000));

        // Carte : un seul scarabée, à gauche, sur la ligne de la pastille.
        expect(find.byKey(const Key('feedback-map')), findsOneWidget);
        expect(find.byType(DonyFeedbackButton), findsOneWidget);
        final bug = tester.getCenter(find.byKey(const Key('feedback-map')));
        final pastille = tester.getCenter(
          find.byKey(const Key('home-list-pill')),
        );
        expect((bug.dy - pastille.dy).abs(), lessThan(kDonyMinTapTarget));
        expect(bug.dx, lessThan(pastille.dx));

        // Plein écran : plus de scarabée. Favoris, recherche, « + » et cloche
        // prennent sa place dans l'en-tête de la liste, et la rangée de la
        // carte n'existe plus (pas de doublon).
        await ouvrirListe(tester);
        expect(find.byType(DonyFeedbackButton), findsNothing);
        expect(find.byKey(const Key('feedback-map')), findsNothing);
        expect(find.byKey(const Key('corridor-bar-sheet')), findsOneWidget);
        expect(find.byKey(const Key('corridor-bar')), findsNothing);
        expect(find.byKey(const Key('favorites-button')), findsOneWidget);
        expect(find.byKey(const Key('home-publish-button')), findsOneWidget);
        final bar = tester.getRect(find.byKey(const Key('corridor-bar-sheet')));
        final publier = tester.getCenter(
          find.byKey(const Key('home-publish-button')),
        );
        final favoris = tester.getCenter(
          find.byKey(const Key('favorites-button')),
        );
        // Une seule rangée : favoris à gauche de la barre, « + » à sa droite.
        expect(favoris.dx, lessThan(bar.left));
        expect(publier.dx, greaterThan(bar.right));
        expect((publier.dy - favoris.dy).abs(), lessThan(4));
      },
    );

    testWidgets('vue carte par défaut : pastille « Liste », aucune liste', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byKey(const Key('home-list-pill')), findsOneWidget);
      // La liste n'est pas construite tant qu'on reste sur la carte.
      expect(find.byKey(const Key('home-sheet')), findsNothing);
      expect(find.byType(TravelerCard), findsNothing);
      expect(find.text('Liste'), findsOneWidget);
    });

    testWidgets(
      'le titre de la liste suit le mode : en Colis il compte les demandes, '
      'pas les trajets',
      (tester) async {
        // Deux jeux de tailles différentes, pour qu'un compteur pris du mauvais
        // côté soit visible : 1 trajet contre 3 demandes.
        prSearchState = PackageRequestSearchState(
          status: SearchStatus.loaded,
          results: [_makeRequest('r1'), _makeRequest('r2'), _makeRequest('r3')],
        );

        await pumpHome(tester, tripResults: [_makeAnn()]);
        await ouvrirListe(tester);
        expect(titreListe(tester), startsWith('1 '));

        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();

        expect(titreListe(tester), startsWith('3 '));
      },
    );

    // FLUTTER-58 : ses propres demandes étaient masquées du fil et de la carte,
    // l'expéditeur croyait qu'elles n'étaient pas publiées. Elles restent
    // affichées (marquées comme les siennes) et le compteur suit la liste.
    testWidgets(
      'le compteur Colis compte ses propres demandes, affichées dans le fil',
      (tester) async {
        prSearchState = PackageRequestSearchState(
          status: SearchStatus.loaded,
          results: [
            _makeRequest('r1'),
            _makeRequest('r2'),
            _makeOwnRequest('r-moi'),
          ],
        );

        await pumpHome(tester, tripResults: [_makeAnn()]);
        await ouvrirListe(tester);
        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();

        expect(titreListe(tester), startsWith('3 '));
      },
    );

    // Le compteur suivait les lignes chargées (20 puis 40 au défilement) au
    // lieu du total serveur.
    testWidgets(
      'le compteur Colis suit le total serveur, pas les pages chargées',
      (tester) async {
        final avant = PackageRequestSearchState(
          status: SearchStatus.loaded,
          results: [for (var i = 0; i < 20; i++) _makeRequest('a$i')],
          totalElements: 45,
        );
        final apres = avant.copyWith(
          results: [for (var i = 0; i < 40; i++) _makeRequest('a$i')],
          page: 1,
        );
        final flux = StreamController<PackageRequestSearchState>();
        addTearDown(flux.close);
        getIt.unregister<PackageRequestSearchBloc>();
        getIt.registerFactory<PackageRequestSearchBloc>(() {
          final mock = MockPackageRequestSearchBloc();
          when(() => mock.state).thenReturn(avant);
          whenListen(mock, flux.stream, initialState: avant);
          return mock;
        });

        await pumpHome(tester, tripResults: [_makeAnn()]);
        await ouvrirListe(tester);
        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();

        expect(titreListe(tester), startsWith('45 '));

        // Le chargement de la page suivante amène 40 lignes, le total reste.
        flux.add(apres);
        await tester.pumpAndSettle();

        expect(titreListe(tester), startsWith('45 '));
        expect(find.textContaining('40 colis'), findsNothing);
      },
    );

    testWidgets('ses propres demandes sont dans le fil, marquées', (
      tester,
    ) async {
      prSearchState = PackageRequestSearchState(
        status: SearchStatus.loaded,
        results: [_makeRequest('r1'), _makeOwnRequest('r-moi')],
      );

      await pumpHome(tester, tripResults: [_makeAnn()]);
      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();
      await ouvrirListe(tester);

      final cards = tester
          .widgetList<PackageRequestListCard>(
            find.byType(PackageRequestListCard),
          )
          .toList();
      expect(cards.map((c) => c.item.id), containsAll(['r1', 'r-moi']));
      expect(
        cards.singleWhere((c) => c.item.id == 'r-moi').isOwnRequest,
        isTrue,
      );
      expect(cards.singleWhere((c) => c.item.id == 'r1').isOwnRequest, isFalse);
    });

    testWidgets('« Liste » ouvre la liste plein écran, « Carte » revient', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await ouvrirListe(tester);

      // En plein écran : l'en-tête de la liste porte la recherche, et la
      // pastille « Carte » ramène à la carte au même endroit que « Liste ».
      expect(find.byKey(const Key('corridor-bar-sheet')), findsOneWidget);
      expect(find.byKey(const Key('home-map-pill')), findsOneWidget);
      final carte = tester.getCenter(find.byKey(const Key('home-map-pill')));

      await tester.tap(find.byKey(const Key('home-map-pill')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-sheet')), findsNothing);
      final liste = tester.getCenter(find.byKey(const Key('home-list-pill')));
      expect((liste.dy - carte.dy).abs(), lessThan(1));
      expect((liste.dx - carte.dx).abs(), lessThan(1));
    });

    // Sentry FLUTTER-4X : en paysage (≈360 dp de haut) la feuille ne doit
    // jamais déborder, ni sur la carte ni en liste plein écran.
    testWidgets('paysage : la carte et la liste ne débordent pas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(820, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home-list-pill')), findsOneWidget);

      await ouvrirListe(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'bouton de localisation : la feuille de rayon s\'ouvre avant d\'activer '
      'le filtre',
      (tester) async {
        GeolocatorPlatform.instance = _MockGeolocatorPlatform();

        await tester.pumpWidget(
          _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('near-me-fab')));
        await tester.pumpAndSettle();

        // Feuille « Près de moi » ouverte, filtre pas encore actif.
        expect(find.text('Près de moi'), findsOneWidget);
        expect(find.text('Activer le filtre'), findsOneWidget);
        expect(find.byKey(const Key('near-me-radius-pill')), findsNothing);
        expect(find.text('5 km'), findsOneWidget);
        expect(find.text('200 km'), findsOneWidget);

        await tester.tap(find.text('Activer le filtre'));
        await tester.pumpAndSettle();

        // Filtre actif : puce de rayon sous les filtres, plus de carrousel de
        // trajets, la liste reste à un tap.
        expect(find.byKey(const Key('near-me-radius-pill')), findsOneWidget);
        expect(find.text('Rayon · 25 km'), findsOneWidget);
        expect(find.byKey(const Key('home-list-pill')), findsOneWidget);
        expect(find.byKey(const Key('chip-near-me')), findsOneWidget);
      },
    );

    testWidgets('fermer la feuille de rayon sans valider n\'active rien', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _MockGeolocatorPlatform();

      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('near-me-radius-pill')), findsNothing);
      expect(find.byKey(const Key('chip-near-me')), findsNothing);
    });

    testWidgets('2e tap sur le bouton désactive le filtre Près de moi', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _MockGeolocatorPlatform();

      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump();

      await activerPresDeMoi(tester);
      expect(find.byKey(const Key('near-me-radius-pill')), findsOneWidget);

      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('near-me-radius-pill')), findsNothing);
      expect(find.byKey(const Key('home-list-pill')), findsOneWidget);
    });

    testWidgets('la croix de la puce Rayon désactive « Près de moi »', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _MockGeolocatorPlatform();

      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump();

      await activerPresDeMoi(tester);
      await tester.tap(find.byKey(const Key('near-me-radius-clear')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('near-me-radius-pill')), findsNothing);
      expect(find.byKey(const Key('chip-near-me')), findsNothing);
    });

    testWidgets('la puce Près de moi de la liste se retire d\'un tap', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _MockGeolocatorPlatform();

      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump();

      await activerPresDeMoi(tester);
      await ouvrirListe(tester);

      // La liste garde le filtre : puce « Près de moi · 25 km ✕ » en tête.
      expect(find.text('Près de moi · 25 km'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chip-near-me')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chip-near-me')), findsNothing);
    });

    testWidgets('radius pill re-opens the slider without losing the filter', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _MockGeolocatorPlatform();

      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump();

      await activerPresDeMoi(tester);

      // La puce de rayon est affichée tant que le filtre est actif.
      expect(find.byKey(const Key('near-me-radius-pill')), findsOneWidget);

      // Un tap la rouvre avec le CTA « Appliquer » sur place.
      await tester.tap(find.text('Rayon · 25 km'));
      await tester.pumpAndSettle();
      expect(find.text('Appliquer'), findsOneWidget);

      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      // Le filtre est toujours actif.
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
        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();

        await activerPresDeMoi(tester);

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
        when(
          () => announcementBloc.stream,
        ).thenAnswer((_) => const Stream.empty());
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
              _helpCenterProvider(),
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
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));

        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
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

  // ─── search_submitted (tracking « En une phrase » vs filtres) ─────────────
  //
  // La mesure qui décidera du sort du bloc « En une phrase » : si les
  // recherches passent par les filtres dans plus de 90 % des cas, il se
  // retire sans rien casser. `_openComposer` est le SEUL point de sortie —
  // un réglage direct au doigt (chip, sheet) ajuste un filtre mais ne
  // « soumet » jamais de recherche, il ne doit donc jamais tracer cet event
  // (régression du bug corrigé : avant, `_onFiltersChanged` le traçait à
  // chaque changement, faussant complètement le ratio phrase/filtres).
  // Ouvrir la feuille Capacité puis « Appliquer » sans rien toucher posait
  // 1 à 50 kg : les trajets de plus de 50 kg disponibles disparaissaient.
  group('feuille Capacité : une poignée au bout = pas de borne', () {
    Future<MockAnnouncementBloc> pumpTrips(WidgetTester tester) async {
      final bloc = MockAnnouncementBloc();
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _buildHome(
          announcementBlocOverride: bloc,
          user: _makeUser(roles: const ['SENDER', 'TRAVELER']),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      return bloc;
    }

    Future<void> openSheet(WidgetTester tester) async {
      final chip = find.byKey(const Key('chip-capacity'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    List<AnnouncementSearchRequested> searches(MockAnnouncementBloc bloc) =>
        verify(
          () => bloc.add(captureAny()),
        ).captured.whereType<AnnouncementSearchRequested>().toList();

    String chipLabel(WidgetTester tester) => tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(const Key('chip-capacity')),
                matching: find.byType(Text),
              )
              .first,
        )
        .data!;

    testWidgets('appliquer sans toucher : aucune borne, puce inactive', (
      tester,
    ) async {
      final bloc = await pumpTrips(tester);
      await openSheet(tester);
      expect(find.text('50 kg et +'), findsOneWidget);
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      for (final e in searches(bloc)) {
        expect(e.minAvailableKg, isNull);
        expect(e.maxAvailableKg, isNull);
      }
      expect(chipLabel(tester), 'Kilos');
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.searchFilterApplied,
          properties: {'filter': 'weight', 'mode': 'trips'},
        ),
      );
    });

    testWidgets('minimum seul déplacé : seul minAvailableKg part', (
      tester,
    ) async {
      final bloc = await pumpTrips(tester);
      await openSheet(tester);
      final slider = tester.getRect(find.byType(RangeSlider));
      await tester.dragFrom(
        Offset(slider.left + 24, slider.center.dy),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      final last = searches(bloc).last;
      expect(last.minAvailableKg, isNotNull);
      expect(last.minAvailableKg, greaterThan(1));
      expect(last.maxAvailableKg, isNull);
      expect(chipLabel(tester), startsWith('≥ '));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.searchFilterApplied,
          properties: {'filter': 'weight', 'mode': 'trips'},
        ),
      ).called(1);
    });

    testWidgets('maximum seul déplacé : seul maxAvailableKg part', (
      tester,
    ) async {
      final bloc = await pumpTrips(tester);
      await openSheet(tester);
      final slider = tester.getRect(find.byType(RangeSlider));
      await tester.dragFrom(
        Offset(slider.right - 24, slider.center.dy),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      final last = searches(bloc).last;
      expect(last.minAvailableKg, isNull);
      expect(last.maxAvailableKg, isNotNull);
      expect(last.maxAvailableKg, lessThan(50));
      expect(chipLabel(tester), startsWith('≤ '));
    });

    testWidgets('puce Valise 23 kg + Capacité au bout : minimum 23 seul', (
      tester,
    ) async {
      final bloc = await pumpTrips(tester);
      await tester.tap(find.byKey(const Key('chip-suitcase-23')));
      await tester.pumpAndSettle();
      await openSheet(tester);
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      final last = searches(bloc).last;
      expect(last.minAvailableKg, 23);
      expect(last.maxAvailableKg, isNull);
      expect(chipLabel(tester), 'Kilos');
    });
  });

  group('première arrivée sur l\'onglet : liste à 100 %', () {
    testWidgets(
      'la feuille se pose à 100 % : favoris, recherche, « + » dans son '
      'en-tête, sans scarabée',
      (tester) async {
        HomeSheetSession.reset();
        await pumpHome(tester, tripResults: [_makeAnn()]);
        await tester.pump(const Duration(milliseconds: 1000));

        expect(find.byKey(const Key('corridor-bar-sheet')), findsOneWidget);
        expect(find.byKey(const Key('corridor-bar')), findsNothing);
        expect(find.byKey(const Key('favorites-button')), findsOneWidget);
        expect(find.byKey(const Key('home-publish-button')), findsOneWidget);
        expect(find.byType(DonyFeedbackButton), findsNothing);
        // La liste est visible dès l'arrivée : la feuille couvre l'écran.
        final sheet = tester.getRect(find.byKey(const Key('home-sheet')));
        expect(sheet.top, lessThan(1));
        expect(find.byType(TravelerCard), findsWidgets);
      },
    );

    testWidgets('le cran « plein écran » est mesuré comme une ouverture '
        'automatique', (tester) async {
      HomeSheetSession.reset();
      await pumpHome(tester, tripResults: [_makeAnn()]);
      await tester.pump(const Duration(seconds: 1));

      final snaps = verify(
        () => analytics.logEvent(
          AnalyticsEvents.homeSheetSnapped,
          properties: captureAny(named: 'properties'),
        ),
      ).captured.cast<Map<String, Object>>();
      expect(snaps, hasLength(1));
      expect(snaps.single['size'], 'full');
      expect(snaps.single['auto'], isTrue);
      expect(snaps.single.containsKey('from'), isFalse);
    });

    testWidgets('une seule fois par session : le second écran s\'ouvre comme '
        'avant, sur la carte, avec la rangée sur la carte', (tester) async {
      HomeSheetSession.reset();
      await pumpHome(tester, tripResults: [_makeAnn()]);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byKey(const Key('corridor-bar-sheet')), findsOneWidget);

      // Un nouvel écran dans le même processus (reconnexion) : l'ouverture à
      // 100 % est consommée.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.byKey(const Key('corridor-bar')), findsOneWidget);
      expect(find.byKey(const Key('corridor-bar-sheet')), findsNothing);
    });

    testWidgets('en repliant la liste depuis le plein écran, la rangée '
        'favoris, recherche, « + » repasse sur la carte et le scarabée '
        'revient', (tester) async {
      HomeSheetSession.reset();
      await pumpHome(tester, tripResults: [_makeAnn()]);
      await tester.pump(const Duration(milliseconds: 1000));

      await tester.tap(find.text('Carte'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('corridor-bar')), findsOneWidget);
      expect(find.byKey(const Key('corridor-bar-sheet')), findsNothing);
      expect(find.byKey(const Key('favorites-button')), findsOneWidget);
      expect(find.byType(DonyFeedbackButton), findsOneWidget);
    });
  });

  group('mesure de la carte, du carrousel et de la feuille', () {
    testWidgets(
      'tap sur une carte de la liste : home_card_opened source list',
      (tester) async {
        await pumpHome(tester, tripResults: [_makeAnn()]);
        await tester.pump(const Duration(milliseconds: 1000));
        await ouvrirListe(tester);

        final carte = find.byType(TravelerCard).first;
        await tester.ensureVisible(carte);
        await tester.pumpAndSettle();
        await tester.tap(carte);
        await tester.pumpAndSettle();

        verify(
          () => analytics.logEvent(
            AnalyticsEvents.homeCardOpened,
            properties: {'source': 'list', 'mode': 'trips', 'kind': 'trip'},
          ),
        ).called(1);
      },
    );

    testWidgets(
      'un tap sur un marqueur ne fait que sélectionner le trajet : la carte-'
      'résumé s\'ouvre, et son tap trace home_card_opened source map',
      (tester) async {
        await tester.pumpWidget(
          _buildHome(
            announcementState: AnnouncementSearchLoaded([
              _makeAnn(),
              _makeAnn(id: 'a2'),
            ]),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byKey(const Key('map-trip-summary')), findsNothing);

        tester
            .widget<AnnouncementMapView>(find.byType(AnnouncementMapView))
            .onAnnouncementSelected!('a2');
        await tester.pumpAndSettle();

        verify(
          () => analytics.logEvent(
            AnalyticsEvents.homeMapMarkerTapped,
            properties: {'mode': 'trips', 'kind': 'trip'},
          ),
        ).called(1);
        // Le marqueur n'ouvre aucune fiche à lui seul.
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.homeCardOpened,
            properties: any(named: 'properties'),
          ),
        );
        expect(find.byKey(const Key('map-trip-summary')), findsOneWidget);

        await tester.tap(find.byType(TravelerCard));
        await tester.pumpAndSettle();
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.homeCardOpened,
            properties: {'source': 'map', 'mode': 'trips', 'kind': 'trip'},
          ),
        ).called(1);
      },
    );

    testWidgets(
      'la croix de la carte-résumé et le tap sur la carte la ferment',
      (tester) async {
        await tester.pumpWidget(
          _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
        );
        await tester.pump(const Duration(milliseconds: 600));
        final map = tester.widget<AnnouncementMapView>(
          find.byType(AnnouncementMapView),
        );

        map.onAnnouncementSelected!('a1');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map-summary-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map-trip-summary')), findsNothing);

        map.onAnnouncementSelected!('a1');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map-trip-summary')), findsOneWidget);
        map.onMapTapped!();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map-trip-summary')), findsNothing);
      },
    );

    testWidgets(
      'la bascule trace son cran une fois posée : liste par geste, puis '
      'retour sur la carte, jamais pendant le mouvement',
      (tester) async {
        await tester.pumpWidget(
          _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        List<Map<String, Object>> snaps() => verify(
          () => analytics.logEvent(
            AnalyticsEvents.homeSheetSnapped,
            properties: captureAny(named: 'properties'),
          ),
        ).captured.cast<Map<String, Object>>();

        // Au repos sur la carte : rien à tracer.
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.homeSheetSnapped,
            properties: any(named: 'properties'),
          ),
        );

        // « Liste » : rien pendant le mouvement.
        await tester.tap(find.byKey(const Key('home-list-pill')));
        await tester.pump(const Duration(milliseconds: 100));
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.homeSheetSnapped,
            properties: any(named: 'properties'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        final liste = snaps();
        expect(liste, hasLength(1));
        expect(liste.single['size'], 'full');
        expect(liste.single['auto'], isFalse);
        expect(liste.single.containsKey('from'), isFalse);
        clearInteractions(analytics);

        // « Carte » : retour sur la carte.
        await tester.tap(find.byKey(const Key('home-map-pill')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        final carte = snaps();
        expect(carte, hasLength(1));
        expect(carte.single['size'], 'map');
        expect(carte.single['from'], 'full');
      },
    );
  });

  group('search_submitted', () {
    testWidgets('un changement direct au doigt (hors composer) ne trace rien', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('🔥 Urgent'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chip-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Aujourd'hui").last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.searchSubmitted,
          properties: any(named: 'properties'),
        ),
      );
    });

    testWidgets(
      'valider depuis l\'écran de composition trace le mode et le bon nombre '
      'de filtres actifs',
      (tester) async {
        await pumpHome(tester);

        await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

        // Le corridor (départ + arrivée) compte pour un seul filtre actif.
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.searchSubmitted,
            properties: {'mode': 'trips', 'filter_count': 1},
          ),
        ).called(1);
      },
    );
  });

  group('sélecteur de mode', () {
    testWidgets(
      'sur sa propre ligne sous la barre de recherche, hors de la rangée de '
      'chips',
      (tester) async {
        await pumpHome(tester);

        // Rendu dans les chips, il se lisait comme un filtre de plus.
        expect(find.byType(SearchModeSelector), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(HomeFilterChipsRow),
            matching: find.byType(SearchModeSelector),
          ),
          findsNothing,
        );

        final barre = tester.getBottomLeft(
          find.byKey(const Key('corridor-bar')),
        );
        final selecteur = tester.getRect(find.byType(SearchModeSelector));
        final chips = tester.getTopLeft(find.byType(HomeFilterChipsRow));
        expect(selecteur.top, greaterThanOrEqualTo(barre.dy));
        expect(selecteur.bottom, lessThanOrEqualTo(chips.dy));
      },
    );

    testWidgets('feuille dépliée : le sélecteur est dans son en-tête', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: [_makeAnn()]);

      await ouvrirListe(tester);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('home-sheet')),
          matching: find.byType(SearchModeSelector),
        ),
        findsOneWidget,
      );
    });
  });

  group('modes de recherche', () {
    testWidgets('ouvre en mode Trajets', (tester) async {
      await pumpHome(tester);
      await ouvrirListe(tester);

      expect(
        find.byKey(const Key('search_mode_segment_trips')),
        findsOneWidget,
      );
      expect(titreListe(tester), contains('voyageur'));
    });

    testWidgets(
      'une session invitée ouvre aussi en mode Trajets, comme un inscrit',
      (tester) async {
        // La recherche de trajets fonctionne désormais pour un visiteur
        // (Task 7) : `initialSearchMode` n'a plus de raison de le distinguer
        // d'un inscrit à l'ouverture de l'écran, la méthode a été supprimée.
        getIt.unregister<FirebaseSessionProbe>();
        getIt.registerSingleton<FirebaseSessionProbe>(
          const _StubSessionProbe.guest(),
        );

        await pumpHome(tester, authState: const AuthGuestSessionReady());
        await ouvrirListe(tester);

        expect(
          find.byKey(const Key('search_mode_segment_trips')),
          findsOneWidget,
        );
        expect(titreListe(tester), contains('voyageur'));
      },
    );

    testWidgets(
      'la pastille « Mon argent » a quitté l\'en-tête de l\'accueil pour '
      'celui d\'Activités (FLUTTER-J3)',
      (tester) async {
        await pumpHome(tester);
        expect(find.byKey(const Key('money-header-button')), findsNothing);
      },
    );

    testWidgets(
      'la carte de trajet n\'a plus de signet : il se pose depuis le détail',
      (tester) async {
        final favCubit = _makeFavCubit();
        getIt.unregister<FirebaseSessionProbe>();
        getIt.registerSingleton<FirebaseSessionProbe>(
          const _StubSessionProbe.guest(),
        );

        await pumpHome(
          tester,
          tripResults: troisTrajets,
          authState: const AuthGuestSessionReady(),
          favCubit: favCubit,
        );

        // Le corridor prend toute la ligne du haut : le signet des favoris
        // n'est plus sur la carte, il reste dans le détail du trajet.
        expect(find.byType(FavoriteHeartButton), findsNothing);
      },
    );

    testWidgets('le mode Colis est proposé à tout utilisateur', (tester) async {
      // Anciennement conditionné à isTraveler. Le rôle voyageur est universel.
      await pumpHome(tester, isTraveler: false);

      expect(
        find.byKey(const Key('search_mode_segment_colis')),
        findsOneWidget,
      );
    });

    testWidgets('basculer sur Colis change le header de la liste', (
      tester,
    ) async {
      await pumpHome(tester);
      await ouvrirListe(tester);

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();

      expect(titreListe(tester), contains('colis à transporter'));
      expect(titreListe(tester), isNot(contains('voyageur')));
    });

    testWidgets('le corridor survit à la bascule de mode', (tester) async {
      await pumpHome(tester);
      // Poser Paris → Dakar via la sheet de filtres en mode trajets.
      await ouvrirSheetEtSaisirCorridor(tester, 'Paris', 'Dakar');

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
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

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
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

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();

      verify(
        () => packageRequestSearchBloc.add(
          any(that: isA<SearchFiltersChanged>()),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('les chips spécifiques changent avec le mode', (tester) async {
      await pumpHome(tester);
      expect(find.text('GP Pro'), findsOneWidget);

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();

      expect(find.text('GP Pro'), findsNothing);
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
            gpProOnly: any(named: 'gpProOnly'),
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
        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();

        await ouvrirSheetEtSaisirCorridor(tester, 'Paris', 'Dakar');

        // Corridor seul : il part tel quel dans le compte.
        expect(appels, isNotEmpty);
        expect(appels.last[#departureCity], 'Paris');
        expect(appels.last[#arrivalCity], 'Dakar');

        final avantNearMe = appels.length;
        await activerPresDeMoi(tester);

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
        // Le filtre s'active d'office pour qui a un trajet actif ; ici la
        // personne l'avait déjà retiré, la pastille part donc éteinte.
        matchingStore.out = true;
        await pumpHome(tester);

        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
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

        // Activer la pastille depuis la feuille de filtres colis. Le libellé
        // existe à deux endroits depuis que la pastille est aussi dans la
        // rangée de chips : on cible celle de la feuille par sa clé.
        await tester.tap(find.byKey(const Key('corridor-bar')));
        await tester.pumpAndSettle();
        await tester.dragUntilVisible(
          find.byKey(const Key('chip-matching-my-trips')),
          find.byType(Scrollable).first,
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
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

  // ─── Filtre « Pour mes trajets » ────────────────────────────────────────────
  group('« Pour mes trajets »', () {
    /// Ouvre la feuille de filtres colis et amène la pastille à l'écran.
    Future<void> ouvrirPastille(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('corridor-bar')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const Key('chip-matching-my-trips')),
        find.byType(Scrollable).first,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
    }

    /// Vrai si la pastille est rendue à 40 % d'opacité (état désactivé du DS).
    bool pastilleGrisee(WidgetTester tester) => tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.byKey(const Key('chip-matching-my-trips')),
            matching: find.byType(Opacity),
          ),
        )
        .any((o) => o.opacity == 0.4);

    testWidgets('sans trajet actif : la pastille est grisée', (tester) async {
      await pumpHome(tester, activeTrips: 0);
      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();
      await ouvrirPastille(tester);

      expect(pastilleGrisee(tester), isTrue);
    });

    testWidgets('avec des trajets actifs : la pastille est normale', (
      tester,
    ) async {
      await pumpHome(tester, activeTrips: 3);
      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();
      await ouvrirPastille(tester);

      expect(pastilleGrisee(tester), isFalse);
    });

    testWidgets(
      'sans trajet actif : le tap explique et ne filtre pas la recherche',
      (tester) async {
        await pumpHome(tester, activeTrips: 0);
        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();
        await ouvrirPastille(tester);

        await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
        await tester.pumpAndSettle();

        expect(find.text('Publier un trajet'), findsOneWidget);
        verifyNever(
          () => prBloc.add(
            any(
              that: isA<SearchFiltersChanged>().having(
                (e) => e.matchingMyTrips,
                'matchingMyTrips',
                isTrue,
              ),
            ),
          ),
        );
      },
    );

    testWidgets('l\'explication ne contient aucun tiret cadratin', (
      tester,
    ) async {
      await pumpHome(tester, activeTrips: 0);
      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();
      await ouvrirPastille(tester);
      await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
      await tester.pumpAndSettle();

      // Sans ces deux assertions, « aucun texte ne contient de tiret cadratin »
      // passerait trivialement sur un écran où rien ne s'est ouvert.
      expect(find.text('Aucun trajet actif'), findsOneWidget);
      expect(
        find.textContaining('Publiez un trajet pour vous en servir.'),
        findsOneWidget,
      );

      final textes = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      expect(textes.any((t) => t.contains('—')), isFalse);
    });

    // ── Résumé d'activité en échec : le nombre de trajets est INCONNU ────────
    //
    // Inconnu n'est pas zéro. Le confondre ferait lire « Aucun trajet actif » à
    // un voyageur qui en a cinq, et pour toute la session (le résumé n'est
    // chargé qu'à la création de l'écran).
    testWidgets(
      'résumé en échec : la pastille reste utilisable, aucune contre-vérité',
      (tester) async {
        await pumpHome(tester, summaryState: const TripsSummaryState.hidden());
        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();
        await ouvrirPastille(tester);

        expect(pastilleGrisee(tester), isFalse);

        await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
        await tester.pumpAndSettle();

        // Aucune explication mensongère.
        expect(find.text('Aucun trajet actif'), findsNothing);

        await tester.tap(find.text('Rechercher'));
        await tester.pumpAndSettle();

        // Le filtre part au serveur : c'est lui qui tranche.
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

        // Et le tracking n'invente pas de nombre de trajets.
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.homeMatchingTripsFilterToggled,
            properties: {'active': true, 'source': 'user'},
          ),
        ).called(1);
      },
    );

    testWidgets('résumé en échec : l\'en-tête n\'annonce pas « 0 trajet »', (
      tester,
    ) async {
      prSearchState = PackageRequestSearchState(
        status: SearchStatus.loaded,
        results: [_makeRequest('r-1'), _makeRequest('r-2')],
        matchingMyTrips: true,
      );
      await pumpHome(tester, summaryState: const TripsSummaryState.hidden());

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();

      expect(titreListe(tester), '2 colis compatibles');
      expect(find.textContaining('0 trajet'), findsNothing);
    });

    testWidgets(
      'activer la pastille trace la bascule et le nombre de trajets',
      (tester) async {
        matchingStore.out = true;
        await pumpHome(tester, activeTrips: 3);
        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();
        await ouvrirPastille(tester);

        await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rechercher'));
        await tester.pumpAndSettle();

        verify(
          () => analytics.logEvent(
            AnalyticsEvents.homeMatchingTripsFilterToggled,
            properties: {'active': true, 'active_trips': 3, 'source': 'user'},
          ),
        ).called(1);
      },
    );

    testWidgets('valider sans toucher la pastille ne trace rien', (
      tester,
    ) async {
      matchingStore.out = true;
      await pumpHome(tester, activeTrips: 3);
      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('corridor-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();

      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: any(named: 'properties'),
        ),
      );
    });

    testWidgets('l\'en-tête annonce les colis compatibles et les trajets', (
      tester,
    ) async {
      prSearchState = PackageRequestSearchState(
        status: SearchStatus.loaded,
        results: [_makeRequest('r-1'), _makeRequest('r-2')],
        matchingMyTrips: true,
      );
      await pumpHome(tester, activeTrips: 3);

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();
      await ouvrirListe(tester);

      expect(titreListe(tester), '2 colis compatibles');
      expect(titreListe(tester), isNot(contains('à transporter')));
      expect(find.text('Avec vos 3 trajets actifs'), findsOneWidget);
    });

    testWidgets('un seul résultat et un seul trajet : accord au singulier', (
      tester,
    ) async {
      prSearchState = PackageRequestSearchState(
        status: SearchStatus.loaded,
        results: [_makeRequest('r-1')],
        matchingMyTrips: true,
      );
      await pumpHome(tester, activeTrips: 1);
      await ouvrirListe(tester);

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();

      expect(titreListe(tester), '1 colis compatible');
      expect(sousTitreListe(tester), 'Avec votre trajet actif');
    });

    testWidgets('filtre inactif : l\'en-tête reste celui des demandes', (
      tester,
    ) async {
      prSearchState = PackageRequestSearchState(
        status: SearchStatus.loaded,
        results: [_makeRequest('r-1')],
      );
      await pumpHome(tester, activeTrips: 3);

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();

      expect(titreListe(tester), contains('colis à transporter'));
      expect(titreListe(tester), isNot(contains('compatible')));
    });
  });

  // ─── « Pour mes trajets » actif d'office ────────────────────────────────────
  group('« Pour mes trajets » par défaut', () {
    Future<void> versColis(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();
    }

    Future<void> basculerPastilleDansLeComposeur(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('corridor-bar')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const Key('chip-matching-my-trips')),
        find.byType(Scrollable).first,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();
    }

    testWidgets("trajet actif : le mode Colis s'ouvre filtré et trace "
        'source « default »', (tester) async {
      await pumpHome(tester, activeTrips: 3);
      await versColis(tester);

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
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: {'active': true, 'active_trips': 3, 'source': 'default'},
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.searchFilterApplied,
          properties: {'filter': 'matching_my_trips', 'mode': 'parcels'},
        ),
      ).called(1);
    });

    testWidgets("aucun trajet actif : pas d'activation d'office", (
      tester,
    ) async {
      await pumpHome(tester, activeTrips: 0);
      await versColis(tester);

      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: any(named: 'properties'),
        ),
      );
    });

    testWidgets("nombre de trajets inconnu : pas d'activation d'office", (
      tester,
    ) async {
      await pumpHome(tester, summaryState: const TripsSummaryState.hidden());
      await versColis(tester);

      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: any(named: 'properties'),
        ),
      );
    });

    testWidgets("refus mémorisé : le mode Colis s'ouvre sans filtre", (
      tester,
    ) async {
      matchingStore.out = true;
      await pumpHome(tester, activeTrips: 3);
      await versColis(tester);

      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: any(named: 'properties'),
        ),
      );
    });

    testWidgets('retirer la pastille mémorise le refus', (tester) async {
      await pumpHome(tester, activeTrips: 3);
      await versColis(tester);
      expect(matchingStore.out, isFalse);

      // Le filtre est actif d'office : un tap le retire.
      await basculerPastilleDansLeComposeur(tester);

      expect(matchingStore.out, isTrue);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: {'active': false, 'active_trips': 3, 'source': 'user'},
        ),
      ).called(1);
    });

    testWidgets('reposer la pastille lève le refus', (tester) async {
      matchingStore.out = true;
      await pumpHome(tester, activeTrips: 3);
      await versColis(tester);

      await basculerPastilleDansLeComposeur(tester);

      expect(matchingStore.out, isFalse);
    });
  });

  // ─── Ouverture depuis l'écran de succès d'un trajet ─────────────────────────
  group('intention « colis pour mes trajets »', () {
    testWidgets("en attente à l'ouverture : mode Colis, filtre posé, "
        'intention consommée', (tester) async {
      // Un refus mémorisé n'empêche pas une demande explicite.
      matchingStore.out = true;
      final notifier = PendingSearchNotifier()..setPendingParcelsForMyTrips();
      getIt.registerSingleton<PendingSearchNotifier>(notifier);

      await pumpHome(tester);
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
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: {'active': true, 'source': 'success_screen'},
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.homeSearchModeChanged,
          properties: {'mode': 'parcels'},
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.searchFilterApplied,
          properties: {'filter': 'matching_my_trips', 'mode': 'parcels'},
        ),
      ).called(1);
      expect(notifier.hasParcelsForMyTrips, isFalse);
      // La demande explicite ne touche pas au refus mémorisé.
      expect(matchingStore.out, isTrue);
    });

    testWidgets("posée après l'ouverture : l'accueil déjà monté la prend en "
        'compte', (tester) async {
      final notifier = PendingSearchNotifier();
      getIt.registerSingleton<PendingSearchNotifier>(notifier);
      await pumpHome(tester);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: any(named: 'properties'),
        ),
      );

      notifier.setPendingParcelsForMyTrips();
      await tester.pumpAndSettle();

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: {'active': true, 'source': 'success_screen'},
        ),
      ).called(1);
      expect(notifier.hasParcelsForMyTrips, isFalse);
    });
  });

  // ─── Rôle voyageur universel ────────────────────────────────────────────────
  //
  // Tout compte porte SENDER + TRAVELER dès l'inscription et ne peut plus en
  // perdre un (le self-service de désactivation a été retiré : il permettait
  // à un compte de perdre TRAVELER sans aucun moyen, côté app, de le
  // réactiver). Le mode Colis n'est donc plus jamais bloqué, quel que soit
  // `isTraveler` — conservé ici en paramètre de test uniquement pour prouver
  // que l'absence de TRAVELER dans `roles` ne change plus rien à l'UI.
  group('mode Colis sans distinction de rôle', () {
    testWidgets('le tap bascule normalement, avec ou sans TRAVELER', (
      tester,
    ) async {
      await pumpHome(tester, isTraveler: false);
      await ouvrirListe(tester);

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();

      expect(find.text('Ouvrir les réglages'), findsNothing);
      expect(titreListe(tester), contains('colis à transporter'));
    });

    MockPackageRequestRepository enregistrerCompteurColis() {
      final repo = MockPackageRequestRepository();
      when(
        () => repo.search(
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
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer(
        (_) async => const PackageRequestSearchPage(
          content: [],
          totalElements: 7,
          page: 0,
          size: 1,
        ),
      );
      getIt.registerSingleton<PackageRequestRepository>(repo);
      return repo;
    }

    testWidgets('le comptage de l\'autre mode part, avec ou sans TRAVELER', (
      tester,
    ) async {
      final repo = enregistrerCompteurColis();
      await pumpHome(tester, isTraveler: false);

      await ouvrirSheetEtSaisirCorridor(tester, 'Paris', 'Dakar');

      verify(
        () => repo.search(
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
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  // ─── Routage des deux garde-fous ────────────────────────────────────────────
  group('garde-fous : routage', () {
    testWidgets('« Publier un trajet » ouvre la création de trajet', (
      tester,
    ) async {
      _registerTripsSummary(0);
      final visited = <String>[];
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildHomeStubRoutes(
          visited: visited,
          user: _makeUser(roles: const ['SENDER', 'TRAVELER']),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('corridor-bar')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const Key('chip-matching-my-trips')),
        find.byType(Scrollable).first,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Publier un trajet'));
      await tester.pumpAndSettle();

      expect(visited, contains('/trips/create'));
    });

    testWidgets(
      'publier un trajet puis revenir recharge le résumé des trajets',
      (tester) async {
        // Scénario nominal du garde-fou : aucun trajet actif, l'utilisateur en
        // publie un. Au retour, le résumé doit être rechargé, sinon la pastille
        // resterait grisée avec « Aucun trajet actif » alors que c'est faux.
        final summary = _registerTripsSummary(0);
        final visited = <String>[];
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildHomeStubRoutes(
            visited: visited,
            user: _makeUser(roles: const ['SENDER', 'TRAVELER']),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));

        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('corridor-bar')));
        await tester.pumpAndSettle();
        await tester.dragUntilVisible(
          find.byKey(const Key('chip-matching-my-trips')),
          find.byType(Scrollable).first,
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Publier un trajet'));
        await tester.pumpAndSettle();

        expect(visited, contains('/trips/create'));
        // Un seul chargement jusqu'ici : celui de la création de l'écran.
        // `verify` consomme les appels enregistrés, le suivant ne comptera
        // donc que ceux d'après le retour.
        verify(() => summary.load()).called(1);

        // Retour de la création de trajet.
        await tester.tap(find.text('STUB /trips/create'));
        await tester.pumpAndSettle();

        verify(() => summary.load()).called(1);
      },
    );
  });

  group('alerte depuis la recherche', () {
    testWidgets('0 résultat sur un corridor : « M\'alerter » est proposé', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: const []);
      tester.view.physicalSize = const Size(1000, 2400);
      await tester.pump();
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');
      await ouvrirListe(tester);

      final tile = find.byKey(const Key('alert-for-search'));
      expect(tile, findsOneWidget);
      final label = tester
          .widget<Text>(find.descendant(of: tile, matching: find.byType(Text)))
          .data!;
      expect(label, contains('trajet'));
      expect(label, contains('Lyon → Bamako'));
      expect(label, isNot(contains('—')));
    });

    testWidgets('sans corridor complet, rien n\'est proposé', (tester) async {
      await pumpHome(tester, tripResults: const []);
      expect(find.byKey(const Key('alert-for-search')), findsNothing);
    });

    testWidgets('un invité ne voit pas la proposition', (tester) async {
      await pumpHome(
        tester,
        tripResults: const [],
        authState: const AuthGuestSessionReady(),
      );
      tester.view.physicalSize = const Size(1000, 2400);
      await tester.pump();
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');
      expect(find.byKey(const Key('alert-for-search')), findsNothing);
    });
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
      await ouvrirListe(tester);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      expect(find.byKey(const Key('cross-discovery')), findsOneWidget);
      expect(
        labelTuile(tester),
        '5 colis cherchent un voyageur sur Lyon → Bamako',
      );
      // Jamais de tiret cadratin dans un texte affiché.
      expect(labelTuile(tester), isNot(contains('—')));
    });

    testWidgets('la cible tactile fait au moins 44 points de haut', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 5);
      await ouvrirListe(tester);
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
      await ouvrirListe(tester);

      // Fenêtre agrandie après coup pour garder la tuile de découverte
      // croisée dans le viewport (pumpHome fixe systématiquement 1000×2000,
      // écraser avant n'aurait aucun effet).
      tester.view.physicalSize = const Size(1000, 2400);
      await tester.pump();

      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      await tester.tap(find.byKey(const Key('cross-discovery')));
      await tester.pumpAndSettle();

      expect(titreListe(tester), contains('colis à transporter'));
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
      await ouvrirListe(tester);

      expect(
        labelTuile(tester),
        '1 colis cherche un voyageur sur Lyon → Bamako',
      );
    });

    testWidgets('ville de départ seule : suffixe « au départ de Lyon »', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 5);
      await ouvrirListe(tester);

      await tester.tap(find.byKey(const Key('corridor-bar-sheet')));
      await tester.pumpAndSettle();
      await _choisirVille(tester, const Key('composer-departure-city'), 'Lyon');
      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cross-discovery')), findsOneWidget);
      expect(
        labelTuile(tester),
        '5 colis cherchent un voyageur au départ de Lyon',
      );
      // Jamais de tiret cadratin dans un texte affiché.
      expect(labelTuile(tester), isNot(contains('—')));
    });

    testWidgets('ville d\'arrivée seule : suffixe « vers Bamako »', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 5);

      await tester.tap(find.byKey(const Key('corridor-bar')));
      await tester.pumpAndSettle();
      await _choisirVille(tester, const Key('composer-arrival-city'), 'Bamako');
      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();
      await ouvrirListe(tester);

      expect(find.byKey(const Key('cross-discovery')), findsOneWidget);
      expect(labelTuile(tester), '5 colis cherchent un voyageur vers Bamako');
      // Jamais de tiret cadratin dans un texte affiché.
      expect(labelTuile(tester), isNot(contains('—')));
    });

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
        await ouvrirListe(tester);

        expect(find.byKey(const Key('cross-discovery')), findsOneWidget);
        expect(labelTuile(tester), '5 colis cherchent un voyageur');
        expect(labelTuile(tester), isNot(contains('→')));
        expect(labelTuile(tester), isNot(contains('Tous les trajets')));
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
          gpProOnly: any(named: 'gpProOnly'),
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
      await ouvrirListe(tester);

      await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
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
            gpProOnly: any(named: 'gpProOnly'),
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

        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
        await tester.pumpAndSettle();
        await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');
        await ouvrirListe(tester);

        expect(labelTuile(tester), '1 voyageur passe sur Lyon → Bamako');
      },
    );
  });

  group('état vide au-dessus de la pastille « Carte »', () {
    testWidgets(
      'feuille plein écran, 0 trajet : l\'état vide réserve la zone des '
      'contrôles flottants et son bouton reste au-dessus de « Carte »',
      (tester) async {
        await pumpHome(tester, tripResults: const [], otherModeCount: 0);
        await ouvrirSheetEtSaisirCorridor(tester, 'Abidjan', 'Usangi');

        // La liste plein écran : la pastille « Carte » prend la place de
        // « Liste ».
        await ouvrirListe(tester);
        expect(find.text('Aucun voyageur avec ces filtres'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        // Même marge que les listes : l'état vide s'arrête au-dessus de la
        // pastille et de la barre flottante (recette Redmi, bouton « Effacer
        // les filtres » caché sous « Carte »).
        final marge = tester.widget<SliverPadding>(
          find
              .ancestor(
                of: find.byType(SliverFillRemaining),
                matching: find.byType(SliverPadding),
              )
              .first,
        );
        expect(
          marge.padding.resolve(TextDirection.ltr).bottom,
          greaterThanOrEqualTo(96),
        );

        final bouton = tester.getRect(find.text('Effacer les filtres'));
        final pastille = tester.getRect(find.text('Carte'));
        expect(bouton.bottom, lessThan(pastille.top));
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
            gpProOnly: any(named: 'gpProOnly'),
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
        await ouvrirListe(tester);

        // Mode Colis : autre mode (Trajets) à 0 via le mock ci-dessus →
        // aucune tuile de découverte croisée, donc rien ne masque le bouton.
        await tester.tap(find.byKey(const Key('search_mode_segment_colis')));
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
      await tester.pumpWidget(_buildHome(favCubit: _makeFavCubit()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('favorites-badge')), findsNothing);
    });

    testWidgets('shows badge with count when favorites count > 0', (
      tester,
    ) async {
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
      when(
        () => announcementBloc.stream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => authBloc.state).thenReturn(AuthAuthenticated(_makeUser()));
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
          _helpCenterProvider(),
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
          theme: AppTheme.light(),
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

    testWidgets('un invité accède aux favoris sans feuille d\'inscription', (
      tester,
    ) async {
      // Les favoris sont le seul contenu qu'un visiteur peut conserver :
      // le bouton ne doit plus présenter d'`AuthRequiredSheet` (Task 7).
      final visited = <String>[];
      final favCubit = _makeFavCubit(count: 1);
      final announcementBloc = MockAnnouncementBloc();
      final authBloc = MockAuthBloc();
      final roleCubit = MockActiveRoleCubit();
      final notifBloc = MockNotificationBloc();
      final bidBloc = MockBidBloc();

      when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
      when(
        () => announcementBloc.stream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => authBloc.state).thenReturn(const AuthGuestSessionReady());
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
          _helpCenterProvider(),
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
          theme: AppTheme.light(),
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

      expect(find.text('Connexion requise'), findsNothing);
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
    // FLUTTER-7X : la cloche se fiait à AuthBloc.currentUser, nul tant que le
    // profil n'est pas chargé (AuthLoading, AuthError) ; un utilisateur bien
    // connecté voyait alors « Connexion requise ».
    testWidgets(
      'profil non chargé mais session réelle : la cloche ne demande pas de se connecter',
      (tester) async {
        await tester.pumpWidget(
          _buildHome(
            authState: const AuthLoading(),
            notificationState: const NotificationLoaded(
              notifications: [],
              unreadCount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bell'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connexion requise'), findsNothing);
      },
    );

    testWidgets('un invité qui touche la cloche voit « Connexion requise »', (
      tester,
    ) async {
      getIt.unregister<FirebaseSessionProbe>();
      getIt.registerSingleton<FirebaseSessionProbe>(
        const _StubSessionProbe.guest(),
      );
      await tester.pumpWidget(
        _buildHome(
          authState: const AuthGuestSessionReady(),
          notificationState: const NotificationLoaded(
            notifications: [],
            unreadCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bell'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connexion requise'), findsOneWidget);
    });

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

  // ── FLUTTER-B8 : bouton rond « + Publier » de la rangée du haut ─────────
  group('HomeScreen — bouton « + Publier »', () {
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    final publish = find.byKey(const Key('home-publish-button'));
    final corridor = find.byKey(const Key('corridor-bar'));
    final bell = find.byWidgetPredicate(
      (w) => w is DonyIcon && w.name == 'bell',
    );

    testWidgets('posé entre la barre de recherche et la cloche, une seule '
        'fois, jamais sur la carte ni la feuille', (tester) async {
      await pumpAt(tester, const Size(430, 932));

      expect(publish, findsOneWidget);
      final publishCenter = tester.getCenter(publish);
      expect(publishCenter.dx, greaterThan(tester.getCenter(corridor).dx));
      expect(publishCenter.dx, lessThan(tester.getCenter(bell).dx));
      // Même ligne que la cloche : la rangée flottante du haut.
      expect((publishCenter.dy - tester.getCenter(bell).dy).abs(), lessThan(1));
      // L'ancien bouton flottant de #440 ne revient pas.
      expect(find.byKey(const Key('home-publish-parcel')), findsNothing);
      expect(tester.getSize(publish), const Size(48, 48));
    });

    testWidgets('ouvre la feuille aux deux choix', (tester) async {
      await pumpAt(tester, const Size(430, 932));

      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(find.text('Que voulez-vous publier ?'), findsOneWidget);
      expect(find.text('Envoyer un colis'), findsOneWidget);
      expect(find.text('Publier un trajet'), findsOneWidget);
    });

    testWidgets('invité : « Connexion requise », comme la cloche', (
      tester,
    ) async {
      getIt.unregister<FirebaseSessionProbe>();
      getIt.registerSingleton<FirebaseSessionProbe>(
        const _StubSessionProbe.guest(),
      );
      await pumpAt(tester, const Size(430, 932));

      await tester.tap(publish);
      await tester.pumpAndSettle();

      expect(find.text('Connexion requise'), findsOneWidget);
      expect(find.text('Que voulez-vous publier ?'), findsNothing);
    });

    for (final width in [320.0, 375.0]) {
      testWidgets('petit écran ($width dp) : rangée resserrée, sans '
          'débordement, barre de recherche lisible', (tester) async {
        await pumpAt(tester, Size(width, 667));

        expect(tester.takeException(), isNull);
        expect(publish, findsOneWidget);
        expect(tester.getSize(publish), const Size(44, 44));
        // Le trajet recherché garde une vraie place à côté de 3 boutons.
        expect(tester.getSize(corridor).width, greaterThanOrEqualTo(150));
        expect(tester.getRect(bell).right, lessThanOrEqualTo(width));
        // La loupe ne tombe que sur l'écran le plus étroit.
        expect(
          find.descendant(
            of: corridor,
            matching: find.byWidgetPredicate(
              (w) => w is DonyIcon && w.name == 'search',
            ),
          ),
          width < 330 ? findsNothing : findsOneWidget,
        );
      });
    }

    testWidgets('320 dp, texte à 130 % : toujours sans débordement', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpAt(tester, const Size(320, 667));

      expect(tester.takeException(), isNull);
      expect(publish, findsOneWidget);
    });
  });

  // ── Réaction aux blocages ────────────────────────────────────────────────
  group('HomeScreen — blocages', () {
    late BlockEventsService blockEvents;

    setUp(() {
      blockEvents = BlockEventsService();
      getIt.registerSingleton<BlockEventsService>(blockEvents);
    });

    tearDown(() => blockEvents.dispose());

    testWidgets('un blocage relance la recherche de trajets', (tester) async {
      final announcementBloc = MockAnnouncementBloc();
      await tester.pumpWidget(
        _buildHome(announcementBlocOverride: announcementBloc),
      );
      await tester.pump(const Duration(milliseconds: 1000));

      // Une seule recherche au montage avant l'événement.
      verify(
        () =>
            announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())),
      ).called(1);

      blockEvents.notifyBlocked('traveler-1');
      await tester.pump(const Duration(milliseconds: 50));

      verify(
        () =>
            announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())),
      ).called(1);
    });

    testWidgets('un déblocage relance aussi la recherche', (tester) async {
      final announcementBloc = MockAnnouncementBloc();
      await tester.pumpWidget(
        _buildHome(announcementBlocOverride: announcementBloc),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      verify(
        () =>
            announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())),
      ).called(1);

      blockEvents.notifyUnblocked('traveler-1');
      await tester.pump(const Duration(milliseconds: 50));

      verify(
        () =>
            announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())),
      ).called(1);
    });
  });

  // ── Feuille « Date de départ » (_DatePresetSheet) ─────────────────────────
  //
  // K3 : la date choisie via le calendrier s'affiche dans l'option de la
  // feuille selon l'ordre de la langue (motif fixe 'EEE d MMM' en fr,
  // squelette MMMEd en en). Le calendrier est désormais celui d'une période :
  // un seul jour reste affiché comme avant, une période « début → fin ».
  group('feuille de date personnalisée', () {
    setUpAll(() async {
      await initializeDateFormatting('fr');
      await initializeDateFormatting('en');
    });

    // Jour à [n] jours d'aujourd'hui, sans `Duration` (changement d'heure).
    DateTime inDays(int n) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day + n);
    }

    // Ouvre la feuille puis le calendrier de période, et saisit les bornes
    // au clavier : indépendant du jour où tourne le test (le calendrier
    // affiche plusieurs mois, un numéro de jour y est ambigu).
    Future<void> choisirPeriode(
      WidgetTester tester, {
      required String choisirLabel,
      required DateTime start,
      required DateTime end,
    }) async {
      await tester.tap(find.byKey(const Key('chip-date')));
      await tester.pumpAndSettle();

      await tester.tap(find.text(choisirLabel));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      final loc = MaterialLocalizations.of(
        tester.element(find.byType(DateRangePickerDialog)),
      );
      await tester.tap(find.byTooltip(loc.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), loc.formatCompactDate(start));
      await tester.enterText(fields.at(1), loc.formatCompactDate(end));
      await tester.tap(find.text(loc.okButtonLabel));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'fr non-régression : un seul jour au motif EEE d MMM inchangé',
      (tester) async {
        await pumpHome(tester);
        final date = inDays(1);
        await choisirPeriode(
          tester,
          choisirLabel: 'Choisir une période',
          start: date,
          end: date,
        );

        expect(
          find.textContaining(DateFormat('EEE d MMM', 'fr').format(date)),
          findsOneWidget,
        );
      },
    );

    testWidgets('en anglais : un seul jour dans l\'ordre anglais', (
      tester,
    ) async {
      useEnglish();
      await pumpHome(tester);
      final date = inDays(1);
      await choisirPeriode(
        tester,
        choisirLabel: 'Choose a period',
        start: date,
        end: date,
      );

      expect(
        find.textContaining(DateFormat.MMMEd('en').format(date)),
        findsOneWidget,
      );
    });

    testWidgets(
      'une période : option et puce « début → fin », recherche bornée',
      (tester) async {
        final bloc = MockAnnouncementBloc();
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _buildHome(
            announcementBlocOverride: bloc,
            user: _makeUser(roles: const ['SENDER', 'TRAVELER']),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));

        final start = inDays(3);
        final end = inDays(40);
        await choisirPeriode(
          tester,
          choisirLabel: 'Choisir une période',
          start: start,
          end: end,
        );
        final label = formatSearchPeriod(start, end, 'fr', withWeekday: true);
        expect(find.text(label), findsOneWidget);

        await tester.tap(find.text('Appliquer'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(const Key('chip-date')),
            matching: find.text(formatSearchPeriod(start, end, 'fr')),
          ),
          findsOneWidget,
        );
        final last = verify(
          () => bloc.add(captureAny()),
        ).captured.whereType<AnnouncementSearchRequested>().last;
        expect(last.departureDateFrom, start);
        expect(last.departureDateTo, end);
      },
    );
  });

  // FLUTTER-CD : « 17 voyageurs disponibles » au-dessus d'une carte vide, la
  // feuille repliée tout en bas : un nouvel utilisateur croyait que rien ne
  // chargeait. La carte est désormais plein écran, la liste à un tap de
  // pastille « Liste », et le bouton de localisation juste au-dessus d'elle.
  group('carte plein écran et pastille « Liste »', () {
    testWidgets('la carte est plein écran : aucune feuille, barre de recherche '
        'visible, pastille « Liste » centrée en bas', (tester) async {
      await pumpHome(
        tester,
        tripResults: [
          _makeAnn(),
          _makeAnn(id: 'a2'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-sheet')), findsNothing);
      expect(find.byKey(const Key('corridor-bar')), findsOneWidget);
      final ecran = tester.view.physicalSize / tester.view.devicePixelRatio;
      final pastille = tester.getRect(find.byKey(const Key('home-list-pill')));
      expect(pastille.center.dx, closeTo(ecran.width / 2, 1));
      expect(pastille.bottom, lessThan(ecran.height));
      expect(pastille.height, 44);
    });

    testWidgets('le bouton de localisation se pose au-dessus de la pastille', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: [_makeAnn()]);
      await tester.pumpAndSettle();

      final fab = tester.getRect(find.byKey(const Key('near-me-fab')));
      final pastille = tester.getRect(find.byKey(const Key('home-list-pill')));
      expect(fab.bottom, lessThanOrEqualTo(pastille.top));
      expect(fab.right, greaterThan(pastille.right));
    });

    testWidgets('la carte-résumé s\'ouvre au-dessus de la pastille et le '
        'bouton de localisation la surmonte', (tester) async {
      await pumpHome(tester, tripResults: [_makeAnn()]);
      await tester.pumpAndSettle();

      tester
          .widget<AnnouncementMapView>(find.byType(AnnouncementMapView))
          .onAnnouncementSelected!('a1');
      await tester.pumpAndSettle();

      final resume = tester.getRect(find.byKey(const Key('map-trip-summary')));
      final pastille = tester.getRect(find.byKey(const Key('home-list-pill')));
      final fab = tester.getRect(find.byKey(const Key('near-me-fab')));
      expect(resume.bottom, lessThanOrEqualTo(pastille.top));
      expect(fab.bottom, lessThanOrEqualTo(resume.top));
    });

    testWidgets('pendant le chargement, la carte reste plein écran', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementLoading()),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home-sheet')), findsNothing);
      expect(find.byKey(const Key('home-list-pill')), findsOneWidget);
    });

    testWidgets('sans résultat, l\'état vide s\'affiche dans la liste', (
      tester,
    ) async {
      await pumpHome(tester, tripResults: const []);
      await tester.pumpAndSettle();
      expect(find.text('Aucun voyageur sur ce trajet'), findsNothing);

      await ouvrirListe(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Aucun voyageur sur ce trajet'), findsOneWidget);
    });

    testWidgets('la liste plein écran couvre tout l\'écran', (tester) async {
      await pumpHome(tester, tripResults: [_makeAnn()]);
      await ouvrirListe(tester);

      expect(
        tester.getTopLeft(find.byKey(const Key('home-sheet'))).dy,
        lessThan(1),
      );
      expect(
        find.byKey(const Key('home-list-pill')).hitTestable(),
        findsNothing,
      );
    });

    testWidgets('paysage : aucune erreur d\'affichage sur la carte', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(820, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded([_makeAnn()])),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home-list-pill')), findsOneWidget);
    });
  });

  group('cartes d\'état vide sur la carte', () {
    testWidgets('Près de moi sans voyageur : message, « Élargir à 50 km » et '
        '« Désactiver »', (tester) async {
      GeolocatorPlatform.instance = _MockGeolocatorPlatform();
      await tester.pumpWidget(
        _buildHome(announcementState: AnnouncementSearchLoaded(const [])),
      );
      await tester.pump();

      await activerPresDeMoi(tester);

      expect(find.byKey(const Key('map-near-me-empty')), findsOneWidget);
      expect(find.text('Aucun voyageur à proximité'), findsOneWidget);
      expect(find.text('Élargir à 50 km'), findsOneWidget);

      await tester.tap(find.text('Élargir à 50 km'));
      await tester.pumpAndSettle();
      expect(find.text('Rayon · 50 km'), findsOneWidget);

      await tester.tap(find.text('Désactiver « Près de moi »'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('near-me-radius-pill')), findsNothing);
    });

    testWidgets('zone visible sans trajet : « Voir tous les trajets » recadre '
        'la carte', (tester) async {
      await pumpHome(tester, tripResults: [_makeAnn()]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-zone-empty')), findsNothing);

      tester
          .widget<AnnouncementMapView>(find.byType(AnnouncementMapView))
          .onZoneEmptyChanged!(true);
      await tester.pumpAndSettle();

      expect(find.text('Aucun trajet dans cette zone'), findsOneWidget);
      final avant = tester
          .widget<AnnouncementMapView>(find.byType(AnnouncementMapView))
          .fitAllSignal;

      await tester.tap(find.text('Voir tous les trajets'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-zone-empty')), findsNothing);
      expect(
        tester
            .widget<AnnouncementMapView>(find.byType(AnnouncementMapView))
            .fitAllSignal,
        avant + 1,
      );
    });
  });
}
