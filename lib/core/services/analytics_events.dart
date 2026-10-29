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

  /// Échec du rattachement d'un numéro depuis Profil › Modifier le profil ›
  /// Téléphone (`POST /auth/sms-otp/attach`). Propriété `error_code` : code
  /// métier du backend (`phone-already-exists`, `phone-pending-deletion`,
  /// `phone-otp-invalid`, …) ou `unknown`. Jamais le numéro.
  static const phoneAttachFailed = 'phone_attach_failed';

  // KYC
  static const kycStarted = 'kyc_started';
  static const kycCompleted = 'kyc_completed';
  static const kycFailed = 'kyc_failed';

  /// Nom d'écran de la WebView du fournisseur (Didit, Stripe en repli).
  /// `/kyc/verify` sert aussi à l'écran de statut : sans ce nom distinct,
  /// PostHog ne permettait pas de savoir si l'on quittait le statut ou le
  /// parcours du fournisseur.
  static const kycProviderWebviewScreen = '/kyc/verify/webview';

  // Announcements
  /// Trajet créé. Propriétés : `corridor`, `available_kg`, `price_per_kg`,
  /// `is_draft`, `from_ai`, `currency`, `transport_mode`, `negotiable`,
  /// `payment_methods`, `pricing_mode`, `stops` (avion seulement).
  static const announcementCreated = 'announcement_created';

  /// Brouillon de trajet publié. Propriétés `announcement_id`, `currency`.
  static const announcementPublished = 'announcement_published';

  /// Trajet modifié. Propriétés `announcement_id`, `currency`.
  static const announcementUpdated = 'announcement_updated';

  /// Création, publication ou modification de trajet refusée. Propriétés
  /// `action`, `error_code` (`draft-limit-reached`, `pro-limit-reached`,
  /// `kyc-not-verified`, `unsupported`…), `is_draft`.
  static const announcementSubmitFailed = 'announcement_submit_failed';

  /// Modèle de trajet créé, modifié ou supprimé. Propriété `action`.
  static const tripTemplateSaved = 'trip_template_saved';

  /// Trajet récurrent créé, modifié ou supprimé. Propriété `action`.
  static const tripRecurrenceSaved = 'trip_recurrence_saved';
  static const announcementViewed = 'announcement_viewed';
  static const surplusOpened = 'surplus_opened';
  static const tripCreateStarted = 'trip_create_started';

  /// Brouillon local d'un formulaire de publication (trajet ou demande
  /// d'envoi), à n'importe quelle étape : enregistré, supprimé. La reprise
  /// se mesure par `publish_draft_chosen` (`choice: local`).
  static const formDraftSaved = 'form_draft_saved';
  static const formDraftDiscarded = 'form_draft_discarded';

  /// Aiguillage avant le formulaire de publication : engagements acceptés,
  /// feuille des brouillons montrée, choix fait dans cette feuille.
  static const publishCommitmentAccepted = 'publish_commitment_accepted';
  static const publishDraftsSheetShown = 'publish_drafts_sheet_shown';
  static const publishDraftChosen = 'publish_draft_chosen';

  /// Trajet récurrent par dates précises : calendrier ouvert depuis l'écran
  /// de succès, série créée, modèle enregistré depuis le trajet.
  static const tripSeriesOpened = 'trip_series_opened';
  static const tripSeriesCreated = 'trip_series_created';
  static const tripSeriesTemplateSaved = 'trip_series_template_saved';

  /// Voyage à plusieurs étapes (FLUTTER-4D) : étape ajoutée au formulaire.
  static const tripLegAdded = 'trip_leg_added';

  /// Voyage à plusieurs étapes publié (toutes les étapes en une fois).
  static const tripGroupCreated = 'trip_group_created';

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
  //
  // Émis par `PaymentSheetBloc`, seul point de passage des paiements Stripe
  // (carte, Apple Pay / Google Pay, PayPal) : avant, `payment_succeeded`
  // partait de trois appelants avec `method: 'card'` écrit en dur, deux fois
  // pour `/payments/pay`, et `payment_failed` ne partait jamais. Propriétés
  // communes : `context` (`bid`, `trip_negotiation`, `negotiation`, `escrow`,
  // `wallet_topup`), `currency`, `amount_bracket` (voir
  // `analyticsAmountBracket`), et `method` (`wallet`/`paypal`/`card`) dès
  // qu'un moyen est choisi (`AnalyticsPaymentMethod` : `platform_pay` pour
  // Apple Pay / Google Pay). Jamais de montant exact.
  //
  // `payment_succeeded` / `payment_failed` couvrent TOUS les mouvements
  // d'argent lancés depuis l'app, pas seulement Stripe : mobile money d'un
  // colis, recharges (carte, mobile money, code), commission d'un accord en
  // espèces. Se lisent par `method` × `context`.

  /// Feuille de paiement ouverte et moyens résolus. Propriétés en plus :
  /// `wallet_available`, `paypal_available`.
  static const paymentSheetOpened = 'payment_sheet_opened';

  /// Tap sur un moyen de paiement, avant la confirmation Stripe.
  static const paymentInitiated = 'payment_initiated';

  /// Paiement autorisé par Stripe.
  static const paymentSucceeded = 'payment_succeeded';

  /// Annulation par l'utilisateur (feuille native fermée, 3DS abandonné).
  static const paymentCancelled = 'payment_cancelled';

  /// Échec. Propriété `reason` : `declined`, `authentication_failed` (3-D
  /// Secure), `sheet_unavailable`, `card_unavailable`, `generic`.
  static const paymentFailed = 'payment_failed';

  /// Biométrie ou PIN refusé avant un paiement (`requirePaymentAuth`).
  static const paymentAuthDenied = 'payment_auth_denied';

  /// Paiement mobile money en attente arrivé à expiration sans validation.
  /// Propriété `scope`.
  static const mobileMoneyExpired = 'mobile_money_expired';
  static const mobileMoneyAwaiting = 'mobile_money_awaiting';

  // Activation des versements (Stripe Connect). Sans eux, l'étape paiements de
  // l'inscription était une boîte noire : on voyait l'écran, jamais l'issue.
  static const connectOnboardingLinkOpened = 'connect_onboarding_link_opened';
  static const connectOnboardingCompleted = 'connect_onboarding_completed';
  static const connectOnboardingStillPending =
      'connect_onboarding_still_pending';
  static const connectOnboardingFailed = 'connect_onboarding_failed';

  /// Lien vers l'espace Stripe Express obtenu (« Changer de compte
  /// bancaire »). Propriété `source` (`payouts_screen`/`bank_payout_sheet`).
  static const bankAccountChangeLinkOpened = 'bank_account_change_link_opened';

  /// Lien vers l'espace Stripe Express refusé ou navigateur non ouvert.
  /// Propriétés `source`, `reason`, `error_code`.
  static const bankAccountChangeLinkFailed = 'bank_account_change_link_failed';

  /// Comptes de versement mobile money du voyageur : ajout, changement de
  /// numéro, retrait (propriétés `provider` = code opérateur, `accounts_count`
  /// = comptes restants après relecture). Jamais le numéro, même masqué.
  static const mobileMoneyPayoutAccountAdded =
      'mobile_money_payout_account_added';
  static const mobileMoneyPayoutAccountNumberChanged =
      'mobile_money_payout_account_number_changed';
  static const mobileMoneyPayoutAccountRemoved =
      'mobile_money_payout_account_removed';

  /// Écriture sur un compte de versement refusée par le back. Propriétés
  /// `action` (`added`/`number_changed`/`removed`) et `error_code`
  /// (`AppException.code`, `unknown` sinon).
  static const mobileMoneyPayoutAccountActionFailed =
      'mobile_money_payout_account_action_failed';

  /// Paiement mobile money d'un bid (pawaPay) : initiation d'un dépôt,
  /// séquestre atteint, dépôt refusé.
  static const mobileMoneyInitiated = 'mobile_money_initiated';
  static const mobileMoneyConfirmed = 'mobile_money_confirmed';
  static const mobileMoneyFailed = 'mobile_money_failed';

  /// Composant partagé « compte qui paie » (recharge, paiement d'un colis,
  /// versement). Toutes portent la propriété `flow` (`topup`...) et ne
  /// contiennent jamais de numéro.
  ///
  /// Pays choisi. Propriétés `country`, `available` (servi ou « Bientôt »).
  static const mobileMoneyCountrySelected = 'mobile_money_country_selected';

  /// Pays « Bientôt » affiché. Propriété `country`.
  static const mobileMoneyCountryUnavailableViewed =
      'mobile_money_country_unavailable_viewed';

  /// Opérateur remplacé par celui que pawaPay reconnaît sur le numéro.
  /// Propriétés `from`, `to` (codes opérateur).
  static const mobileMoneyOperatorAutoSwitched =
      'mobile_money_operator_auto_switched';

  /// Numéro reconnu sur un opérateur que ce paiement n'accepte pas.
  /// Propriété `operator` (code de l'opérateur détecté).
  static const mobileMoneyOperatorNotAllowed =
      'mobile_money_operator_not_allowed';

  /// Numéro refusé ou inconnu des opérateurs du pays.
  static const mobileMoneyNumberUnrecognized =
      'mobile_money_number_unrecognized';

  /// Bouton « Recharger par carte » touché depuis un pays « Bientôt ».
  /// Propriété `country`.
  static const mobileMoneySwitchToCardTapped =
      'mobile_money_switch_to_card_tapped';

  /// Fiche d'un trajet : l'opérateur mobile money habituel de l'expéditeur
  /// (dernier paiement ou dernière recharge réussis, gardé sur l'appareil)
  /// n'est pas accepté par le voyageur, l'encart « Vous payez d'habitude avec
  /// … » est affiché. Propriété `operator` (code opérateur pawaPay). Jamais le
  /// numéro.
  static const mobileMoneyHabitualOperatorNotAcceptedViewed =
      'mobile_money_habitual_operator_not_accepted_viewed';

  // Tracking / QR
  static const qrScanSuccess = 'qr_scan_success';
  static const deliveryConfirmed = 'delivery_confirmed';

  // Onglet Suivi unifié (« Valider une étape » | « Suivre un colis »)
  /// Mode choisi par l'utilisateur (propriété `mode` : `valider`/`suivre`).
  static const suiviModeChanged = 'suivi_mode_changed';

  /// Segment « Envois / Réceptions » choisi en mode Suivre (FLUTTER-GQ).
  static const suiviSegmentChanged = 'suivi_segment_changed';

  /// Trajet affiché changé (propriété `source` : `picker`/`other_trip`).
  static const suiviTripChanged = 'suivi_trip_changed';

  /// QR Yadony lu depuis l'onglet (propriétés `mode`, `outcome` :
  /// `own_trip`/`other_trip`/`unknown`).
  static const suiviQrScanned = 'suivi_qr_scanned';

  /// Parcours d'un colis demandé en lecture seule (propriété `source` :
  /// `number`/`qr`/`my_shipments`).
  static const suiviTrackSubmitted = 'suivi_track_submitted';

  /// Étape envoyée (ou mise en file hors ligne) après le délai d'annulation
  /// (propriétés `step` : `DEPART`/`TRANSIT`, `method` : `qr`/`number`).
  static const suiviStepValidated = 'suivi_step_validated';

  /// Validation annulée pendant le délai, rien n'est envoyé (propriété
  /// `step`).
  static const suiviStepUndone = 'suivi_step_undone';

  // Package Request
  /// Formulaire de demande d'envoi ouvert (création). Propriété `source` :
  /// `new`, `duplicate`, `draft`.
  static const packageRequestCreateStarted = 'package_request_create_started';

  /// Étape 1 ou 2 du formulaire validée. Propriétés `step`, `editing`, et
  /// `transport_mode`/`has_date` (étape 1) ou `parcel_size`/`categories_count`
  /// (étape 2). L'étape 3 se lit dans `package_request_created`.
  static const packageRequestStepCompleted = 'package_request_step_completed';

  /// Soumission refusée. Propriétés `error_code`, `is_draft`, `editing`.
  static const packageRequestSubmitFailed = 'package_request_submit_failed';

  /// Propriétés : `corridor`, `negotiable`, `payment_methods`, `from_ai`,
  /// `is_draft`, `currency`, `budget_bracket`, `transport_mode`,
  /// `parcel_size`, `has_photos`, `has_promo_code`.
  static const packageRequestCreated = 'package_request_created';
  static const packageRequestUpdated = 'package_request_updated';

  /// Brouillon publié (DRAFT → OPEN) depuis la grille d'actions propriétaire
  /// de « Ma demande » (écran ou sheet).
  static const packageRequestPublished = 'package_request_published';

  /// Demande retirée de la circulation sans l'annuler (OPEN → DRAFT), avant
  /// la première offre — même origine que ci-dessus.
  static const packageRequestUnpublished = 'package_request_unpublished';

  /// Partage texte de la demande depuis la barre fixe de « Ma demande ».
  static const packageRequestShared = 'package_request_shared';

  /// Annulation confirmée par le serveur depuis le menu « … » de « Ma demande ».
  static const packageRequestCancelled = 'package_request_cancelled';

  /// Invitation d'un voyageur sur l'axe (propriété `outcome` : sent / already_sent).
  static const packageRequestTravelerInvited =
      'package_request_traveler_invited';

  /// Ouverture du menu « … » de « Ma demande ».
  static const packageRequestMenuOpened = 'package_request_menu_opened';

  /// Ouverture du formulaire pré-rempli depuis une demande existante
  /// (propriété `source` : duplicate / similar / republish).
  static const packageRequestDuplicateStarted =
      'package_request_duplicate_started';
  static const packageRequestPhotoAdded = 'package_request_photo_added';
  static const packageRequestPhotoRemoved = 'package_request_photo_removed';
  static const packageRequestDetailOpened = 'package_request_detail_opened';
  static const packageRequestReported = 'package_request_reported';

  /// Ligne expéditeur de la fiche publique d'une demande tapée (FLUTTER-GF).
  static const packageRequestSenderOpened = 'package_request_sender_opened';

  /// Photo du carrousel d'une demande touchée : galerie plein écran ouverte.
  static const packageRequestPhotosViewed = 'package_request_photos_viewed';
  static const packageRequestSearched = 'package_request_searched';
  static const negotiationOfferMade = 'negotiation_offer_made';

  /// Étape de la feuille « Faire une offre » affichée (`trip` / `price` /
  /// `recap`) : mesure où le voyageur abandonne le parcours en trois étapes.
  static const makeOfferStepViewed = 'make_offer_step_viewed';
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

  /// Commission d'un accord en espèces (offre ou fil de négociation) : le
  /// voyageur choisit de payer le complément depuis un autre portefeuille,
  /// converti au taux du jour (FLUTTER-CG). Propriétés `currency` (code ISO
  /// du portefeuille choisi) et `context` (`bid`/`negotiation`/
  /// `bid_supplement`). Jamais de
  /// montant ni de solde.
  static const commissionFundingCurrencyChosen =
      'commission_funding_currency_chosen';
  static const firmPriceTaken = 'firm_price_taken';
  static const paymentMethodSelected = 'payment_method_selected';

  /// `/checkout` d'un fil de négociation colis accepté par le serveur : la
  /// mise en relation est payée (carte) ou réglée en espèces. Propriétés
  /// `thread_id`, `payment_method` (`card`/`cash`), `currency`. Le paiement
  /// Stripe lui-même est compté par `payment_succeeded`.
  static const negotiationCheckoutCompleted = 'negotiation_checkout_completed';

  /// `/checkout` refusé par le serveur alors que le paiement Stripe a pu
  /// aboutir : sans cet événement, l'utilisateur payé mais non confirmé
  /// disparaissait du tunnel. Propriétés `thread_id`, `error_code`.
  static const negotiationCheckoutFailed = 'negotiation_checkout_failed';

  // Négociation colis ↔ voyageur. Tous les événements du fil portent
  // `thread_id`, `request_id`, `round` (tours déjà joués) et `currency` (devise
  // du fil) pour relier offre → acceptation → trajet → paiement.

  /// Offre refusée (côté colis). Propriété `has_reason`, jamais le motif.
  static const negotiationOfferRejected = 'negotiation_offer_rejected';

  /// Trajet lié au fil. Propriété `mode` : `existing`, `changed`,
  /// `dedicated` ; `payment_method` quand il est choisi à cette étape.
  static const negotiationTripLinked = 'negotiation_trip_linked';

  /// L'expéditeur refuse le trajet proposé par le voyageur.
  static const negotiationTripRefused = 'negotiation_trip_refused';

  /// Dépôt mobile money en vol annulé par l'expéditeur.
  static const negotiationDepositCancelled = 'negotiation_deposit_cancelled';

  /// Action de négociation en échec. Propriétés `action` (`start`,
  /// `counter`, `accept`, `reject`, `refuse_trip`, `trip_link_<mode>`),
  /// `error_code`, `thread_id`.
  static const negotiationActionFailed = 'negotiation_action_failed';

  /// Règlement de la commission d'un accord en espèces en échec. Propriétés
  /// `thread_id`, `method` (`wallet_balance`/`card`), `reason`
  /// (`server_refused`, `authentication_failed`, `insufficient_balance`,
  /// `declined`), `error_code`. Doublé d'un `payment_failed`
  /// (`context: commission`).
  static const negotiationCommissionFailed = 'negotiation_commission_failed';

  /// Traveler blocked at trip-linking because no payment method they can
  /// honor overlaps the sender's accepted set (422 `payment-method/*`).
  /// Property `reason`: `no_card` / `no_cash_funds` / `none`.
  static const tripLinkPaymentBlocked = 'trip_link_payment_blocked';

  // Messaging
  static const conversationOpened = 'conversation_opened';
  static const messageSent = 'message_sent';

  /// Photo envoyée dans le chat, acceptée par le back (FLUTTER-B4).
  static const chatPhotoSent = 'chat_photo_sent';

  /// Envoi de photo refusé ou échoué (propriété `reason` : `notAllowed` /
  /// `rateLimited` / `invalid` / `other`).
  static const chatPhotoFailed = 'chat_photo_failed';

  /// Message texte modifié / supprimé par son auteur, confirmé par le serveur
  /// (FLUTTER-MG). Aucune propriété : jamais le contenu.
  static const messageEdited = 'message_edited';
  static const messageDeleted = 'message_deleted';

  /// Modification ou suppression refusée ou échouée. Propriétés `action`
  /// (`edit` / `delete`) et `reason` (`MessageEditFailure.name`).
  static const messageEditFailed = 'message_edit_failed';
  static const conversationCallInitiated = 'conversation_call_initiated';
  // Appels audio Yadony (Stream Video).
  static const callModeChosen = 'call_mode_chosen';
  static const callStarted = 'call_started';
  static const callConnected = 'call_connected';
  static const callEnded = 'call_ended';
  static const callFailed = 'call_failed';
  static const callIncomingAccepted = 'call_incoming_accepted';

  /// Feuille « Ne manquez aucun appel » montrée (une fois) à l'ouverture d'une
  /// conversation avec appel Yadony. Propriété `kind` :
  /// `full_screen_intent` / `manufacturer`.
  static const callLockScreenPromptShown = 'call_lock_screen_prompt_shown';

  /// Réglage système ouvert pour afficher les appels écran verrouillé.
  /// Propriétés `kind` et `source` (`prompt` / `settings`).
  static const callLockScreenSettingsOpened =
      'call_lock_screen_settings_opened';
  static const messageBlocked = 'message_blocked';

  /// Notifications d'une conversation coupées / réactivées, confirmé par le
  /// serveur. Propriété `source` : `chat` (menu ⋯) / `list` (volet glissant).
  static const conversationNotificationsMuted =
      'conversation_notifications_muted';
  static const conversationNotificationsUnmuted =
      'conversation_notifications_unmuted';

  /// Mode sélection ouvert par un appui long (FLUTTER-M4). Propriété
  /// `source` : `list` / `archives`.
  static const conversationSelectionStarted = 'conversation_selection_started';

  /// Actions groupées confirmées par le serveur. Propriétés `count` (fils
  /// traités) et `failed` (refusés) ; `undo` (bool) pour le désarchivage.
  static const conversationsBatchArchived = 'conversations_batch_archived';
  static const conversationsBatchUnarchived = 'conversations_batch_unarchived';
  static const conversationsBatchDeleted = 'conversations_batch_deleted';

  // Wallet
  // Recharges du solde. Propriété `method` : `card`, `mobile_money`,
  // `voucher` (code). Chaque issue est doublée d'un `payment_succeeded` /
  // `payment_failed` (`context: wallet_topup`) ; la carte l'a via la feuille
  // de paiement.

  /// Écran de montant ouvert. Propriété `method`.
  static const walletTopupStarted = 'wallet_topup_started';

  /// Recharge payée. Propriétés `method`, `currency`, `amount_bracket`,
  /// `provider` (mobile money). Partait avant à la création du PaymentIntent.
  static const walletTopupCompleted = 'wallet_topup_completed';

  /// Recharge en échec. Propriétés `method`, `reason` (`intent_failed`,
  /// `initiate_failed`, `declined`, `code_rejected`), `error_code` (pour un
  /// refus mobile money : code Yadony du back, ex. `insufficient-balance`),
  /// `currency`, `provider`.
  static const walletTopupFailed = 'wallet_topup_failed';

  /// Recharge mobile money encore ouverte abandonnée par « Payer avec un
  /// autre numéro » (proposé après l'échéance), jamais en quittant
  /// l'attente (voir [walletTopupAwaitingClosed]).
  static const walletTopupCancelled = 'wallet_topup_cancelled';

  /// Recharge mobile money initiée (dépôt pawaPay lancé, avant confirmation).
  /// Propriétés `provider` et `currency` uniquement : jamais le montant, ni
  /// le numéro de téléphone (même masqué).
  static const walletTopupMobileMoneyInitiated =
      'wallet_topup_mobile_money_initiated';

  /// Recharge mobile money confirmée (portefeuille crédité), une seule fois
  /// par recharge. Mêmes propriétés que [walletTopupMobileMoneyInitiated].
  static const walletTopupMobileMoneyConfirmed =
      'wallet_topup_mobile_money_confirmed';

  /// Écran d'attente mobile money quitté (✕, retour système) sans abandonner
  /// la recharge. Propriété `remaining_s` : secondes restantes avant
  /// l'échéance (0 une fois passée).
  static const walletTopupAwaitingClosed = 'wallet_topup_awaiting_closed';

  /// Recharge mobile money encore ouverte reprise à l'ouverture de l'écran
  /// Recharger. Propriétés `provider` et `currency`.
  static const walletTopupResumed = 'wallet_topup_resumed';

  // Ratings
  static const ratingSubmitted = 'rating_submitted';

  /// Fenêtre native d'avis Store demandée après une note de 4 ou 5 étoiles
  /// donnée à l'autre partie (`StoreReviewService.requestAfterRating`).
  /// Propriétés `stars`, `role_rated`. Le système peut ne rien afficher.
  static const storeReviewRequested = 'store_review_requested';

  /// Fiche Google Play / App Store ouverte pour laisser un avis
  /// (`StoreReviewService.openStoreListing`). Propriété `source`.
  static const storeListingOpened = 'store_listing_opened';

  // Cancellations
  static const cancellationInitiated = 'cancellation_initiated';
  static const bidCancelled = 'bid_cancelled';
  static const bidCancelledBeforePayment = 'bid_cancelled_before_payment';

  /// Colis non conforme refusé par le voyageur à la remise
  /// (`POST /bids/{id}/refuse-parcel`), confirmé par le serveur. Propriétés
  /// `reason` (code fermé de [ParcelRefusalReason]), `status` (statut avant
  /// le refus), `payment_method`. Jamais le détail saisi.
  static const parcelRefused = 'parcel_refused';

  /// Refus du colis impossible (photo non envoyée, statut changé, trajet
  /// parti). Propriétés `reason`, `error_code`.
  static const parcelRefusalFailed = 'parcel_refusal_failed';

  // Supplément de prix à la remise (`/bids/{bidId}/supplements`). Jamais le
  // montant exact (tranche `amount_bracket` + `currency`), jamais le texte du
  // motif.

  /// Feuille « Demander un supplément » ouverte et ses options chargées.
  /// Propriétés `payment_method` (moyen de paiement du colis), `status`.
  static const bidSupplementSheetOpened = 'bid_supplement_sheet_opened';

  /// Demande de supplément créée par le serveur. Propriétés `reason`
  /// (`grid_item`/`extra_weight`/`other`), `suggestion`
  /// (`grid_item`/`kg`/`custom`), `amount_bracket`, `currency`,
  /// `payment_method`, et en espèces `commission_source` (`wallet`/`card`).
  static const bidSupplementRequested = 'bid_supplement_requested';

  /// Demande impossible (photo non envoyée, montant hors bornes, départ trop
  /// proche…). Propriétés `reason`, `error_code`.
  static const bidSupplementRequestFailed = 'bid_supplement_request_failed';

  /// Le voyageur retire sa demande, confirmé par le serveur.
  static const bidSupplementWithdrawn = 'bid_supplement_withdrawn';

  /// Encart du supplément affiché dans le détail d'envoi, une fois par
  /// écran. Propriétés `role` (`sender`/`traveler`), `status`.
  static const bidSupplementViewed = 'bid_supplement_viewed';

  /// L'expéditeur refuse le supplément, confirmé par le serveur. Propriété
  /// `payment_method`.
  static const bidSupplementDeclined = 'bid_supplement_declined';

  /// Retrait ou refus impossible. Propriétés `action`
  /// (`withdraw`/`decline`/`pay`/`confirm_payment`), `error_code`.
  static const bidSupplementActionFailed = 'bid_supplement_action_failed';

  /// L'expéditeur lance le paiement du supplément : le serveur a accepté et
  /// rendu un PaymentIntent. Propriétés `method` (`card`), `currency`,
  /// `amount_bracket`. Le paiement lui-même est tracé par la feuille
  /// (`payment_*`, `context: bid_supplement`).
  static const bidSupplementPaymentStarted = 'bid_supplement_payment_started';

  /// Colis payé en espèces : l'expéditeur accepte le supplément et s'engage à
  /// remettre le complément en main propre (`POST …/accept`, rail `CASH`).
  /// Propriétés `amount_bracket`, `currency`. Aucun argent ne passe par
  /// l'app : pas de `payment_succeeded`.
  static const bidSupplementCashAccepted = 'bid_supplement_cash_accepted';

  /// Colis payé en espèces : le voyageur relance depuis l'encart la
  /// validation de la commission d'une demande en attente (3DS abandonnée,
  /// débit sans réponse). Propriété `outcome` : `proposed` (demande partie à
  /// l'expéditeur), `pending` (encore en attente), `failed`.
  static const bidSupplementCommissionResumed =
      'bid_supplement_commission_resumed';

  /// Scan de remise refusé par le serveur (409
  /// `handover-supplement-pending`) : un supplément attend la réponse de
  /// l'expéditeur. Propriété `channel` (`direct`/`offline`).
  static const handoverBlockedSupplement = 'handover_blocked_supplement';

  // Modification d'un colis accepté (`/bids/{bidId}/amendments`). Jamais le
  // montant exact (tranche `amount_bracket` + `currency`).

  /// Feuille « Modifier mon colis » ouverte.
  /// Propriété `rails_count` (moyens de paiement proposés).
  static const bidAmendmentSheetOpened = 'bid_amendment_sheet_opened';

  /// Demande de modification créée par le serveur.
  /// Propriétés `method` (`card`/`mobile_money`/`cash`), `added_kg`, `items_count`, `amount_bracket`, `currency`.
  static const bidAmendmentRequested = 'bid_amendment_requested';

  /// Demande impossible.
  /// Propriété `error_code`.
  static const bidAmendmentRequestFailed = 'bid_amendment_request_failed';

  /// Encart de la modification affiché dans le détail d'envoi, une fois par écran.
  /// Propriétés `role` (`sender`/`traveler`), `status`.
  static const bidAmendmentViewed = 'bid_amendment_viewed';

  /// L'expéditeur annule sa demande, confirmé par le serveur.
  /// Aucune propriété.
  static const bidAmendmentCancelled = 'bid_amendment_cancelled';

  /// Le voyageur accepte la modification, confirmé par le serveur.
  /// Propriétés `method`, et en espèces `commission_source` (`wallet`/`card`).
  static const bidAmendmentAccepted = 'bid_amendment_accepted';

  /// Le voyageur refuse la modification.
  /// Propriété `method`.
  static const bidAmendmentDeclined = 'bid_amendment_declined';

  /// Le voyageur déclare ne pas avoir apporté le complément d'une modification acceptée.
  /// Propriété `method`.
  static const bidAmendmentNotBrought = 'bid_amendment_not_brought';

  /// Action impossible.
  /// Propriétés `action` (`cancel`/`accept`/`decline`/`not_brought`/`confirm_authorization`/`confirm_commission`), `error_code`.
  static const bidAmendmentActionFailed = 'bid_amendment_action_failed';

  /// Le paiement de la modification démarre (autorisation carte ou dépôt mobile money).
  /// Propriété `method`.
  /// Le paiement lui-même est tracé en `payment_*` (`context: bid_amendment`).
  static const bidAmendmentPaymentStarted = 'bid_amendment_payment_started';

  /// Scan de remise refusé par le serveur (409 `handover-amendment-pending`) : une modification attend le voyageur.
  /// Propriété `channel` (`direct`/`offline`).
  static const handoverBlockedAmendment = 'handover_blocked_amendment';
  static const rematchAccepted = 'rematch_accepted';
  static const rematchAlternativesOpened = 'rematch_alternatives_opened';
  static const noShowReportedBySender = 'no_show_reported_by_sender';
  static const noShowReportedByTraveler = 'no_show_reported_by_traveler';
  static const deliveryNoShowReportedByTraveler =
      'delivery_no_show_reported_by_traveler';
  static const deliveryNoShowReportedBySender =
      'delivery_no_show_reported_by_sender';
  static const deliveryNoShowContested = 'delivery_no_show_contested';

  /// FLUTTER-E2 : l'expéditeur fixe un nouveau rendez-vous pendant la garde.
  static const deliveryRetryAppointmentSet = 'delivery_retry_appointment_set';
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

  /// Ticket support créé avec succès (propriété `category` : énumération
  /// fermée backend, jamais le sujet ni le message).
  static const supportTicketCreated = 'support_ticket_created';

  /// Écran support ouvert avec une demande préremplie (`SupportTicketDraft`),
  /// avant toute saisie. Propriété `origin` : écran d'où vient la demande
  /// (`team_cancelled_parcel`, `phone_already_used`, `email_change`). Jamais
  /// le sujet ni le message.
  static const supportDraftOpened = 'support_draft_opened';

  /// Message utilisateur envoyé dans un ticket support existant. Aucune
  /// propriété : le contenu ne part jamais dans l'analytics.
  static const supportTicketMessageSent = 'support_ticket_message_sent';
  static const supportTicketHidden = 'support_ticket_hidden';

  /// Image jointe à un message support uploadée avec succès. Aucune propriété
  /// (ni chemin, ni taille, ni contenu — PII).
  static const supportAttachmentAdded = 'support_attachment_added';

  // Assistant IA (bulle in-app). Aucun texte de question ou de réponse ne
  // part jamais dans les properties.
  /// Bulle de l'assistant ouverte.
  static const assistantOpened = 'assistant_opened';

  /// Question envoyée au back.
  static const assistantQuestionAsked = 'assistant_question_asked';

  /// Réponse reçue du back.
  static const assistantAnswerReceived = 'assistant_answer_received';

  /// Bouton d'action d'une réponse touché.
  static const assistantActionTapped = 'assistant_action_tapped';

  /// Action proposée sans écran correspondant dans l'app.
  static const assistantActionUnmatched = 'assistant_action_unmatched';

  /// Retour donné sur une réponse.
  static const assistantFeedback = 'assistant_feedback';

  /// Demande de transfert vers le support humain.
  static const assistantEscalated = 'assistant_escalated';

  /// Quota quotidien atteint.
  static const assistantQuotaReached = 'assistant_quota_reached';

  /// Explication de l'écran d'origine affichée à l'ouverture de l'assistant.
  static const assistantScreenExplained = 'assistant_screen_explained';

  /// Assistant ouvert depuis un écran qu'aucune fiche n'explique encore.
  static const assistantScreenUnexplained = 'assistant_screen_unexplained';

  /// Avertissement d'approche de la limite quotidienne affiché sous une réponse.
  static const assistantQuotaWarningShown = 'assistant_quota_warning_shown';

  /// Colis proposés au choix sous une réponse (question sur l'un des siens).
  static const assistantParcelChoicesShown = 'assistant_parcel_choices_shown';

  /// Colis touché parmi ceux proposés : la question est reposée pour lui.
  static const assistantParcelChosen = 'assistant_parcel_chosen';

  /// Bulle de l'assistant allumée ou éteinte dans Réglages (propriété
  /// `enabled`).
  static const assistantBubbleToggled = 'assistant_bubble_toggled';

  // ── Formulaires remplis par l'IA (trajet, demande d'envoi) ─────────────────
  // Propriété `kind` sur chacun : `trip` ou `package_request`. Jamais le texte
  // saisi ou dicté.

  /// Feuille « Créer avec l'IA » ouverte.
  static const aiFormDraftOpened = 'ai_form_draft_opened';

  /// Un tour a été envoyé depuis la dictée (et non le clavier).
  static const aiFormDraftVoiceUsed = 'ai_form_draft_voice_used';

  /// Réponse reçue pour un tour. Propriétés `turns`, `missing_count`.
  static const aiFormDraftTurn = 'ai_form_draft_turn';

  /// Tout est compris (ou limite de tours). Propriétés `turns`, `turn_limit`.
  static const aiFormDraftReady = 'ai_form_draft_ready';

  /// « Remplir le formulaire » touché. Propriété `fields_count`.
  static const aiFormDraftApplied = 'ai_form_draft_applied';

  /// Aucun fournisseur n'a répondu, ou l'assistant est éteint en cours de route.
  static const aiFormDraftDegraded = 'ai_form_draft_degraded';

  /// Quota quotidien des formulaires atteint (HTTP 429).
  static const aiFormDraftQuotaExceeded = 'ai_form_draft_quota_exceeded';

  // ── Accord avant l'envoi à une IA tierce (Apple 5.1.2(i)) ──────────────────
  // Propriété `entry` : `assistant`, `form_trip` ou `form_package_request`.

  /// Feuille d'accord affichée avant le premier usage de l'IA.
  static const aiConsentShown = 'ai_consent_shown';

  /// Réponse à cette feuille. Propriété `granted` (fermer la feuille = refus).
  static const aiConsentAnswered = 'ai_consent_answered';

  static const helpCenterOpened = 'help_center_opened';
  static const helpTutorialOpened = 'help_tutorial_opened';
  static const helpTutorialPlayStarted = 'help_tutorial_play_started';
  static const helpTutorialCompleted = 'help_tutorial_completed';
  static const helpTutorialExternalOpened = 'help_tutorial_external_opened';
  static const helpSocialLinkOpened = 'help_social_link_opened';
  static const helpYoutubeSubscribeTapped = 'help_youtube_subscribe_tapped';
  static const helpConfigLoadFailed = 'help_config_load_failed';

  // Billing (abonnement PRO)
  static const proSubscriptionViewed = 'pro_subscription_viewed';
  static const proPortalOpened = 'pro_portal_opened';
  static const proPortalOpenFailed = 'pro_portal_open_failed';

  /// `DELETE /auth/me/upgrade-to-pro` refusé en `409`
  /// `active-stripe-subscription` : l'abonnement Stripe est encore actif, la
  /// résiliation passe par le portail web. Câblé dans
  /// `UpgradeToProBloc._onDowngrade`, aucune propriété (ni identifiant, ni
  /// message serveur).
  static const proDowngradeBlocked = 'pro_downgrade_blocked';

  // Referral
  static const referralShared = 'referral_shared';

  /// Récompense de parrainage choisie (propriété `choice` :
  /// `WALLET_CREDIT` / `DISCOUNT_CODE`).
  static const referralRewardChosen = 'referral_reward_chosen';

  /// Lien d'invitation `yadony://referral?code=…` ouvert dans l'app.
  static const referralLinkOpened = 'referral_link_opened';

  /// Bouton « Ouvrir Yadony » d'un e-mail de notification ouvert dans l'app
  /// (lien universel `https://yadony.com/ouvrir?type=…` ou
  /// `yadony://open?type=…`). Propriétés `type` (type de notification) et
  /// `resolved` (un écran correspond).
  static const emailLinkOpened = 'email_link_opened';

  // Settings
  static const analyticsConsentChanged = 'analytics_consent_changed';
  static const accountDeletionRequested = 'account_deletion_requested';
  static const walletRefundRequested = 'wallet_refund_requested';

  /// Demande de remboursement du solde refusée. Propriétés `source`,
  /// `currency` (depuis le portefeuille), `error_code`.
  static const walletRefundFailed = 'wallet_refund_failed';

  /// Devise choisie dans la sheet « Quelle devise rembourser ? » quand
  /// plusieurs devises sont remboursables. Propriété `currency` uniquement.
  static const walletRefundCurrencyChosen = 'wallet_refund_currency_chosen';

  /// Ligne de l'historique du solde liée à un colis touchée (FLUTTER-QP) :
  /// la fiche du colis s'ouvre. Propriété `type` : code serveur de la ligne
  /// (`COMMISSION_DEDUCTED`, `REFUND`, `BID_PAYMENT`...). Ni montant ni
  /// identifiant.
  static const walletTxParcelOpened = 'wallet_tx_parcel_opened';

  /// Changement de portefeuille actif depuis l'écran Portefeuille
  /// (FLUTTER-8F). Propriétés `from` et `to` : codes devise, aucun montant.
  static const walletActiveCurrencySwitched = 'wallet_active_currency_switched';

  /// Écran « Mon argent » chargé (FLUTTER-HV), une fois par ouverture.
  /// Propriétés `traveler_items`, `sender_items` (nombres de colis listés) et
  /// `legacy_backend` (back sans l'aperçu : soldes seuls). Aucun montant.
  static const moneyOverviewViewed = 'money_overview_viewed';
  static const moneyTripsViewed = 'money_trips_viewed';
  static const phoneVisibilityToggled = 'phone_visibility_toggled';
  static const userBlocked = 'user_blocked';
  static const userUnblocked = 'user_unblocked';

  // Envois
  static const shipmentFilterApplied = 'shipment_filter_applied';
  static const shipmentNewRequestOpened = 'shipment_new_request_opened';

  // Trajets (Mes trajets)
  static const tripFilterApplied = 'trip_filter_applied';
  static const publishIntroStripeReminderTapped =
      'publish_intro_stripe_reminder_tapped';

  /// Bouton « Modifier mon pays de résidence » de `ConnectUnavailableView`
  /// (onboarding Connect et « Recevoir mes paiements ») : mène à Réglages ›
  /// Préférences quand le pays de résidence déclaré n'est pas couvert par
  /// Stripe ou n'est pas renseigné. Propriété `country_set` (bool).
  static const connectUnavailableChangeCountryTapped =
      'connect_unavailable_change_country_tapped';

  /// Pays de résidence changé et enregistré par le serveur depuis Réglages ›
  /// Préférences (`BusinessPrefsBloc._onCountry`). Propriété
  /// `reset_payout_setup` (bool) : le changement a annulé une activation des
  /// paiements par carte commencée (yadony-back #530). Jamais le pays.
  static const residenceCountryChanged = 'residence_country_changed';

  // Détail trajet (propriétaire)
  static const tripOwnerDetailOpened = 'trip_owner_detail_opened';
  static const tripAudienceLoaded = 'trip_audience_loaded';
  static const tripParcelsViewed = 'trip_parcels_viewed';
  static const tripParcelsFiltered = 'trip_parcels_filtered';

  /// Bascule du sélecteur de mode de la recherche. Propriété `mode` : trips / parcels.
  static const homeSearchModeChanged = 'home_search_mode_changed';

  /// Tap sur un point de la carte de l'accueil. Propriétés `mode`
  /// (trips / parcels) et `kind` : `trip` (marqueur d'un trajet),
  /// `package_request` (marqueur d'une demande) ou `cluster` (groupe de
  /// points, dont `cluster_size`). Jamais la ville ni l'identifiant.
  static const homeMapMarkerTapped = 'home_map_marker_tapped';

  /// Glissement de l'utilisateur dans le carrousel « Près de moi ». Propriétés
  /// `mode` et `position` (rang de la carte atteinte, à partir de 0). Un
  /// défilement déclenché par un tap sur la carte n'est pas compté.
  static const homeCarouselSwiped = 'home_carousel_swiped';

  /// Fiche ouverte depuis l'accueil. Propriétés `source` (`map` marqueur,
  /// `carousel` carrousel « Près de moi », `list` liste de la feuille), `mode`
  /// et `kind` (`trip` / `package_request`). Sert à comparer les trois chemins.
  static const homeCardOpened = 'home_card_opened';

  /// Feuille de résultats de l'accueil posée sur un nouveau cran. Propriétés
  /// `size` (`peek` repliée, `raised` mi-hauteur, `full` plein écran), `from`
  /// (cran précédent, absent au premier) et `auto` (montée d'elle-même à
  /// l'ouverture, FLUTTER-CD, plutôt que geste de l'utilisateur).
  static const homeSheetSnapped = 'home_sheet_snapped';

  /// Tap sur la ligne de bascule de l'état vide. Propriétés `from_mode`, `count`.
  static const homeCrossDiscoveryTapped = 'home_cross_discovery_tapped';

  /// Tap sur « M'alerter dès que… » sous l'état vide. Propriété `mode`.
  static const homeAlertForSearchTapped = 'home_alert_for_search_tapped';

  /// Bascule de la pastille « Pour mes trajets » de la feuille de filtres colis.
  /// Propriétés `active` (bool) et `active_trips` (nombre de trajets actifs).
  static const homeMatchingTripsFilterToggled =
      'home_matching_trips_filter_toggled';

  /// Bouton rond « + Publier » de la rangée du haut de l'accueil (FLUTTER-B8),
  /// utilisateur connecté : ouvre la feuille de choix. Propriété
  /// `active_role` : `sender` / `traveler`.
  static const homePublishSheetOpened = 'home_publish_sheet_opened';

  /// Choix retenu dans la feuille « + Publier » de l'accueil. Propriétés
  /// `choice` : `parcel` / `trip`, et `active_role`.
  static const homePublishTapped = 'home_publish_tapped';

  /// SettingsScreen._resetGuidanceCards — tuile « Réafficher les
  /// suggestions », réaffiche les `ContextualTutorialCard` fermées.
  static const settingsGuidanceCardsReset = 'settings_guidance_cards_reset';
  static const settingsFlightsVisibilityChanged =
      'settings_flights_visibility_changed';

  /// FlightAlertsPauseCubit — réponse à la feuille « Mettre aussi vos alertes
  /// prix en pause ? » ouverte quand l'utilisateur masque les billets avec des
  /// alertes actives. Propriétés `active_count`, `choice` :
  /// `pause` / `keep` / `dismiss`.
  static const settingsFlightsAlertsPausePrompt =
      'settings_flights_alerts_pause_prompt';

  /// FlightAlertsPauseCubit.pause — alertes mises en pause depuis cette
  /// feuille. Propriétés `count` (réussies), `failed` (refusées).
  static const settingsFlightsAlertsPaused = 'settings_flights_alerts_paused';
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

  /// Ligne « Discussions de prix » épinglée en tête de Messages (FLUTTER-44),
  /// raccourci vers `/negotiations`. Propriétés `open_count`,
  /// `awaiting_me_count`.
  static const messagesNegotiationsShortcutOpened =
      'messages_negotiations_shortcut_opened';
  static const activitesHubTripCreateOpened =
      'activites_hub_trip_create_opened';
  static const activitesHubRequestCreateOpened =
      'activites_hub_request_create_opened';
  static const activitesHubStatsPeriodChanged =
      'activites_hub_stats_period_changed';
  static const activitesHubStatsRevenuesOpened =
      'activites_hub_stats_revenues_opened';
  static const activitesHubStatsKgSoldOpened =
      'activites_hub_stats_kg_sold_opened';
  static const activitesHubStatsTripsOpened =
      'activites_hub_stats_trips_opened';
  static const activitesHubStatsParcelsOpened =
      'activites_hub_stats_parcels_opened';

  /// Entrée « Mes statistiques » du menu ☰ d'Activités.
  static const activitesHubStatsMenuOpened = 'activites_hub_stats_menu_opened';

  /// Bloc « Billets d'avion » du hub Activités.
  static const activitesHubFlightsSearchTapped =
      'activites_hub_flights_search_tapped';
  static const activitesHubFlightsSeeAllTapped =
      'activites_hub_flights_see_all_tapped';

  /// Bon plan touché dans le bloc (propriété `discount_percent`).
  static const activitesHubFlightsDealOpened =
      'activites_hub_flights_deal_opened';

  /// Ligne « Alertes prix vols » des Outils (propriété `state`).
  static const activitesHubFlightAlertsOpened =
      'activites_hub_flight_alerts_opened';
  static const activitesHubSearchOpened = 'activites_hub_search_opened';
  static const activitesHubMenuOpened = 'activites_hub_menu_opened';
  static const activitesHubScanOpened = 'activites_hub_scan_opened';
  static const activitesHubSettingsOpened = 'activites_hub_settings_opened';
  static const activitesHubWalletOpened = 'activites_hub_wallet_opened';
  static const activitesHubHistoryOpened = 'activites_hub_history_opened';
  static const activitesHubHelpOpened = 'activites_hub_help_opened';
  static const activitesHubIntroDismissed = 'activites_hub_intro_dismissed';

  // ── Onglet Moi : feuille de menu du burger ─────────────────────────────────
  static const profileMenuOpened = 'profile_menu_opened';
  static const profileMenuEditOpened = 'profile_menu_edit_opened';
  static const profileHeaderTapped = 'profile_header_tapped';
  static const profilePhotoViewed = 'profile_photo_viewed';
  static const profileLanguagesPicked = 'profile_languages_picked';
  static const profileMenuSettingsOpened = 'profile_menu_settings_opened';
  static const profileMenuExportOpened = 'profile_menu_export_opened';
  static const profileMenuLogoutTapped = 'profile_menu_logout_tapped';
  static const profileMenuDeleteOpened = 'profile_menu_delete_opened';
  static const activitesHubAlertsOpened = 'activites_hub_alerts_opened';
  static const activitesHubTemplatesOpened = 'activites_hub_templates_opened';
  static const activitesHubAddressesOpened = 'activites_hub_addresses_opened';
  static const activitesHubRecipientsOpened = 'activites_hub_recipients_opened';
  static const activitesHubPriceGridOpened = 'activites_hub_price_grid_opened';
  static const activitesHubToolsCompletionLoaded =
      'activites_hub_tools_completion_loaded';
  static const activitesHubToolsCtaTapped = 'activites_hub_tools_cta_tapped';
  static const toolConfigured = 'tool_configured';
  static const toolsSetupCompleted = 'tools_setup_completed';
  static const paymentCardSaved = 'payment_card_saved';
  static const priceGridItemAdded = 'price_grid_item_added';
  static const priceGridCreated = 'price_grid_created';

  // Écran Demandes — filtre appliqué (tiré dans TravelerBidsBloc)
  static const travelerBidsFilterApplied = 'traveler_bids_filter_applied';

  // Demandes voyageur
  static const pendingRequestsOpened = 'pending_requests_opened';

  // Détail d'envoi (vue expéditeur)
  static const bidQrSheetOpened = 'bid_qr_sheet_opened';
  static const bidQrDownloaded = 'bid_qr_downloaded';
  static const bidRetraitCodeOpened = 'bid_retrait_code_opened';

  /// Code de retrait régénéré par l'expéditeur (propriété `after_block` :
  /// depuis le talon « Code de retrait bloqué », FLUTTER-G1).
  static const pickupCodeRegenerated = 'pickup_code_regenerated';

  /// Le voyageur demande un nouveau code de retrait à l'expéditeur
  /// (FLUTTER-G2). Propriétés : `source` (écran) et `outcome` seulement.
  static const pickupCodeRequested = 'pickup_code_requested';
  static const travelerCallInitiated = 'traveler_call_initiated';
  static const senderCallInitiated = 'sender_call_initiated';
  static const trackingLinkShared = 'tracking_link_shared';
  static const recipientNotified = 'recipient_notified';
  static const bidRecipientChanged = 'bid_recipient_changed';

  // Le destinataire a refusé le colis : le voyageur demande à l'expéditeur
  // d'en désigner un autre (FLUTTER-E8). Statut du colis et issue seulement.
  static const recipientReplacementRequested =
      'recipient_replacement_requested';

  // Le voyageur prévient les destinataires de ses colis (lot 3B). Jamais le
  // nom ni le numéro : canal, statut, compteurs.
  static const recipientsNotifyOpened = 'recipients_notify_opened';
  static const recipientContacted = 'recipient_contacted';

  // Conversation séparée voyageur ↔ destinataire (lot 3C). Seulement le côté
  // qui l'ouvre (`role` : traveler/recipient), jamais d'identité.
  static const recipientConversationOpened = 'recipient_conversation_opened';
  static const recipientMessageTapped = 'recipient_message_tapped';

  // Colis à recevoir (lot 2 destinataire). Jamais le nom, le numéro ni le
  // code : seulement des statuts et des comptes.
  static const receptionsSectionViewed = 'receptions_section_viewed';
  // Bandeau « Un colis vous attend » de l'accueil (YADONY-FLUTTER-PROD-12),
  // propriété `count` seulement.
  static const receptionsPromptShown = 'receptions_prompt_shown';
  static const receptionsPromptTapped = 'receptions_prompt_tapped';
  static const receptionOpened = 'reception_opened';
  static const receptionConfirmed = 'reception_confirmed';
  static const receptionDeclined = 'reception_declined';
  static const receptionWithdrawn = 'reception_withdrawn';
  static const receptionTravelerRated = 'reception_traveler_rated';

  // Lien yadony://colis/{id} de la page publique du QR colis : rôle résolu
  // (`role` : sender/traveler/recipient/none). Jamais l'identifiant du colis.
  static const parcelDeepLinkResolved = 'parcel_deep_link_resolved';
  static const screenFeedbackSubmitted = 'screen_feedback_submitted';

  // Trip matching (Colis sur mes trajets)
  static const tripMatchingViewed = 'trip_matching_viewed';
  static const packageMatchAlertToggled = 'package_match_alert_toggled';

  /// Boîte « Annonces Yadony » ouverte et chargée depuis le sheet de
  /// notifications (propriétés `count`, `unread`), sans aucun texte d'annonce.
  static const announcementsInboxOpened = 'announcements_inbox_opened';

  /// Écran de détail générique d'une notification chargé (propriétés `type`,
  /// `category`), jamais son texte.
  static const notificationDetailOpened = 'notification_detail_opened';

  // Préférences de notification (Réglages › Notifications)
  static const notificationPrefToggled = 'notification_pref_toggled';

  // Corridor alerts
  /// Bascule de la cloche d'un voyageur suivi (propriété `enabled`). Ne mesure
  /// que le push : la notification reste inscrite au centre de notifications
  /// dans les deux cas.
  static const subscriptionPushToggled = 'subscription_push_toggled';

  /// Désabonnement confirmé depuis « Mes abonnements ».
  static const subscriptionRemoved = 'subscription_removed';

  /// « Tout marquer comme vu » de l'en-tête (propriété `count`).
  static const subscriptionsMarkedAllSeen = 'subscriptions_marked_all_seen';

  /// Tap sur la ligne du dernier trajet d'une carte d'abonnement : raccourci
  /// vers l'annonce, distinct du tap sur la carte qui mène au profil.
  static const subscriptionLastTripOpened = 'subscription_last_trip_opened';

  /// Section « En cours » d'un profil chargée (trajets et demandes ouverts de
  /// ce membre, `GET /users/{id}/open-listings`). Propriétés `trip_count` et
  /// `request_count`. Non émis en cas d'échec ni sur un back sans la route.
  static const openListingsViewed = 'open_listings_viewed';

  /// Filtre « Tout / Trajets / Demandes » de la section « En cours » touché
  /// (propriété `filter` : `all`/`trips`/`requests`).
  static const openListingsFilterChanged = 'open_listings_filter_changed';

  /// Section « En cours » repliée ou dépliée depuis son en-tête (propriété
  /// `expanded`, état après le geste), pour atteindre les avis plus bas dans la page.
  static const openListingsToggled = 'open_listings_toggled';

  /// Carte de la section « En cours » ouverte (propriété `kind` : `trip` ou
  /// `request`). Jamais l'identifiant ni le profil consulté.
  static const openListingOpened = 'open_listing_opened';

  static const corridorAlertToggled = 'corridor_alert_toggled';
  static const corridorAlertDeleted = 'corridor_alert_deleted';
  static const corridorAlertCreated = 'corridor_alert_created';
  static const corridorAlertUpdated = 'corridor_alert_updated';

  /// « Me prévenir si de la place se libère » sur un trajet complet, accepté
  /// par le serveur (FLUTTER-JH).
  static const tripSpaceAlertSubscribed = 'trip_space_alert_subscribed';

  /// Alerte de place retirée depuis la feuille du trajet complet (FLUTTER-JH).
  static const tripSpaceAlertUnsubscribed = 'trip_space_alert_unsubscribed';
  static const corridorAlertMatchesViewed = 'corridor_alert_matches_viewed';

  // Favorites
  static const favoritesOpened = 'favorites_opened';

  // Recipients (carnet d'adresses)
  static const recipientCreated = 'recipient_created';
  static const recipientDefaultSet = 'recipient_default_set';
  static const recipientSelected = 'recipient_selected';
  static const recipientPickerOpened = 'recipient_picker_opened';
  // Destinataire Yadony par invitation (lot 4). Jamais le numéro ni l'email.
  static const recipientInvitationSent = 'recipient_invitation_sent';
  static const recipientInvitationAnswered = 'recipient_invitation_answered';
  static const recipientInvitationRevoked = 'recipient_invitation_revoked';
  static const recipientInvitationAppLinkShared =
      'recipient_invitation_app_link_shared';

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
  static const tripRescheduled = 'trip_rescheduled';
  static const tripRescheduleDecided = 'trip_reschedule_decided';
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

  /// Offre retirée sur le fil de négociation d'un trajet. Propriétés
  /// `bid_id`, `round`, `actor`.
  static const tripNegotiationCancelled = 'trip_negotiation_cancelled';

  /// Offre carte créée, en attente de paiement (`/bids/checkout`).
  /// Propriétés `announcement_id`, `bid_id`, `weight_kg`, `currency`,
  /// `payment_method`.
  static const bidCheckoutStarted = 'bid_checkout_started';

  /// Création d'offre refusée. Propriétés `payment_method`, `error_code`.
  static const bidSubmitFailed = 'bid_submit_failed';

  /// Acceptation d'une offre en espèces refusée (commission). Propriétés
  /// `bid_id`, `method` (`wallet_balance`/`card`), `reason`, `error_code`.
  static const bidAcceptFailed = 'bid_accept_failed';
  static const tripNegotiationPaymentStarted =
      'trip_negotiation_payment_started';

  // Affiche de trajet — le voyageur la génère puis la poste sur ses propres
  // canaux. Ces trois events mesurent le seul entonnoir qui compte ici :
  // combien d'affiches ouvertes finissent réellement publiées.
  static const tripPosterOpened = 'trip_poster_opened';
  static const tripPosterShared = 'trip_poster_shared';
  static const tripPosterLinkCopied = 'trip_poster_link_copied';

  /// Échec d'un enregistrement dans la galerie (affiche de trajet ou de
  /// demande, QR code du colis), YADONY-FLUTTER-PROD-T. Propriétés `context`,
  /// `stage` (`request_access`/`write`) et `error_code`.
  static const gallerySaveFailed = 'gallery_save_failed';

  // Affiche de demande d'envoi — jumelle de l'affiche de trajet, côté
  // expéditeur : il la poste pour trouver un voyageur sur son axe.
  static const packageRequestPosterOpened = 'package_request_poster_opened';
  static const packageRequestPosterShared = 'package_request_poster_shared';
  static const packageRequestPosterLinkCopied =
      'package_request_poster_link_copied';

  // Écran de composition de la recherche (« Filtrer »)
  static const searchComposerOpened = 'search_composer_opened';
  static const searchFilterApplied = 'search_filter_applied';
  static const searchFilterCleared = 'search_filter_cleared';
  static const searchSubmitted = 'search_submitted';
  static const searchSimilarShown = 'search_similar_shown';

  // Onboarding progressif — lot 1
  static const onboardingStepSkipped = 'onboarding_step_skipped';

  // Onboarding progressif — lot 2
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingStepCompleted = 'onboarding_step_completed';
  static const onboardingCompleted = 'onboarding_completed';

  // Onboarding progressif — lot 3
  //
  // Nom légal *déclaré* par l'utilisateur, à ne pas confondre avec l'identité
  // *vérifiée* par Stripe Identity. Émis sans aucune property par
  // `PersonalInfoCubit.submit()` : le seul signal utile est que l'étape a
  // abouti, et le nom lui-même ne doit jamais partir dans l'analytics.
  static const onboardingIdentityDeclared = 'onboarding_identity_declared';

  /// Choix de l'écran de fin d'inscription : trip, parcel ou later.
  static const firstStepsChoice = 'first_steps_choice';
  static const intentDeclared = 'intent_declared';
  static const intentPromptShown = 'intent_prompt_shown';
  static const firstActionCardTapped = 'first_action_card_tapped';
  static const successScreenTertiaryTapped = 'success_screen_tertiary_tapped';

  // Langue serveur — synchronisation de la langue effective de l'app avec
  // `preferredLanguage` du compte (`LanguageSyncCubit`).
  static const preferredLanguageSynced = 'preferred_language_synced';

  // Billets d'avion en affiliation (onglet Billets, `features/flights`).
  // Aucune ville saisie, aucun prix exact ni numéro ne part dans l'analytics.
  static const flightsSearchSubmitted = 'flights_search_submitted';
  static const flightsSearchFailed = 'flights_search_failed';
  static const flightsPrefillApplied = 'flights_prefill_applied';
  static const flightsDealOpened = 'flights_deal_opened';
  static const flightsFilterApplied = 'flights_filter_applied';
  static const flightsOfferClicked = 'flights_offer_clicked';
  static const flightsOfferOpenFailed = 'flights_offer_open_failed';
  static const flightsAlertCreated = 'flights_alert_created';
  static const flightsAlertToggled = 'flights_alert_toggled';
  static const flightsAlertDeleted = 'flights_alert_deleted';
  static const flightsSortTabChanged = 'flights_sort_tab_changed';
  static const flightsRecentSearchOpened = 'flights_recent_search_opened';
  static const flightsRecentSearchesCleared = 'flights_recent_searches_cleared';
  static const flightsAllAirlinesOpened = 'flights_all_airlines_opened';
  static const flightsSimilarOffersShown = 'flights_similar_offers_shown';
  static const flightsEmptySuggestionTapped = 'flights_empty_suggestion_tapped';
  static const flightsLocationUsed = 'flights_location_used';
  static const flightsAlertOffersViewed = 'flights_alert_offers_viewed';

  // ── Mode maintenance ───────────────────────────────────────────────────
  /// L'écran de maintenance recouvre l'app (propriété `source` : `status`
  /// relecture de `/config/maintenance`, `api` 503 d'une requête).
  static const maintenanceScreenShown = 'maintenance_screen_shown';

  /// L'écran de maintenance se referme à la réouverture (propriété
  /// `duration_s` : secondes passées dessus).
  static const maintenanceEnded = 'maintenance_ended';

  /// « Réessayer » touché sur l'écran de maintenance.
  static const maintenanceRetryTapped = 'maintenance_retry_tapped';

  // ── GP Pro (badge de voyageur régulier accordé par l'admin) ────────────
  /// Écran de candidature GP Pro ouvert.
  static const gpProApplicationOpened = 'gp_pro_application_opened';

  /// Candidature GP Pro envoyée.
  static const gpProApplicationSubmitted = 'gp_pro_application_submitted';

  /// Candidature GP Pro en attente annulée par le voyageur.
  static const gpProApplicationCancelled = 'gp_pro_application_cancelled';

  /// Pièce jointe ajoutée à la candidature.
  static const gpProDocumentAdded = 'gp_pro_document_added';

  /// Pièce jointe retirée de la candidature.
  static const gpProDocumentRemoved = 'gp_pro_document_removed';

  /// Badge GP Pro touché (propriété `surface` : écran d'origine).
  static const gpProBadgeTapped = 'gp_pro_badge_tapped';

  /// Entrée GP Pro du menu de l'onglet Moi.
  static const profileMenuGpProOpened = 'profile_menu_gp_pro_opened';

  // ── Suivi approximatif du voyageur ─────────────────────────────────────
  /// « Je pars » confirmé depuis l'écran du trajet (propriété `has_position`).
  /// Jamais de coordonnées.
  static const tripDepartureConfirmed = 'trip_departure_confirmed';

  /// Position envoyée en silence à la reprise de l'app (propriété `source` :
  /// `resume`). Jamais de coordonnées.
  static const tripPositionSent = 'trip_position_sent';

  /// Carte « Suivi du voyageur » affichée à l'expéditeur, une fois par
  /// instance de carte (propriétés `status` : `not_activated` / `en_route` /
  /// `arrived` / `stale`, et `has_history` bool). Jamais de ville ni de
  /// coordonnées.
  static const travelerTrackingCardViewed = 'traveler_tracking_card_viewed';

  /// Lien « Voir toutes les étapes et photos » de la carte ouvert (propriété
  /// `status`, mêmes valeurs).
  static const travelerTrackingTimelineOpened =
      'traveler_tracking_timeline_opened';

  /// Tuile de la grille « Votre envoi » de la fiche colis (vue expéditeur)
  /// touchée : son bottom sheet s'ouvre (propriété `tile` : `prevenir` /
  /// `suivi` / `lieux` / `colis` / `details`). Ni identifiant ni nom.
  static const bidDetailTileOpened = 'bid_detail_tile_opened';

  /// Envoi silencieux de la position non fait (propriété `reason` :
  /// `no_permission` ou `no_position` seulement).
  static const tripPositionSkipped = 'trip_position_skipped';

  /// Feuille de consentement au suivi du trajet affichée (propriété `source` :
  /// `accepted_parcel` / `trip_screen` / `depart` / `settings`).
  static const trackingConsentSheetShown = 'tracking_consent_sheet_shown';

  /// Réponse au partage de l'avancée du trajet (propriétés `granted` : bool,
  /// vrai seulement si la position du système est accordée, et `source`).
  static const trackingConsentAnswered = 'tracking_consent_answered';
}
