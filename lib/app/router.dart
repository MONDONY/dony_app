import 'package:dony/app/main_shell.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/presentation/screens/local_auth_screen.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:dony/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:dony/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/presentation/screens/cancellation_screen.dart';
import 'package:dony/features/cancellation/presentation/screens/rematch_search_screen.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_onboarding_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_status_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/announcement_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/create_announcement_screen.dart';
import 'package:dony/features/matching/presentation/screens/create_bid_screen.dart';
import 'package:dony/features/matching/presentation/screens/handover_screen.dart';
import 'package:dony/features/matching/presentation/screens/matching_management_screen.dart';
import 'package:dony/features/matching/presentation/screens/search_announcement_screen.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:dony/features/notifications/presentation/inbox_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/screens/escrow_explainer_screen.dart';
import 'package:dony/features/payments/presentation/screens/payment_screen.dart';
import 'package:dony/features/payments/presentation/screens/payout_onboarding_screen.dart';
import 'package:dony/features/config/bloc/config_bloc.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/presentation/screens/connect_onboarding_intro_screen.dart';
import 'package:dony/features/connect_onboarding/presentation/screens/connect_onboarding_pending_screen.dart';
import 'package:dony/features/profile/presentation/edit_profile_screen.dart';
import 'package:dony/features/profile/presentation/profile_screen.dart';
import 'package:dony/features/profile/presentation/screens/upgrade_to_pro_screen.dart';
import 'package:dony/features/splash/presentation/splash_screen.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/presentation/rating_screen.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/delete_account_screen.dart';
import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/presentation/screens/offline_scan_queue_screen.dart';
import 'package:dony/features/tracking/presentation/screens/qr_scanner_screen.dart';
import 'package:dony/features/tracking/presentation/screens/reception_confirm_screen.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_search_screen.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _publicRoutes = {
  '/splash',
  '/onboarding',
  '/auth/phone',
  '/auth/otp',
  '/auth/pin-setup',
  '/auth/local',
};

