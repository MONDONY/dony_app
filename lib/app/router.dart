import 'package:dony/app/main_shell.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/presentation/screens/local_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:dony/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:dony/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_search_screen.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/presentation/screens/cancellation_screen.dart';
import 'package:dony/features/cancellation/presentation/screens/rematch_search_screen.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_onboarding_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_status_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/screens/payment_screen.dart';
import 'package:dony/features/payments/presentation/screens/payout_onboarding_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/announcement_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/create_announcement_screen.dart';
import 'package:dony/features/matching/presentation/screens/matching_management_screen.dart';
import 'package:dony/features/matching/presentation/screens/create_bid_screen.dart';
import 'package:dony/features/matching/presentation/screens/handover_screen.dart';
import 'package:dony/features/matching/presentation/screens/search_announcement_screen.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:dony/features/profile/presentation/edit_profile_screen.dart';
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
    // ── Auth (hors shell) ─────────────────────────────────────────────────
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

    // ── KYC (hors shell) ─────────────────────────────────────────────────
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

    // ── Bid detail + handover (hors shell) ──────────────────────────────
    GoRoute(
      path: '/bids/:bidId',
      builder: (context, state) {
        final bid = state.extra as BidModel;
        return BidDetailScreen(bid: bid);
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

    // ── Routes plein écran (hors shell) ─────────────────────────────────
    GoRoute(
      path: '/tracking/scan',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Scanner QR'),
    ),
    GoRoute(
      path: '/tracking/search',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<TrackingBloc>(),
        child: const TrackingSearchScreen(),
      ),
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
        return BlocProvider(
          create: (_) => getIt<PaymentBloc>(),
          child: PaymentScreen(bid: bid),
        );
      },
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
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Admin'),
    ),

    // ── Shell principal avec Bottom Navigation ───────────────────────────
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

        // Branch 1 — Envois (annonces + recherche)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/announcements',
              builder: (context, state) => const MatchingManagementScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) =>
                      const CreateAnnouncementScreen(),
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
                        final announcement =
                            state.extra as AnnouncementModel?;
                        return CreateAnnouncementScreen(
                          announcement: announcement,
                        );
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
              builder: (context, state) => BlocProvider(
                create: (_) => getIt<AnnouncementBloc>(),
                child: const SearchAnnouncementScreen(),
              ),
              routes: [
                GoRoute(
                  path: ':id',
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
              ],
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

        // Branch 3 — Messages (placeholder)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messages',
              builder: (context, state) =>
                  const _PlaceholderScreen(title: 'Messages'),
            ),
          ],
        ),

        // Branch 4 — Profil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => BlocProvider(
                create: (_) => getIt<BidBloc>(),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    color: Color(0xFF1E88E5), size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Suivre un colis',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entrez votre numéro de suivi DON-XXXXXX\npour connaître le statut de votre colis.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7A8D), height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/tracking/search'),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text(
                    'Rechercher par numéro',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
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
