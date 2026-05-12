import 'package:dony/app/main_shell.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/local_auth_screen.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:dony/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:dony/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/presentation/screens/rematch_search_screen.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_status_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/matching_management_screen.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:dony/features/notifications/presentation/inbox_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/screens/payment_screen.dart';
import 'package:dony/features/payments/presentation/screens/payout_onboarding_screen.dart';
import 'package:dony/features/config/bloc/config_bloc.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/presentation/screens/connect_onboarding_intro_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/complete_details_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/shipment_steps_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_detail_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:dony/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/link_trip_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_search_screen.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/favorite_travelers/bloc/favorite_traveler_bloc.dart';
import 'package:dony/features/favorite_travelers/presentation/screens/favorite_travelers_screen.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_address_edit_screen.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_addresses_screen.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/support_contact_bloc.dart';
import 'package:dony/features/profile/presentation/profile_screen.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/bloc/my_reviews_event.dart';
import 'package:dony/features/ratings/presentation/screens/my_reviews_screen.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/presentation/screens/recipient_edit_screen.dart';
import 'package:dony/features/recipients/presentation/screens/recipients_screen.dart';
import 'package:dony/features/profile/presentation/screens/faq_screen.dart';
import 'package:dony/features/profile/presentation/screens/shipments_history_screen.dart';
import 'package:dony/features/profile/presentation/screens/support_contact_screen.dart';
import 'package:dony/features/profile/presentation/screens/upgrade_to_pro_screen.dart';
import 'package:dony/features/splash/presentation/splash_screen.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/presentation/screens/offline_scan_queue_screen.dart';
import 'package:dony/features/tracking/presentation/screens/qr_scanner_screen.dart';
import 'package:dony/features/tracking/presentation/screens/reception_confirm_screen.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_hub_screen.dart';
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
      path: '/kyc/verify',
      builder: (context, state) {
        final raw = state.extra;
        if (raw is! String) {
          return const KycStatusScreen();
        }
        final uri = Uri.tryParse(raw);
        final host = uri?.host ?? '';
        final isStripe = uri?.scheme == 'https' &&
            (host == 'verify.stripe.com' || host.endsWith('.stripe.com'));
        if (!isStripe) {
          return const KycStatusScreen();
        }
        return BlocProvider(
          create: (_) => getIt<KycBloc>(),
          child: KycWebViewScreen(stripeUrl: raw),
        );
      },
    ),
    GoRoute(
      path: '/kyc/status',
      builder: (context, state) => const KycStatusScreen(),
    ),

    // ── Bid detail (hors shell) ──────────────────────────────────────────
    GoRoute(
      path: '/bids/:bidId',
      builder: (context, state) {
        final bid = state.extra is BidModel
            ? state.extra as BidModel
            : BidModel.skeleton(state.pathParameters['bidId']!);
        final fromPayment = state.uri.queryParameters['from'] == 'payment';
        return BidDetailScreen(bid: bid, fromPayment: fromPayment);
      },
    ),

    // ── Cancellation (hors shell) ────────────────────────────────────────
    GoRoute(
      path: '/cancellations/rematch',
      builder: (context, state) {
        final cancellation = state.extra as CancellationModel;
        return RematchSearchScreen(cancellation: cancellation);
      },
    ),

    // ── Connect onboarding (hors shell) ─────────────────────────────────
    GoRoute(
      path: '/connect/onboarding/intro',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ConnectOnboardingBloc>(),
        child: const ConnectOnboardingIntroScreen(),
      ),
    ),

    // ── Routes plein écran (hors shell) ─────────────────────────────────
    GoRoute(
      path: '/tracking/scan',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => getIt<TrackingBloc>()),
          BlocProvider(create: (_) => getIt<RatingBloc>()),
        ],
        child: const QrScannerScreen(),
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
      redirect: (context, state) => '/connect/onboarding/intro?from=stripe',
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

    // ── Bids d'une annonce (hors shell — plein écran) ────────────────────
    GoRoute(
      path: '/announcements/:id/bids',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>?;
        return BidListScreen(
          announcementId: id,
          initialTabIndex: extra?['initialTabIndex'] as int? ?? 0,
        );
      },
    ),

    // ── Suivi hors-ligne (hors shell) ────────────────────────────────────
    GoRoute(
      path: '/tracking/offline-queue',
      builder: (context, state) => const OfflineScanQueueScreen(),
    ),

    // ── Suivi expéditeur (hors shell) ────────────────────────────────────
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

    // ── Profile — quick wins (hors shell) ────────────────────────────
    GoRoute(
      path: '/profile/help/faq',
      builder: (context, state) => const FaqScreen(),
    ),
    GoRoute(
      path: '/profile/help/contact',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<SupportContactBloc>(),
        child: const SupportContactScreen(),
      ),
    ),
    GoRoute(
      path: '/profile/shipments/history',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<BidBloc>()..add(BidMyListRequested()),
        child: const ShipmentsHistoryScreen(),
      ),
    ),

    // ── Pickup addresses (hors shell) ────────────────────────────────────
    GoRoute(
      path: '/profile/addresses',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<PickupAddressBloc>()..add(const PickupAddressLoaded()),
        child: const PickupAddressesScreen(),
      ),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<PickupAddressBloc>()
              ..add(const PickupAddressLoaded()),
            child: const PickupAddressEditScreen(),
          ),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<PickupAddressBloc>()
              ..add(const PickupAddressLoaded()),
            child: PickupAddressEditScreen(
              addressId: state.pathParameters['id'],
            ),
          ),
        ),
      ],
    ),

    // ── Recipients (hors shell) ───────────────────────────────────────────
    GoRoute(
      path: '/profile/recipients',
      builder: (context, state) => BlocProvider(
        create: (_) =>
            getIt<RecipientBloc>()..add(const RecipientLoaded()),
        child: const RecipientsScreen(),
      ),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<RecipientBloc>()..add(const RecipientLoaded()),
            child: const RecipientEditScreen(),
          ),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<RecipientBloc>()..add(const RecipientLoaded()),
            child: RecipientEditScreen(
              recipientId: state.pathParameters['id'],
            ),
          ),
        ),
      ],
    ),

    // ── Favorite travelers (hors shell) ──────────────────────────────────
    GoRoute(
      path: '/profile/favorites',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<FavoriteTravelerBloc>()
          ..add(const FavoriteTravelerLoaded()),
        child: const FavoriteTravelersScreen(),
      ),
    ),

    // ── Upgrade PRO (hors shell) ──────────────────────────────────────
    GoRoute(
      path: '/profile/upgrade-to-pro',
      builder: (context, state) => const UpgradeToProScreen(),
    ),

    // ── Mes avis reçus (hors shell) ──────────────────────────────────
    GoRoute(
      path: '/profile/reviews',
      builder: (context, state) => BlocProvider(
        create: (_) =>
            getIt<MyReviewsBloc>()..add(const MyReviewsRequested()),
        child: const MyReviewsScreen(),
      ),
    ),

    // ── Mon profil public (hors shell) ───────────────────────────────
    GoRoute(
      path: '/profile/public',
      builder: (context, state) {
        final userId = state.extra as String?;
        return BlocProvider(
          create: (_) => getIt<ProfilePublicBloc>()
            ..add(ProfilePublicRequested(userId ?? '')),
          child: ProfilePublicScreen(userId: userId),
        );
      },
    ),

    // ── Settings (hors shell) ──────────────────────────────────────────
    GoRoute(
      path: '/settings',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<AccountDeletionBloc>(),
        child: const SettingsScreen(),
      ),
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
              builder: (context, state) => const TrackingHubScreen(),
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
              builder: (context, state) => BlocProvider(
                create: (_) => getIt<AccountDeletionBloc>(),
                child: const ProfileScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    // ── Marketplace de demandes d'envoi (package requests) ─────────────────
    GoRoute(
      path: '/package-requests/new',
      builder: (_, __) => const PackageRequestCreateScreen(),
    ),
    GoRoute(
      path: '/package-requests/me',
      builder: (_, __) => const MyPackageRequestsScreen(),
    ),
    GoRoute(
      path: '/package-requests/search',
      builder: (_, __) => const PackageRequestSearchScreen(),
    ),
    GoRoute(
      path: '/package-requests/:id',
      builder: (_, state) =>
          PackageRequestDetailScreen(requestId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/package-requests/:id/public',
      builder: (_, state) => PackageRequestPublicDetailScreen(
          requestId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/package-requests/:id/complete-details',
      builder: (_, state) =>
          CompleteDetailsScreen(requestId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/package-requests/:id/shipment',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ShipmentStepsScreen(
          requestId: state.pathParameters['id']!,
          travelerDisplayName: extra?['travelerDisplayName'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/negotiations',
      builder: (_, __) => const MyNegotiationsScreen(),
    ),
    GoRoute(
      path: '/negotiations/:id',
      builder: (context, state) {
        final authState = context.read<AuthBloc>().state;
        final userId = authState is AuthAuthenticated
            ? authState.user.id
            : authState is AuthProfileUpdated
                ? authState.user.id
                : '';
        return NegotiationThreadScreen(
          threadId: state.pathParameters['id']!,
          viewerUserId: userId,
        );
      },
    ),
    GoRoute(
      path: '/negotiations/:id/link-trip',
      builder: (context, state) {
        final thread = state.extra as NegotiationThread;
        return BlocProvider.value(
          value: getIt<NegotiationBloc>()
            ..add(NegotiationFetchRequested(thread.id)),
          child: LinkTripScreen(thread: thread),
        );
      },
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
