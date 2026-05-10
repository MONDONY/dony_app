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
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
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

    const errorMessage = 'La réactivation a échoué. Veuillez réessayer.';

    whenListen<AccountDeletionState>(
      deletionBloc,
      Stream.fromIterable([
        AccountDeletionError(error: NetworkException(errorMessage)),
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
    expect(find.text(errorMessage), findsOneWidget);
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
}
