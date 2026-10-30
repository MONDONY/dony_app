import 'dart:typed_data';

import 'package:dony/app/main_shell.dart';
import 'package:dony/core/config/flights_flag.dart';
import 'package:dony/core/config/pro_flag.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_route_filter.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/services/replay_privacy.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/presentation/screens/intent_step_screen.dart';
import 'package:dony/features/app_update/presentation/screens/force_update_screen.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/bloc/assistant_voice_cubit.dart';
import 'package:dony/features/assistant/presentation/assistant_bubble_blockers.dart';
import 'package:dony/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/bloc/country_onboarding_cubit.dart';
import 'package:dony/features/auth/bloc/personal_info_cubit.dart';
import 'package:dony/features/auth/bloc/profile_basics_cubit.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/auth/domain/country_from_phone.dart';
import 'package:dony/features/auth/guest_access_guard.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/analytics_consent_screen.dart';
import 'package:dony/features/auth/presentation/screens/auth_method_screen.dart';
import 'package:dony/features/auth/presentation/screens/country_selection_screen.dart';
import 'package:dony/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/features/auth/presentation/screens/local_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:dony/features/auth/presentation/screens/personal_info_screen.dart';
import 'package:dony/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/profile_basics_screen.dart';
import 'package:dony/features/auth/presentation/screens/referral_code_screen.dart';
import 'package:dony/features/calls/presentation/call_screen.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/presentation/screens/rematch_search_screen.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/presentation/screens/connect_onboarding_intro_screen.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/corridor_alert_list_screen.dart';
import 'package:dony/features/corridor_alerts/presentation/corridor_alert_matches_screen.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/presentation/screens/delivery_address_edit_screen.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/dispute_detail_screen.dart';
import 'package:dony/features/disputes/presentation/dispute_list_screen.dart';
import 'package:dony/features/favorites/bloc/favorite_requests_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_trips_cubit.dart';
import 'package:dony/features/favorites/presentation/favorites_screen.dart';
import 'package:dony/features/flights/bloc/flight_alert_offers_cubit.dart';
import 'package:dony/features/flights/bloc/flight_route_picker_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/presentation/flight_alert_offers_screen.dart';
import 'package:dony/features/flights/presentation/flight_alerts_screen.dart';
import 'package:dony/features/flights/presentation/flight_city_picker_screen.dart';
import 'package:dony/features/flights/presentation/flights_screen.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_signup_cubit.dart';
import 'package:dony/features/gp_pro/presentation/screens/gp_pro_screen.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/home/presentation/screens/search_composer_screen.dart';
import 'package:dony/features/incident_report/bloc/incident_photos_cubit.dart';
import 'package:dony/features/incident_report/bloc/incident_report_cubit.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/incident_report/presentation/screens/incident_report_screen.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/presentation/kyc_return_route.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_status_screen.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/pinned_trips_cubit.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/activites_hub_screen.dart';
import 'package:dony/features/matching/presentation/screens/activity_stats_screen.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_accepted_success_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/bid_negotiation_thread_screen.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/screens/demandes_screen.dart';
import 'package:dony/features/matching/presentation/screens/mes_colis_screen.dart';
import 'package:dony/features/matching/presentation/screens/mobile_money_awaiting_screen.dart';
import 'package:dony/features/matching/presentation/screens/pending_bids_screen.dart';
import 'package:dony/features/matching/presentation/screens/publish_intro_screen.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:dony/features/matching/presentation/screens/trip_owner_detail_screen.dart';
import 'package:dony/features/matching/presentation/screens/trip_poster_screen.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_notifications/conversation_notifications_cubit.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/archived_conversations_screen.dart';
import 'package:dony/features/messaging/presentation/chat_photo_preview_screen.dart';
import 'package:dony/features/messaging/presentation/chat_photo_viewer_screen.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:dony/features/messaging/presentation/conversation_loader_screen.dart';
import 'package:dony/features/notifications/presentation/announcements_inbox_screen.dart';
import 'package:dony/features/notifications/presentation/inbox_screen.dart';
import 'package:dony/features/notifications/presentation/notification_detail_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_cubit.dart';
import 'package:dony/features/package_request/bloc/package_request_form_draft.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/complete_details_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/negotiation_paid_success_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_detail_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_poster_screen.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:dony/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/link_trip_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/negotiation_commission_settled_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/presentation/screens/commission_method_screen.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/bloc/money_trips_cubit.dart';
import 'package:dony/features/payments/money/presentation/screens/money_overview_screen.dart';
import 'package:dony/features/payments/money/presentation/screens/money_trips_screen.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_header_button.dart';
import 'package:dony/features/payments/presentation/screens/mobile_money_account_screen.dart';
import 'package:dony/features/payments/presentation/screens/mobile_money_payout_account_add_screen.dart';
import 'package:dony/features/payments/presentation/screens/payment_screen.dart';
import 'package:dony/features/payments/presentation/screens/payout_onboarding_screen.dart';
import 'package:dony/features/payments/presentation/stripe_onboarding_return.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_active_currency_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_requests_list_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_availability_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_refund_requests_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_amount_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_selection.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_args.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_screen.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_address_edit_screen.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_addresses_screen.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/presentation/price_grid_screen.dart';
import 'package:dony/features/profile/bloc/faq_bloc.dart';
import 'package:dony/features/profile/bloc/open_listings_cubit.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/presentation/profile_screen.dart';
import 'package:dony/features/profile/presentation/screens/community_screen.dart';
import 'package:dony/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:dony/features/profile/presentation/screens/faq_screen.dart';
import 'package:dony/features/profile/presentation/screens/help_tutorial_screen.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/profile/presentation/screens/shipments_history_screen.dart';
import 'package:dony/features/profile/presentation/screens/upgrade_to_pro_screen.dart';
import 'package:dony/features/profile/presentation/widgets/add_contact_sheets.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/presentation/screens/my_reviews_screen.dart';
import 'package:dony/features/receptions/bloc/parcel_link_cubit.dart';
import 'package:dony/features/receptions/presentation/screens/parcel_link_screen.dart';
import 'package:dony/features/receptions/presentation/screens/reception_detail_screen.dart';
import 'package:dony/features/recipients/bloc/incoming_invitations_cubit.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/bloc/sent_invitations_cubit.dart';
import 'package:dony/features/recipients/presentation/screens/recipient_edit_screen.dart';
import 'package:dony/features/recipients/presentation/screens/recipient_invitations_screen.dart';
import 'package:dony/features/recipients/presentation/screens/recipients_screen.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/pending_referral_code_store.dart';
import 'package:dony/features/referral/data/pending_referral_redeemer.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dony/features/referral/presentation/screens/referral_screen.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/connected_devices_bloc.dart';
import 'package:dony/features/settings/bloc/data_export_bloc.dart';
import 'package:dony/features/settings/bloc/diagnostics_bloc.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/pin_status_cubit.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:dony/features/settings/presentation/screens/accessibility_settings_screen.dart';
import 'package:dony/features/settings/presentation/screens/blocked_users_screen.dart';
import 'package:dony/features/settings/presentation/screens/business_prefs_screen.dart';
import 'package:dony/features/settings/presentation/screens/change_pin_screen.dart';
import 'package:dony/features/settings/presentation/screens/connected_devices_screen.dart';
import 'package:dony/features/settings/presentation/screens/data_settings_screen.dart';
import 'package:dony/features/settings/presentation/screens/diagnostics_screen.dart';
import 'package:dony/features/settings/presentation/screens/legal_web_view_screen.dart';
import 'package:dony/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:dony/features/settings/presentation/screens/privacy_settings_screen.dart';
import 'package:dony/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/screens/account_disabled_screen.dart';
import 'package:dony/features/stripe_account/presentation/screens/account_rejected_screen.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_bloc.dart';
import 'package:dony/features/subscriptions/presentation/mes_abonnements_screen.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/screens/support_home_screen.dart';
import 'package:dony/features/support/presentation/screens/support_ticket_detail_screen.dart';
import 'package:dony/features/tracking/bloc/suivi_cubit.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/presentation/screens/offline_scan_queue_screen.dart';
import 'package:dony/features/tracking/presentation/screens/qr_picker_screen.dart';
import 'package:dony/features/tracking/presentation/screens/reception_confirm_screen.dart';
import 'package:dony/features/tracking/presentation/screens/scan_confirm_screen.dart';
import 'package:dony/features/tracking/presentation/screens/scan_identify_screen.dart';
import 'package:dony/features/tracking/presentation/screens/scan_photo_screen.dart';
import 'package:dony/features/tracking/presentation/screens/suivi_screen.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_recurrence_edit_screen.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_template_edit_screen.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_templates_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _publicRoutes = {
  '/onboarding',
  '/auth/method',
  '/auth/phone',
  '/auth/otp',
  '/auth/email',
  '/auth/email-otp',
  '/auth/referral-code',
  '/auth/analytics-consent',
  '/auth/country-selection',
  intentStepRoute,
  '/auth/personal-info',
  '/auth/local',
  '/home',
  '/recherche/composer',
  // Consultables sans compte : la mention légale de l'écran de connexion y
  // renvoie, et les relecteurs des deux boutiques les ouvrent avant de
  // s'inscrire.
  '/legal/terms',
  '/legal/privacy',
};

