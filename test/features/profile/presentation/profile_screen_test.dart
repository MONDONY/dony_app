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
class FakeAccountDeletionEvent extends Fake implements RequestDeletion {}
class FakeBidEvent extends Fake implements BidEvent {}
class FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

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

Widget _buildTestHarness({
  required MockAuthBloc authBloc,
  required MockAccountDeletionBloc deletionBloc,
  required MockBidBloc bidBloc,
  required MockAnnouncementBloc announcementBloc,
  required MockActiveRoleCubit activeRoleCubit,
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
    GoRoute(path: '/auth/phone', builder: (_, __) => const Scaffold(body: Text('AuthPhone'))),
    GoRoute(path: '/settings', builder: (_, __) => const Scaffold(body: Text('Settings'))),
    GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Home'))),
    GoRoute(path: '/announcements', builder: (_, __) => const Scaffold(body: Text('Announcements'))),
    GoRoute(path: '/package-requests/match', builder: (_, __) => const Scaffold(body: Text('ColisMatch'))),
    GoRoute(path: '/package-requests/search', builder: (_, __) => const Scaffold(body: Text('PackageRequestsSearch'))),
    GoRoute(path: '/negotiations', builder: (_, __) => const Scaffold(body: Text('Negotiations'))),
    GoRoute(path: '/profile/public', builder: (_, __) => const Scaffold(body: Text('PublicProfile'))),
    GoRoute(path: '/profile/reviews', builder: (_, __) => const Scaffold(body: Text('Reviews'))),
    GoRoute(path: '/disputes', builder: (_, __) => const Scaffold(body: Text('Disputes'))),
    GoRoute(path: '/profile/help/contact', builder: (_, __) => const Scaffold(body: Text('Contact'))),
    GoRoute(path: '/profile/help/faq', builder: (_, __) => const Scaffold(body: Text('FAQ'))),
    GoRoute(path: '/payments/onboarding', builder: (_, __) => const Scaffold(body: Text('PaymentsOnboarding'))),
    GoRoute(path: '/payments/commission-method', builder: (_, __) => const Scaffold(body: Text('CommissionMethod'))),
    GoRoute(path: '/profile/referral', builder: (_, __) => const Scaffold(body: Text('Referral'))),
    GoRoute(path: '/profile/shipments/history', builder: (_, __) => const Scaffold(body: Text('ShipmentsHistory'))),
    GoRoute(path: '/profile/addresses', builder: (_, __) => const Scaffold(body: Text('Addresses'))),
    GoRoute(path: '/profile/recipients', builder: (_, __) => const Scaffold(body: Text('Recipients'))),
  ];

  return MaterialApp.router(
    routerConfig: GoRouter(initialLocation: '/', routes: routes),
    // Simule la safe-area (barre de statut) présente sur tout device réel.
    // Sans elle, MediaQuery.padding.top vaut 0 en widget test et le header
    // collapsible (expandedHeight = topPad + 56 + contentHeight) perd ~44px
    // de marge, ce qui fait déborder ProfileHeader de 11px.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(padding: const EdgeInsets.only(top: 44)),
      child: child!,
    ),
  );
}

// ── Helpers pour naviguer entre onglets ───────────────────────────────────────

// Finders stables basés sur les Key des ListViews de chaque onglet.
Finder get _activityScrollable =>
    find.descendant(of: find.byKey(const Key('profile_activity_tab')), matching: find.byType(Scrollable));

Finder get _accountScrollable =>
    find.descendant(of: find.byKey(const Key('profile_account_tab')), matching: find.byType(Scrollable));

Finder get _settingsScrollable =>
    find.descendant(of: find.byKey(const Key('profile_settings_tab')), matching: find.byType(Scrollable));

Future<void> _goToCompteTab(WidgetTester tester) async {
  await tester.tap(find.text('Compte'));
  await tester.pump();                                    // démarre l'animation
  await tester.pump(const Duration(milliseconds: 350));   // avance jusqu'à la fin (kTabScrollDuration=300ms)
  await tester.pump();                                    // settle layout
}

