import 'package:dony/app/main_shell.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/favorites/bloc/favorite_requests_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_trips_cubit.dart';
import 'package:dony/features/favorites/presentation/favorites_screen.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/auth/presentation/screens/local_auth_screen.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:dony/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:dony/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/auth_method_screen.dart';
import 'package:dony/features/auth/presentation/screens/analytics_consent_screen.dart';
import 'package:dony/features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/presentation/screens/rematch_search_screen.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_status_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/pending_bids_screen.dart';
import 'package:dony/features/matching/presentation/screens/trip_owner_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/screens/publish_intro_screen.dart';
import 'package:dony/features/matching/presentation/screens/activites_hub_screen.dart';
import 'package:dony/features/matching/presentation/screens/demandes_screen.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/presentation/archived_conversations_screen.dart';
import 'package:dony/features/notifications/presentation/inbox_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/presentation/screens/commission_method_screen.dart';
import 'package:dony/features/payments/presentation/screens/payment_screen.dart';
import 'package:dony/features/payments/presentation/screens/payout_onboarding_screen.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_amount_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_screen.dart';
import 'package:dony/features/config/bloc/config_bloc.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/presentation/screens/connect_onboarding_intro_screen.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/screens/account_disabled_screen.dart';
import 'package:dony/features/stripe_account/presentation/screens/account_rejected_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/complete_details_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_detail_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:dony/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/link_trip_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/dispute_detail_screen.dart';
import 'package:dony/features/disputes/presentation/dispute_list_screen.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/corridor_alert_list_screen.dart';
import 'package:dony/features/corridor_alerts/presentation/corridor_alert_matches_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_search_screen.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/presentation/screens/mobile_money_awaiting_screen.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_bloc.dart';
import 'package:dony/features/subscriptions/presentation/mes_abonnements_screen.dart';
import 'package:dony/features/subscriptions/presentation/traveler_profile_hub_screen.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_address_edit_screen.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_addresses_screen.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/presentation/screens/delivery_address_edit_screen.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_bloc.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_template_edit_screen.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_templates_screen.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_recurrence_edit_screen.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/support_contact_bloc.dart';
import 'package:dony/features/profile/presentation/profile_screen.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/presentation/screens/my_reviews_screen.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/presentation/screens/recipient_edit_screen.dart';
import 'package:dony/features/recipients/presentation/screens/recipients_screen.dart';
import 'package:dony/features/profile/presentation/screens/faq_screen.dart';
import 'package:dony/features/profile/presentation/screens/shipments_history_screen.dart';
import 'package:dony/features/profile/presentation/screens/support_contact_screen.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/presentation/price_grid_screen.dart';
import 'package:dony/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:dony/features/profile/presentation/screens/upgrade_to_pro_screen.dart';
import 'package:dony/features/splash/presentation/splash_screen.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/data_export_bloc.dart';
import 'package:dony/features/settings/bloc/diagnostics_bloc.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:dony/features/settings/presentation/screens/accessibility_settings_screen.dart';
import 'package:dony/features/settings/presentation/screens/business_prefs_screen.dart';
import 'package:dony/features/settings/presentation/screens/data_settings_screen.dart';
import 'package:dony/features/settings/presentation/screens/diagnostics_screen.dart';
import 'package:dony/features/incident_report/bloc/incident_photos_cubit.dart';
import 'package:dony/features/incident_report/bloc/incident_report_cubit.dart';
import 'package:dony/features/incident_report/presentation/screens/incident_report_screen.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/settings/presentation/screens/change_pin_screen.dart';
import 'package:dony/features/settings/presentation/screens/legal_web_view_screen.dart';
import 'package:dony/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:dony/features/settings/presentation/screens/privacy_settings_screen.dart';
import 'package:dony/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/bloc/connected_devices_bloc.dart';
import 'package:dony/features/settings/presentation/screens/blocked_users_screen.dart';
import 'package:dony/features/settings/presentation/screens/connected_devices_screen.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/presentation/screens/referral_screen.dart';
import 'package:dony/features/auth/presentation/screens/referral_code_screen.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/presentation/screens/offline_scan_queue_screen.dart';
import 'package:dony/features/tracking/presentation/screens/qr_scanner_screen.dart';
import 'package:dony/features/tracking/presentation/screens/reception_confirm_screen.dart';
import 'package:dony/features/tracking/presentation/screens/scan_hub_screen.dart';
import 'package:dony/features/tracking/presentation/screens/suivi_screen.dart';
import 'package:dony/features/tracking/presentation/screens/qr_picker_screen.dart';
import 'package:dony/features/tracking/presentation/screens/scan_identify_screen.dart';
import 'package:dony/features/tracking/presentation/screens/scan_photo_screen.dart';
import 'package:dony/features/tracking/presentation/screens/scan_confirm_screen.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_search_screen.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _publicRoutes = {
  '/splash',
  '/onboarding',
  '/auth/method',
  '/auth/phone',
  '/auth/otp',
  '/auth/email',
  '/auth/email-otp',
  '/auth/pin-setup',
  '/auth/referral-code',
  '/auth/analytics-consent',
  '/auth/local',
};

