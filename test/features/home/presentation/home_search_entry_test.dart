// Tests d'entrée de l'onglet Rechercher (Task 5).
//
// Ce que le brief demandait littéralement ne compile pas tel quel (un
// `_HomeHarness` jamais défini, un libellé « Où envoyez-vous ? » qui
// supposerait de refondre la barre corridor en barre de recherche — un
// changement visuel plus large que le périmètre de cette tâche, qui est le
// BRANCHEMENT : déclarer la route, remplacer l'ouverture de l'ancienne
// feuille de filtres par l'ouverture du nouvel écran, retirer le code mort).
//
// Ce fichier vérifie donc le contrat réellement livré : la barre corridor de
// l'onglet Rechercher ouvre `SearchComposerScreen` (et non plus l'ancienne
// `SearchFilterSheet`, supprimée), et les filtres qu'on y valide reviennent
// bien appliqués à l'écran d'accueil.

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
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
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/data/repositories/search_parse_repository.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/home/presentation/screens/search_composer_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_recent_city_store.dart';

const _emptyHelpConfigJson = '''
{"schemaVersion": 1, "socialLinks": [], "tutorials": []}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);
  final String json;
  @override
  String get activatedJson => json;
  @override
  Future<String?> fetchAndActivate() async => json;
}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

class MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class MockFavoriteIdsCubit extends MockCubit<FavoriteIdsState>
    implements FavoriteIdsCubit {}

class MockTripsSummaryCubit extends MockCubit<TripsSummaryState>
    implements TripsSummaryCubit {}

class MockPackageRequestSearchBloc
    extends MockBloc<PackageRequestSearchEvent, PackageRequestSearchState>
    implements PackageRequestSearchBloc {}

class MockHiveService extends Mock implements HiveService {}

class MockCityRepository extends Mock implements CityRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

class MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

class MockSearchParseRepository extends Mock implements SearchParseRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

class _FakeBidEvent extends Fake implements BidEvent {}

class _FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

class _FakeBox extends Fake implements Box<dynamic> {
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) => defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {}
}

UserModel _makeUser() => const UserModel(
  id: 'uid-1',
  phoneNumber: '+33600000000',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  roles: ['SENDER', 'TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

/// Route `/recherche/composer` de test, même contrat que celle de
/// `lib/app/router.dart`. `SearchComposerBloc` est construit directement avec
/// des mocks non stubés (comme `search_composer_screen_test.dart`) : sans
/// stub, `_refreshCount` avale l'échec (`MissingStubError`), le compteur du
/// bouton « Rechercher » reste simplement absent.
GoRoute _composerRoute() => GoRoute(
  path: '/recherche/composer',
  builder: (context, state) {
    final extra = state.extra as Map? ?? {};
    final mode = (extra['mode'] as SearchMode?) ?? SearchMode.trips;
    final filters =
        (extra['filters'] as HomeSearchFilters?) ?? const HomeSearchFilters();
    return BlocProvider(
      create: (_) => SearchComposerBloc(
        MockSearchParseRepository(),
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

Widget _buildHome() {
  final announcementBloc = MockAnnouncementBloc();
  final authBloc = MockAuthBloc();
  final roleCubit = MockActiveRoleCubit();
  final notifBloc = MockNotificationBloc();
  final bidBloc = MockBidBloc();
  final favCubit = MockFavoriteIdsCubit();

  when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
  when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => authBloc.state).thenReturn(AuthAuthenticated(_makeUser()));
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

  final providers = MultiBlocProvider(
    providers: [
      BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
      BlocProvider<NotificationBloc>.value(value: notifBloc),
      BlocProvider<BidBloc>.value(value: bidBloc),
      BlocProvider<FavoriteIdsCubit>.value(value: favCubit),
      BlocProvider<HelpCenterBloc>(
        create: (_) => HelpCenterBloc(
          HelpCenterRepository(
            const _StaticHelpCenterSource(_emptyHelpConfigJson),
            fallbackJsonLoader: () async => _emptyHelpConfigJson,
          ),
          getIt<AnalyticsService>(),
        )..add(const HelpCenterLoadRequested()),
      ),
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
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr'), Locale('en')],
    locale: const Locale('fr'),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(_FakeAnnouncementEvent());
    registerFallbackValue(StatsPeriod.thirtyDays);
    registerCityFallbackValues();
  });

  setUp(() {
    final hive = MockHiveService();
    final box = _FakeBox();
    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => hive.listenUserPrefs(keys: any(named: 'keys')),
    ).thenReturn(ValueNotifier<Box>(box));
    getIt.registerSingleton<HiveService>(hive);

    final analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<AnalyticsService>(analytics);

    // La ville saisie dans le champ OÙ du composer redescend en suggestion
    // exacte : les sélections de ville sont déterministes.
    final cityRepo = MockCityRepository();
    when(() => cityRepo.searchCities(any())).thenAnswer(
      (inv) async => [
        CityModel(
          name: inv.positionalArguments.first as String,
          countryCode: 'ML',
          countryName: 'Mali',
          lat: 12.65,
          lng: -8.0,
        ),
      ],
    );
    when(() => cityRepo.getPopularCorridors()).thenAnswer((_) async => []);
    getIt.registerSingleton<CityRepository>(cityRepo);
    getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));
    getIt.registerFactory<IContentCategoryRepository>(
      () => _FakeContentCategoryRepository(),
    );
    registerFakeRecentCityStore();

    final summary = MockTripsSummaryCubit();
    const summaryState = TripsSummaryState.loaded(
      TripsSummaryModel(activeTrips: 2, kgSold: 0, revenue: 0),
    );
    when(() => summary.state).thenReturn(summaryState);
    whenListen(
      summary,
      const Stream<TripsSummaryState>.empty(),
      initialState: summaryState,
    );
    when(
      () => summary.load(period: any(named: 'period')),
    ).thenAnswer((_) async {});
    getIt.registerFactory<TripsSummaryCubit>(() => summary);

    const prState = PackageRequestSearchState();
    getIt.registerFactory<PackageRequestSearchBloc>(() {
      final mock = MockPackageRequestSearchBloc();
      when(() => mock.state).thenReturn(prState);
      whenListen(
        mock,
        Stream<PackageRequestSearchState>.fromIterable([prState]),
        initialState: prState,
      );
      return mock;
    });
  });

  tearDown(getIt.reset);

  testWidgets('la barre corridor est visible sur l onglet Rechercher', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHome());
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.byKey(const Key('corridor-bar')), findsOneWidget);
    expect(find.text('Tous les corridors'), findsWidgets);
  });

  testWidgets(
    'les filtres validés dans l écran de composition reviennent appliqués',
    (tester) async {
      await tester.pumpWidget(_buildHome());
      await tester.pump(const Duration(milliseconds: 1000));

      // La barre ouvre l'écran de composition, plus l'ancienne feuille :
      // preuve que le branchement (Task 5) fonctionne.
      await tester.tap(find.byKey(const Key('corridor-bar')));
      await tester.pumpAndSettle();

      expect(find.byType(SearchComposerScreen), findsOneWidget);
      expect(find.text('Filtrer les trajets'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('composer-arrival-city')),
        'Bamako',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Bamako').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();

      // L'écran de composition s'est fermé et a rendu la main à l'accueil.
      expect(find.byType(SearchComposerScreen), findsNothing);
      // Le filtre revient bien appliqué : la barre reflète désormais
      // « Bamako » (sous forme de puce du libellé corridor).
      expect(find.textContaining('Bamako'), findsWidgets);
    },
  );
}
