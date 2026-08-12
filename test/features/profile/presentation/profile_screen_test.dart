import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_avatar.dart';
import 'package:dony/core/error/app_exception.dart';
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
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/profile/presentation/profile_screen.dart';
import 'package:dony/features/profile/presentation/widgets/wallet_balance_card.dart';
import 'package:dony/features/profile/presentation/widgets/pending_deletion_banner.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
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

class MockReferralBloc extends MockBloc<ReferralEvent, ReferralState>
    implements ReferralBloc {}

class MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

// ── Fallback values ───────────────────────────────────────────────────────────

class FakeAuthEvent extends Fake implements AuthEvent {}

class FakeAccountDeletionEvent extends Fake implements RequestDeletion {}

class FakeBidEvent extends Fake implements BidEvent {}

class FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

class FakeReferralEvent extends Fake implements ReferralEvent {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// Modèle double rôle : depuis l'inscription unifiée, tout compte porte les
/// deux rôles. C'est l'utilisateur de référence des tests.
const _dualRoleUser = UserModel(
  id: 'user-4',
  firstName: 'Dual',
  lastName: 'Role',
  roles: ['TRAVELER', 'SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

/// Compte encore mono-rôle (données antérieures au modèle double rôle) : la
/// page doit lui proposer exactement les mêmes sections.
const _senderOnlyUser = UserModel(
  id: 'user-1',
  firstName: 'Alice',
  lastName: 'Dupont',
  roles: ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

const _verifiedUser = UserModel(
  id: 'user-3',
  firstName: 'Amadou',
  lastName: 'Diallo',
  roles: ['TRAVELER', 'SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  totalTrips: 3,
);

final _pendingDeletionUser = UserModel(
  id: 'user-2',
  firstName: 'Bob',
  lastName: 'Martin',
  roles: const ['SENDER', 'TRAVELER'],
  kycStatus: 'NOT_STARTED',
  status: 'PENDING_DELETION',
  deletionRequestedAt: DateTime(2026, 5),
);

// ── Test harness ──────────────────────────────────────────────────────────────

Widget _buildTestHarness({
  required MockAuthBloc authBloc,
  required MockAccountDeletionBloc deletionBloc,
  required MockBidBloc bidBloc,
  required MockAnnouncementBloc announcementBloc,
  required MockReferralBloc referralBloc,
  required MockWalletBloc walletBloc,
}) {
  Widget stub(String label) => Scaffold(body: Text(label));

  final routes = <RouteBase>[
    GoRoute(
      path: '/',
      builder: (_, _) => MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<AccountDeletionBloc>.value(value: deletionBloc),
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
          BlocProvider<ReferralBloc>.value(value: referralBloc),
          BlocProvider<WalletBloc>.value(value: walletBloc),
        ],
        child: const ProfileScreen(),
      ),
    ),
    GoRoute(path: '/auth/method', builder: (_, _) => stub('AuthMethod')),
    GoRoute(path: '/settings', builder: (_, _) => stub('Settings')),
    GoRoute(path: '/profile/public', builder: (_, _) => stub('PublicProfile')),
    GoRoute(path: '/profile/reviews', builder: (_, _) => stub('Reviews')),
    GoRoute(path: '/disputes', builder: (_, _) => stub('Disputes')),
    GoRoute(path: '/profile/help/faq', builder: (_, _) => stub('FAQ')),
    GoRoute(path: '/profile/community', builder: (_, _) => stub('Community')),
    GoRoute(path: '/profile/help/contact', builder: (_, _) => stub('Contact')),
    GoRoute(
      path: '/payments/onboarding',
      builder: (_, _) => stub('PaymentsOnboarding'),
    ),
    GoRoute(
      path: '/payments/commission-method',
      builder: (_, _) => stub('CommissionMethod'),
    ),
    GoRoute(path: '/payments/wallet', builder: (_, _) => stub('Wallet')),
    GoRoute(
      path: '/payments/wallet/topup/method',
      builder: (_, _) => stub('TopupMethod'),
    ),
    GoRoute(path: '/profile/referral', builder: (_, _) => stub('Referral')),
    GoRoute(
      path: '/profile/upgrade-to-pro',
      builder: (_, _) => stub('UpgradeToPro'),
    ),
    GoRoute(path: '/profile/price-grid', builder: (_, _) => stub('PriceGrid')),
    GoRoute(
      path: '/profile/subscriptions',
      builder: (_, _) => stub('Subscriptions'),
    ),
    GoRoute(path: '/profile/edit', builder: (_, _) => stub('EditProfile')),
  ];

  return MaterialApp.router(
    routerConfig: GoRouter(initialLocation: '/', routes: routes),
    // Simule la safe-area (barre de statut) présente sur tout device réel.
    // Sans elle, MediaQuery.padding.top vaut 0 en widget test et le header
    // collapsible perd ~44px de marge, ce qui le fait déborder.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(padding: const EdgeInsets.only(top: 44)),
      child: child!,
    ),
  );
}

/// La page est un scroll unique : la plupart des lignes sont hors écran au
/// premier rendu. `scrollUntilVisible` sur le seul Scrollable de la page.
Future<void> _scrollTo(
  WidgetTester tester,
  Finder target, {
  bool settle = true,
}) async {
  await tester.scrollUntilVisible(
    target,
    240,
    // Le header replié contient un SingleChildScrollView (non scrollable) :
    // on vise explicitement celui de la page.
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .last,
  );
  // `settle: false` pour les écrans portant une animation infinie (le spinner
  // du KYC en cours) : pumpAndSettle ne rendrait jamais la main.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(const ReactivateAccount());
    registerFallbackValue(FakeBidEvent());
    registerFallbackValue(FakeAnnouncementEvent());
    registerFallbackValue(FakeReferralEvent());
    registerFallbackValue(WalletLoadRequested());
  });