/// Décide si une navigation doit être détournée vers l'écran de connexion, et
/// renvoie `null` si elle peut aboutir.
///
/// C'est le seul rempart de l'application contre la navigation directe et les
/// liens profonds : la plupart des écrans protégés (paiement, KYC,
/// portefeuille) n'ont pas de garde propre et ne comptent que sur celui-ci.
///
/// [hasRealSession] : une session Firebase existe **et** appartient à un
/// utilisateur réel. Une session anonyme vaut `false`. Un simple
/// `currentUser != null` serait toujours vrai depuis l'ouverture de session
/// anonyme, et ce redirect ne bloquerait plus jamais rien.
///
/// Extrait du `redirect` du routeur pour rester vérifiable sans Firebase ni
/// montage de l'application (cf. `test/app/router_auth_redirect_test.dart`).
@visibleForTesting
/// Garde de la route `/profile/upgrade-to-pro` : tant que l'offre PRO est
/// fermée (`pro_enabled=false` côté backend), l'écran de vente est renvoyé
/// vers le profil. Fonction pure, testée sans monter le routeur.
String? resolveProRouteRedirect({required bool proEnabled}) =>
    proEnabled ? null : '/profile';

String? resolveAuthRedirect({
  required String matchedLocation,
  required String path,
  required bool hasRealSession,
}) {
  if (hasRealSession) return null;
  if (_publicRoutes.any(matchedLocation.startsWith)) return null;
  if (GuestAccessGuard.isPublicGuestPath(path)) return null;
  return '/auth/method';
}

/// Garde pays de la publication d'un trajet : le pays est demandé au moment
/// où il sert. Renvoie la sélection de pays avec `next` (la route à retrouver
/// ensuite), ou `null` si la navigation peut aboutir. Fonction pure, testée
/// sans monter le routeur.
@visibleForTesting
String? resolveCountryGuardRedirect({
  required String path,
  required bool countryEmpty,
  required bool travelerCountryUnsupported,
}) {
  if (path != '/trips/create') return null;
  if (!countryEmpty && !travelerCountryUnsupported) return null;
  return '/auth/country-selection?next=${Uri.encodeQueryComponent(path)}';
}

/// Route d'entrée, calculée par `resolveInitialLocation()` avant `runApp`
/// (cf. `lib/app/initial_location.dart`).
///
/// `appRouter` est un `final` de haut niveau : Dart l'initialise paresseusement,
/// au premier accès (le `MaterialApp.router` de `DonyApp`). Affecter cette
/// variable dans le bootstrap, avant `runApp`, est donc bien pris en compte.
/// Repli sur `/auth/method` si le bootstrap ne l'a pas renseignée (tests).
String initialAppLocation = '/auth/method';

/// Verrou de version minimale : calculé une fois avant `runApp`
/// (`AppUpdateService.isUpdateRequired()` dans `main.dart`), à partir de la
/// dernière valeur Remote Config déjà connue sur l'appareil — jamais de
/// réseau à cet instant. Repli sûr sur `false` si le bootstrap ne l'a pas
/// renseignée (tests) : une valeur non calculée ne doit jamais bloquer.
bool appUpdateRequired = false;

/// Provenance d'une étape passée en `extra` (identification → photo →
/// confirmation). Absente ou d'un autre type : rien n'est envoyé au back.
ScanMethod? _scanMethodExtra(Map<String, dynamic> extra) =>
    switch (extra['scanMethod']) {
      final ScanMethod method => method,
      _ => null,
    };

/// Chemin de l'écran affiché (onglets compris), lu sur le routeur.
String? replayCurrentPath() =>
    replayPathOf(appRouter.routerDelegate.currentConfiguration);

/// Met le replay en pause sur les écrans sensibles. Branché deux fois : sur
/// les navigations du routeur racine (feuilles, pages poussées) et sur chaque
/// changement de configuration du routeur (onglets), cf. `main.dart`.
final replayPrivacyObserver = ReplayPrivacyObserver.forAnalytics(
  currentPath: replayCurrentPath,
  analytics: () => getIt<AnalyticsService>(),
);

