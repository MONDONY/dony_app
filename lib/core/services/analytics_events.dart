abstract final class AnalyticsEvents {
  // Auth
  static const signupStarted = 'signup_started';
  static const otpSubmitted = 'otp_submitted';
  static const signupCompleted = 'signup_completed';
  static const analyticsConsentAnswered = 'analytics_consent_answered';
  static const countryOnboardingSelected = 'country_onboarding_selected';
  static const countryOnboardingSkipped = 'country_onboarding_skipped';
  static const loginSuccess = 'login_success';
  static const loginFailed = 'login_failed';

  /// Session Firebase anonyme ouverte avec succès depuis le CTA "Parcourir
  /// sans compte". Mesure l'entrée de l'entonnoir invité → inscription.
  static const guestSessionStarted = 'guest_session_started';

  /// Échec de l'ouverture de la session anonyme (hors ligne, Firebase
  /// indisponible). Propriété `reason` : code d'erreur Firebase le cas
  /// échéant, `unknown` sinon.
  static const guestSessionFailed = 'guest_session_failed';

  /// Données posées en session visiteur (favoris, alertes) rattachées avec
  /// succès au compte créé à l'inscription. Mesure la sortie de l'entonnoir
  /// invité → inscription, c'est-à-dire la promesse tenue du mode visiteur.
  static const guestDataClaimed = 'guest_data_claimed';

  /// Échec du rattachement : le compte est bien créé, mais le visiteur perd
  /// ses favoris. Propriété `reason` : code métier du backend
  /// (`guest-claim-invalid-token`, `guest-claim-self`, …) ou `unknown`.
  static const guestDataClaimFailed = 'guest_data_claim_failed';

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

  /// Brouillon publié (DRAFT → OPEN) depuis la grille d'actions propriétaire
  /// de « Ma demande » (écran ou sheet).
  static const packageRequestPublished = 'package_request_published';

  /// Demande retirée de la circulation sans l'annuler (OPEN → DRAFT), avant
  /// la première offre — même origine que ci-dessus.
  static const packageRequestUnpublished = 'package_request_unpublished';
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

  /// Le voyageur a réglé la commission Yadony d'un accord conclu en espèces
  /// (directement ou après authentification 3DS), scellant l'accord.
  /// Propriété `thread_id` (identifiant technique, pas de PII).
  static const negotiationCommissionSettled = 'negotiation_commission_settled';

  /// Le voyageur a explicitement renoncé à régler la commission : la
  /// demande est libérée immédiatement pour un autre voyageur. Pas de
  /// propriétés (aucune PII).
  static const negotiationCommissionDeclined =
      'negotiation_commission_declined';
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
  static const walletRefundRequested = 'wallet_refund_requested';
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

  /// Tap sur une carte du carousel de guidance evergreen (écran Recherche),
  /// déclenché depuis `EvergreenGuidanceCarousel` (toute la carte est
  /// cliquable, pas de bouton CTA séparé).
  /// Propriété `slide` : trip / parcel / alert / kyc / tutorial.
  static const homeGuidanceCarouselCtaTapped =
      'home_guidance_carousel_cta_tapped';

  /// `EvergreenGuidanceCarousel` — fermeture manuelle (X) d'une slide,
  /// masquage définitif indépendant de son état d'éligibilité.
  /// Propriété `slide` : trip / parcel / alert / kyc / tutorial.
  static const homeGuidanceCarouselSlideDismissed =
      'home_guidance_carousel_slide_dismissed';

  /// SettingsScreen._resetGuidanceCards — tuile « Réafficher les
  /// suggestions », efface tous les flags de fermeture manuelle des slides
  /// du carousel de guidance evergreen (Recherche).
  static const settingsGuidanceCardsReset = 'settings_guidance_cards_reset';
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

  // Arrivée à destination (trajet)
  static const tripMarkedArrived = 'trip_marked_arrived';
  static const arrivalInstructionsUpdated = 'arrival_instructions_updated';
  // Négociation du prix d'un trajet. L'entonnoir se lit dans cet ordre :
  // ouverture du mode → première proposition → contre-offres → issue.
  // Bascule « J'accepte les propositions de prix » à la création du trajet.
  static const tripNegotiableToggled = 'trip_negotiable_toggled';
  static const tripNegotiationOpened = 'trip_negotiation_opened';
  static const tripNegotiationProposed = 'trip_negotiation_proposed';
  static const tripNegotiationCountered = 'trip_negotiation_countered';
  static const tripNegotiationAccepted = 'trip_negotiation_accepted';
  static const tripNegotiationRejected = 'trip_negotiation_rejected';
  static const tripNegotiationPaymentStarted =
      'trip_negotiation_payment_started';

  // Affiche de trajet — le voyageur la génère puis la poste sur ses propres
  // canaux. Ces trois events mesurent le seul entonnoir qui compte ici :
  // combien d'affiches ouvertes finissent réellement publiées.
  static const tripPosterOpened = 'trip_poster_opened';
  static const tripPosterShared = 'trip_poster_shared';
  static const tripPosterLinkCopied = 'trip_poster_link_copied';

  // Recherche en langage naturel — écran de composition
  static const searchComposerOpened = 'search_composer_opened';
  static const searchPhraseParsed = 'search_phrase_parsed';
  static const searchParseFailed = 'search_parse_failed';
  static const searchSubmitted = 'search_submitted';

  // Onboarding progressif — lot 1
  static const residenceAddressSaved = 'residence_address_saved';
  static const onboardingStepSkipped = 'onboarding_step_skipped';

  // Onboarding progressif — lot 2
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingStepCompleted = 'onboarding_step_completed';
  static const onboardingCompleted = 'onboarding_completed';

  // Onboarding progressif — lot 3
  //
  // Identité *déclarée* par l'utilisateur (nom, date de naissance), à ne pas
  // confondre avec l'identité *vérifiée* par Stripe Identity. Ne porte que
  // des booléens de présence — jamais les valeurs.
  static const onboardingIdentityDeclared = 'onboarding_identity_declared';
}
