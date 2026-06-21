import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
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
import 'package:dony/features/profile/presentation/widgets/become_traveler_cta_card.dart';
import 'package:dony/features/profile/presentation/widgets/pending_deletion_banner.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/bloc/referral_event.dart';
import 'package:dony/features/referral/bloc/referral_state.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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

class MockReferralBloc extends MockBloc<ReferralEvent, ReferralState>
    implements ReferralBloc {}

// ── Fallback values ───────────────────────────────────────────────────────────

class FakeAuthEvent extends Fake implements AuthEvent {}

class FakeAccountDeletionEvent extends Fake implements RequestDeletion {}

class FakeBidEvent extends Fake implements BidEvent {}

class FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

class FakeReferralEvent extends Fake implements ReferralEvent {}

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
  required MockReferralBloc referralBloc,
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
          BlocProvider<ReferralBloc>.value(value: referralBloc),
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
    GoRoute(
      path: '/trip-templates',
      builder: (_, __) => const Scaffold(body: Text('TripTemplates')),
    ),
    GoRoute(
      path: '/profile/subscriptions',
      builder: (_, __) => const Scaffold(body: Text('Subscriptions')),
    ),
    GoRoute(
      path: '/payments/wallet',
      builder: (_, __) => const Scaffold(body: Text('Wallet')),
    ),
    GoRoute(
      path: '/profile/become-traveler',
      builder: (_, __) => const Scaffold(body: Text('BecomeTraveler')),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (_, __) => const Scaffold(body: Text('EditProfile')),
    ),
    GoRoute(
      path: '/profile/price-grid',
      builder: (_, __) => const Scaffold(body: Text('PriceGrid')),
    ),
    GoRoute(
      path: '/trajets-colis',
      builder: (_, __) => const Scaffold(body: Text('TrajetsCoils')),
    ),
    GoRoute(
      path: '/mes-colis',
      builder: (_, __) => const Scaffold(body: Text('MesColis')),
    ),
  ];

  return MaterialApp.router(
    routerConfig: GoRouter(initialLocation: '/', routes: routes),
    // Simule la safe-area (barre de statut) présente sur tout device réel.
    // Sans elle, MediaQuery.padding.top vaut 0 en widget test et le header
    // collapsible (expandedHeight = topPad + 56 + contentHeight) perd ~44px
    // de marge, ce qui fait déborder ProfileHeader de 11px.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(padding: const EdgeInsets.only(top: 44)),
      child: child!,
    ),
  );
}

// ── Helpers pour naviguer entre onglets ───────────────────────────────────────

// Finders stables basés sur les Key des ListViews de chaque onglet.
Finder get _activityScrollable => find.descendant(
  of: find.byKey(const Key('profile_activity_tab')),
  matching: find.byType(Scrollable),
);

Finder get _accountScrollable => find.descendant(
  of: find.byKey(const Key('profile_account_tab')),
  matching: find.byType(Scrollable),
);

Finder get _settingsScrollable => find.descendant(
  of: find.byKey(const Key('profile_settings_tab')),
  matching: find.byType(Scrollable),
);

