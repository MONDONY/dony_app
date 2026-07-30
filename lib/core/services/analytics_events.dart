abstract final class AnalyticsEvents {
  // Auth
  static const signupStarted = 'signup_started';
  static const otpSubmitted = 'otp_submitted';
  static const signupCompleted = 'signup_completed';
  static const analyticsConsentAnswered = 'analytics_consent_answered';
  static const loginSuccess = 'login_success';
  static const loginFailed = 'login_failed';

  // KYC
  static const kycStarted = 'kyc_started';
  static const kycCompleted = 'kyc_completed';
  static const kycFailed = 'kyc_failed';

  // Announcements
  static const announcementCreated = 'announcement_created';
  static const announcementViewed = 'announcement_viewed';
  static const surplusOpened = 'surplus_opened';
  static const tripCreateStarted = 'trip_create_started';

  // Bids
  static const bidSubmitted = 'bid_submitted';
  static const bidAccepted = 'bid_accepted';
  static const bidRejected = 'bid_rejected';
  static const bidPhotoAdded = 'bid_photo_added';
  static const bidPhotoRemoved = 'bid_photo_removed';
  static const bidPhotosViewed = 'bid_photos_viewed';
  static const reimbursementConditionsOpened =
      'reimbursement_conditions_opened';

  // Signalements d'incident
  static const incidentPhotoAdded = 'incident_photo_added';
  static const incidentReported = 'incident_reported';

  // Payments
  static const paymentInitiated = 'payment_initiated';
  static const paymentSucceeded = 'payment_succeeded';
  static const paymentFailed = 'payment_failed';
  static const mobileMoneyAwaiting = 'mobile_money_awaiting';

  // Tracking / QR
  static const qrScanSuccess = 'qr_scan_success';
  static const deliveryConfirmed = 'delivery_confirmed';

  // Suivi (entrées additives)
  static const suiviScanOpened = 'suivi_scan_opened';
  static const suiviTrackOpened = 'suivi_track_opened';

  // Package Request
  static const packageRequestCreated = 'package_request_created';
  static const packageRequestUpdated = 'package_request_updated';
  static const packageRequestPhotoAdded = 'package_request_photo_added';
  static const packageRequestPhotoRemoved = 'package_request_photo_removed';
  static const packageRequestDetailOpened = 'package_request_detail_opened';
  static const packageRequestReported = 'package_request_reported';
  static const packageRequestSearched = 'package_request_searched';
  static const negotiationOfferMade = 'negotiation_offer_made';
  static const negotiationOfferAccepted = 'negotiation_offer_accepted';

  /// Négociation terminée par l'une des parties ("end negotiation").
  /// Terminal, comme un rejet. Pas de propriétés (aucune PII).
  static const negotiationCancelled = 'negotiation_cancelled';

  /// Relance (nudge) envoyée par une partie à l'autre sur un thread de
  /// négociation. Pas de propriétés (aucune PII).
  static const negotiationNudgeSent = 'negotiation_nudge_sent';
  static const firmPriceTaken = 'firm_price_taken';
  static const paymentMethodSelected = 'payment_method_selected';

  /// Traveler blocked at trip-linking because no payment method they can
  /// honor overlaps the sender's accepted set (422 `payment-method/*`).
  /// Property `reason`: `no_card` / `no_cash_funds` / `none`.
  static const tripLinkPaymentBlocked = 'trip_link_payment_blocked';

  // Messaging
  static const conversationOpened = 'conversation_opened';
  static const messageSent = 'message_sent';
  static const conversationCallInitiated = 'conversation_call_initiated';
  static const messageBlocked = 'message_blocked';

  // Wallet
  static const walletTopupStarted = 'wallet_topup_started';
  static const walletTopupCompleted = 'wallet_topup_completed';

  // Ratings
  static const ratingSubmitted = 'rating_submitted';

  // Cancellations
  static const cancellationInitiated = 'cancellation_initiated';
  static const rematchAccepted = 'rematch_accepted';
  static const rematchAlternativesOpened = 'rematch_alternatives_opened';
  static const noShowReportedBySender = 'no_show_reported_by_sender';
  static const noShowReportedByTraveler = 'no_show_reported_by_traveler';
  static const deliveryNoShowReportedByTraveler =
      'delivery_no_show_reported_by_traveler';
  static const deliveryNoShowReportedBySender =
      'delivery_no_show_reported_by_sender';
  static const deliveryNoShowContested = 'delivery_no_show_contested';
  // Annulation après remise (D5/D6/D7)
  static const cancelAfterHandoverInitiated = 'cancel_after_handover_initiated';
  static const returnCodeViewed = 'return_code_viewed';
  static const returnCodeEntryOpened = 'return_code_entry_opened';
  static const returnConfirmed = 'return_confirmed';

  // Profile
  static const upgradeToProStarted = 'upgrade_to_pro_started';
  static const profilePhotoUpdated = 'profile_photo_updated';
  static const profileAboutUpdated = 'profile_about_updated';
  static const publicReviewsOpened = 'public_reviews_opened';
  static const reviewsFiltered = 'reviews_filtered';
  static const faqQuestionOpened = 'faq_question_opened';
  static const faqContactRequested = 'faq_contact_requested';
  static const supportEmailComposerOpened = 'support_email_composer_opened';
  static const supportContactFailed = 'support_contact_failed';
  static const helpCenterOpened = 'help_center_opened';
  static const helpTutorialOpened = 'help_tutorial_opened';
  static const helpTutorialPlayStarted = 'help_tutorial_play_started';
  static const helpTutorialCompleted = 'help_tutorial_completed';
  static const helpTutorialExternalOpened = 'help_tutorial_external_opened';
  static const helpSocialLinkOpened = 'help_social_link_opened';
  static const helpYoutubeSubscribeTapped = 'help_youtube_subscribe_tapped';
  static const helpConfigLoadFailed = 'help_config_load_failed';

  // Referral
  static const referralShared = 'referral_shared';

  // Settings
  static const analyticsConsentChanged = 'analytics_consent_changed';
  static const accountDeletionRequested = 'account_deletion_requested';
  static const phoneVisibilityToggled = 'phone_visibility_toggled';

  // Envois
  static const shipmentFilterApplied = 'shipment_filter_applied';
  static const shipmentNewRequestOpened = 'shipment_new_request_opened';

  // Trajets (Mes trajets)
  static const tripFilterApplied = 'trip_filter_applied';
  static const publishIntroStripeReminderTapped =
      'publish_intro_stripe_reminder_tapped';

  // Détail trajet (propriétaire)
  static const tripOwnerDetailOpened = 'trip_owner_detail_opened';
  static const tripParcelsViewed = 'trip_parcels_viewed';
  static const tripParcelsFiltered = 'trip_parcels_filtered';

  // Onglet « Envoyer » — noms d'écran (logScreen par onglet)
  static const envoyerEnvoisScreen = 'envoyer_envois';
  static const envoyerDemandesScreen = 'envoyer_demandes';

  /// Bascule du sélecteur de mode de la recherche. Propriété `mode` : trips / parcels.
  static const homeSearchModeChanged = 'home_search_mode_changed';

  /// Tap sur la ligne de bascule de l'état vide. Propriétés `from_mode`, `count`.
  static const homeCrossDiscoveryTapped = 'home_cross_discovery_tapped';

  /// Bascule de la pastille « Pour mes trajets » de la feuille de filtres colis.
  /// Propriétés `active` (bool) et `active_trips` (nombre de trajets actifs).
  static const homeMatchingTripsFilterToggled =
      'home_matching_trips_filter_toggled';

  // Filtre urgent (chip 🔥 Urgent — Accueil)
  static const urgentFilterToggled = 'urgent_filter_toggled';

  // Annonces tab navigation (Phase 1 — modèle additif)
  static const annoncesTripsOpened = 'annonces_trips_opened';
  static const annoncesSendOpened = 'annonces_send_opened';

  // Hub Activités (Phase 2 — double rôle permanent)
  static const activitesHubTripsOpened = 'activites_hub_trips_opened';
  static const activitesHubEnvoisOpened = 'activites_hub_envois_opened';
  static const activitesHubDemandesOpened = 'activites_hub_demandes_opened';
  static const activitesHubNegotiationsOpened =
      'activites_hub_negotiations_opened';
  static const activitesHubTripCreateOpened =
      'activites_hub_trip_create_opened';
  static const activitesHubRequestCreateOpened =
      'activites_hub_request_create_opened';
  static const activitesHubStatsPeriodChanged =
      'activites_hub_stats_period_changed';
  static const activitesHubSearchOpened = 'activites_hub_search_opened';
  static const activitesHubHistoryOpened = 'activites_hub_history_opened';
  static const activitesHubHelpOpened = 'activites_hub_help_opened';
  static const activitesHubIntroDismissed = 'activites_hub_intro_dismissed';
  static const activitesHubAlertsOpened = 'activites_hub_alerts_opened';
  static const activitesHubTemplatesOpened = 'activites_hub_templates_opened';
  static const activitesHubAddressesOpened = 'activites_hub_addresses_opened';
  static const activitesHubRecipientsOpened = 'activites_hub_recipients_opened';

  // Écran Demandes — filtre appliqué (tiré dans TravelerBidsBloc)
  static const travelerBidsFilterApplied = 'traveler_bids_filter_applied';

  // Demandes voyageur
  static const pendingRequestsOpened = 'pending_requests_opened';

  // Détail d'envoi (vue expéditeur)
  static const bidQrSheetOpened = 'bid_qr_sheet_opened';
  static const bidQrDownloaded = 'bid_qr_downloaded';
  static const bidRetraitCodeOpened = 'bid_retrait_code_opened';
  static const travelerCallInitiated = 'traveler_call_initiated';
  static const senderCallInitiated = 'sender_call_initiated';
  static const trackingLinkShared = 'tracking_link_shared';
  static const screenFeedbackSubmitted = 'screen_feedback_submitted';

  // Trip matching (Colis sur mes trajets)
  static const tripMatchingViewed = 'trip_matching_viewed';
  static const packageMatchAlertToggled = 'package_match_alert_toggled';

  // Préférences de notification (Réglages › Notifications)
  static const notificationPrefToggled = 'notification_pref_toggled';

  // Corridor alerts
  static const corridorAlertToggled = 'corridor_alert_toggled';
  static const corridorAlertDeleted = 'corridor_alert_deleted';
  static const corridorAlertCreated = 'corridor_alert_created';
  static const corridorAlertUpdated = 'corridor_alert_updated';
  static const corridorAlertMatchesViewed = 'corridor_alert_matches_viewed';

  // Favorites
  static const favoritesOpened = 'favorites_opened';

  // Recipients (carnet d'adresses)
  static const recipientCreated = 'recipient_created';
  static const recipientDefaultSet = 'recipient_default_set';
  static const recipientSelected = 'recipient_selected';
  static const recipientPickerOpened = 'recipient_picker_opened';

  // Errors (BlocObserver)
  static const blocError = 'bloc_error';

  // Success screen (écran de succès générique — DonySuccessScreen)
  static const successScreenViewed = 'success_screen_viewed';
  static const successScreenCtaTapped = 'success_screen_cta_tapped';
  static const successScreenClosed = 'success_screen_closed';
  static const successScreenSecondaryTapped = 'success_screen_secondary_tapped';

  // Litiges
  static const disputesOpened = 'disputes_opened';
  static const disputeDetailOpened = 'dispute_detail_opened';

  // Accessibilité
  static const accessibilitySettingChanged = 'accessibility_setting_changed';
}