final GoRouter appRouter = GoRouter(
  initialLocation: initialAppLocation,
  // PosthogObserver : auto-capture des vues d'écran ($screen) à chaque
  // changement de route (no-op tant que le consentement n'est pas accordé).
  // `assistantModalObserver` : masque la bulle de l'assistant sous les
  // feuilles et les dialogues du navigateur racine.
  observers: [
    SentryNavigatorObserver(),
    PosthogObserver(routeFilter: posthogRouteFilter),
    // Replay de session : pause sur les écrans sensibles (paiement, identité,
    // messages, détail d'un colis…). Cf. `kReplaySensitivePathPrefixes`.
    replayPrivacyObserver,
    assistantModalObserver,
  ],
  redirect: (context, state) {
    // Prioritaire sur tout le reste (auth incluse) : une version qui plante
    // au premier statut de négociation inconnu ne doit jamais laisser
    // passer un utilisateur, connecté ou non. `matchedLocation` évite la
    // boucle une fois sur /force-update.
    if (appUpdateRequired && state.matchedLocation != '/force-update') {
      return '/force-update';
    }

    final authRedirect = resolveAuthRedirect(
      matchedLocation: state.matchedLocation,
      path: state.uri.path,
      hasRealSession: getIt<FirebaseSessionProbe>().hasRealSession,
    );
    if (authRedirect != null) {
      return authRedirect;
    }

    const guardedRoutes = {'/trips/create'};
    if (guardedRoutes.contains(state.matchedLocation)) {
      final travelerCountryUnsupported =
          getIt.isRegistered<HiveService>() &&
          getIt<HiveService>().userPrefs.get(
                HiveService.kTravelerCountryUnsupported,
                defaultValue: false,
              ) ==
              true;
      // Vide = ni le cache Hive ni les préférences synchronisées avec le
      // serveur ne connaissent le pays (une réinstallation peut vider Hive
      // alors que le serveur le sait : pas de détour dans ce cas).
      final hiveCountry = getIt.isRegistered<HiveService>()
          ? getIt<HiveService>().userPrefs.get(HiveService.kCountryCode)
          : null;
      final syncedCountry = context.read<BusinessPrefsBloc>().state.country;
      final countryEmpty =
          (hiveCountry is! String || hiveCountry.isEmpty) &&
          (syncedCountry == null || syncedCountry.isEmpty);
      final countryRedirect = resolveCountryGuardRedirect(
        path: state.matchedLocation,
        countryEmpty: countryEmpty,
        travelerCountryUnsupported: travelerCountryUnsupported,
      );
      if (countryRedirect != null) return countryRedirect;
      final accountState = context.read<StripeAccountBloc>().state;
      if (accountState is StripeAccountReady) {
        if (accountState.accountStatus.isDisabled) return '/account/disabled';
        if (accountState.accountStatus.isRejected) return '/account/rejected';
      }
    }

    return null;
  },
  routes: [
    // ── Verrou de version minimale ──────────────────────────────────────────
    GoRoute(
      path: '/force-update',
      builder: (context, state) => const ForceUpdateScreen(),
    ),
    // ── Auth (hors shell) ─────────────────────────────────────────────────
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
      path: '/auth/country-selection',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<CountryOnboardingCubit>(),
        child: CountrySelectionScreen(next: state.uri.queryParameters['next']),
      ),
    ),
    GoRoute(
      path: intentStepRoute,
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                getIt<IntentCubit>(param1: (intent: null, destination: null)),
          ),
          BlocProvider(create: (_) => getIt<GpProSignupCubit>()),
        ],
        child: IntentStepScreen(
          progress: readOnboardingProgress(
            context,
            reachedPast: OnboardingStep.country,
          ),
          args:
              state.extra as IntentStepArgs? ??
              const IntentStepArgs(next: '/auth/referral-code'),
        ),
      ),
    ),
    GoRoute(
      path: '/auth/personal-info',
      builder: (context, state) {
        // `AuthBloc.state.currentUser?.country` n'est jamais renseigné :
        // `POST /auth/register` n'écrit pas `users.country`. Le pays choisi
        // à l'étape précédente est prioritairement lu dans `extra` — passé
        // par `country_selection_screen.dart` juste après un `select()`
        // réussi, donc garanti frais. `BusinessPrefsBloc.state.country`
        // reste le repli : ce singleton app-wide est construit avant cet
        // écran et ne se resynchronise pas automatiquement quand
        // `CountryOnboardingCubit` écrit directement dans Hive, mais il
        // reste utile pour toute navigation qui ne passerait pas par
        // `country_selection_screen` (deep link, retour arrière...). Même
        // repli réutilisé pour `countryFallback` : sans lui, la jauge
        // afficherait l'étape « Pays » comme non faite juste après l'avoir
        // choisie (`readOnboardingProgress` ne le déduit pas seul).
        final country =
            (state.extra as String?) ??
            context.read<BusinessPrefsBloc>().state.country;
        return BlocProvider(
          create: (_) => getIt<PersonalInfoCubit>(),
          child: PersonalInfoScreen(
            country: country,
            // Préremplit ce que le profil sait déjà (retour sur l'étape
            // depuis le profil, second passage) — lu ici comme le reste de
            // l'état ambiant, jamais dans l'écran.
            user: context.read<AuthBloc>().state.currentUser,
            progress: readOnboardingProgress(
              context,
              current: OnboardingStep.personalInfo,
              countryFallback: country,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/auth/referral-code',
      builder: (context, state) => BlocProvider(
        create: (_) => ReferralBloc(
          getIt<ReferralRepository>(),
          getIt<AnalyticsService>(),
        ),
        // Aucune étape en cours : le parrainage est hors décompte (spec §4.2).
        // Même repli `extra ?? BusinessPrefsBloc` que `personal-info`
        // pour `countryFallback` : `personal_info_screen.dart` transmet
        // le pays en `extra` (repli immédiat, le temps que le
        // `AuthProfileRefreshRequested` déclenché juste avant revienne) —
        // sans lui, l'étape « Pays » regresserait sur cet écran (correction 1
        // de la revue finale du lot 2).
        child: ReferralCodeScreen(
          // Code venu d'un lien d'invitation ouvert avant l'inscription :
          // pré-rempli, jamais appliqué sans « Appliquer ».
          pendingCodeStore: getIt<PendingReferralCodeStore>(),
          progress: readOnboardingProgress(
            context,
            // Hors décompte mais pas hors position : le parrainage vient
            // juste après les informations, la jauge doit donc afficher
            // « 3 / 5 » et non retomber sur les seuls faits accomplis.
            reachedPast: OnboardingStep.personalInfo,
            countryFallback:
                (state.extra as String?) ??
                context.read<BusinessPrefsBloc>().state.country,
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/auth/analytics-consent',
      builder: (context, state) => AnalyticsConsentScreen(
        progress: readOnboardingProgress(
          context,
          current: OnboardingStep.consent,
        ),
      ),
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
        // `/kyc/verify` a deux entrées : le parcours d'onboarding (identité,
        // spec §2) et le profil (vérifier son identité à tout moment). Seul
        // ce query param les distingue — c'est lui qui décide si la jauge
        // s'affiche et si l'écran enchaîne sur l'étape suivante une fois
        // terminé ou passé, plutôt que de renvoyer droit à l'accueil comme
        // depuis le profil.
        final fromOnboarding =
            state.uri.queryParameters[onboardingEntryParam] ==
            onboardingEntryValue;
        final progress = fromOnboarding
            ? readOnboardingProgress(context, current: OnboardingStep.identity)
            : null;
        final returnTo = kycReturnRouteOrNull(
          state.uri.queryParameters[kycReturnParam],
        );

        final raw = state.extra;
        if (raw is! String) {
          return KycStatusScreen(progress: progress, returnTo: returnTo);
        }
        // Second filtre, en plus de celui de la webview elle-même : une URL
        // qui n'est pas celle d'un fournisseur connu ne doit même pas ouvrir
        // l'écran. Les deux partagent `isVerificationProviderHost` — quand la
        // liste vivait en double, ajouter Didit à la webview ne suffisait pas :
        // le routeur retombait silencieusement sur l'écran de statut, sans
        // message, et le parcours paraissait « ne rien faire ».
        final uri = Uri.tryParse(raw);
        final estFournisseurConnu =
            uri != null &&
            uri.scheme == 'https' &&
            isVerificationProviderHost(uri.host);
        if (!estFournisseurConnu) {
          return KycStatusScreen(progress: progress, returnTo: returnTo);
        }
        return BlocProvider(
          create: (_) => getIt<KycBloc>(),
          child: KycWebViewScreen(
            stripeUrl: raw,
            progress: progress,
            returnTo: returnTo,
          ),
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
      builder: (_, state) {
        // `extra` reste tolérant à l'annonce nue : tous les points d'entrée
        // historiques la passaient telle quelle.
        final extra = state.extra;
        final args = extra is CreateBidArgs
            ? extra
            : CreateBidArgs(announcement: extra! as AnnouncementModel);
        return CreateBidScreen(
          announcement: args.announcement,
          negotiation: args.negotiation,
        );
      },
    ),

    // ── Fil de négociation du prix d'un trajet (hors shell) ──────────────
    // Déclarée avant `/bids/:bidId` : GoRouter retient la première route qui
    // matche, et `:bidId` avalerait le segment `negotiation`.
    GoRoute(
      path: '/bids/:bidId/negotiation',
      builder: (context, state) {
        final bidId = state.pathParameters['bidId']!;
        // Sert seulement à poser les bulles du bon côté (FLUTTER-BM) : le fil
        // sait se replier sans lui.
        final authState = context.read<AuthBloc>().state;
        final userId = authState is AuthAuthenticated
            ? authState.user.id
            : authState is AuthProfileUpdated
            ? authState.user.id
            : null;
        return MultiBlocProvider(
          providers: [
            BlocProvider<BidNegotiationBloc>(
              create: (_) =>
                  getIt<BidNegotiationBloc>()
                    ..add(BidNegotiationFetchRequested(bidId)),
            ),
            // Accord en espèces côté voyageur (FLUTTER-H7) : le fil règle la
            // commission par le même flux que le détail du colis. Pas de
            // BidBloc ici : il masquerait le BidBloc global que
            // refreshActivityAfterBidChange rafraîchit ; le refus du colis
            // crée le sien sous la barre d'actions.
            BlocProvider<BidAcceptanceBloc>(
              create: (_) => getIt<BidAcceptanceBloc>(),
            ),
          ],
          child: BidNegotiationThreadScreen(
            bidId: bidId,
            viewerUserId: userId,
            archived: state.uri.queryParameters['archived'] == 'true',
          ),
        );
      },
    ),

    // ── Demande acceptée : écran de succès (hors shell) ──────────────────
    // Déclarée avant `/bids/:bidId`, même raison que `/negotiation`.
    GoRoute(
      path: '/bids/:bidId/accepted',
      builder: (_, state) =>
          BidAcceptedSuccessScreen(bidId: state.pathParameters['bidId']!),
    ),

    // ── Paiement mobile money d'un colis : écran d'attente (hors shell), pour
    //    un bid, un fil de négociation et le supplément de prix. Déclarées
    //    avant `/bids/:bidId`, même raison que `/negotiation`. Ouvertes par le
    //    bouton « Payer » de l'expéditeur ou par le retour Wave
    //    (`yadony://bids/{id}/supplements/{id}/…`).
    ...buildMobileMoneyAwaitingRoutes(),

    // ── Bid detail (hors shell) ──────────────────────────────────────────
    GoRoute(
      path: '/bids/:bidId',
      builder: (context, state) {
        final bid = state.extra is BidModel
            ? state.extra as BidModel
            : BidModel.skeleton(state.pathParameters['bidId']!);
        final fromPayment = state.uri.queryParameters['from'] == 'payment';
        // Notification CONFIRMATION_CODE_REQUESTED (FLUTTER-G2) : le voyageur
        // demande un nouveau code, la fiche ouvre directement la régénération.
        final action = state.uri.queryParameters['action'];
        return BidDetailScreen(
          bid: bid,
          fromPayment: fromPayment,
          openCodeRenewal: action == 'new-code',
          // Notifications de supplément (REQUESTED pour l'expéditeur, DECLINED
          // et EXPIRED pour le voyageur, EXPIRED aussi pour l'expéditeur) : la
          // fiche amène l'encart du supplément à l'écran.
          focusSupplement: action == 'supplement',
          // Notifications de modification de colis (voyageur ou expéditeur
          // selon le type) : la fiche amène la carte de la modification à
          // l'écran.
          focusAmendment: action == 'amendment',
        );
      },
    ),

    // Écran de succès « Offre acceptée et payée ! » d'un fil séquestré (hors
    // shell) : poussé par la feuille de récapitulatif au retour de l'écran
    // d'attente mobile money. Le CTA ramène sur le fil via `go`.
    GoRoute(
      path: '/negotiations/:id/paid',
      builder: (_, state) =>
          NegotiationPaidSuccessScreen(threadId: state.pathParameters['id']!),
    ),
    // Écran de succès « Ce colis est à toi ! » (hors shell) : poussé par le
    // fil quand le voyageur a réglé la commission d'un accord en espèces.
    GoRoute(
      path: '/negotiations/:id/commission-settled',
      builder: (_, state) => NegotiationCommissionSettledScreen(
        threadId: state.pathParameters['id']!,
      ),
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
            // Colis remis puis annulé : bandeau « à récupérer » (billet_talon).
            parcelReturn: state.uri.queryParameters['retour'] == '1',
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
    // Ancien lecteur QR plein écran, remplacé par Suivi › Valider
    // (YADONY-FLUTTER-PROD-1S) : la route reste pour les vieux liens et le
    // deep link `yadony://tracking/scan`.
    GoRoute(
      path: '/tracking/scan',
      redirect: (_, _) => '/tracking?mode=${SuiviMode.valider.name}',
    ),
    // Mode Valider sur le trajet d'un colis, poussé depuis son détail : le
    // retour ramène au colis, ce que l'onglet Suivi (go) ne permettait pas
    // (FLUTTER-9N).
    GoRoute(
      path: '/tracking/validate',
      builder: (context, state) => SuiviScreen(
        requestedMode: SuiviMode.valider,
        tripId: state.uri.queryParameters['trip'],
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
          returnResult: extra['returnResult'] as bool? ?? false,
          scanMethod: _scanMethodExtra(extra),
          deliveryWindow: extra['deliveryWindow'] as DeliveryWindow?,
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
            gpsLabel: extra['gpsLabel'] as String?,
            packageLabel: extra['packageLabel'] as String? ?? '',
            scanMethod: _scanMethodExtra(extra),
            deliveryWindow: extra['deliveryWindow'] as DeliveryWindow?,
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
          BlocProvider(create: (_) => getIt<PinnedTripsCubit>()),
          BlocProvider(
            create: (_) => getIt<TripFilterCubit>()
              ..seedFilter(
                resolveTripFilter(state.uri.queryParameters['filter']),
              ),
          ),
          BlocProvider.value(value: getIt<NegotiationListBloc>()),
        ],
        child: const AnnouncementListScreen(showBackButton: true),
      ),
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
        return MultiBlocProvider(
          providers: [
            BlocProvider<TripTemplateBloc>(
              create: (_) => getIt<TripTemplateBloc>(),
            ),
            BlocProvider<AnnouncementFormBloc>(
              create: (_) => getIt<AnnouncementFormBloc>(),
            ),
            BlocProvider<MobileMoneyAccountBloc>(
              create: (_) =>
                  getIt<MobileMoneyAccountBloc>()
                    ..add(const MobileMoneyAccountsRequested()),
            ),
            // `.value` obligatoire : StripeAccountBloc est un lazySingleton
            // GetIt partagé par toute l'app (cf. create_trip_screen.dart).
            BlocProvider<StripeAccountBloc>.value(
              value: getIt<StripeAccountBloc>(),
            ),
          ],
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
    // Après le code : prénom, nom et pays, tout facultatif (voir
    // ProfileBasicsScreen). Le pays proposé vient du numéro du compte.
    GoRoute(
      path: profileBasicsRoute,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ProfileBasicsCubit>(),
        child: ProfileBasicsScreen(
          redeemer: getIt<PendingReferralRedeemer>(),
          initialCountryCode: countryFromPhone(
            context.read<AuthBloc>().state.currentUser?.phoneNumber,
          ),
        ),
      ),
    ),
    // Fin d'inscription : choix de la première action (voir FirstStepsScreen).
    GoRoute(
      path: firstStepsRoute,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            getIt<IntentCubit>(param1: (intent: null, destination: null)),
        child: const FirstStepsScreen(),
      ),
    ),
    GoRoute(
      path: '/payments/onboarding',
      builder: (context, state) {
        // Même double entrée que `/kyc/verify` : onboarding (paiements,
        // dernière étape comptée) ou profil (« Recevoir mes paiements »
        // dans Réglages, à tout moment).
        final fromOnboarding =
            state.uri.queryParameters[onboardingEntryParam] ==
            onboardingEntryValue;
        return BlocProvider(
          create: (_) => getIt<PaymentBloc>(),
          child: PayoutOnboardingScreen(
            progress: fromOnboarding
                ? readOnboardingProgress(
                    context,
                    current: OnboardingStep.payouts,
                  )
                : null,
          ),
        );
      },
    ),
    GoRoute(
      path: '/payments/mobile-money/account',
      name: '/payments/mobile-money/account',
      builder: (_, _) => BlocProvider(
        create: (_) =>
            getIt<MobileMoneyAccountBloc>()
              ..add(const MobileMoneyAccountsRequested()),
        child: const MobileMoneyAccountScreen(),
      ),
      routes: [
        // « Ajouter un compte », ou « Changer de numéro » avec `account`
        // (identifiant), `provider` et `country` du compte. Son propre BLoC
        // relit la liste (opérateurs déjà ajoutés, compte à changer) ; le
        // composant « compte qui paie » lit le catalogue des versements,
        // réglé par l'écran. Rend `true` après une écriture réussie.
        GoRoute(
          path: 'add',
          name: '/payments/mobile-money/account/add',
          builder: (_, state) {
            final query = state.uri.queryParameters;
            final provider = query['provider'];
            final country = query['country'];
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      getIt<MobileMoneyAccountBloc>()
                        ..add(const MobileMoneyAccountsRequested()),
                ),
                BlocProvider<PayerAccountCubit>(
                  create: (_) =>
                      getIt<PayerAccountCubit>(param1: payerAccountPayoutFlow),
                ),
              ],
              child: MobileMoneyPayoutAccountAddScreen(
                accountId: query['account'],
                fixed: provider != null && country != null
                    ? (country: country, operator: provider)
                    : null,
              ),
            );
          },
        ),
      ],
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
    // ── Mon argent (hors shell, FLUTTER-HV) ──────────────────────────────
    GoRoute(
      path: kMoneyOverviewRoute,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            getIt<MoneyOverviewBloc>(param1: false)
              ..add(const MoneyOverviewLoadRequested()),
        child: const MoneyOverviewScreen(),
      ),
    ),
    // « Mes trajets » de « Mon argent » (écran D), filtrable sur un trajet.
    GoRoute(
      path: kMoneyTripsRoute,
      builder: (context, state) {
        final announcementId = state.uri.queryParameters['announcementId'];
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  getIt<MoneyOverviewBloc>(param1: true)
                    ..add(const MoneyOverviewLoadRequested()),
            ),
            BlocProvider(
              create: (_) => getIt<MoneyTripsCubit>(param1: announcementId),
            ),
          ],
          child: MoneyTripsScreen(announcementId: announcementId),
        );
      },
    ),
    // ── Wallet (hors shell) ──────────────────────────────────────────────
    GoRoute(
      path: '/payments/wallet',
      builder: (context, state) {
        // Poussé par l'écran d'attente mobile money via `context.go(extra:
        // {'topupConfirmed': status})` : bandeau de confirmation affiché une
        // fois par `WalletScreen`. Absent sur toute autre entrée (menu,
        // retour arrière).
        final extra = state.extra as Map<String, dynamic>?;
        final topupConfirmed =
            extra?['topupConfirmed'] as WalletTopupStatusModel?;
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => getIt<WalletBloc>()..add(WalletLoadRequested()),
            ),
            BlocProvider(create: (_) => getIt<WalletRefundRequestCubit>()),
            BlocProvider(create: (_) => getIt<WalletActiveCurrencyCubit>()),
          ],
          child: WalletScreen(topupConfirmed: topupConfirmed),
        );
      },
    ),
    GoRoute(
      path: '/payments/wallet/refunds',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<WalletRefundRequestsListCubit>(),
        child: const WalletRefundRequestsScreen(),
      ),
    ),
    GoRoute(
      path: '/payments/wallet/topup/method',
      // Le cubit mobile money vit ici, au niveau de la route : cet écran
      // reste empilé (jamais dépilé) tant que l'écran de montant puis
      // d'attente sont poussés par-dessus, si bien que la même instance
      // survit à tout le parcours de recharge — elle est transmise en aval
      // via WalletTopupMethodSelection.cubit, jamais recréée.
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<WalletTopupMobileMoneyCubit>(
            create: (_) => getIt<WalletTopupMobileMoneyCubit>(),
          ),
          // Compte qui paie (pays, opérateur, numéro) : catalogue des pays
          // chargé dès l'ouverture, préremplissage de la dernière recharge.
          BlocProvider<PayerAccountCubit>(
            create: (_) => getIt<PayerAccountCubit>(param1: 'topup')..load(),
          ),
          // Sonde la disponibilité du rail mobile money côté backend dès
          // l'ouverture : la tuile n'apparaît qu'en cas de réponse positive.
          BlocProvider<WalletTopupMobileMoneyAvailabilityCubit>(
            create: (_) =>
                getIt<WalletTopupMobileMoneyAvailabilityCubit>()..probe(),
          ),
        ],
        child: const WalletTopupMethodScreen(),
      ),
    ),
    GoRoute(
      path: '/payments/wallet/topup/amount',
      builder: (context, state) {
        final selection = state.extra as WalletTopupMethodSelection;
        if (selection.method == 'MOBILE_MONEY') {
          return BlocProvider<WalletTopupMobileMoneyCubit>.value(
            value: selection.cubit!,
            child: WalletTopupAmountScreen(
              paymentMethod: selection.method,
              mobileMoneyPhoneNumber: selection.phoneNumber,
              mobileMoneyCurrency: selection.currency,
              mobileMoneyOperator: selection.operator,
            ),
          );
        }
        return BlocProvider(
          create: (_) => getIt<WalletBloc>(),
          child: WalletTopupAmountScreen(paymentMethod: selection.method),
        );
      },
    ),
    GoRoute(
      path: '/payments/wallet/topup/mobile-money/awaiting',
      builder: (context, state) {
        final args = state.extra as WalletTopupMobileMoneyAwaitingArgs;
        return BlocProvider<WalletTopupMobileMoneyCubit>.value(
          value: args.cubit,
          child: WalletTopupMobileMoneyAwaitingScreen(
            phoneNumber: args.phoneNumber,
            amount: args.amount,
          ),
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
    // ── Stripe Connect deep-link return routes ───────────────────────────
    // Retour vers l'écran qui a ouvert le lien (voir StripeOnboardingReturn),
    // l'intro « devenir voyageur » restant le repli.
    GoRoute(
      path: '/stripe/onboarding/complete',
      redirect: (context, state) =>
          StripeOnboardingReturn.consume() ??
          '/connect/onboarding/intro?from=stripe',
    ),
    GoRoute(
      path: '/stripe/onboarding/refresh',
      redirect: (context, state) =>
          StripeOnboardingReturn.consume() ?? '/connect/onboarding/intro',
    ),
    // ── Boîte « Annonces Yadony » (hors shell) ───────────────────────────
    GoRoute(
      path: AnnouncementsInboxScreen.route,
      builder: (_, _) => const AnnouncementsInboxScreen(),
    ),
    // Détail générique d'une notification (annonces plateforme, texte complet).
    // Déclaré après « annonces » : le segment littéral doit gagner sur `:id`.
    GoRoute(
      path: '/notifications/:id',
      builder: (_, state) =>
          NotificationDetailScreen(id: state.pathParameters['id']!),
    ),

    // ── Demandes d'expéditeurs (hors shell) ──────────────────────────────
    // Invitations « destinataire Yadony » reçues (lot 4) : notification
    // RECIPIENT_INVITATION, bandeau de l'onglet Suivi, Confidentialité.
    GoRoute(
      path: '/recipient-invitations',
      builder: (_, _) => BlocProvider(
        create: (_) => getIt<IncomingInvitationsCubit>()..load(),
        child: const RecipientInvitationsScreen(),
      ),
    ),

    // ── Colis à recevoir (hors shell) ────────────────────────────────────
    // Ouvert depuis la section de l'onglet Suivi et les notifications
    // RECIPIENT_PARCEL_* (deeplink `yadony://receptions/{bidId}`).
    GoRoute(
      path: '/receptions/:bidId',
      builder: (_, state) =>
          ReceptionDetailScreen(bidId: state.pathParameters['bidId']!),
    ),

    // ── Lien colis depuis la page publique du QR (yadony://colis/{id}) ─────
    // Écran de transition : ouvre Réceptions ou la fiche du colis selon le
    // rôle de l'utilisateur. Hors shell, derrière l'authentification.
    GoRoute(
      path: '/colis/:bidId',
      builder: (_, state) {
        final bidId = state.pathParameters['bidId']!;
        return BlocProvider(
          create: (_) => getIt<ParcelLinkCubit>()..load(bidId),
          child: ParcelLinkScreen(bidId: bidId),
        );
      },
    ),

    // ── Billets d'avion : ancien onglet, désormais dans Activités ─────────
    // `/flights` reste un chemin valide (anciens liens, raccourcis internes) :
    // il ouvre l'écran Billets par-dessus le hub Activités.
    GoRoute(path: '/flights', redirect: (_, _) => '/announcements/flights'),

    // ── Alertes prix des billets (hors shell) ────────────────────────────
    // Cloche de l'écran Billets, notification FLIGHT_PRICE_ALERT et deeplink
    // `yadony://flights/alerts`.
    GoRoute(
      path: '/flights/alerts',
      redirect: (_, _) async => await flightsEnabledResolved() ? null : '/home',
      builder: (_, _) => const FlightAlertsScreen(),
      routes: [
        // Vols trouvés par une alerte : « Voir » de « Mes alertes » (l'alerte
        // en `extra`) et notification FLIGHT_PRICE_ALERT
        // (`?source=notification`). Hors shell comme « Mes alertes », d'où
        // il s'ouvre : poussé depuis une page racine, un écran de la branche
        // Activités passerait dessous.
        GoRoute(
          path: ':id/offers',
          name: '/flights/alerts/:id/offers',
          builder: (_, state) => FlightAlertOffersScreen(
            alertId: state.pathParameters['id']!,
            alert: state.extra is FlightAlert
                ? state.extra! as FlightAlert
                : null,
            source: FlightAlertOffersSource.parse(
              state.uri.queryParameters['source'],
            ),
          ),
        ),
      ],
    ),
    // « Où allez-vous ? » : choix des villes d'un billet, en plein écran par
    // dessus la barre du bas. Sans `extra` (lien direct), champ destination.
    GoRoute(
      path: '/flights/city',
      redirect: (_, _) async => await flightsEnabledResolved() ? null : '/home',
      builder: (_, state) => FlightCityPickerScreen(
        args: state.extra is FlightRoutePickerArgs
            ? state.extra! as FlightRoutePickerArgs
            : const FlightRoutePickerArgs(departure: false),
      ),
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
      // Depuis la liste, l'alerte voyage en extra ; depuis un push (digest),
      // seul l'id est connu et l'écran la charge lui-même.
      builder: (context, state) => CorridorAlertMatchesScreen(
        alertId: state.pathParameters['id'],
        alert: state.extra is CorridorAlertModel
            ? state.extra as CorridorAlertModel
            : null,
      ),
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
    // ── Messagerie — archives (hors shell) ───────────────────────────────
    GoRoute(
      path: '/messages/archives',
      builder: (context, state) => BlocProvider.value(
        value: getIt<ConversationListBloc>(),
        child: const ArchivedConversationsScreen(),
      ),
    ),

    // ── Messagerie — conversation individuelle (hors shell) ─────────────
    // Appel audio Yadony, sortant (depuis une conversation) ou entrant
    // (décroché). `:callId` vaut `pending` tant que le back n'a pas créé
    // l'appel ; les détails passent par `extra` (CallScreenArgs), ou par
    // l'URL pour un appel entrant (CallScreenArgs.incomingLocation).
    GoRoute(
      path: '/calls/:callId',
      pageBuilder: (context, state) {
        final args = state.extra is CallScreenArgs
            ? state.extra! as CallScreenArgs
            : CallScreenArgs.fromRoute(
                state.pathParameters['callId']!,
                state.uri.queryParameters,
              );
        // Le bloc de l'appel vit dans ActiveCallHolder, pas dans la route :
        // réduire l'écran (ou le retour système) ne raccroche plus. La barre
        // d'appel rouvre l'appel par `activeCallLocation`.
        return CustomTransitionPage<void>(
          key: state.pageKey,
          name: '/calls',
          child: ActiveCallScope(args: args),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        );
      },
    ),
    // Photos du chat (FLUTTER-B4) : aperçu avant envoi (rend `true` sur
    // « Envoyer ») et visionneuse plein écran. Sans extra (lien restauré),
    // retour à la messagerie.
    GoRoute(
      path: '/chat/photo-preview',
      redirect: (context, state) =>
          state.extra is Uint8List ? null : '/messages',
      pageBuilder: (context, state) => CustomTransitionPage<bool>(
        key: state.pageKey,
        name: '/chat/photo-preview',
        child: ChatPhotoPreviewScreen(bytes: state.extra! as Uint8List),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/chat/photo',
      redirect: (context, state) =>
          state.extra is ChatPhotoViewerArgs ? null : '/messages',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        name: '/chat/photo',
        // Non opaque : en glissant la photo vers le bas, la conversation
        // réapparaît derrière (FLUTTER-GR).
        opaque: false,
        child: ChatPhotoViewerScreen(args: state.extra! as ChatPhotoViewerArgs),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/conversations/:id',
      builder: (context, state) {
        // Navigation interne (liste, fiche bid) : le modèle complet arrive en
        // extra. Depuis une notification (push ou boîte de réception), seul
        // l'id est disponible → ConversationLoaderScreen le récupère par API.
        if (state.extra is ConversationModel) {
          final conversation = state.extra as ConversationModel;
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => getIt<ChatBloc>()),
              // Le numéro n'est plus dans la conversation : il est demandé au tap.
              BlocProvider(create: (_) => getIt<ContactRevealBloc>()),
              BlocProvider(
                create: (_) =>
                    getIt<ConversationNotificationsCubit>(param1: conversation),
              ),
            ],
            child: ChatScreen(conversation: conversation),
          );
        }
        return ConversationLoaderScreen(
          conversationId: state.pathParameters['id']!,
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
          title: extra?['title'] as String? ?? context.l10n.shellRequestsTitle,
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
            // Chargé par TripAudienceSection, monté pour le seul propriétaire.
            BlocProvider(create: (_) => getIt<TripAudienceCubit>()),
            // Étapes du voyage (FLUTTER-4D) : carte « Étape i/n » et
            // proposition d'annuler les étapes suivantes.
            BlocProvider(create: (_) => getIt<TripGroupCubit>()..load(id)),
          ],
          child: TripOwnerDetailScreen(announcementId: id, initial: extra),
        );
      },
    ),

    // ── Affiche de trajet (hors shell — plein écran) ─────────────────────
    // Même contrat que `/announcements/:id/trip` : l'identifiant suffit, et
    // `extra` n'est qu'un raccourci d'affichage immédiat pour les appelants qui
    // tiennent déjà le trajet (succès de publication, détail propriétaire).
    GoRoute(
      path: '/announcements/:id/affiche',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra is AnnouncementModel
            ? state.extra as AnnouncementModel
            : null;
        return BlocProvider(
          create: (_) =>
              getIt<AnnouncementBloc>()..add(AnnouncementDetailRequested(id)),
          child: TripPosterRoute(initial: extra),
        );
      },
    ),

    // ── Suivi hors-ligne (hors shell) ────────────────────────────────────
    GoRoute(
      path: '/tracking/offline-queue',
      builder: (context, state) => const OfflineScanQueueScreen(),
    ),

    // ── Anciennes entrées du suivi ───────────────────────────────────────
    // Recherche et hub de scan vivent désormais dans l'onglet Suivi : ces
    // chemins (liens et notifications déjà émis) y mènent avec le bon mode.
    GoRoute(
      path: '/tracking/search',
      redirect: (_, _) => '/tracking?mode=${SuiviMode.suivre.name}',
    ),
    GoRoute(
      path: '/tracking/scan-hub',
      redirect: (_, _) => '/tracking?mode=${SuiviMode.valider.name}',
    ),

    // ── Mes colis — hub expéditeur (hors shell) ───────────────────────

    // ── Envois et demandes — destinations du hub Activités ────────────
    // MesColisScreen pose lui-même ses providers (BidBloc + PackageRequestBloc)
    // et laisse chaque volet déclencher son propre chargement.
    GoRoute(
      path: '/envois',
      builder: (_, state) => MesColisScreen(
        initialStatuses: resolveShipmentStatuses(
          state.uri.queryParameters['status'],
        ),
      ),
    ),
    // `?bid=<id>` : posé par la notification « Nouvelle demande d'envoi »,
    // ouvre cette demande par-dessus la liste (validé comme UUID par l'écran).
    // `?filter=<onglet>` (nom de `TravelerBidFilter`) impose l'onglet, et
    // `?announcement=<uuid>` restreint la liste à un trajet : posés par la
    // tuile « Demandes » de la fiche trajet. Une valeur inconnue ou un id qui
    // n'est pas un UUID sont ignorés (écran ouvert comme sans paramètre).
    GoRoute(
      path: '/demandes',
      builder: (_, state) => DemandesScreen(
        focusBidId: state.uri.queryParameters['bid'],
        initialFilter: resolveTravelerBidFilter(
          state.uri.queryParameters['filter'],
        ),
        announcementId: validUuidParam(
          state.uri.queryParameters['announcement'],
        ),
      ),
    ),

    // ── Profile — quick wins (hors shell) ────────────────────────────
    GoRoute(
      path: '/profile/help/faq',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<FaqBloc>(),
        child: const FaqScreen(),
      ),
    ),
    GoRoute(
      path: '/profile/community',
      builder: (context, state) => const CommunityScreen(),
    ),
    buildHelpTutorialRoute(),
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
          name: '/profile/addresses/new',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<PickupAddressBloc>()..add(const PickupAddressLoaded()),
            child: const PickupAddressEditScreen(),
          ),
        ),
        GoRoute(
          path: ':id',
          name: '/profile/addresses/:id',
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
          name: '/profile/addresses/delivery/new',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<DeliveryAddressBloc>()
                  ..add(const DeliveryAddressLoaded()),
            child: const DeliveryAddressEditScreen(),
          ),
        ),
        GoRoute(
          path: 'delivery/:id',
          name: '/profile/addresses/delivery/:id',
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
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => getIt<RecipientBloc>()..add(const RecipientLoaded()),
          ),
          // Invitations « destinataire Yadony » (lot 4), silencieuses en
          // échec.
          BlocProvider(create: (_) => getIt<SentInvitationsCubit>()..load()),
        ],
        child: const RecipientsScreen(),
      ),
      routes: [
        GoRoute(
          path: 'new',
          name: '/profile/recipients/new',
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
          name: '/profile/recipients/:id',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<RecipientBloc>()..add(const RecipientLoaded()),
            child: RecipientEditScreen(recipientId: state.pathParameters['id']),
          ),
        ),
      ],
    ),

    // ── Profil d'un voyageur suivi (hors shell) ──────────────────────
    // Le profil public, avec la section « En cours » de ses annonces ouvertes.
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
            BlocProvider(create: (_) => getIt<TravelerSubscribeBloc>()),
            BlocProvider(create: (_) => getIt<OpenListingsCubit>()..load(id)),
          ],
          child: ProfilePublicScreen(userId: id),
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
    GoRoute(
      path: '/profile/edit/email',
      builder: (context, state) => const EditEmailScreen(),
    ),
    GoRoute(
      path: '/profile/edit/phone',
      builder: (context, state) => const EditPhoneScreen(),
    ),

    // ── Upgrade PRO (hors shell) ──────────────────────────────────────
    GoRoute(
      path: '/profile/upgrade-to-pro',
      // Offre PRO fermée : la route n'a plus d'entrée dans l'interface, mais
      // un lien profond ou une ancienne notification peuvent encore la viser.
      redirect: (context, state) =>
          resolveProRouteRedirect(proEnabled: proEnabledListenable.value),
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
        // `?code=` : lien d'invitation ouvert par un compte connecté
        // (`yadony://referral?code=…`, voir `referral_deep_link.dart`).
        child: ReferralScreen(
          prefillCode: PendingReferralCodeStore.normalize(
            state.uri.queryParameters['code'],
          ),
          pendingCodeStore: getIt<PendingReferralCodeStore>(),
        ),
      ),
    ),

    // ── GP Pro : demande et statut du badge (hors shell) ──────────────
    GoRoute(
      path: '/profile/gp-pro',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<GpProCubit>()..load(),
        child: const GpProScreen(),
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
            BlocProvider(
              create: (_) =>
                  getIt<OpenListingsCubit>()..load(args.userId ?? ''),
            ),
          ],
          child: ProfilePublicScreen(userId: args.userId),
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
          name: '/settings/security',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<PinStatusCubit>()..refresh(),
            child: const SecuritySettingsScreen(),
          ),
          routes: [
            GoRoute(
              path: 'change-pin',
              name: '/settings/security/change-pin',
              builder: (context, state) =>
                  ChangePinScreen(authService: getIt<LocalAuthService>()),
            ),
            // Première configuration : aucun code actuel à vérifier.
            GoRoute(
              path: 'create-pin',
              name: '/settings/security/create-pin',
              builder: (context, state) => ChangePinScreen(
                authService: getIt<LocalAuthService>(),
                isCreation: true,
              ),
            ),
            GoRoute(
              path: 'devices',
              name: '/settings/security/devices',
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
          name: '/settings/privacy',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<PrivacySettingsBloc>()
                  ..add(const PrivacySettingsLoadRequested()),
            child: const PrivacySettingsScreen(),
          ),
          routes: [
            GoRoute(
              path: 'blocked-users',
              name: '/settings/privacy/blocked-users',
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
          name: '/settings/data',
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
          name: '/settings/notifications',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<NotificationPrefsBloc>(),
            child: const NotificationSettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'preferences',
          name: '/settings/preferences',
          builder: (context, state) => const BusinessPrefsScreen(),
        ),
        GoRoute(
          path: 'accessibility',
          name: '/settings/accessibility',
          builder: (context, state) => BlocProvider.value(
            value: getIt<AccessibilityBloc>(),
            child: const AccessibilitySettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'diagnostics',
          name: '/settings/diagnostics',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<DiagnosticsBloc>(),
            child: const DiagnosticsScreen(),
          ),
        ),
        GoRoute(
          path: 'report-incident',
          name: '/settings/report-incident',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final targetType =
                extra?['targetType'] as IncidentTargetType? ??
                IncidentTargetType.app;
            final targetId = extra?['targetId'] as String?;
            // Signalement d'un message du chat (FLUTTER-B4) : targetId est la
            // conversation, messageId le message Firestore.
            final messageId = extra?['messageId'] as String?;
            return MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => getIt<IncidentReportCubit>()),
                BlocProvider(create: (_) => getIt<IncidentPhotosCubit>()),
              ],
              child: IncidentReportScreen(
                targetType: targetType,
                targetId: targetId,
                messageId: messageId,
              ),
            );
          },
        ),
      ],
    ),

    // ── Pages légales (hors shell, publiques) ────────────────────────────
    // Ces deux écrans vivaient sous `/settings/legal/…`, donc derrière la
    // garde d'authentification : la mention « En continuant tu acceptes nos
    // CGU » de l'écran de connexion pointait vers une route qui renvoyait le
    // visiteur déconnecté sur `/auth/method`. Or Apple (2.1) comme Google
    // ouvrent ces liens **avant** de créer un compte. Le chemin est désormais
    // de premier niveau, calqué sur l'URL web, et listé dans `_publicRoutes`.
    GoRoute(
      path: '/legal/terms',
      builder: (context, state) => LegalWebViewScreen(
        title: context.l10n.shellTermsTitle,
        url: 'https://yadony.com/legal/terms',
      ),
    ),
    GoRoute(
      path: '/legal/privacy',
      builder: (context, state) => LegalWebViewScreen(
        title: context.l10n.shellPrivacyPolicyTitle,
        url: 'https://yadony.com/legal/privacy',
      ),
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

    // ── Écran de composition de recherche (hors shell — plein écran) ─────
    // Remplace l'ancienne `SearchFilterSheet` comme point d'entrée « Filtrer »
    // de l'onglet Rechercher (`HomeScreen._openComposer`). `activeTrips` et
    // `onPublishTrip` sont facultatifs dans `extra` : absents, le garde-fou
    // « Pour mes trajets » reste utilisable (nombre inconnu) mais son CTA
    // « Publier un trajet » ne fait rien, aucun appelant réel n'omet ces clés.
    GoRoute(
      path: '/recherche/composer',
      builder: (context, state) {
        final extra = state.extra as Map? ?? {};
        final mode = (extra['mode'] as SearchMode?) ?? SearchMode.trips;
        final filters =
            (extra['filters'] as HomeSearchFilters?) ??
            const HomeSearchFilters();
        return BlocProvider(
          create: (_) => SearchComposerBloc(
            getIt<AnnouncementRepository>(),
            getIt<PackageRequestRepository>(),
            getIt<AnalyticsService>(),
            mode: mode,
            initialFilters: filters,
          ),
          child: SearchComposerScreen(
            mode: mode,
            initialFilters: filters,
            activeTrips: extra['activeTrips'] as int?,
            onPublishTrip: extra['onPublishTrip'] as VoidCallback?,
          ),
        );
      },
    ),

    // ── Shell principal avec Bottom Navigation ───────────────────────────
    // Règle : les 5 racines de tabs ; seule Activités porte deux sous-pages
    // (Billets d'avion, statistiques), ouvertes sous la barre d'onglets.
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
        //
        // Ses deux sous-pages s'ouvrent par-dessus le hub, dans la branche :
        // la barre d'onglets reste visible et Activités reste sélectionné.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/announcements',
              builder: (context, state) => const ActivitesHubScreen(),
              routes: [
                // Billets d'avion (flag flights_enabled), ouverts depuis le
                // bloc « Billets d'avion » du hub. `extra` : un bon plan
                // touché dans le hub, dont la recherche part à l'ouverture.
                GoRoute(
                  path: 'flights',
                  name: '/announcements/flights',
                  redirect: (_, _) async =>
                      await flightsEnabledResolved() ? null : '/home',
                  builder: (context, state) => FlightsScreen(
                    launch: state.extra is FlightsLaunch
                        ? state.extra! as FlightsLaunch
                        : null,
                  ),
                  routes: [
                    // Alias des vols trouvés par une alerte, rangé sous
                    // Billets : l'écran vit hors shell, avec « Mes alertes ».
                    GoRoute(
                      path: 'alerts/:id/offers',
                      name: '/announcements/flights/alerts/:id/offers',
                      redirect: (_, state) =>
                          '/flights/alerts/${state.pathParameters['id']}/offers'
                          '${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
                    ),
                  ],
                ),
                // Statistiques (revenus, kg vendus, trajets, colis), sorties
                // du hub vers le menu ☰.
                GoRoute(
                  path: 'stats',
                  name: '/announcements/stats',
                  builder: (context, state) => const ActivityStatsScreen(),
                ),
              ],
            ),
          ],
        ),

        // Branch 2 — Suivi (valider une étape | suivre un colis)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tracking',
              builder: (context, state) => SuiviScreen(
                requestedMode: suiviModeFromQuery(
                  state.uri.queryParameters['mode'],
                ),
                requestedSegment: suiviSegmentFromQuery(
                  state.uri.queryParameters['segment'],
                ),
              ),
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
                  BlocProvider(
                    create: (_) =>
                        getIt<WalletBloc>()..add(WalletLoadRequested()),
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
      builder: (_, state) => PackageRequestCreateScreen(
        initial: state.extra is PackageRequest
            ? state.extra as PackageRequest
            : null,
        duplicating: state.extra is PackageRequestDuplicate
            ? state.extra as PackageRequestDuplicate
            : null,
        resuming: state.extra is PackageRequestDraftResume
            ? state.extra as PackageRequestDraftResume
            : null,
      ),
    ),
    GoRoute(
      path: '/package-requests/:id',
      builder: (_, state) =>
          PackageRequestDetailScreen(requestId: state.pathParameters['id']!),
    ),
    // Affiche partageable d'une demande d'envoi (hors shell). Même contrat
    // que `/announcements/:id/affiche` : l'identifiant suffit, `extra` n'est
    // qu'un raccourci d'affichage pour l'appelant qui tient déjà la demande.
    GoRoute(
      path: '/package-requests/:id/affiche',
      builder: (_, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra is PackageRequest
            ? state.extra as PackageRequest
            : null;
        return BlocProvider(
          create: (_) => getIt<PackageRequestDetailCubit>(param1: id)..load(),
          child: PackageRequestPosterRoute(initial: extra),
        );
      },
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
      builder: (_, _) => const MyNegotiationsScreen(),
    ),
    // Avant `/negotiations/:id`, qui capterait sinon « archives » comme un id.
    GoRoute(
      path: '/negotiations/archives',
      builder: (_, _) => const ArchivedNegotiationsScreen(),
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
    GoRoute(
      path: '/assistant',
      // Singleton : `.value` pour que le BLoC ne soit pas fermé à la sortie de
      // l'écran (l'historique survit à la fermeture). `source` : `bubble` ou
      // `messages_header` (analytics).
      builder: (_, state) => MultiBlocProvider(
        providers: [
          BlocProvider<AssistantBloc>.value(value: getIt<AssistantBloc>()),
          // Dictée : une instance par écran, arrêtée à la fermeture.
          BlocProvider<AssistantVoiceCubit>(
            create: (_) => getIt<AssistantVoiceCubit>(),
          ),
        ],
        child: AssistantScreen(
          source: state.uri.queryParameters['source'] ?? 'bubble',
          screen: state.uri.queryParameters['screen'],
          parcelId: state.uri.queryParameters['parcel'],
        ),
      ),
    ),
    GoRoute(
      path: '/support',
      // `extra` : demande préremplie (colis annulé par l'équipe, FLUTTER-R4).
      // Toute autre valeur est ignorée : l'écran s'ouvre comme d'habitude.
      builder: (_, state) => BlocProvider(
        create: (_) => getIt<SupportBloc>()..add(const SupportHomeRequested()),
        child: SupportHomeScreen(
          draft: switch (state.extra) {
            final SupportTicketDraft draft => draft,
            _ => null,
          },
        ),
      ),
    ),
    GoRoute(
      path: '/support/tickets/:id',
      builder: (_, state) {
        final ticketId = state.pathParameters['id']!;
        return BlocProvider(
          create: (_) =>
              getIt<SupportBloc>()..add(SupportTicketDetailRequested(ticketId)),
          child: SupportTicketDetailScreen(ticketId: ticketId),
        );
      },
    ),
  ],
);