Future<void> _goToCompteTab(WidgetTester tester) async {
  await tester.tap(find.text('Compte'));
  await tester.pump(); // démarre l'animation
  await tester.pump(
    const Duration(milliseconds: 350),
  ); // avance jusqu'à la fin (kTabScrollDuration=300ms)
  await tester.pump(); // settle layout
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
    registerFallbackValue(FakeReferralEvent());
  });

  late MockAuthBloc authBloc;
  late MockAccountDeletionBloc deletionBloc;
  late MockBidBloc bidBloc;
  late MockAnnouncementBloc announcementBloc;
  late MockReferralBloc referralBloc;

  setUp(() {
    authBloc = MockAuthBloc();
    deletionBloc = MockAccountDeletionBloc();
    bidBloc = MockBidBloc();
    announcementBloc = MockAnnouncementBloc();
    referralBloc = MockReferralBloc();

    whenListen<BidState>(
      bidBloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );
    whenListen<AnnouncementState>(
      announcementBloc,
      const Stream.empty(),
      initialState: AnnouncementInitial(),
    );
    whenListen<ReferralState>(
      referralBloc,
      const Stream.empty(),
      initialState: const ReferralInitial(),
    );
  });

  // ── Bannières ────────────────────────────────────────────────────────────────

  testWidgets(
    'PendingDeletionBanner renders when user status is PENDING_DELETION',
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

      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(PendingDeletionBanner), findsOneWidget);
    },
  );

  testWidgets('PendingDeletionBanner is absent when user status is ACTIVE', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(PendingDeletionBanner), findsNothing);
  });

  testWidgets(
    'AccountReactivated state causes AuthCheckRequested to be dispatched',
    (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_pendingDeletionUser),
      );
      whenListen<AccountDeletionState>(
        deletionBloc,
        Stream.fromIterable([AccountReactivated(_activeUser)]),
        initialState: const AccountDeletionInitial(),
      );

      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      verify(() => authBloc.add(const AuthCheckRequested())).called(1);
    },
  );

  testWidgets('AccountDeletionError state shows a SnackBar', (tester) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Erreur réseau'), findsOneWidget);
  });

  // ── Onglet Réglages — Paramètres ─────────────────────────────────────────────

  testWidgets('tapping "Paramètres" (onglet Réglages) navigates to /settings', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
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
    });

    testWidgets(
      'onglet Activité affiche les sections EN COURS et SUIVI',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        for (final label in ['EN COURS', 'SUIVI']) {
          await tester.scrollUntilVisible(
            find.text(label),
            300,
            scrollable: _activityScrollable,
          );
          expect(
            find.text(label),
            findsOneWidget,
            reason: 'Section "$label" manquante dans Activité',
          );
        }
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'onglet Compte affiche IDENTITÉ & CONTACT, RÉPUTATION, PAIEMENTS, AVANTAGES',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await _goToCompteTab(tester);

        // Order matches the widget-tree order in _AccountTab (top → bottom):
        // IDENTITÉ & CONTACT → RÉPUTATION → PAIEMENTS → AVANTAGES
        for (final label in [
          'IDENTITÉ & CONTACT',
          'RÉPUTATION',
          'PAIEMENTS',
          'AVANTAGES',
        ]) {
          await tester.scrollUntilVisible(
            find.text(label),
            300,
            scrollable: _accountScrollable,
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.text(label),
            findsOneWidget,
            reason: 'Section "$label" manquante dans Compte',
          );
        }
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'onglet Réglages affiche SUPPORT avec Contacter le support et FAQ',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await _goToReglagesTab(tester);

        for (final tile in ['Contacter le support', 'FAQ & aide']) {
          await tester.scrollUntilVisible(
            find.text(tile),
            300,
            scrollable: _settingsScrollable,
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.text(tile),
            findsOneWidget,
            reason: '$tile manquant dans Réglages',
          );
        }
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'affiche "Mes trajets et colis" (hub) et pas les 4 anciennes tuiles ni "Demandes d\'envoi à transporter"',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await tester.scrollUntilVisible(
          find.text('Mes trajets et colis'),
          300,
          scrollable: _activityScrollable,
        );
        expect(find.text('Mes trajets et colis'), findsOneWidget);
        // Les 4 anciennes tuiles ne sont plus directement dans le profil.
        expect(find.text('Colis sur mes trajets'), findsNothing);
        expect(find.text("Demandes d'envoi à transporter"), findsNothing);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets('affiche "Mon profil public" dans onglet Compte', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);
      await tester.scrollUntilVisible(
        find.text('Mon profil public'),
        300,
        scrollable: _accountScrollable,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mon profil public'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('affiche "Mes avis reçus" dans onglet Compte', (tester) async {
      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);
      await tester.scrollUntilVisible(
        find.text('Mes avis reçus'),
        300,
        scrollable: _accountScrollable,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mes avis reçus'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets(
        'hub "Mes trajets et colis" visible sans badge matchs (count retiré)',
        (tester) async {
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

      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Le badge "N matchs" n'a jamais été affiché sur le hub.
      // La tuile "Mes trajets et colis" n'a pas de trailing count matchs.
      expect(find.textContaining('matchs'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('pas de badge matchs quand 0 annonces ACTIVE', (tester) async {
      whenListen<AnnouncementState>(
        announcementBloc,
        const Stream.empty(),
        initialState: AnnouncementListLoaded(const []),
      );

      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('matchs'), findsNothing);
    });

    group('Collapsed AppBar title', () {
      testWidgets('AppBar title contient DonyAvatar quand voyageur', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(DonyAvatar), findsWidgets);
      });

      testWidgets(
        'AppBar title affiche icône verified pour un utilisateur KYC vérifié',
        (tester) async {
          await tester.pumpWidget(
            _buildTestHarness(
              authBloc: authBloc,
              deletionBloc: deletionBloc,
              bidBloc: bidBloc,
              announcementBloc: announcementBloc,
              referralBloc: referralBloc,
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));

          expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check'), findsWidgets);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        },
      );
    });

    testWidgets(
      'voyageur : base commune visible + tuile hub "Mes trajets et colis" ajoutée (modèle additif)',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        // Modèle additif : les sections de base sont visibles pour TOUS les utilisateurs,
        // y compris les voyageurs. La tuile hub est ajoutée en plus pour les voyageurs.
        await tester.scrollUntilVisible(
          find.text('Mes envois en cours'),
          300,
          scrollable: _activityScrollable,
        );
        expect(
          find.text('Mes envois en cours'),
          findsOneWidget,
          reason: 'Mes envois en cours est une section base visible par tous',
        );
        await tester.scrollUntilVisible(
          find.text('Mes trajets et colis'),
          300,
          scrollable: _activityScrollable,
        );
        expect(
          find.text('Mes trajets et colis'),
          findsOneWidget,
          reason: 'voyageur voit en plus la tuile hub "Mes trajets et colis"',
        );
      },
    );

    testWidgets(
      'voyageur : DEVENIR VOYAGEUR absent en onglet Compte (additive, isTraveler=true)',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await _goToCompteTab(tester);
        // Un voyageur ne doit pas voir la CTA Devenir voyageur.
        expect(
          find.text('DEVENIR VOYAGEUR'),
          findsNothing,
          reason: 'un voyageur ne doit pas voir la section DEVENIR VOYAGEUR',
        );
        expect(
          find.byType(BecomeTravelerCtaCard),
          findsNothing,
          reason: 'un voyageur ne doit pas voir BecomeTravelerCtaCard',
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    // Navigation depuis onglet Activité — le hub "Mes trajets et colis" remplace les 4 tuiles.
    testWidgets(
      'tapping "Mes trajets et colis" navigates to /trajets-colis',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await tester.scrollUntilVisible(
          find.text('Mes trajets et colis'),
          300,
          scrollable: _activityScrollable,
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await tester.ensureVisible(find.text('Mes trajets et colis'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mes trajets et colis'));
        await tester.pumpAndSettle();

        expect(find.text('TrajetsCoils'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "Mes négociations" navigates to /negotiations',
      (tester) async {
        // "Mes négociations" est toujours visible (commun aux deux rôles).
        final now = DateTime(2026, 6, 1);
        whenListen<BidState>(
          bidBloc,
          const Stream.empty(),
          initialState: BidListLoaded([
            BidModel(
              id: 'bid-neg-1',
              announcementId: 'ann-1',
              senderId: 'user-3',
              weightKg: 5,
              status: 'ACCEPTED',
              paymentMethod: BidPaymentMethod.stripe,
              createdAt: now,
              updatedAt: now,
            ),
          ]),
        );

        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await tester.scrollUntilVisible(
          find.text('Mes négociations'),
          300,
          scrollable: _activityScrollable,
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await tester.ensureVisible(find.text('Mes négociations'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mes négociations'));
        await tester.pumpAndSettle();

        expect(find.text('Negotiations'), findsOneWidget);
      },
    );

    testWidgets('tapping "Mes litiges" navigates to /disputes', (tester) async {
      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Mes litiges'),
        300,
        scrollable: _activityScrollable,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Mes litiges'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Disputes'), findsOneWidget);
    });

    // Navigation depuis onglet Compte
    testWidgets(
      'tapping "Mon profil public" (onglet Compte) navigates to /profile/public',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await _goToCompteTab(tester);
        await tester.scrollUntilVisible(
          find.text('Mon profil public'),
          300,
          scrollable: _accountScrollable,
        );
        await tester.pump(); // stabilise avant le tap
        // ensureVisible assure que l'item est dans la zone visible (pas seulement buildé)
        await tester.ensureVisible(find.text('Mon profil public'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mon profil public'));
        await tester.pumpAndSettle();

        expect(find.text('PublicProfile'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "Recevoir mes paiements" (onglet Compte) navigates to /payments/onboarding',
      (tester) async {
        // Viewport de test agrandi : tout l'onglet Compte tient sans scroll
        // précaire, ce qui rend le tap déterministe quelle que soit la hauteur.
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1080, 2600);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await _goToCompteTab(tester);
        await tester.scrollUntilVisible(
          find.text('Recevoir mes paiements'),
          300,
          scrollable: _accountScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recevoir mes paiements'));
        await tester.pumpAndSettle();

        expect(find.text('PaymentsOnboarding'), findsOneWidget);
      },
    );

    testWidgets('onglet Compte affiche la section PAIEMENTS (ex-MON PORTEFEUILLE)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);
      await tester.scrollUntilVisible(
        find.text('PAIEMENTS'),
        300,
        scrollable: _accountScrollable,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('PAIEMENTS'), findsOneWidget);
      expect(find.text('Mon portefeuille'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets(
      'tapping "Mon portefeuille" (onglet Compte) navigates to /payments/wallet',
      (tester) async {
        // Viewport agrandi : tout l'onglet Compte tient, tap déterministe.
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1080, 2600);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await _goToCompteTab(tester);
        await tester.scrollUntilVisible(
          find.text('Mon portefeuille'),
          300,
          scrollable: _accountScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mon portefeuille'));
        await tester.pumpAndSettle();

        expect(find.text('Wallet'), findsOneWidget);
      },
    );
  });

  // ── Groupe expéditeur ─────────────────────────────────────────────────────────

  group('Section expéditeur', () {
    setUp(() {
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
    });

    testWidgets('sections voyageur absentes du tab Activité quand sender', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Ces labels voyageur ne doivent pas apparaître quand sender.
      expect(find.text('Colis sur mes trajets'), findsNothing);
      // « Mes négociations » est commun aux deux rôles (section EN COURS)
      // → présent même côté expéditeur.
      await tester.scrollUntilVisible(
        find.text('Mes négociations'),
        300,
        scrollable: _activityScrollable,
      );
      expect(find.text('Mes négociations'), findsOneWidget);
    });

    testWidgets('tab Activité sender affiche EN COURS et SUIVI', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Vérifie les entrées des sections sender (plus fiable que les headers
      // dans un NestedScrollView où scrollUntilVisible peut ne pas fonctionner).
      await tester.scrollUntilVisible(
        find.text('Mes envois en cours'),
        300,
        scrollable: _activityScrollable,
      );
      expect(
        find.text('Mes envois en cours'),
        findsOneWidget,
        reason: 'section EN COURS sender absente',
      );
      await tester.scrollUntilVisible(
        find.text('Mes abonnements'),
        300,
        scrollable: _activityScrollable,
      );
      expect(
        find.text('Mes abonnements'),
        findsOneWidget,
        reason: 'section SUIVI sender absente (abonnements)',
      );
      await tester.scrollUntilVisible(
        find.text('Mes litiges'),
        300,
        scrollable: _activityScrollable,
      );
      expect(
        find.text('Mes litiges'),
        findsOneWidget,
        reason: 'section SUIVI sender absente (litiges)',
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets(
      'tab Compte sender affiche la CTA Devenir voyageur (PAIEMENTS & FACTURES supprimé)',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await _goToCompteTab(tester);
        // 'PAIEMENTS & FACTURES' a été supprimé — ses tuiles sont toutes Bientôt.
        expect(find.text('PAIEMENTS & FACTURES'), findsNothing);
        expect(find.text('Moyens de paiement'), findsNothing);
        expect(find.text('Factures'), findsNothing);
        expect(find.text('Crédits & codes promo'), findsNothing);

        // Le label DEVENIR VOYAGEUR a été remplacé par la carte CTA.
        expect(find.text('DEVENIR VOYAGEUR'), findsNothing);
        expect(
          find.byType(BecomeTravelerCtaCard),
          findsOneWidget,
          reason: 'BecomeTravelerCtaCard manquante pour un sender',
        );
        expect(
          find.text('Devenir voyageur'),
          findsOneWidget,
          reason: 'Titre CTA manquant',
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets('tab Compte sender affiche aussi section PAIEMENTS (ex-MON PORTEFEUILLE)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);
      await tester.scrollUntilVisible(
        find.text('PAIEMENTS'),
        300,
        scrollable: _accountScrollable,
      );
      expect(
        find.text('PAIEMENTS'),
        findsOneWidget,
        reason: 'section PAIEMENTS manquante (sender Compte)',
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('sender shows "X en cours" badge when activeBids > 0', (
      tester,
    ) async {
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

      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.scrollUntilVisible(
        find.text('2 en cours'),
        300,
        scrollable: _activityScrollable,
      );
      expect(find.text('2 en cours'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    // ── Phase 4 : modèle additif ─────────────────────────────────────────────────

    testWidgets(
      'pur expéditeur : hub "Mes trajets et colis" absent (isTraveler=false)',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          find.text('Mes trajets et colis'),
          findsNothing,
          reason: 'sender ne doit pas voir le hub "Mes trajets et colis"',
        );
      },
    );

    testWidgets(
      'Mes adresses retiré du profil (déplacé vers le hub colis/trajets)',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHarness(
            authBloc: authBloc,
            deletionBloc: deletionBloc,
            bidBloc: bidBloc,
            announcementBloc: announcementBloc,
            referralBloc: referralBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        // « Mes adresses » et « Mes destinataires » ont quitté MON CARNET :
        // ils vivent désormais dans les hubs « Mes trajets et colis » / « Mes
        // colis », plus sur l'onglet Activité du profil.
        expect(find.text('Mes adresses'), findsNothing);
        expect(find.text('Mes destinataires'), findsNothing);
      },
    );

    testWidgets('pur expéditeur : section AVANTAGES présente en onglet Compte', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await _goToCompteTab(tester);
      await tester.scrollUntilVisible(
        find.text('AVANTAGES'),
        300,
        scrollable: _accountScrollable,
      );
      expect(
        find.text('AVANTAGES'),
        findsOneWidget,
        reason: 'section AVANTAGES doit être visible pour tous les utilisateurs',
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  // ── KYC status (onglet Compte) ────────────────────────────────────────────────

  testWidgets('KYC REJECTED shows "Réessayer" dans onglet Compte', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await _goToCompteTab(tester);
    await tester.scrollUntilVisible(
      find.text('Réessayer'),
      300,
      scrollable: _accountScrollable,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('KYC PENDING shows "En cours" dans onglet Compte', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await _goToCompteTab(tester);
    await tester.scrollUntilVisible(
      find.text('En cours'),
      300,
      scrollable: _accountScrollable,
    );
    expect(find.text('En cours'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  // ── Auth navigation ───────────────────────────────────────────────────────────

  testWidgets('AuthInitial state triggers navigation to /auth/phone', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('AuthPhone'), findsOneWidget);
  });

  testWidgets('AuthAccountDeleted state triggers navigation to /auth/phone', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('AuthPhone'), findsOneWidget);
  });

  testWidgets('AuthProfileUpdated state renders updated user display name', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Updated Name'), findsWidgets);
  });

  // ── Bannière suppression ──────────────────────────────────────────────────────

  testWidgets('tapping "Annuler la suppression" dispatches ReactivateAccount', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Annuler la suppression'));
    await tester.pump();

    verify(() => deletionBloc.add(const ReactivateAccount())).called(1);
  });

  // ── E2 — Tuiles Bientôt masquées + renommage PAIEMENTS ──────────────────────

  testWidgets('Tuiles Bientôt masquées + section PAIEMENTS', (tester) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await _goToCompteTab(tester);

    // Tuiles ComingSoon supprimées.
    expect(find.text('Moyens de paiement'), findsNothing);
    expect(find.text('Factures'), findsNothing);
    expect(find.text('Crédits & codes promo'), findsNothing);

    // Section renommée PAIEMENTS (anciennement MON PORTEFEUILLE).
    await tester.scrollUntilVisible(
      find.text('PAIEMENTS'),
      300,
      scrollable: _accountScrollable,
    );
    expect(find.text('PAIEMENTS'), findsOneWidget);
    expect(find.text('Mon portefeuille'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  // ── Modèle additif (Phase 4) ─────────────────────────────────────────────────

  testWidgets('dual-role: no role pill shown in header (additive model)', (
    tester,
  ) async {
    // _dualRoleUser a TRAVELER + SENDER : le modèle additif n'affiche plus de pill
    // dans le header. La gestion de rôle se fait par isTraveler, pas par activeRole.
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // Le pill Expéditeur/Voyageur n'existe plus dans le header.
    // La tuile hub est visible car _dualRoleUser.isTraveler == true.
    await tester.scrollUntilVisible(
      find.text('Mes trajets et colis'),
      300,
      scrollable: _activityScrollable,
    );
    expect(
      find.text('Mes trajets et colis'),
      findsOneWidget,
      reason: 'dual-role user (isTraveler=true) doit voir la tuile hub',
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  // ── E3 — CTA Devenir voyageur en tête de Compte ──────────────────────────────

  testWidgets('CTA Devenir voyageur en tête de Compte (non-voyageur)', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await _goToCompteTab(tester);
    expect(find.byType(BecomeTravelerCtaCard), findsOneWidget);
    expect(find.text('Devenir voyageur'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('Pas de CTA Devenir voyageur pour un voyageur', (tester) async {
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

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await _goToCompteTab(tester);
    expect(find.byType(BecomeTravelerCtaCard), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  group('onglet Compte réorganisé', () {
    Future<void> openCompte(WidgetTester tester, UserModel user) async {
      whenListen<AuthState>(authBloc, const Stream.empty(),
          initialState: AuthAuthenticated(user));
      whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(),
          initialState: const AccountDeletionInitial());
      await tester.pumpWidget(_buildTestHarness(
          authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
          announcementBloc: announcementBloc, referralBloc: referralBloc));
      await tester.pump(const Duration(milliseconds: 600));
      await _goToCompteTab(tester);
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('sections regroupées présentes (voyageur)', (tester) async {
      await openCompte(tester, _travelerUser);
      await tester.pump(const Duration(milliseconds: 100));
      for (final label in ['IDENTITÉ & CONTACT', 'RÉPUTATION', 'PAIEMENTS', 'AVANTAGES']) {
        await tester.scrollUntilVisible(find.text(label), 300, scrollable: _accountScrollable);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('REVENUS & PAIEMENTS'), findsNothing);
      expect(find.text('FIDÉLITÉ'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('PAIEMENTS unifié : voyageur voit portefeuille + revenus',
        (tester) async {
      await openCompte(tester, _travelerUser);
      await tester.scrollUntilVisible(find.text('Ma grille de prix'), 300,
          scrollable: _accountScrollable);
      expect(find.text('Mon portefeuille'), findsOneWidget);
      expect(find.text('Recevoir mes paiements'), findsOneWidget);
      expect(find.text('Ma grille de prix'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('PAIEMENTS : expéditeur ne voit que le portefeuille',
        (tester) async {
      await openCompte(tester, _activeUser);
      await tester.scrollUntilVisible(find.text('Mon portefeuille'), 300,
          scrollable: _accountScrollable);
      expect(find.text('Mon portefeuille'), findsOneWidget);
      expect(find.text('Recevoir mes paiements'), findsNothing);
      expect(find.text('Ma grille de prix'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('onglet Activité réorganisé', () {
    testWidgets('voyageur : hub "Mes trajets et colis" en section EN COURS',
        (tester) async {
      whenListen<AuthState>(authBloc, const Stream.empty(),
          initialState: AuthAuthenticated(_travelerUser));
      whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(),
          initialState: const AccountDeletionInitial());
      await tester.pumpWidget(_buildTestHarness(
          authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
          announcementBloc: announcementBloc, referralBloc: referralBloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('EN COURS'), findsOneWidget);
      expect(find.text('Mes trajets et colis'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('SUIVI'),
        300,
        scrollable: _activityScrollable,
      );
      expect(find.text('SUIVI'), findsOneWidget);
      expect(find.text('Mes colis'), findsNothing);
      expect(find.text('MON CARNET'), findsNothing);
    });

    testWidgets('expéditeur : hub "Mes colis" en section EN COURS',
        (tester) async {
      whenListen<AuthState>(authBloc, const Stream.empty(),
          initialState: AuthAuthenticated(_activeUser));
      whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(),
          initialState: const AccountDeletionInitial());
      await tester.pumpWidget(_buildTestHarness(
          authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
          announcementBloc: announcementBloc, referralBloc: referralBloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Mes colis'), findsOneWidget);
      expect(find.text('Mes trajets et colis'), findsNothing);
    });

    testWidgets('section SUIVI contient litiges et abonnements', (tester) async {
      whenListen<AuthState>(authBloc, const Stream.empty(),
          initialState: AuthAuthenticated(_travelerUser));
      whenListen<AccountDeletionState>(deletionBloc, const Stream.empty(),
          initialState: const AccountDeletionInitial());
      await tester.pumpWidget(_buildTestHarness(
          authBloc: authBloc, deletionBloc: deletionBloc, bidBloc: bidBloc,
          announcementBloc: announcementBloc, referralBloc: referralBloc));
      await tester.pump(const Duration(milliseconds: 600));

      final scrollable = find.descendant(
        of: find.byKey(const Key('profile_activity_tab')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(find.text('Mes litiges'), 300,
          scrollable: scrollable);
      expect(find.text('Mes litiges'), findsOneWidget);
      expect(find.text('Mes abonnements'), findsOneWidget);
    });
  });
}
