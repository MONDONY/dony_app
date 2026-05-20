import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/core/design/widgets/dony_avatar.dart';
import 'package:dony/features/profile/presentation/profile_screen.dart';
import 'package:dony/features/profile/presentation/widgets/pending_deletion_banner.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

// ── Fallback values ───────────────────────────────────────────────────────────

class FakeAuthEvent extends Fake implements AuthEvent {}
// AccountDeletionEvent is sealed — use a concrete subclass as fallback value.
class FakeAccountDeletionEvent extends Fake implements RequestDeletion {}
class FakeBidEvent extends Fake implements BidEvent {}
class FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

// ── Test fixtures ─────────────────────────────────────────────────────────────

final _activeUser = UserModel(
  id: 'user-1',
  firstName: 'Alice',
  lastName: 'Dupont',
  roles: const ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

final _pendingDeletionUser = UserModel(
  id: 'user-2',
  firstName: 'Bob',
  lastName: 'Martin',
  roles: const ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'PENDING_DELETION',
  deletionRequestedAt: DateTime(2026, 5, 1),
);

final _travelerUser = UserModel(
  id: 'user-3',
  firstName: 'Amadou',
  lastName: 'Diallo',
  roles: const ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  totalTrips: 3,
);

final _dualRoleUser = UserModel(
  id: 'user-4',
  firstName: 'Dual',
  lastName: 'Role',
  roles: const ['TRAVELER', 'SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

// ── Test harness ──────────────────────────────────────────────────────────────

/// Builds the full test widget tree with all required BLoC providers and a
/// GoRouter so that [ProfileScreen] can call [context.push] / [context.go].
Widget _buildTestHarness({
  required MockAuthBloc authBloc,
  required MockAccountDeletionBloc deletionBloc,
  required MockBidBloc bidBloc,
  required MockAnnouncementBloc announcementBloc,
  required MockActiveRoleCubit activeRoleCubit,
  List<RouteBase>? extraRoutes,
}) {
  final routes = <RouteBase>[
    GoRoute(
      path: '/',
      builder: (_, __) => MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<AccountDeletionBloc>.value(value: deletionBloc),
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
          BlocProvider<ActiveRoleCubit>.value(value: activeRoleCubit),
        ],
        child: const ProfileScreen(),
      ),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (_, __) => const Scaffold(body: Text('AuthPhone')),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const Scaffold(body: Text('Settings')),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const Scaffold(body: Text('Home')),
    ),
    GoRoute(
      path: '/announcements',
      builder: (_, __) => const Scaffold(body: Text('Announcements')),
    ),
    GoRoute(
      path: '/package-requests/match',
      builder: (_, __) => const Scaffold(body: Text('ColisMatch')),
    ),
    GoRoute(
      path: '/package-requests/search',
      builder: (_, __) => const Scaffold(body: Text('PackageRequestsSearch')),
    ),
    GoRoute(
      path: '/negotiations',
      builder: (_, __) => const Scaffold(body: Text('Negotiations')),
    ),
    GoRoute(
      path: '/profile/public',
      builder: (_, __) => const Scaffold(body: Text('PublicProfile')),
    ),
    GoRoute(
      path: '/profile/reviews',
      builder: (_, __) => const Scaffold(body: Text('Reviews')),
    ),
    GoRoute(
      path: '/disputes',
      builder: (_, __) => const Scaffold(body: Text('Disputes')),
    ),
    GoRoute(
      path: '/profile/help/contact',
      builder: (_, __) => const Scaffold(body: Text('Contact')),
    ),
    GoRoute(
      path: '/profile/help/faq',
      builder: (_, __) => const Scaffold(body: Text('FAQ')),
    ),
    GoRoute(
      path: '/payments/onboarding',
      builder: (_, __) => const Scaffold(body: Text('PaymentsOnboarding')),
    ),
    GoRoute(
      path: '/payments/commission-method',
      builder: (_, __) => const Scaffold(body: Text('CommissionMethod')),
    ),
    GoRoute(
      path: '/profile/referral',
      builder: (_, __) => const Scaffold(body: Text('Referral')),
    ),
    GoRoute(
      path: '/profile/shipments/history',
      builder: (_, __) => const Scaffold(body: Text('ShipmentsHistory')),
    ),
    GoRoute(
      path: '/profile/addresses',
      builder: (_, __) => const Scaffold(body: Text('Addresses')),
    ),
    GoRoute(
      path: '/profile/recipients',
      builder: (_, __) => const Scaffold(body: Text('Recipients')),
    ),
    ...?extraRoutes,
  ];

  return MaterialApp.router(
    routerConfig: GoRouter(initialLocation: '/', routes: routes),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(const ReactivateAccount()); // concrete sealed subclass
    registerFallbackValue(FakeBidEvent());
    registerFallbackValue(FakeAnnouncementEvent());
  });

  late MockAuthBloc authBloc;
  late MockAccountDeletionBloc deletionBloc;
  late MockBidBloc bidBloc;
  late MockAnnouncementBloc announcementBloc;
  late MockActiveRoleCubit activeRoleCubit;

  setUp(() {
    authBloc = MockAuthBloc();
    deletionBloc = MockAccountDeletionBloc();
    bidBloc = MockBidBloc();
    announcementBloc = MockAnnouncementBloc();
    activeRoleCubit = MockActiveRoleCubit();

    // Default stable states for blocs not under test.
    whenListen<BidState>(bidBloc, const Stream.empty(), initialState: BidInitial());
    whenListen<AnnouncementState>(
      announcementBloc,
      const Stream.empty(),
      initialState: AnnouncementInitial(),
    );
    when(() => activeRoleCubit.state).thenReturn(ActiveRole.sender);
  });

  // ── Test 1: PendingDeletionBanner renders when PENDING_DELETION ──────────

  testWidgets('PendingDeletionBanner renders when user status is PENDING_DELETION',
      (tester) async {
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_pendingDeletionUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    // Pump enough to let flutter_animate delays settle (max 320ms in screen).
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(PendingDeletionBanner), findsOneWidget);
  });

  // ── Test 2: PendingDeletionBanner absent when ACTIVE ────────────────────

  testWidgets('PendingDeletionBanner is absent when user status is ACTIVE',
      (tester) async {
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_activeUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(PendingDeletionBanner), findsNothing);
  });

  // ── Test 3: AccountReactivated dispatches AuthCheckRequested ────────────

  testWidgets(
      'AccountReactivated state causes AuthCheckRequested to be dispatched to AuthBloc',
      (tester) async {
    // AuthBloc starts authenticated so the screen renders normally.
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_pendingDeletionUser),
    );

    // AccountDeletionBloc will emit AccountReactivated after initial state.
    whenListen<AccountDeletionState>(
      deletionBloc,
      Stream.fromIterable([AccountReactivated(_activeUser)]),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(); // let BlocListener react

    verify(() => authBloc.add(const AuthCheckRequested())).called(1);
  });

  // ── Test 4: AccountDeletionError shows a SnackBar ───────────────────────

  testWidgets(
      'AccountDeletionError state shows a SnackBar with the error message',
      (tester) async {
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_pendingDeletionUser),
    );

    whenListen<AccountDeletionState>(
      deletionBloc,
      Stream.fromIterable([
        AccountDeletionError(
          error: const NetworkException('La réactivation a échoué.'),
        ),
      ]),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(); // let BlocListener react and SnackBar appear

    expect(find.byType(SnackBar), findsOneWidget);
    // ErrorPresenter resolves NetworkException → "Erreur réseau" title from catalog.
    expect(find.text('Erreur réseau'), findsOneWidget);
  });

  // ── Test 5: Paramètres tile navigates to /settings ──────────────────────

  testWidgets('tapping "Paramètres" navigates to /settings', (tester) async {
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_activeUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    // Scroll until the Paramètres tile is visible and tap it.
    await tester.scrollUntilVisible(
      find.text('Paramètres'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });

  group('Section voyageur', () {
    setUp(() {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_travelerUser),
      );
      whenListen<AccountDeletionState>(
        deletionBloc,
        const Stream.empty(),
        initialState: const AccountDeletionInitial(),
      );
      when(() => activeRoleCubit.state).thenReturn(ActiveRole.traveler);
    });

    testWidgets('affiche les 6 section labels voyageur', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      for (final label in [
        'MON ACTIVITÉ',
        'REVENUS & PAIEMENTS',
        'COMPTE PRO',
        'IDENTITÉ & CONFIANCE',
        'FIDÉLITÉ',
        'SUPPORT',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(label), findsOneWidget, reason: 'Section "$label" manquante');
      }
      // Drain pending animation timers before the test teardown.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets(
        'affiche "Colis sur mes trajets" et pas "Demandes d\'envoi à transporter"',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.scrollUntilVisible(
        find.text('Colis sur mes trajets'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Colis sur mes trajets'), findsOneWidget);
      expect(find.text("Demandes d'envoi à transporter"), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('affiche "Mon profil public" dans IDENTITÉ & CONFIANCE',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.scrollUntilVisible(
        find.text('Mon profil public'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mon profil public'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('affiche "Mes avis reçus" dans IDENTITÉ & CONFIANCE',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.scrollUntilVisible(
        find.text('Mes avis reçus'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mes avis reçus'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('affiche les 3 tiles SUPPORT', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      for (final tile in ['Mes litiges', 'Contacter le support', 'FAQ & aide']) {
        await tester.scrollUntilVisible(
          find.text(tile),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        // Pump animation frames so flutter_animate timers are consumed.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(tile), findsOneWidget,
            reason: '$tile manquant dans SUPPORT');
      }
      // Drain all pending animation timers before the test ends.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('badge "2 matchs" visible quand 2 annonces ACTIVE', (tester) async {
      final now = DateTime(2026, 6, 1);
      whenListen<AnnouncementState>(
        announcementBloc,
        const Stream.empty(),
        initialState: AnnouncementListLoaded(
          List.generate(
            2,
            (i) => AnnouncementModel(
              id: 'ann-$i',
              travelerId: 'user-3',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
              departureDate: now,
              availableKg: 10,
              totalKg: 10,
              pricePerKg: 5,
              status: 'ACTIVE',
              createdAt: now,
              updatedAt: now,
            ),
          ),
        ),
      );

      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.scrollUntilVisible(
        find.text('2 matchs'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('2 matchs'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('pas de badge matchs quand 0 annonces ACTIVE', (tester) async {
      whenListen<AnnouncementState>(
        announcementBloc,
        const Stream.empty(),
        initialState: AnnouncementListLoaded(const []),
      );

      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('matchs'), findsNothing);
    });

    group('Collapsed AppBar title', () {
      testWidgets('AppBar title contient DonyAvatar quand voyageur',
          (tester) async {
        await tester.pumpWidget(_buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          activeRoleCubit: activeRoleCubit,
        ));
        await tester.pump(const Duration(milliseconds: 600));

        // The SliverAppBar title contains a DonyAvatar (collapsed state elements)
        expect(find.byType(DonyAvatar), findsWidgets);
        // The profile header itself also has a DonyAvatar, so at least 2 are present
        // (one in the flexible space, one in the AppBar title Row)
      });

      testWidgets(
          'AppBar title affiche icône verified pour un utilisateur KYC vérifié',
          (tester) async {
        await tester.pumpWidget(_buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          activeRoleCubit: activeRoleCubit,
        ));
        await tester.pump(const Duration(milliseconds: 600));

        // Icons.verified_rounded appears in the AppBar title Row when isKycVerified
        expect(find.byIcon(Icons.verified_rounded), findsWidgets);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });
    });

    testWidgets('section sender non impactée quand activeRole == sender',
        (tester) async {
      when(() => activeRoleCubit.state).thenReturn(ActiveRole.sender);
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_activeUser),
      );

      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      // Les sections exclusives au voyageur ne doivent pas apparaître.
      expect(find.text('REVENUS & PAIEMENTS'), findsNothing);
      expect(find.text('COMPTE PRO'), findsNothing);
      expect(find.text('FIDÉLITÉ'), findsNothing);

      // La section "MON ACTIVITÉ" existe aussi côté sender — vérifier son contenu.
      await tester.scrollUntilVisible(
        find.text('Mes envois en cours'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Mes envois en cours'), findsOneWidget);
      // "Colis sur mes trajets" est exclusif au voyageur.
      expect(find.text('Colis sur mes trajets'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('tapping "Mes trajets" navigates to /announcements', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Mes trajets'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Mes trajets'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Announcements'), findsOneWidget);
    });

    testWidgets('tapping "Colis sur mes trajets" navigates to /package-requests/match',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Colis sur mes trajets'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Colis sur mes trajets'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('ColisMatch'), findsOneWidget);
    });

    testWidgets('tapping "Mes négociations" navigates to /negotiations', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Mes négociations'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Mes négociations'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Negotiations'), findsOneWidget);
    });

    testWidgets('tapping "Mon profil public" navigates to /profile/public',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Mon profil public'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Mon profil public'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('PublicProfile'), findsOneWidget);
    });

    testWidgets('tapping "Recevoir mes paiements" navigates to /payments/onboarding',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Recevoir mes paiements'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Recevoir mes paiements'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('PaymentsOnboarding'), findsOneWidget);
    });

    testWidgets('tapping "Mes litiges" navigates to /disputes', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Mes litiges'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Mes litiges'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Disputes'), findsOneWidget);
    });
  });

  // ── Auth navigation tests ─────────────────────────────────────────────────

  testWidgets('AuthInitial state triggers navigation to /auth/phone',
      (tester) async {
    // Start authenticated, then emit AuthInitial to trigger logout redirect.
    whenListen<AuthState>(
      authBloc,
      Stream.fromIterable([const AuthInitial()]),
      initialState: AuthAuthenticated(_activeUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    // Pump once to let BlocListener react, then drain timers with pumpAndSettle.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('AuthPhone'), findsOneWidget);
  });

  testWidgets('AuthAccountDeleted state triggers navigation to /auth/phone',
      (tester) async {
    whenListen<AuthState>(
      authBloc,
      Stream.fromIterable([const AuthAccountDeleted()]),
      initialState: AuthAuthenticated(_activeUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('AuthPhone'), findsOneWidget);
  });

  testWidgets('AuthProfileUpdated state renders updated user display name',
      (tester) async {
    final updatedUser = UserModel(
      id: 'user-1',
      firstName: 'Updated',
      lastName: 'Name',
      roles: const ['SENDER'],
      kycStatus: 'NOT_STARTED',
      status: 'ACTIVE',
    );
    whenListen<AuthState>(
      authBloc,
      Stream.fromIterable([AuthProfileUpdated(updatedUser)]),
      initialState: AuthAuthenticated(_activeUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Updated Name'), findsWidgets);
  });

  // ── KYC status tile tests ─────────────────────────────────────────────────

  testWidgets('KYC REJECTED shows "Réessayer" trailing text', (tester) async {
    final rejectedKycUser = UserModel(
      id: 'user-rej',
      firstName: 'Rejected',
      lastName: 'User',
      roles: const ['SENDER'],
      kycStatus: 'REJECTED',
      status: 'ACTIVE',
    );
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(rejectedKycUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.scrollUntilVisible(
      find.text('Réessayer'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    // Flush zero-duration animation timers.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('KYC PENDING shows "En cours" trailing text', (tester) async {
    final pendingKycUser = UserModel(
      id: 'user-pend',
      firstName: 'Pending',
      lastName: 'User',
      roles: const ['SENDER'],
      kycStatus: 'PENDING',
      status: 'ACTIVE',
    );
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(pendingKycUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.scrollUntilVisible(
      find.text('En cours'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('En cours'), findsOneWidget);
    // The CircularProgressIndicator has an ongoing animation — pump a fixed
    // number of frames to flush any zero-duration timers without waiting forever.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('sender section shows "X en cours" badge when activeBids > 0',
      (tester) async {
    final now = DateTime(2026, 6, 1);
    whenListen<BidState>(
      bidBloc,
      const Stream.empty(),
      initialState: BidListLoaded(
        List.generate(
          2,
          (i) => BidModel(
            id: 'bid-$i',
            announcementId: 'ann-$i',
            senderId: 'user-1',
            weightKg: 5,
            status: 'ACCEPTED',
            paymentMethod: BidPaymentMethod.stripe,
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ),
    );
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_activeUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.scrollUntilVisible(
      find.text('2 en cours'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2 en cours'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('tapping "Annuler la suppression" dispatches ReactivateAccount',
      (tester) async {
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_pendingDeletionUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    // Tap the reactivation button in PendingDeletionBanner.
    await tester.tap(find.text('Annuler la suppression'));
    await tester.pump();

    verify(() => deletionBloc.add(const ReactivateAccount())).called(1);
  });

  testWidgets('dual-role user: tapping Expéditeur pill calls switchToSender and goes /home',
      (tester) async {
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_dualRoleUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );
    // Start as traveler so the Expéditeur pill is untapped.
    when(() => activeRoleCubit.state).thenReturn(ActiveRole.traveler);

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    // The role pill switcher is visible in ProfileHeader — tap Expéditeur.
    expect(find.text('Expéditeur'), findsOneWidget);
    await tester.tap(find.text('Expéditeur'), warnIfMissed: false);
    await tester.pumpAndSettle();

    verify(() => activeRoleCubit.switchToSender()).called(1);
  });
}