Future<void> _goToReglagesTab(WidgetTester tester) async {
  await tester.tap(find.text('Réglages'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(const ReactivateAccount());
    registerFallbackValue(FakeBidEvent());
    registerFallbackValue(FakeAnnouncementEvent());
  });

  late MockAuthBloc authBloc;
  late MockAccountDeletionBloc deletionBloc;
  late MockBidBloc bidBloc;
  late MockAnnouncementBloc announcementBloc;
  late MockActiveRoleCubit activeRoleCubit;

  setUp(() {
    authBloc         = MockAuthBloc();
    deletionBloc     = MockAccountDeletionBloc();
    bidBloc          = MockBidBloc();
    announcementBloc = MockAnnouncementBloc();
    activeRoleCubit  = MockActiveRoleCubit();

    whenListen<BidState>(bidBloc, const Stream.empty(), initialState: BidInitial());
    whenListen<AnnouncementState>(announcementBloc, const Stream.empty(), initialState: AnnouncementInitial());
    when(() => activeRoleCubit.state).thenReturn(ActiveRole.sender);
  });

  // ── Bannières ────────────────────────────────────────────────────────────────

  testWidgets('PendingDeletionBanner renders when user status is PENDING_DELETION',
      (tester) async {
    whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(_pendingDeletionUser));
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(PendingDeletionBanner), findsOneWidget);
  });

  testWidgets('PendingDeletionBanner is absent when user status is ACTIVE',
      (tester) async {
    whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(_activeUser));
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(PendingDeletionBanner), findsNothing);
  });

  testWidgets('AccountReactivated state causes AuthCheckRequested to be dispatched',
      (tester) async {
    whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(_pendingDeletionUser));
    whenListen<AccountDeletionState>(
      deletionBloc,
      Stream.fromIterable([AccountReactivated(_activeUser)]),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    verify(() => authBloc.add(const AuthCheckRequested())).called(1);
  });

  testWidgets('AccountDeletionError state shows a SnackBar', (tester) async {
    whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(_pendingDeletionUser));
    whenListen<AccountDeletionState>(
      deletionBloc,
      Stream.fromIterable([AccountDeletionError(error: const NetworkException('La réactivation a échoué.'))]),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Erreur réseau'), findsOneWidget);
  });

  // ── Onglet Réglages — Paramètres ─────────────────────────────────────────────

  testWidgets('tapping "Paramètres" (onglet Réglages) navigates to /settings',
      (tester) async {
    whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(_activeUser));
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await _goToReglagesTab(tester);

    await tester.scrollUntilVisible(
      find.text('Paramètres'),
      200,
      scrollable: _settingsScrollable,
    );
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });

  // ── Groupe voyageur ───────────────────────────────────────────────────────────

  group('Section voyageur', () {
    setUp(() {
      whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(_travelerUser));
      whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());
      when(() => activeRoleCubit.state).thenReturn(ActiveRole.traveler);
    });

    testWidgets('onglet Activité affiche les sections MON ACTIVITÉ et LITIGES',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      for (final label in ['MON ACTIVITÉ', 'LITIGES']) {
        await tester.scrollUntilVisible(
          find.text(label), 300, scrollable: _activityScrollable,
        );
        expect(find.text(label), findsOneWidget, reason: 'Section "$label" manquante dans Activité');
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('onglet Compte affiche IDENTITÉ & CONFIANCE, REVENUS & PAIEMENTS, COMPTE PRO, FIDÉLITÉ',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);

      for (final label in [
        'CONTACT & SÉCURITÉ',
        'IDENTITÉ & CONFIANCE',
        'REVENUS & PAIEMENTS',
        'COMPTE PRO',
        'FIDÉLITÉ',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label), 300, scrollable: _accountScrollable,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(label), findsOneWidget, reason: 'Section "$label" manquante dans Compte');
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('onglet Réglages affiche SUPPORT avec Contacter le support et FAQ',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await _goToReglagesTab(tester);

      for (final tile in ['Contacter le support', 'FAQ & aide']) {
        await tester.scrollUntilVisible(
          find.text(tile), 300, scrollable: _settingsScrollable,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(tile), findsOneWidget, reason: '$tile manquant dans Réglages');
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('affiche "Colis sur mes trajets" et pas "Demandes d\'envoi à transporter"',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.scrollUntilVisible(
        find.text('Colis sur mes trajets'), 300, scrollable: _activityScrollable,
      );
      expect(find.text('Colis sur mes trajets'), findsOneWidget);
      expect(find.text("Demandes d'envoi à transporter"), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('affiche "Mon profil public" dans onglet Compte', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);
      await tester.scrollUntilVisible(
        find.text('Mon profil public'), 300, scrollable: _accountScrollable,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mon profil public'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('affiche "Mes avis reçus" dans onglet Compte', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);
      await tester.scrollUntilVisible(
        find.text('Mes avis reçus'), 300, scrollable: _accountScrollable,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mes avis reçus'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('badge "2 matchs" visible quand 2 annonces ACTIVE', (tester) async {
      final now = DateTime(2026, 6, 1);
      whenListen<AnnouncementState>(
        announcementBloc,
        const Stream.empty(),
        initialState: AnnouncementListLoaded(
          List.generate(2, (i) => AnnouncementModel(
            id: 'ann-$i', travelerId: 'user-3',
            departureCity: 'Paris', arrivalCity: 'Dakar',
            departureDate: now, availableKg: 10, totalKg: 10,
            pricePerKg: 5, status: 'ACTIVE', createdAt: now, updatedAt: now,
          )),
        ),
      );

      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.scrollUntilVisible(
        find.text('2 matchs'), 300, scrollable: _activityScrollable,
      );
      expect(find.text('2 matchs'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('pas de badge matchs quand 0 annonces ACTIVE', (tester) async {
      whenListen<AnnouncementState>(announcementBloc, const Stream.empty(),
          initialState: AnnouncementListLoaded(const []));

      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('matchs'), findsNothing);
    });

    group('Collapsed AppBar title', () {
      testWidgets('AppBar title contient DonyAvatar quand voyageur', (tester) async {
        await tester.pumpWidget(_buildTestHarness(
          authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
          announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
        ));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(DonyAvatar), findsWidgets);
      });

      testWidgets('AppBar title affiche icône verified pour un utilisateur KYC vérifié',
          (tester) async {
        await tester.pumpWidget(_buildTestHarness(
          authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
          announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
        ));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byIcon(Icons.verified_rounded), findsWidgets);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });
    });

    testWidgets('sections sender absentes quand activeRole == traveler', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      // Dans tab Activité (défaut), les sections sender ne doivent pas apparaître.
      expect(find.text('Mes envois en cours'), findsNothing);
      expect(find.text('MON CARNET'), findsNothing);
    });

    // Navigation depuis onglet Activité
    testWidgets('tapping "Mes trajets" navigates to /announcements', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Mes trajets'), 300, scrollable: _activityScrollable,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Mes trajets'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Announcements'), findsOneWidget);
    });

    testWidgets('tapping "Colis sur mes trajets" navigates to /package-requests/match',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Colis sur mes trajets'), 300, scrollable: _activityScrollable,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Colis sur mes trajets'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('ColisMatch'), findsOneWidget);
    });

    testWidgets('tapping "Mes négociations" navigates to /negotiations', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Mes négociations'), 300, scrollable: _activityScrollable,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Mes négociations'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Negotiations'), findsOneWidget);
    });

    testWidgets('tapping "Mes litiges" navigates to /disputes', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Mes litiges'), 300, scrollable: _activityScrollable,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Mes litiges'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Disputes'), findsOneWidget);
    });

    // Navigation depuis onglet Compte
    testWidgets('tapping "Mon profil public" (onglet Compte) navigates to /profile/public',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);
      await tester.scrollUntilVisible(
        find.text('Mon profil public'), 300, scrollable: _accountScrollable,
      );
      await tester.pump(); // stabilise avant le tap
      // ensureVisible assure que l'item est dans la zone visible (pas seulement buildé)
      await tester.ensureVisible(find.text('Mon profil public'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mon profil public'));
      await tester.pumpAndSettle();

      expect(find.text('PublicProfile'), findsOneWidget);
    });

    testWidgets('tapping "Recevoir mes paiements" (onglet Compte) navigates to /payments/onboarding',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _goToCompteTab(tester);
      await tester.scrollUntilVisible(
        find.text('Recevoir mes paiements'), 300, scrollable: _accountScrollable,
      );
      await tester.pump(); // stabilise avant le tap
      // ensureVisible assure que l'item est dans la zone visible (pas seulement buildé)
      await tester.ensureVisible(find.text('Recevoir mes paiements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recevoir mes paiements'));
      await tester.pumpAndSettle();

      expect(find.text('PaymentsOnboarding'), findsOneWidget);
    });
  });

  // ── Groupe expéditeur ─────────────────────────────────────────────────────────

  group('Section expéditeur', () {
    setUp(() {
      whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(_activeUser));
      whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());
      when(() => activeRoleCubit.state).thenReturn(ActiveRole.sender);
    });

    testWidgets('sections voyageur absentes du tab Activité quand sender', (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      // Ces labels voyageur ne doivent pas apparaître quand sender.
      expect(find.text('Colis sur mes trajets'), findsNothing);
      expect(find.text('Mes négociations'), findsNothing);
    });

    testWidgets('tab Activité sender affiche MON ACTIVITÉ, MON CARNET, LITIGES',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      // Vérifie les entrées des sections sender (plus fiable que les headers
      // dans un NestedScrollView où scrollUntilVisible peut ne pas fonctionner).
      expect(find.text('Mes envois en cours'), findsOneWidget,
          reason: 'section MON ACTIVITÉ sender absente');
      await tester.scrollUntilVisible(
        find.text('Mes destinataires'), 300, scrollable: _activityScrollable,
      );
      expect(find.text('Mes destinataires'), findsOneWidget,
          reason: 'section MON CARNET sender absente');
      await tester.scrollUntilVisible(
        find.text('Mes litiges'), 300, scrollable: _activityScrollable,
      );
      expect(find.text('Mes litiges'), findsOneWidget,
          reason: 'section LITIGES sender absente');
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('tab Compte sender affiche PAIEMENTS & FACTURES et DEVENIR VOYAGEUR',
        (tester) async {
      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);
      for (final label in ['PAIEMENTS & FACTURES', 'DEVENIR VOYAGEUR']) {
        await tester.scrollUntilVisible(
          find.text(label), 300, scrollable: _accountScrollable,
        );
        expect(find.text(label), findsOneWidget, reason: '$label manquant (sender Compte)');
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('sender shows "X en cours" badge when activeBids > 0', (tester) async {
      final now = DateTime(2026, 6, 1);
      whenListen<BidState>(
        bidBloc,
        const Stream.empty(),
        initialState: BidListLoaded(
          List.generate(2, (i) => BidModel(
            id: 'bid-$i', announcementId: 'ann-$i', senderId: 'user-1',
            weightKg: 5, status: 'ACCEPTED',
            paymentMethod: BidPaymentMethod.stripe, createdAt: now, updatedAt: now,
          )),
        ),
      );

      await tester.pumpWidget(_buildTestHarness(
        authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
        announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.scrollUntilVisible(
        find.text('2 en cours'), 300, scrollable: _activityScrollable,
      );
      expect(find.text('2 en cours'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  // ── KYC status (onglet Compte) ────────────────────────────────────────────────

  testWidgets('KYC REJECTED shows "Réessayer" dans onglet Compte', (tester) async {
    final rejectedKycUser = UserModel(
      id: 'user-rej', firstName: 'Rejected', lastName: 'User',
      roles: const ['SENDER'], kycStatus: 'REJECTED', status: 'ACTIVE',
    );
    whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(rejectedKycUser));
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await _goToCompteTab(tester);
    await tester.scrollUntilVisible(
      find.text('Réessayer'), 300, scrollable: _accountScrollable,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('KYC PENDING shows "En cours" dans onglet Compte', (tester) async {
    final pendingKycUser = UserModel(
      id: 'user-pend', firstName: 'Pending', lastName: 'User',
      roles: const ['SENDER'], kycStatus: 'PENDING', status: 'ACTIVE',
    );
    whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(pendingKycUser));
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await _goToCompteTab(tester);
    await tester.scrollUntilVisible(
      find.text('En cours'), 300, scrollable: _accountScrollable,
    );
    expect(find.text('En cours'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  // ── Auth navigation ───────────────────────────────────────────────────────────

  testWidgets('AuthInitial state triggers navigation to /auth/phone', (tester) async {
    whenListen<AuthState>(
      authBloc,
      Stream.fromIterable([const AuthInitial()]),
      initialState: AuthAuthenticated(_activeUser),
    );
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('AuthPhone'), findsOneWidget);
  });

  testWidgets('AuthAccountDeleted state triggers navigation to /auth/phone', (tester) async {
    whenListen<AuthState>(
      authBloc,
      Stream.fromIterable([const AuthAccountDeleted()]),
      initialState: AuthAuthenticated(_activeUser),
    );
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('AuthPhone'), findsOneWidget);
  });

  testWidgets('AuthProfileUpdated state renders updated user display name', (tester) async {
    final updatedUser = UserModel(
      id: 'user-1', firstName: 'Updated', lastName: 'Name',
      roles: const ['SENDER'], kycStatus: 'NOT_STARTED', status: 'ACTIVE',
    );
    whenListen<AuthState>(
      authBloc,
      Stream.fromIterable([AuthProfileUpdated(updatedUser)]),
      initialState: AuthAuthenticated(_activeUser),
    );
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Updated Name'), findsWidgets);
  });

  // ── Bannière suppression ──────────────────────────────────────────────────────

  testWidgets('tapping "Annuler la suppression" dispatches ReactivateAccount',
      (tester) async {
    whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(_pendingDeletionUser));
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Annuler la suppression'));
    await tester.pump();

    verify(() => deletionBloc.add(const ReactivateAccount())).called(1);
  });

  // ── Toggle rôle (double rôle) ────────────────────────────────────────────────

  testWidgets('dual-role: tapping Expéditeur pill calls switchToSender', (tester) async {
    whenListen<AuthState>(authBloc, const Stream.empty(), initialState: AuthAuthenticated(_dualRoleUser));
    whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(), initialState: const AccountDeletionInitial());
    when(() => activeRoleCubit.state).thenReturn(ActiveRole.traveler);

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
      announcementBloc: announcementBloc, activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Expéditeur'), findsOneWidget);
    await tester.tap(find.text('Expéditeur'), warnIfMissed: false);
    await tester.pumpAndSettle();

    verify(() => activeRoleCubit.switchToSender()).called(1);
  });
}