  late MockAuthBloc authBloc;
  late MockAccountDeletionBloc deletionBloc;
  late MockBidBloc bidBloc;
  late MockAnnouncementBloc announcementBloc;
  late MockReferralBloc referralBloc;
  late MockWalletBloc walletBloc;

  setUp(() {
    authBloc = MockAuthBloc();
    deletionBloc = MockAccountDeletionBloc();
    bidBloc = MockBidBloc();
    announcementBloc = MockAnnouncementBloc();
    referralBloc = MockReferralBloc();
    walletBloc = MockWalletBloc();

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
    whenListen<WalletState>(
      walletBloc,
      const Stream.empty(),
      initialState: WalletLoaded(
        const WalletModel(balance: 45, currency: 'EUR', transactions: []),
      ),
    );
  });

  Future<void> pumpWith(
    WidgetTester tester,
    UserModel user, {
    bool settle = true,
  }) async {
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(user),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: AccountDeletionInitial(),
    );

    await tester.pumpWidget(
      _buildTestHarness(
        authBloc: authBloc,
        deletionBloc: deletionBloc,
        bidBloc: bidBloc,
        announcementBloc: announcementBloc,
        referralBloc: referralBloc,
        walletBloc: walletBloc,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  // ── Page unique ─────────────────────────────────────────────────────────────

  group('Page unique — plus d\'onglets', () {
    testWidgets('aucune TabBar ni TabBarView', (tester) async {
      await pumpWith(tester, _dualRoleUser);

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TabBarView), findsNothing);
      expect(find.text('Activité'), findsNothing);
      expect(find.text('Compte'), findsNothing);
      expect(find.text('Réglages'), findsNothing);
    });

    testWidgets('un seul Scrollable porte toute la page', (tester) async {
      await pumpWith(tester, _dualRoleUser);

      // Le header (sonde de mesure) n'est pas scrollable : seule la page l'est.
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('les six libellés de section sont sur la même page', (
      tester,
    ) async {
      await pumpWith(tester, _dualRoleUser);

      for (final label in [
        'MON COMPTE',
        'ARGENT',
        'MA RÉPUTATION',
        'MES AVANTAGES',
        'SUIVI',
        'AIDE & RÉGLAGES',
      ]) {
        await _scrollTo(tester, find.text(label));
        expect(find.text(label), findsOneWidget, reason: 'section $label');
      }
    });

    testWidgets('les entrées toujours migrées vers Activités ont disparu', (
      tester,
    ) async {
      await pumpWith(tester, _dualRoleUser);
      await _scrollTo(tester, find.text('AIDE & RÉGLAGES'));

      expect(find.text('Mes négociations'), findsNothing);
      expect(find.text('Mes colis'), findsNothing);
      expect(find.text('Mes trajets et colis'), findsNothing);
    });
  });

  // ── Modèle double rôle ──────────────────────────────────────────────────────

  group('Modèle double rôle — aucune section conditionnée au rôle', () {
    for (final entry in {
      'double rôle': _dualRoleUser,
      'compte encore mono-rôle': _senderOnlyUser,
    }.entries) {
      testWidgets('${entry.key} : section ARGENT complète', (tester) async {
        await pumpWith(tester, entry.value);

        await _scrollTo(tester, find.byType(WalletBalanceCard));
        expect(find.byType(WalletBalanceCard), findsOneWidget, reason: 'Solde');

        for (final label in [
          'Recevoir mes paiements',
          'Carte commission espèces',
          'Ma grille de prix',
        ]) {
          await _scrollTo(tester, find.text(label));
          expect(find.text(label), findsOneWidget, reason: label);
        }
      });

      testWidgets('${entry.key} : peut passer en compte PRO', (tester) async {
        await pumpWith(tester, entry.value);
        await _scrollTo(tester, find.text('Passer en compte PRO'));

        expect(find.text('Passer en compte PRO'), findsOneWidget);
      });
    }

    testWidgets('compte déjà PRO : la ligne devient « Mon profil PRO »', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const UserModel(
          id: 'pro-1',
          firstName: 'Pro',
          lastName: 'User',
          roles: ['TRAVELER', 'SENDER'],
          kycStatus: 'VERIFIED',
          status: 'ACTIVE',
          isProAccount: true,
        ),
      );
      await _scrollTo(tester, find.text('Mon profil PRO'));

      expect(find.text('Mon profil PRO'), findsOneWidget);
      expect(find.text('Passer en compte PRO'), findsNothing);
    });
  });

