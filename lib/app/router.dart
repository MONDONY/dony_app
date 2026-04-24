import 'package:dony/app/main_shell.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/presentation/screens/local_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:dony/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:dony/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/presentation/screens/cancellation_screen.dart';
import 'package:dony/features/cancellation/presentation/screens/rematch_search_screen.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_onboarding_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_status_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/announcement_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/create_announcement_screen.dart';
import 'package:dony/features/matching/presentation/screens/create_bid_screen.dart';
import 'package:dony/features/matching/presentation/screens/handover_screen.dart';
import 'package:dony/features/matching/presentation/screens/search_announcement_screen.dart';
import 'package:dony/features/profile/presentation/profile_screen.dart';
import 'package:dony/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [SentryNavigatorObserver()],
  routes: [
    // ── Flux d'authentification (hors shell) ──────────────────────────────
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
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
      path: '/auth/role',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/auth/pin-setup',
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: '/auth/local',
      builder: (context, state) => const LocalAuthScreen(),
    ),

    // ── KYC (hors shell) ──────────────────────────────────────────────────
    GoRoute(
      path: '/kyc',
      builder: (context, state) => const KycOnboardingScreen(),
    ),
    GoRoute(
      path: '/kyc/verify',
      builder: (context, state) {
        final stripeUrl = state.extra as String;
        return KycWebViewScreen(stripeUrl: stripeUrl);
      },
    ),
    GoRoute(
      path: '/kyc/status',
      builder: (context, state) => const KycStatusScreen(),
    ),

    // ── Bid detail + handover (hors shell) ───────────────────────────────
    GoRoute(
      path: '/bids/:bidId',
      builder: (context, state) {
        final bid = state.extra as BidModel;
        return BlocProvider(
          create: (_) => getIt<BidBloc>(),
          child: BidDetailScreen(bid: bid),
        );
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

    // ── Cancellation (hors shell) ─────────────────────────────────────────
    GoRoute(
      path: '/cancellations/rematch',
      builder: (context, state) {
        final cancellation = state.extra as CancellationModel;
        return RematchSearchScreen(cancellation: cancellation);
      },
    ),

    // ── Routes plein écran (hors shell) ───────────────────────────────────
    GoRoute(
      path: '/tracking/scan',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Scanner QR'),
    ),
    GoRoute(
      path: '/payment/confirm',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Confirmer paiement'),
    ),
    GoRoute(
      path: '/disputes',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Litiges'),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const _PlaceholderScreen(title: 'Admin'),
    ),

    // ── Shell principal avec Bottom Navigation Bar ────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // Branch 0 — Accueil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // Branch 1 — Annonces & Recherche
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/announcements',
              builder: (context, state) => const AnnouncementListScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const CreateAnnouncementScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return AnnouncementDetailScreen(id: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) {
                        final announcement = state.extra as AnnouncementModel?;
                        return CreateAnnouncementScreen(announcement: announcement);
                      },
                    ),
                    GoRoute(
                      path: 'bids',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        return BidListScreen(announcementId: id);
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
              ],
            ),
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchAnnouncementScreen(),
              routes: [
                GoRoute(
                  path: ':id/bid',
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
          ],
        ),

        // Branch 2 — Suivi
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tracking',
              builder: (context, state) =>
                  const _PlaceholderScreen(title: 'Suivi des colis'),
            ),
          ],
        ),

        // Branch 3 — Profil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(title)),
      );
}