/// Routes de l'écran « Payer le colis » en mobile money (bid, fil de
/// négociation, supplément de prix, modification de colis), isolées du routeur pour être montées dans
/// un test. Chacune fournit le bloc de paiement et le composant « compte qui
/// paie » (`PayerAccountCubit`, [flow] = nom analytics de la portée) à
/// l'écran. Le composant naît sans devise (elle n'est connue qu'avec le
/// statut) et reste inerte tant que l'écran ne l'a pas configuré : un dépôt
/// repris n'appelle jamais le catalogue des pays.
List<GoRoute> buildMobileMoneyAwaitingRoutes() => [
  GoRoute(
    path: '/bids/:bidId/amendments/:amendmentId/mobile-money/awaiting',
    name: '/bids/:bidId/amendments/:amendmentId/mobile-money/awaiting',
    builder: (context, state) => _mobileMoneyAwaitingPage(
      MobileMoneyScope.amendment(
        bidId: state.pathParameters['bidId']!,
        amendmentId: state.pathParameters['amendmentId']!,
      ),
    ),
  ),
  GoRoute(
    path: '/bids/:bidId/supplements/:supplementId/mobile-money/awaiting',
    name: '/bids/:bidId/supplements/:supplementId/mobile-money/awaiting',
    builder: (context, state) => _mobileMoneyAwaitingPage(
      MobileMoneyScope.supplement(
        bidId: state.pathParameters['bidId']!,
        supplementId: state.pathParameters['supplementId']!,
      ),
    ),
  ),
  GoRoute(
    path: '/bids/:bidId/mobile-money/awaiting',
    builder: (context, state) => _mobileMoneyAwaitingPage(
      MobileMoneyScope.bid(state.pathParameters['bidId']!),
    ),
  ),
  // Aucun `extra` : le numéro qui paiera se choisit sur l'écran lui-même.
  GoRoute(
    path: '/negotiations/:id/mobile-money/awaiting',
    builder: (context, state) => _mobileMoneyAwaitingPage(
      MobileMoneyScope.negotiation(state.pathParameters['id']!),
    ),
  ),
];

Widget _mobileMoneyAwaitingPage(MobileMoneyScope scope) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<MobileMoneyPaymentBloc>(
        create: (_) => getIt<MobileMoneyPaymentBloc>(),
      ),
      BlocProvider<PayerAccountCubit>(
        create: (_) => getIt<PayerAccountCubit>(param1: scope.analyticsName),
      ),
    ],
    child: MobileMoneyAwaitingScreen(scope: scope),
  );
}

GoRoute buildHelpTutorialRoute({
  HelpTutorialPlayerSessionFactory playerSessionFactory =
      createYoutubeTutorialPlayerSession,
}) {
  return GoRoute(
    path: '/profile/help/tutorial/:tutorialId',
    builder: (context, state) => HelpTutorialScreen(
      tutorialId: state.pathParameters['tutorialId']!,
      playerSessionFactory: playerSessionFactory,
    ),
  );
}