final appRouter = GoRouter(
  initialLocation: '/splash',
  // PosthogObserver : auto-capture des vues d'écran ($screen) à chaque
  // changement de route (no-op tant que le consentement n'est pas accordé).
  observers: [SentryNavigatorObserver(), PosthogObserver()],
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isAuthenticated = user != null;
    final isPublic = _publicRoutes.any(
      (r) => state.matchedLocation.startsWith(r),
    );
    if (!isAuthenticated && !isPublic) {
      return '/auth/method';
    }

    const guardedRoutes = {'/trips/create'};
    if (guardedRoutes.contains(state.matchedLocation)) {
      final accountState = context.read<StripeAccountBloc>().state;
      if (accountState is StripeAccountReady) {
        if (accountState.accountStatus.isDisabled) return '/account/disabled';
        if (accountState.accountStatus.isRejected) return '/account/rejected';
      }
    }

    return null;
  },
  routes: [
    // ── Auth (hors shell) ─────────────────────────────────────────────────
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/auth/method',
      builder: (context, state) => const AuthMethodScreen(),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) {
        final extra = state.extra as Map? ?? {};
        return PhoneAuthScreen(fromProfile: extra['fromProfile'] == true);
      },
    ),
    GoRoute(
      path: '/auth/otp',
      builder: (context, state) {
        final extra = state.extra as Map? ?? {};
        return OtpVerificationScreen(
          mode: OtpMode.phone,
          fromProfile: extra['fromProfile'] == true,
          contact: (extra['contact'] as String?) ?? '',
        );
      },
    ),
    GoRoute(
      path: '/auth/email',
      builder: (context, state) {
        final extra = state.extra as Map? ?? {};
        return EmailAuthScreen(fromProfile: extra['fromProfile'] == true);
      },
    ),
    GoRoute(
      path: '/auth/email-otp',
      builder: (context, state) {
        final extra = state.extra as Map? ?? {};
        return OtpVerificationScreen(
          mode: OtpMode.email,
          fromProfile: extra['fromProfile'] == true,
          contact: (extra['email'] as String?) ?? '',
        );
      },
    ),
    GoRoute(
      path: '/auth/pin-setup',
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: '/auth/referral-code',
      builder: (context, state) => BlocProvider(
        create: (_) => ReferralBloc(
          getIt<ReferralRepository>(),
          getIt<AnalyticsService>(),
        ),
        child: const ReferralCodeScreen(),
      ),
    ),
    GoRoute(
      path: '/auth/analytics-consent',
      builder: (context, state) => const AnalyticsConsentScreen(),
    ),
    GoRoute(
      path: '/auth/local',
      builder: (context, state) => LocalAuthScreen(
        verifyMode: state.uri.queryParameters['verify'] == 'true',
      ),
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
        final isStripe =
            uri?.scheme == 'https' &&
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

    // ── Création d'une offre (hors shell) ───────────────────────────────
    GoRoute(
      path: '/bids/new',
      builder: (_, state) =>
          CreateBidScreen(announcement: state.extra as AnnouncementModel),
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

    // ── Mobile Money — écran d'attente de paiement (hors shell) ────────
    GoRoute(
      path: '/bids/:bidId/mobile-money/awaiting',
      builder: (context, state) {
        final bidId = state.pathParameters['bidId']!;
        return BlocProvider(
          create: (_) => getIt<MobileMoneyPaymentBloc>(),
          child: MobileMoneyAwaitingScreen(bidId: bidId),
        );
      },
    ),

    // ── Cancellation (hors shell) ────────────────────────────────────────
    GoRoute(
      path: '/cancellations/:id/rematch',
      builder: (context, state) {
        final cancellationId = state.pathParameters['id']!;
        final cancellation = state.extra as CancellationModel?;
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => getIt<CancellationBloc>()),
            // Fetch du vrai AnnouncementModel au tap d'une suggestion
            // (cf. RematchSearchScreen._onSuggestionTap) — jamais de fetch
            // au chargement de la route, uniquement à la demande.
            BlocProvider(create: (_) => getIt<AnnouncementBloc>()),
          ],
          child: RematchSearchScreen(
            cancellationId: cancellationId,
            cancellation: cancellation,
          ),
        );
      },
    ),

    // ── Stripe account status (hors shell) ──────────────────────────────
    GoRoute(
      path: '/account/disabled',
      builder: (context, state) => const AccountDisabledScreen(),
    ),
    GoRoute(
      path: '/account/rejected',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ConnectOnboardingBloc>(),
        child: const AccountRejectedScreen(),
      ),
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
      path: '/tracking/scan/qr-picker',
      builder: (context, state) => const QrPickerScreen(),
    ),
    GoRoute(
      path: '/tracking/scan/identify',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return BlocProvider(
          create: (_) => getIt<TrackingBloc>(),
          child: ScanIdentifyScreen(
            etape: extra['etape'] as String?,
            focusNumber: extra['focusNumber'] as bool? ?? false,
          ),
        );
      },
    ),
    GoRoute(
      path: '/tracking/scan/photo',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ScanPhotoScreen(
          bidId: extra['bidId'] as String? ?? '',
          etape: extra['etape'] as String? ?? '',
          packageLabel: extra['packageLabel'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/tracking/scan/confirm',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => getIt<TrackingBloc>()),
            BlocProvider(create: (_) => getIt<RatingBloc>()),
          ],
          child: ScanConfirmScreen(
            bidId: extra['bidId'] as String? ?? '',
            etape: extra['etape'] as String? ?? '',
            photoPath: extra['photoPath'] as String?,
            gpsLat: extra['gpsLat'] as double?,
            gpsLon: extra['gpsLon'] as double?,
            packageLabel: extra['packageLabel'] as String? ?? '',
          ),
        );
      },
    ),
    // ── Écrans d'intro avant publication (conditions + responsabilités) ──────
    GoRoute(
      path: '/trips/publish-intro',
      builder: (context, state) =>
          const PublishIntroScreen(role: PublishIntroRole.trip),
    ),
    GoRoute(
      path: '/parcels/send-intro',
      builder: (context, state) =>
          const PublishIntroScreen(role: PublishIntroRole.parcel),
    ),

    // ── Créer / modifier un trajet (plein écran, slide-up) ───────────────────
    GoRoute(
      path: '/trips/create',
      pageBuilder: (context, state) {
        final args = state.extra is CreateTripArgs
            ? state.extra as CreateTripArgs
            : null;
        return CustomTransitionPage<bool>(
          // `name` alimente route.settings.name, que PosthogObserver lit pour
          // le $screen. Sans lui (page custom), cet écran n'était pas tracké.
          name: '/trips/create',
          child: CreateTripScreen(args: args),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic)),
              ),
              child: child,
            );
          },
        );
      },
    ),

    // ── Mes trajets (voyageur occasionnel, hors shell) ──────────────────────
    GoRoute(
      path: '/announcements/trips',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                getIt<AnnouncementBloc>()..add(AnnouncementListRequested()),
          ),
          BlocProvider(create: (_) => getIt<TripsSummaryCubit>()),
          BlocProvider(create: (_) => getIt<TripFilterCubit>()),
          BlocProvider.value(value: getIt<NegotiationListBloc>()),
        ],
        child: const AnnouncementListScreen(showBackButton: true),
      ),
    ),

    // ── Envoyer un colis (voyageur PRO, hors shell) ──────────────────────────
    GoRoute(
      path: '/announcements/send',
      builder: (context, state) => const EnvoyerHubScreen(showBackButton: true),
    ),

    // ── Modèles de trajet (hors shell) ───────────────────────────────────
    GoRoute(
      path: '/trip-templates',
      builder: (context, state) => BlocProvider(
        create: (_) =>
            getIt<TripTemplateBloc>()..add(const TripTemplateLoaded()),
        child: const TripTemplatesScreen(),
      ),
    ),
    GoRoute(
      path: '/trip-templates/edit',
      builder: (context, state) {
        final template = state.extra is TripTemplate
            ? state.extra as TripTemplate
            : null;
        return BlocProvider(
          create: (_) => getIt<TripTemplateBloc>(),
          child: TripTemplateEditScreen(template: template),
        );
      },
    ),
    GoRoute(
      path: '/trip-recurrences/new',
      builder: (context, state) {
        final template = state.extra as TripTemplate;
        return BlocProvider(
          create: (_) => getIt<TripRecurrenceBloc>(),
          child: TripRecurrenceEditScreen(template: template),
        );
      },
    ),

    // ── Carte commission (hors shell) ────────────────────────────────────
    GoRoute(
      path: '/payments/commission-method',
      builder: (context, state) => BlocProvider(
        create: (_) =>
            getIt<CommissionMethodBloc>()..add(CommissionMethodLoadRequested()),
        child: const CommissionMethodScreen(),
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
              create: (_) =>
                  getIt<ConfigBloc>()
                    ..add(const ConfigCommissionRateRequested()),
            ),
          ],
          child: PaymentScreen(bid: bid),
        );
      },
    ),
    // ── Wallet (hors shell) ──────────────────────────────────────────────
    GoRoute(
      path: '/payments/wallet',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<WalletBloc>()..add(WalletLoadRequested()),
        child: const WalletScreen(),
      ),
    ),
    GoRoute(
      path: '/payments/wallet/topup/method',
      builder: (context, state) => const WalletTopupMethodScreen(),
    ),
    GoRoute(
      path: '/payments/wallet/topup/amount',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<WalletBloc>(),
        child: WalletTopupAmountScreen(paymentMethod: state.extra as String),
      ),
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
    // ── Alertes corridor (hors shell) ────────────────────────────────────
    GoRoute(
      path: '/corridor-alerts',
      // Sans extra (hub Activités) : toutes les alertes, segment au form.
      builder: (_, state) => CorridorAlertListScreen(
        direction: state.extra is AlertDirection
            ? state.extra as AlertDirection
            : null,
      ),
    ),
    GoRoute(
      path: '/corridor-alerts/:id/matches',
      builder: (context, state) {
        final alert = state.extra as CorridorAlertModel;
        return CorridorAlertMatchesScreen(alert: alert);
      },
    ),

    GoRoute(
      path: '/disputes',
      builder: (context, state) => BlocProvider(
        create: (_) =>
            getIt<DisputeListBloc>()..add(const DisputesLoadRequested()),
        child: const DisputeListScreen(),
      ),
    ),
    GoRoute(
      path: '/disputes/detail',
      redirect: (context, state) =>
          state.extra is DisputeModel ? null : '/disputes',
      builder: (context, state) =>
          DisputeDetailScreen(dispute: state.extra! as DisputeModel),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const _PlaceholderScreen(title: 'Admin'),
    ),

    // ── Messagerie — archives (hors shell) ───────────────────────────────
    GoRoute(
      path: '/messages/archives',
      builder: (context, state) => BlocProvider.value(
        value: getIt<ConversationListBloc>(),
        child: const ArchivedConversationsScreen(),
      ),
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
          title: extra?['title'] as String? ?? 'Demandes',
        );
      },
    ),

    // ── Demandes « À traiter » d'une annonce (hors shell — plein écran) ───
    GoRoute(
      path: '/announcements/:id/bids/pending',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PendingBidsScreen(announcementId: id);
      },
    ),

    // ── Détail trajet propriétaire (hors shell — plein écran) ────────────
    GoRoute(
      path: '/announcements/:id/trip',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra is AnnouncementModel
            ? state.extra as AnnouncementModel
            : null;
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  getIt<AnnouncementBloc>()
                    ..add(AnnouncementDetailRequested(id)),
            ),
            BlocProvider(
              create: (_) => getIt<BidBloc>()..add(BidListRequested(id)),
            ),
            BlocProvider(create: (_) => getIt<CancellationBloc>()),
          ],
          child: TripOwnerDetailScreen(announcementId: id, initial: extra),
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
      path: '/tracking/scan-hub',
      builder: (context, state) => const ScanHubScreen(),
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


    // ── Mes colis — hub expéditeur (hors shell) ───────────────────────

    // ── Envois et demandes — destinations du hub Activités ────────────
    // ShipmentListScreen lit le BidBloc depuis son parent et déclenche
    // lui-même son chargement — pas d'event à ajouter ici.
    GoRoute(
      path: '/envois',
      builder: (_, __) => BlocProvider(
        create: (_) => getIt<BidBloc>(),
        child: const ShipmentListScreen(),
      ),
    ),
    GoRoute(path: '/demandes', builder: (_, __) => const DemandesScreen()),

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

    // ── Pickup + Delivery addresses (hors shell) ──────────────────────────
    GoRoute(
      path: '/profile/addresses',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                getIt<PickupAddressBloc>()..add(const PickupAddressLoaded()),
          ),
          BlocProvider(
            create: (_) =>
                getIt<DeliveryAddressBloc>()
                  ..add(const DeliveryAddressLoaded()),
          ),
        ],
        child: const PickupAddressesScreen(),
      ),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<PickupAddressBloc>()..add(const PickupAddressLoaded()),
            child: const PickupAddressEditScreen(),
          ),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<PickupAddressBloc>()..add(const PickupAddressLoaded()),
            child: PickupAddressEditScreen(
              addressId: state.pathParameters['id'],
            ),
          ),
        ),
        GoRoute(
          path: 'delivery/new',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<DeliveryAddressBloc>()
                  ..add(const DeliveryAddressLoaded()),
            child: const DeliveryAddressEditScreen(),
          ),
        ),
        GoRoute(
          path: 'delivery/:id',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<DeliveryAddressBloc>()
                  ..add(const DeliveryAddressLoaded()),
            child: DeliveryAddressEditScreen(
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
        create: (_) => getIt<RecipientBloc>()..add(const RecipientLoaded()),
        child: const RecipientsScreen(),
      ),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return BlocProvider(
              create: (_) =>
                  getIt<RecipientBloc>()..add(const RecipientLoaded()),
              child: RecipientEditScreen(
                initialFullName: extra?['fullName'] as String?,
                initialPhoneE164: extra?['phone'] as String?,
              ),
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<RecipientBloc>()..add(const RecipientLoaded()),
            child: RecipientEditScreen(recipientId: state.pathParameters['id']),
          ),
        ),
      ],
    ),

    // ── Profil voyageur enrichi (hors shell) ─────────────────────────
    GoRoute(
      path: '/travelers/:travelerId',
      builder: (context, state) {
        final id = state.pathParameters['travelerId']!;
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  getIt<ProfilePublicBloc>()..add(ProfilePublicRequested(id)),
            ),
            BlocProvider(
              create: (_) => getIt<TravelerHubBloc>()..add(LoadTravelerHub(id)),
            ),
          ],
          child: TravelerProfileHubScreen(travelerId: id),
        );
      },
    ),

    // ── Mes abonnements (hors shell) ─────────────────────────────────
    GoRoute(
      path: '/profile/subscriptions',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<SubscriptionsBloc>(),
        child: const MesAbonnementsScreen(),
      ),
    ),

    // ── Edit Profile (hors shell) ────────────────────────────────────
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfileScreen(),
    ),

    // ── Upgrade PRO (hors shell) ──────────────────────────────────────
    GoRoute(
      path: '/profile/upgrade-to-pro',
      builder: (context, state) => const UpgradeToProScreen(),
    ),

    // ── Grille de prix voyageur (hors shell) ─────────────────────────
    GoRoute(
      path: '/profile/price-grid',
      builder: (context, state) => BlocProvider(
        create: (_) =>
            getIt<PriceGridBloc>()..add(const PriceGridLoadRequested()),
        child: const PriceGridScreen(),
      ),
    ),

    // ── Referral (hors shell) ─────────────────────────────────────────
    GoRoute(
      path: '/profile/referral',
      builder: (context, state) => BlocProvider.value(
        value: getIt<ReferralBloc>(),
        child: const ReferralScreen(),
      ),
    ),

    // ── Mes avis reçus (hors shell) ──────────────────────────────────
    GoRoute(
      path: '/profile/reviews',
      builder: (context, state) => BlocProvider.value(
        value: getIt<MyReviewsBloc>(),
        child: const MyReviewsScreen(),
      ),
    ),

    // ── Mon profil public (hors shell) ───────────────────────────────
    GoRoute(
      path: '/profile/public',
      builder: (context, state) {
        final extra = state.extra;
        final args = extra is ProfilePublicArgs
            ? extra
            : ProfilePublicArgs(userId: extra as String?);
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  getIt<ProfilePublicBloc>()
                    ..add(ProfilePublicRequested(args.userId ?? '')),
            ),
            BlocProvider(create: (_) => getIt<TravelerSubscribeBloc>()),
          ],
          child: ProfilePublicScreen(
            userId: args.userId,
            showSubscribe: args.showSubscribe,
          ),
        );
      },
    ),

    // ── Settings (hors shell) ──────────────────────────────────────────
    GoRoute(
      path: '/settings',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => getIt<AccountDeletionBloc>()),
          BlocProvider.value(value: getIt<AppPreferencesBloc>()),
        ],
        child: const SettingsScreen(),
      ),
      routes: [
        GoRoute(
          path: 'security',
          builder: (context, state) => const SecuritySettingsScreen(),
          routes: [
            GoRoute(
              path: 'change-pin',
              builder: (context, state) =>
                  ChangePinScreen(authService: getIt<LocalAuthService>()),
            ),
            GoRoute(
              path: 'devices',
              builder: (context, state) => BlocProvider(
                create: (_) =>
                    getIt<ConnectedDevicesBloc>()
                      ..add(const DevicesLoadRequested()),
                child: const ConnectedDevicesScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'privacy',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<PrivacySettingsBloc>()
                  ..add(const PrivacySettingsLoadRequested()),
            child: const PrivacySettingsScreen(),
          ),
          routes: [
            GoRoute(
              path: 'blocked-users',
              builder: (context, state) => BlocProvider(
                create: (_) =>
                    getIt<BlockedUsersBloc>()
                      ..add(const BlockedUsersLoadRequested()),
                child: const BlockedUsersScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'data',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => getIt<AccountDeletionBloc>()),
              BlocProvider(create: (_) => getIt<DataExportBloc>()),
            ],
            child: const DataSettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'notifications',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<NotificationPrefsBloc>(),
            child: const NotificationSettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'preferences',
          builder: (context, state) => BlocProvider.value(
            value: getIt<BusinessPrefsBloc>(),
            child: const BusinessPrefsScreen(),
          ),
        ),
        GoRoute(
          path: 'accessibility',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<AccessibilityBloc>(),
            child: const AccessibilitySettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'diagnostics',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<DiagnosticsBloc>(),
            child: const DiagnosticsScreen(),
          ),
        ),
        GoRoute(
          path: 'report-incident',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final targetType =
                extra?['targetType'] as IncidentTargetType? ??
                IncidentTargetType.app;
            final targetId = extra?['targetId'] as String?;
            return MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => getIt<IncidentReportCubit>()),
                BlocProvider(create: (_) => getIt<IncidentPhotosCubit>()),
              ],
              child: IncidentReportScreen(
                targetType: targetType,
                targetId: targetId,
              ),
            );
          },
        ),
        GoRoute(
          path: 'legal/terms',
          builder: (context, state) => const LegalWebViewScreen(
            title: 'CGU',
            url: 'https://dony.store/legal/terms',
          ),
        ),
        GoRoute(
          path: 'legal/privacy',
          builder: (context, state) => const LegalWebViewScreen(
            title: 'Politique de confidentialité',
            url: 'https://dony.store/legal/privacy',
          ),
        ),
      ],
    ),

    // ── Mes favoris (hors shell) ─────────────────────────────────────────
    GoRoute(
      path: '/favoris',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => getIt<FavoriteTripsCubit>()),
          BlocProvider(create: (_) => getIt<FavoriteRequestsCubit>()),
        ],
        child: const FavoritesScreen(),
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

        // Branch 1 — Activités (hub unique, double rôle permanent)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/announcements',
              builder: (context, state) => const ActivitesHubScreen(),
            ),
          ],
        ),

        // Branch 2 — Suivi (dispatcher additif par profil)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tracking',
              builder: (context, state) => const SuiviScreen(),
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
                  BlocProvider(create: (_) => getIt<AccountDeletionBloc>()),
                  BlocProvider(
                    create: (_) => ReferralBloc(
                      getIt<ReferralRepository>(),
                      getIt<AnalyticsService>(),
                    )..add(const ReferralLoadRequested()),
                  ),
                ],
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
      builder: (_, state) =>
          PackageRequestCreateScreen(initial: state.extra as PackageRequest?),
    ),
    GoRoute(
      path: '/package-requests/me',
      builder: (_, __) => BlocProvider.value(
        value: getIt<PackageRequestBloc>(),
        child: const MyPackageRequestsScreen(),
      ),
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
        requestId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/package-requests/:id/complete-details',
      builder: (_, state) => CompleteDetailsScreen(
        requestId: state.pathParameters['id']!,
        thread: state.extra as NegotiationThread?,
      ),
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
    GoRoute(
      path: '/negotiations/:id/create-dedicated-trip',
      builder: (context, state) {
        final thread = state.extra as NegotiationThread;
        return BlocProvider.value(
          value: getIt<NegotiationBloc>()
            ..add(NegotiationFetchRequested(thread.id)),
          child: LinkTripScreen(thread: thread, autoCreateDedicated: true),
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