  // ── Navigation ──────────────────────────────────────────────────────────────

  group('Navigation', () {
    for (final nav in [
      ('Paramètres', 'Settings'),
      ('FAQ & aide', 'FAQ'),
      ('Réseaux sociaux et tutoriels', 'Community'),
      ('Contacter le support', 'Contact'),
      ('Mes litiges', 'Disputes'),
      ('Mes abonnements', 'Subscriptions'),
      ('Recevoir mes paiements', 'PaymentsOnboarding'),
      ('Ma grille de prix', 'PriceGrid'),
      ('Mon profil public', 'PublicProfile'),
      ('Mes avis reçus', 'Reviews'),
      ('Parrainages', 'Referral'),
    ]) {
      testWidgets('« ${nav.$1} » ouvre ${nav.$2}', (tester) async {
        await pumpWith(tester, _dualRoleUser);
        await _scrollTo(tester, find.text(nav.$1));

        await tester.tap(find.text(nav.$1));
        await tester.pumpAndSettle();

        expect(find.text(nav.$2), findsOneWidget);
      });
    }

    testWidgets('« Solde » (carte portefeuille) ouvre Wallet', (tester) async {
      await pumpWith(tester, _dualRoleUser);
      await _scrollTo(tester, find.byType(WalletBalanceCard));

      await tester.tap(find.text('Solde'));
      await tester.pumpAndSettle();

      expect(find.text('Wallet'), findsOneWidget);
    });

    testWidgets('« Recharger » sur la carte portefeuille ouvre TopupMethod, '
        'pas Wallet', (tester) async {
      await pumpWith(tester, _dualRoleUser);
      await _scrollTo(tester, find.byType(WalletBalanceCard));

      await tester.tap(find.text('Recharger'));
      await tester.pumpAndSettle();

      expect(find.text('TopupMethod'), findsOneWidget);
      expect(find.text('Wallet'), findsNothing);
    });
  });

  // ── KYC ─────────────────────────────────────────────────────────────────────

