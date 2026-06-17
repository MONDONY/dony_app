import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:hive/hive.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
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

class MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class MockHiveService extends Mock implements HiveService {}

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

AnnouncementModel _makeAnn({String id = 'a1'}) => AnnouncementModel(
  id: id,
  travelerId: 'traveler-1',
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

Widget _buildHome({
  AnnouncementState? announcementState,
  ActiveRole role = ActiveRole.sender,
  UserModel? user,
  BidState? bidState,
  NotificationState? notificationState,
  MockBidBloc? bidBloc,
}) {
  final announcementBloc = MockAnnouncementBloc();
  final authBloc = MockAuthBloc();
  final roleCubit = MockActiveRoleCubit();
  final notifBloc = MockNotificationBloc();
  final effectiveBidBloc = bidBloc ?? MockBidBloc();

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

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() {
    final hive = MockHiveService();
    final box = _FakeBox();
    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => hive.listenUserPrefs(keys: any(named: 'keys')),
    ).thenReturn(ValueNotifier<Box>(box));
    getIt.registerSingleton<HiveService>(hive);

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
      'traveler near-me dispatches the package-request search with a radius',
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

        // Phase 1 : isTraveler est lu depuis le UserModel (capacité réelle),
        // pas depuis ActiveRoleCubit. Il faut donc un utilisateur avec le rôle TRAVELER.
        await tester.pumpWidget(
          _buildHome(
            role: ActiveRole.traveler,
            user: _makeUser(roles: const ['SENDER', 'TRAVELER']),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('near-me-fab')));
        await tester.pumpAndSettle();

        // Traveler near-me drives the package-request search (radius applied).
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