final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [SentryNavigatorObserver()],
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isAuthenticated = user != null;
    final isPublic =
        _publicRoutes.any((r) => state.matchedLocation.startsWith(r));
    if (!isAuthenticated && !isPublic) {
      return '/auth/phone';
    }
    return null;
  },
  routes: [
    // ── Auth (hors shell) ─────────────────────────────────────────────────
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) => const PhoneAuthScreen(),
    ),
    GoRoute(
      path: '/auth/otp',
      builder: (context, state) => const OtpVerificationScreen(),
    ),
    GoRoute(
      path: '/auth/pin-setup',
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: '/auth/local',
      builder: (context, state) => const LocalAuthScreen(),
    ),

    // ── KYC (hors shell) ─────────────────────────────────────────────────
    GoRoute(
      path: '/kyc',
      builder: (context, state) => const KycOnboardingScreen(),
    ),
    GoRoute(
      path: '/kyc/verify',
      builder: (context, state) {
        final raw = state.extra;
        if (raw is! String) {
          return const KycOnboardingScreen();
        }
        final uri = Uri.tryParse(raw);
        final host = uri?.host ?? '';
        final isStripe = uri?.scheme == 'https' &&
            (host == 'verify.stripe.com' || host.endsWith('.stripe.com'));
        if (!isStripe) {
          return const KycOnboardingScreen();
        }
        return KycWebViewScreen(stripeUrl: raw);
      },
    ),
    GoRoute(
      path: '/kyc/status',
      builder: (context, state) => const KycStatusScreen(),
    ),

    // ── Bid detail + handover (hors shell) ──────────────────────────────
    GoRoute(
      path: '/bids/:bidId',
      builder: (context, state) {
        final bid = state.extra is BidModel
            ? state.extra as BidModel
            : BidModel.skeleton(state.pathParameters['bidId']!);
        final fromPayment = state.uri.queryParameters['from'] == 'payment';
        return BidDetailScreen(bid: bid, fromPayment: fromPayment);
      },
      routes: [
        GoRoute(
          path: 'handover',
          builder: (context, state) {
            final bid = state.extra as BidModel;
            return BlocProvider(
              create: (_) => getIt<BidBloc>(),
              child: HandoverScreen(bid: bid),
            );
          },
        ),
      ],
    ),

    // ── Cancellation (hors shell) ────────────────────────────────────────
    GoRoute(
      path: '/cancellations/rematch',
      builder: (context, state) {
        final cancellation = state.extra as CancellationModel;
        return RematchSearchScreen(cancellation: cancellation);
      },
    ),

    // ── Édition profil (hors shell, plein écran) ─────────────────────────
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfileScreen(),
    ),

    // ── Upgrade PRO (hors shell) ─────────────────────────────────────────
    GoRoute(
      path: '/profile/upgrade-pro',
      builder: (context, state) => const UpgradeToProScreen(),
    ),

    // ── Connect onboarding (hors shell) ─────────────────────────────────
    GoRoute(
      path: '/connect/onboarding/intro',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ConnectOnboardingBloc>(),
        child: const ConnectOnboardingIntroScreen(),
      ),
    ),
    GoRoute(
      path: '/connect/onboarding/pending',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ConnectOnboardingBloc>(),
        child: const ConnectOnboardingPendingScreen(),
      ),
    ),

    // ── Routes plein écran (hors shell) ─────────────────────────────────
    GoRoute(
      path: '/tracking/scan',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<TrackingBloc>(),
        child: const QrScannerScreen(),
      ),
    ),
    GoRoute(
      path: '/tracking/search',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<TrackingBloc>(),
        child: const TrackingSearchScreen(),
      ),
    ),
    GoRoute(
      path: '/tracking/:bidId/timeline',
      builder: (context, state) {
        final bidId = state.pathParameters['bidId']!;
        final corridor = state.extra as String? ?? '';
        return BlocProvider(
          create: (_) => getIt<TrackingBloc>(),
          child: TrackingTimelineScreen(bidId: bidId, corridor: corridor),
        );
      },
    ),
    GoRoute(
      path: '/payments/onboarding',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<PaymentBloc>(),
        child: const PayoutOnboardingScreen(),
      ),
    ),
    GoRoute(
      path: '/payments/pay',
      builder: (context, state) {
        final bid = state.extra as BidModel;
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => getIt<PaymentBloc>()),
            BlocProvider(
              create: (_) => getIt<ConfigBloc>()
                ..add(const ConfigCommissionRateRequested()),
            ),
          ],
          child: PaymentScreen(bid: bid),
        );
      },
    ),
    GoRoute(
      path: '/payments/escrow',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return EscrowExplainerScreen(
          amount: (extra['amount'] as num).toDouble(),
          travelerName: extra['travelerName'] as String,
          bidId: extra['bidId'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/tracking/confirm',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>;
        return ReceptionConfirmScreen(
          bidId: extra['bidId']!,
          travelerName: extra['travelerName']!,
        );
      },
    ),
    GoRoute(
      path: '/payment/confirm',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Confirmer paiement'),
    ),
    // ── Stripe Connect deep-link return routes ───────────────────────────
    GoRoute(
      path: '/stripe/onboarding/complete',
      redirect: (context, state) => '/connect/onboarding/pending',
    ),
    GoRoute(
      path: '/stripe/onboarding/refresh',
      redirect: (context, state) => '/connect/onboarding/intro',
    ),
    GoRoute(
      path: '/disputes',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Litiges'),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Admin'),
    ),

    // ── Messagerie — conversation individuelle (hors shell) ─────────────
    GoRoute(
      path: '/conversations/:id',
      builder: (context, state) {
        final conversation = state.extra as ConversationModel;
        return BlocProvider(
          create: (_) => getIt<ChatBloc>(),
          child: ChatScreen(conversation: conversation),
        );
      },
    ),

    // ── Profil voyageur global (hors shell, pas de duplicate key) ────────
    GoRoute(
      path: '/traveler/:announcementId',
      builder: (context, state) {
        final announcementId = state.pathParameters['announcementId']!;
        return TravelerProfileLoaderScreen(announcementId: announcementId);
      },
    ),

    // ── Création / édition trajet (hors shell — plein écran) ────────────
    GoRoute(
      path: '/announcements/create',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<AnnouncementBloc>(),
        child: const CreateAnnouncementScreen(),
      ),
    ),
    GoRoute(
      path: '/announcements/:id/edit',
      builder: (context, state) {
        final announcement = state.extra as AnnouncementModel?;
        return BlocProvider(
          create: (_) => getIt<AnnouncementBloc>(),
          child: CreateAnnouncementScreen(announcement: announcement),
        );
      },
    ),

    // ── Détail annonce + sous-écrans (hors shell — plein écran) ─────────
    // Règle : tout écran avec ← ou ✕ est hors shell.
    GoRoute(
      path: '/announcements/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return BlocProvider(
          create: (_) => getIt<AnnouncementBloc>(),
          child: AnnouncementDetailScreen(id: id),
        );
      },
      routes: [
        GoRoute(
          path: 'bids',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final extra = state.extra as Map<String, dynamic>?;
            return BidListScreen(
              announcementId: id,
              initialTabIndex: extra?['initialTabIndex'] as int? ?? 0,
            );
          },
        ),
        GoRoute(
          path: 'cancel',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return BlocProvider(
              create: (_) => getIt<CancellationBloc>(),
              child: CancellationScreen(announcementId: id),
            );
          },
        ),
      ],
    ),

    // ── Détail annonce expéditeur + envoi colis (hors shell) ─────────────
    GoRoute(
      path: '/search/:id',
      builder: (context, state) {
        final announcement = state.extra as AnnouncementModel;
        return TravelerProfileScreen(announcement: announcement);
      },
      routes: [
        GoRoute(
          path: 'bid',
          builder: (context, state) {
            final announcement = state.extra as AnnouncementModel;
            return BlocProvider(
              create: (_) => getIt<BidBloc>(),
              child: CreateBidScreen(announcement: announcement),
            );
          },
        ),
      ],
    ),

    // ── Ratings (hors shell) ─────────────────────────────────────────────
    GoRoute(
      path: '/ratings/:bidId',
      builder: (context, state) {
        final bidId = state.pathParameters['bidId']!;
        final travelerName = state.extra as String? ?? 'le voyageur';
        return BlocProvider(
          create: (_) => getIt<RatingBloc>(),
          child: RatingScreen(bidId: bidId, travelerName: travelerName),
        );
      },
    ),

    // ── Suivi hors-ligne (hors shell) ────────────────────────────────────
    GoRoute(
      path: '/tracking/offline-queue',
      builder: (context, state) => const OfflineScanQueueScreen(),
    ),

    // ── Résultats de recherche (hors shell — plein écran) ───────────────
    GoRoute(
      path: '/search',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<AnnouncementBloc>(),
        child: const SearchAnnouncementScreen(),
      ),
    ),

    // ── Settings (hors shell) ──────────────────────────────────────────
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: 'delete-account',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<AccountDeletionBloc>(),
            child: const DeleteAccountScreen(),
          ),
        ),
      ],
    ),

    // ── Shell principal avec Bottom Navigation ───────────────────────────
    // Règle : UNIQUEMENT les 5 racines de tabs, sans sous-routes.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // Branch 0 — Accueil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => BlocProvider(
                create: (_) => getIt<AnnouncementBloc>(),
                child: const HomeScreen(),
              ),
            ),
          ],
        ),

        // Branch 1 — Envois (annonces voyageur)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/announcements',
              builder: (context, state) => const MatchingManagementScreen(),
            ),
          ],
        ),

        // Branch 2 — Suivi (QR centre)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tracking',
              builder: (context, state) => const _TrackingHubScreen(),
            ),
          ],
        ),

        // Branch 3 — Boîte de réception
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messages',
              builder: (context, state) => const InboxScreen(),
            ),
          ],
        ),

        // Branch 4 — Profil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => MultiBlocProvider(
                providers: [
                  BlocProvider(create: (_) => getIt<BidBloc>()),
                  BlocProvider(create: (_) => getIt<AccountDeletionBloc>()),
                ],
                child: const ProfileScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _TrackingHubScreen extends StatelessWidget {
  const _TrackingHubScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Suivi des colis',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0D1B2A)),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE9ECEF)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section voyageur ──────────────────────────────────────
            const _HubSectionTitle(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Je suis voyageur',
            ),
            const SizedBox(height: 12),
            _HubCard(
              icon: Icons.qr_code_scanner_rounded,
              iconBg: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1E88E5),
              title: 'Scanner le QR code d\'un colis',
              subtitle: 'À la remise, en transit ou à la livraison',
              onTap: () => context.push('/tracking/scan'),
            ),
            const SizedBox(height: 32),

            // ── Section expéditeur / destinataire ────────────────────
            const _HubSectionTitle(
              icon: Icons.search_rounded,
              label: 'Je suis expéditeur ou destinataire',
            ),
            const SizedBox(height: 12),
            _HubCard(
              icon: Icons.search_rounded,
              iconBg: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF16A34A),
              title: 'Suivre un colis par numéro',
              subtitle: 'Entrez votre numéro DON-XXXXXX',
              onTap: () => context.push('/tracking/search'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubSectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HubSectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7A8D)),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: Color(0xFF6B7A8D), letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HubCard({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: Color(0xFF0D1B2A))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7A8D))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFADB5BD), size: 20),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(title)),
      );
}