  group('Statut KYC dans la section MON COMPTE', () {
    for (final kyc in [
      ('REJECTED', 'Réessayer'),
      ('PENDING', 'En cours'),
      ('NOT_STARTED', 'Vérifier'),
    ]) {
      testWidgets('${kyc.$1} affiche « ${kyc.$2} »', (tester) async {
        // Le statut PENDING affiche un spinner : animation infinie, donc
        // pas de pumpAndSettle sur ce cas.
        final settle = kyc.$1 != 'PENDING';
        await pumpWith(
          tester,
          UserModel(
            id: 'kyc-user',
            firstName: 'Kyc',
            lastName: 'User',
            roles: const ['TRAVELER', 'SENDER'],
            kycStatus: kyc.$1,
            status: 'ACTIVE',
          ),
          settle: settle,
        );
        // « Documents KYC » ouvre la première section : visible sans scroll.
        // On l'exploite pour ce cas, le scroll créant des animations d'entrée
        // dont les timers survivraient à la fin du test.

        expect(find.text(kyc.$2), findsWidgets);
      });
    }

    testWidgets('VERIFIED retire la ligne « Documents d\'identité »', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const UserModel(
          id: 'kyc-user',
          firstName: 'Kyc',
          lastName: 'User',
          roles: ['TRAVELER', 'SENDER'],
          kycStatus: 'VERIFIED',
          status: 'ACTIVE',
        ),
      );

      expect(find.text('Documents d\'identité'), findsNothing);
    });
  });

  // ── Bannières et suppression de compte ──────────────────────────────────────

  group('Bannières', () {
    testWidgets('PendingDeletionBanner affiché si suppression demandée', (
      tester,
    ) async {
      await pumpWith(tester, _pendingDeletionUser);

      expect(find.byType(PendingDeletionBanner), findsOneWidget);
    });

    testWidgets('PendingDeletionBanner absent si le compte est actif', (
      tester,
    ) async {
      await pumpWith(tester, _dualRoleUser);

      expect(find.byType(PendingDeletionBanner), findsNothing);
    });

    testWidgets('« Annuler la suppression » déclenche ReactivateAccount', (
      tester,
    ) async {
      await pumpWith(tester, _pendingDeletionUser);

      await tester.tap(find.text('Annuler la suppression'));
      await tester.pump();

      verify(() => deletionBloc.add(const ReactivateAccount())).called(1);
    });

    testWidgets('AccountDeletionError affiche une SnackBar', (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(_dualRoleUser),
      );
      whenListen<AccountDeletionState>(
        deletionBloc,
        Stream.value(
          const AccountDeletionError(error: NetworkException('Erreur test')),
        ),
        initialState: AccountDeletionInitial(),
      );

      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
          walletBloc: walletBloc,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // ── Header ──────────────────────────────────────────────────────────────────

  group('Header', () {
    testWidgets('le titre replié porte l\'avatar', (tester) async {
      await pumpWith(tester, _verifiedUser);

      // Deux avatars vivent sous l'AppBar : celui du header déplié
      // (flexibleSpace) et celui du titre replié.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(DonyAvatar),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('aucune pastille de rôle (modèle additif)', (tester) async {
      await pumpWith(tester, _dualRoleUser);

      expect(find.text('Voyageur'), findsNothing);
      expect(find.text('Expéditeur'), findsNothing);
    });
  });

  // ── Cycle de vie de la session ──────────────────────────────────────────────

  group('Session', () {
    testWidgets('AuthInitial renvoie vers /auth/method', (tester) async {
      whenListen<AuthState>(
        authBloc,
        Stream.value(const AuthInitial()),
        initialState: const AuthAuthenticated(_dualRoleUser),
      );
      whenListen<AccountDeletionState>(
        deletionBloc,
        const Stream.empty(),
        initialState: AccountDeletionInitial(),
      );

      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
          walletBloc: walletBloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AuthMethod'), findsOneWidget);
    });

    testWidgets('AuthProfileUpdated rafraîchit le nom affiché', (tester) async {
      whenListen<AuthState>(
        authBloc,
        Stream.value(
          const AuthProfileUpdated(
            UserModel(
              id: 'user-4',
              firstName: 'Nouveau',
              lastName: 'Nom',
              roles: ['TRAVELER', 'SENDER'],
              kycStatus: 'NOT_STARTED',
              status: 'ACTIVE',
            ),
          ),
        ),
        initialState: const AuthAuthenticated(_dualRoleUser),
      );
      whenListen<AccountDeletionState>(
        deletionBloc,
        const Stream.empty(),
        initialState: AccountDeletionInitial(),
      );

      await tester.pumpWidget(
        _buildTestHarness(
          authBloc: authBloc,
          deletionBloc: deletionBloc,
          bidBloc: bidBloc,
          announcementBloc: announcementBloc,
          referralBloc: referralBloc,
          walletBloc: walletBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('Nouveau'), findsWidgets);
    });

    testWidgets('« Se déconnecter » déclenche AuthLogoutRequested', (
      tester,
    ) async {
      await pumpWith(tester, _dualRoleUser);
      await _scrollTo(tester, find.text('Se déconnecter'));

      await tester.tap(find.text('Se déconnecter').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se déconnecter').last);
      await tester.pumpAndSettle();

      verify(() => authBloc.add(const AuthLogoutRequested())).called(1);
    });
  });
}
