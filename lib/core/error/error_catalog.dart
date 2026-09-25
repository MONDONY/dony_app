import 'package:dony/core/error/app_exception.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// How an error should be presented to the user.
///
/// - [info]    : neutral message (snackbar bleu).
/// - [warning] : action utilisateur attendue (snackbar orange).
/// - [error]   : échec de l'action (snackbar rouge).
/// - [critical]: bloque le flow (dialog rouge avec CTA).
enum ErrorSeverity { info, warning, error, critical }

/// Self-contained presentation payload for a single error case.
class ErrorPresentation {
  const ErrorPresentation({
    required this.title,
    required this.message,
    required this.severity,
    required this.icon,
  });

  final String title;
  final String message;
  final ErrorSeverity severity;
  final IconData icon;
}

/// Entrée du catalogue : textes résolus à la demande dans la langue voulue.
class _Entry {
  const _Entry({
    required this.title,
    required this.message,
    required this.severity,
    required this.icon,
  });

  final String Function(AppLocalizations l) title;
  final String Function(AppLocalizations l) message;
  final ErrorSeverity severity;
  final IconData icon;

  ErrorPresentation resolve(AppLocalizations l) => ErrorPresentation(
    title: title(l),
    message: message(l),
    severity: severity,
    icon: icon,
  );
}

/// Resolves an [AppException] (or raw error) to a user-facing
/// [ErrorPresentation] in the current app language (French by default).
///
/// Lookup order:
///   1. `error.code` matched against [_byCode] (back-end business codes).
///   2. Runtime type of the exception (Offline, Timeout, …).
///   3. Generic catch-all.
abstract final class ErrorCatalog {
  /// Business codes emitted by the Spring Boot back-end via
  /// `DonyBusinessException` → ProblemDetail `code`.
  /// Source: `dony-back/.../DonyBusinessException` invocations (29 codes).
  static final Map<String, _Entry> _byCode = {
    // ─── Mobile money (pawaPay) ───────────────────────────────────────
    // Rail de versement voyageur (Wave / Orange Money) : activation du
    // compte de versement (`mobile-money-account-*`, `MobileMoneyAccountService`)
    // et paiement d'un bid par l'expéditeur (`mobile-money-payment-*`,
    // `mobile-money-deposit-*`, `mobile-money-operation-*`,
    // `mobile-money-provider-*`, `MobileMoneyBidPaymentService` /
    // `PawapayOperationService` / `PawapayErrors`). Le code
    // `payment-method-unavailable-for-currency`, partagé avec la carte,
    // reste documenté plus bas avec son groupe d'origine.
    'mobile-money-disabled': _Entry(
      title: (l) => l.errorMobileMoneyDisabledTitle,
      message: (l) => l.errorMobileMoneyDisabledMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    // Le message ne présume plus d'un profil à compléter : l'app propose
    // maintenant la saisie du numéro directement dans le flux (formulaire de
    // versement, relance de paiement) plutôt que de renvoyer vers le profil.
    'mobile-money-phone-required': _Entry(
      title: (l) => l.errorMobileMoneyPhoneRequiredTitle,
      message: (l) => l.errorMobileMoneyPhoneRequiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'mobile-money-account-unsupported': _Entry(
      title: (l) => l.errorMobileMoneyAccountUnsupportedTitle,
      message: (l) => l.errorMobileMoneyAccountUnsupportedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'mobile-money-account-required': _Entry(
      title: (l) => l.errorMobileMoneyAccountRequiredTitle,
      message: (l) => l.errorMobileMoneyAccountRequiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'mobile-money-currency-mismatch': _Entry(
      title: (l) => l.errorMobileMoneyCurrencyMismatchTitle,
      message: (l) => l.errorMobileMoneyCurrencyMismatchMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'mobile-money-not-available': _Entry(
      title: (l) => l.errorMobileMoneyNotAvailableTitle,
      message: (l) => l.errorMobileMoneyNotAvailableMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'mobile-money-payer-unsupported': _Entry(
      title: (l) => l.errorMobileMoneyPayerUnsupportedTitle,
      message: (l) => l.errorMobileMoneyPayerUnsupportedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    // 422 renvoyée quand le numéro payeur, une fois normalisé côté client
    // (normalizePayerPhone), reste invalide pour tout opérateur mobile
    // money (aucun réseau ne le reconnaît).
    'mobile-money-invalid-phone': _Entry(
      title: (l) => l.errorMobileMoneyInvalidPhoneTitle,
      message: (l) => l.errorMobileMoneyInvalidPhoneMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'mobile-money-deposit-rejected': _Entry(
      title: (l) => l.errorMobileMoneyDepositRejectedTitle,
      message: (l) => l.errorMobileMoneyDepositRejectedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'mobile-money-payment-expired': _Entry(
      title: (l) => l.errorMobileMoneyPaymentExpiredTitle,
      message: (l) => l.errorMobileMoneyPaymentExpiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    // 409 : le paiement a déjà quitté l'état PENDING (confirmé, expiré ou
    // refusé) au moment où le client agit dessus, ex. régénération de lien
    // (MobileMoneyBidPaymentService) — rien à corriger côté utilisateur,
    // un simple constat, comme `bid-already-paid`/`payment-already-completed`
    // plus bas.
    'mobile-money-payment-not-pending': _Entry(
      title: (l) => l.errorMobileMoneyPaymentNotPendingTitle,
      message: (l) => l.errorMobileMoneyPaymentNotPendingMessage,
      severity: ErrorSeverity.info,
      icon: Icons.info_outline_rounded,
    ),
    // 409 : un dépôt pawaPay est déjà en cours pour ce bid
    // (PawapayOperationService), aligné sur `active-transactions` plus bas
    // (même sévérité et icône : une opération en cours empêche l'action).
    'mobile-money-operation-in-progress': _Entry(
      title: (l) => l.errorMobileMoneyOperationInProgressTitle,
      message: (l) => l.errorMobileMoneyOperationInProgressMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.pending_rounded,
    ),
    // 502 : pawaPay ne répond pas (PawapayErrors), aligné sur les autres
    // services externes indisponibles plus bas (`SERVER_ERROR`,
    // `email-service-error`, `firebase-error` : sévérité error).
    'mobile-money-provider-unavailable': _Entry(
      title: (l) => l.errorMobileMoneyProviderUnavailableTitle,
      message: (l) => l.errorMobileMoneyProviderUnavailableMessage,
      severity: ErrorSeverity.error,
      icon: Icons.cloud_off_rounded,
    ),
    'invalid-payment-method': _Entry(
      title: (l) => l.errorInvalidPaymentMethodTitle,
      message: (l) => l.errorInvalidPaymentMethodMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),

    // ─── Budget d'une demande hors du plafond de sa devise ──────────────
    // Le serveur borne le budget dans la devise de la demande (560 € mis à
    // l'échelle). Le formulaire l'empêche déjà ; l'entrée couvre un client
    // pas à jour ou une devise dont le taux a bougé, sans « Erreur réseau ».
    'request/budget-out-of-bounds': _Entry(
      title: (l) => l.errorRequestBudgetOutOfBoundsTitle,
      message: (l) => l.errorRequestBudgetOutOfBoundsMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.rule_rounded,
    ),
    // ─── Course à la commission (accord en espèces) ──────────────────
    // Sans ces deux entrées, le voyageur qui perd la course lit « Action
    // impossible, l'état actuel ne permet pas cette action », soit exactement
    // le message technique que la règle métier proscrit : il doit comprendre
    // qu'un autre voyageur a réglé avant lui.
    'request/already-accepted': _Entry(
      title: (l) => l.errorRequestAlreadyAcceptedTitle,
      message: (l) => l.errorRequestAlreadyAcceptedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'thread/not-awaiting-commission': _Entry(
      title: (l) => l.errorThreadNotAwaitingCommissionTitle,
      message: (l) => l.errorThreadNotAwaitingCommissionMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    // ─── Auth / accès ────────────────────────────────────────────────
    'unauthorized': _Entry(
      title: (l) => l.errorUnauthorizedTitle,
      message: (l) => l.errorUnauthorizedMessage,
      severity: ErrorSeverity.error,
      icon: Icons.lock_outline,
    ),
    'reauth-required': _Entry(
      title: (l) => l.errorReauthRequiredTitle,
      message: (l) => l.errorReauthRequiredMessage,
      severity: ErrorSeverity.error,
      icon: Icons.lock_reset_rounded,
    ),
    'forbidden': _Entry(
      title: (l) => l.errorForbiddenTitle,
      message: (l) => l.errorForbiddenMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.block_rounded,
    ),
    'access-denied': _Entry(
      title: (l) => l.errorAccessDeniedTitle,
      message: (l) => l.errorAccessDeniedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.do_not_disturb_alt_rounded,
    ),
    'account-banned': _Entry(
      title: (l) => l.errorAccountBannedTitle,
      message: (l) => l.errorAccountBannedMessage,
      severity: ErrorSeverity.critical,
      icon: Icons.gpp_bad_rounded,
    ),
    // Émis par `_AuthInterceptor.onRequest` (api_client.dart) quand
    // `FirebaseAuth.currentUser.getIdToken()` échoue : sans entrée dédiée,
    // le code retombait sur le type `UnauthorizedException` générique
    // (`unauthorized`), qui pousse à se reconnecter alors que la session
    // Firebase est valide — seul le rafraîchissement du jeton a échoué.
    'auth-token-unavailable': _Entry(
      title: (l) => l.errorAuthTokenUnavailableTitle,
      message: (l) => l.errorAuthTokenUnavailableMessage,
      severity: ErrorSeverity.error,
      icon: Icons.lock_outline_rounded,
    ),

    // ─── Connexion : repli générique d'AuthBloc._friendlyError ─────────
    // Les huit entrées `firebase-*` qui vivaient ici référençaient une méthode
    // disparue (`_friendlyFirebaseError`) : plus aucun émetteur, retirées. Le
    // parcours téléphone passe par le back (`phone-otp-*` ci-dessous).
    'auth-generic-error': _Entry(
      title: (l) => l.errorAuthGenericErrorTitle,
      message: (l) => l.errorAuthGenericErrorMessage,
      severity: ErrorSeverity.error,
      icon: Icons.error_outline_rounded,
    ),

    // Codes émis par le backend (POST /auth/sms-otp/*), préfixés `phone-otp-`
    // pour ne jamais collisionner avec les codes homonymes de l'email OTP
    // (`otp-invalid`/`otp-expired` plus bas) ni ceux de confirmation de
    // livraison — un OTP téléphone expiré ne doit pas afficher un texte pensé
    // pour un autre canal.
    'phone-otp-invalid': _Entry(
      title: (l) => l.errorPhoneOtpInvalidTitle,
      message: (l) => l.errorPhoneOtpInvalidMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.password_rounded,
    ),
    'phone-otp-expired': _Entry(
      title: (l) => l.errorPhoneOtpExpiredTitle,
      message: (l) => l.errorPhoneOtpExpiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.timer_off_rounded,
    ),
    'phone-otp-attempts-exceeded': _Entry(
      title: (l) => l.errorPhoneOtpAttemptsExceededTitle,
      message: (l) => l.errorPhoneOtpAttemptsExceededMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.hourglass_top_rounded,
    ),
    'phone-otp-rate-limit': _Entry(
      title: (l) => l.errorPhoneOtpRateLimitTitle,
      message: (l) => l.errorPhoneOtpRateLimitMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.hourglass_top_rounded,
    ),
    'phone-already-set': _Entry(
      title: (l) => l.errorPhoneAlreadySetTitle,
      message: (l) => l.errorPhoneAlreadySetMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.phone_disabled_rounded,
    ),
    'phone-already-exists': _Entry(
      title: (l) => l.errorPhoneAlreadyExistsTitle,
      message: (l) => l.errorPhoneAlreadyExistsMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.phone_disabled_rounded,
    ),
    'sms-otp-disabled': _Entry(
      title: (l) => l.errorSmsOtpDisabledTitle,
      message: (l) => l.errorSmsOtpDisabledMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.phone_disabled_rounded,
    ),

    // Le transporteur SMS (Twilio 21211/21614) refuse le numéro lui-même : le
    // back répond désormais 422 au lieu d'un « code envoyé » qui n'arrivait
    // jamais (Sentry YADONY-BACK-STAGING-2, +225 à neuf chiffres).
    'invalid-phone-number': _Entry(
      title: (l) => l.errorInvalidPhoneNumberTitle,
      message: (l) => l.errorInvalidPhoneNumberMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.phone_disabled_rounded,
    ),

    // ─── Annonces / trajets ──────────────────────────────────────────
    'announcement-not-found': _Entry(
      title: (l) => l.errorAnnouncementNotFoundTitle,
      message: (l) => l.errorAnnouncementNotFoundMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.search_off_rounded,
    ),
    // Le voyageur tente de modifier un trajet (dates, capacité, prix…) sur
    // lequel des colis sont déjà acceptés (announcement_bloc.dart, 409).
    'announcement-update-blocked': _Entry(
      title: (l) => l.errorAnnouncementUpdateBlockedTitle,
      message: (l) => l.errorAnnouncementUpdateBlockedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.block_rounded,
    ),
    'currency-mismatch': _Entry(
      title: (l) => l.errorCurrencyMismatchTitle,
      message: (l) => l.errorCurrencyMismatchMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.currency_exchange_rounded,
    ),
    // ─── Pays (la devise en est dérivée côté serveur) ────────────────
    // Sans ces trois entrées, un voyageur qui a passé l'étape pays (ce que le
    // parcours autorise) lit un message générique au moment de créer son
    // compte de paiement, sans aucun moyen de deviner quoi corriger.
    'country-required': _Entry(
      title: (l) => l.errorCountryRequiredTitle,
      message: (l) => l.errorCountryRequiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.public_rounded,
    ),
    'country-locked': _Entry(
      title: (l) => l.errorCountryLockedTitle,
      message: (l) => l.errorCountryLockedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.lock_outline_rounded,
    ),
    'country-unsupported': _Entry(
      title: (l) => l.errorCountryUnsupportedTitle,
      message: (l) => l.errorCountryUnsupportedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.public_off_rounded,
    ),
    'deletion-impossible': _Entry(
      title: (l) => l.errorDeletionImpossibleTitle,
      message: (l) => l.errorDeletionImpossibleMessage,
      severity: ErrorSeverity.critical,
      icon: Icons.event_busy_rounded,
    ),
    // Suppression de compte bloquée par un escrow actif (RequestDeletion /
    // ConfirmImmediateDeletion, account_deletion_bloc.dart) : cette entrée
    // n'atteint l'utilisateur que si `AccountDeletionError` parvient jusqu'à
    // `ErrorPresenter` (listener générique de profile_screen.dart) — les deux
    // sheets de suppression interceptent `isEscrowBlocked` avant et affichent
    // leur propre texte (`EscrowBlockDialog`, `deletionEscrowBlocked*`).
    'escrow-blocked': _Entry(
      title: (l) => l.errorEscrowBlockedTitle,
      message: (l) => l.errorEscrowBlockedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.lock_clock_rounded,
    ),
    'pro-limit-reached': _Entry(
      title: (l) => l.errorProLimitReachedTitle,
      message: (l) => l.errorProLimitReachedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.workspace_premium_outlined,
    ),
    'draft-limit-reached': _Entry(
      title: (l) => l.errorDraftLimitReachedTitle,
      message: (l) => l.errorDraftLimitReachedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.drafts_outlined,
    ),
    'not-a-draft': _Entry(
      title: (l) => l.errorNotADraftTitle,
      message: (l) => l.errorNotADraftMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.info_outline_rounded,
    ),
    'publishing-suspended': _Entry(
      title: (l) => l.errorPublishingSuspendedTitle,
      message: (l) => l.errorPublishingSuspendedMessage,
      severity: ErrorSeverity.critical,
      icon: Icons.gpp_bad_rounded,
    ),
    'kyc-not-verified': _Entry(
      title: (l) => l.errorKycNotVerifiedTitle,
      message: (l) => l.errorKycNotVerifiedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.badge_outlined,
    ),
    'departure-date-passed': _Entry(
      title: (l) => l.errorDepartureDatePassedTitle,
      message: (l) => l.errorDepartureDatePassedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.event_busy_rounded,
    ),

    // ─── Colis / Bids ────────────────────────────────────────────────
    'bid-not-found': _Entry(
      title: (l) => l.errorBidNotFoundTitle,
      message: (l) => l.errorBidNotFoundMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.search_off_rounded,
    ),
    // Le voyageur n'accepte que les profils vérifiés : c'est son choix, pas un
    // blocage de Yadony. Le message oriente vers la vérification d'identité, qui
    // est la seule issue pour cet expéditeur.
    'contact-kyc-required': _Entry(
      title: (l) => l.errorContactKycRequiredTitle,
      message: (l) => l.errorContactKycRequiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.badge_outlined,
    ),
    'bid-not-accepted': _Entry(
      title: (l) => l.errorBidNotAcceptedTitle,
      message: (l) => l.errorBidNotAcceptedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.pending_actions_rounded,
    ),
    'bid-not-delivered': _Entry(
      title: (l) => l.errorBidNotDeliveredTitle,
      message: (l) => l.errorBidNotDeliveredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.inventory_2_outlined,
    ),
    'invalid-bid-status': _Entry(
      title: (l) => l.errorInvalidBidStatusTitle,
      message: (l) => l.errorInvalidBidStatusMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.error_outline_rounded,
    ),
    'use-confirm-delivery': _Entry(
      title: (l) => l.errorUseConfirmDeliveryTitle,
      message: (l) => l.errorUseConfirmDeliveryMessage,
      severity: ErrorSeverity.info,
      icon: Icons.check_circle_outline_rounded,
    ),

    // ─── Tracking / QR / codes ───────────────────────────────────────
    'qr-not-ready': _Entry(
      title: (l) => l.errorQrNotReadyTitle,
      message: (l) => l.errorQrNotReadyMessage,
      severity: ErrorSeverity.info,
      icon: Icons.qr_code_2_rounded,
    ),
    // Second scan DEPART sur un colis déjà remis : le back répond 409 au lieu
    // du 500 d'index unique (Sentry YADONY-BACK-STAGING-8). Rien à refaire.
    'depart-already-scanned': _Entry(
      title: (l) => l.errorDepartAlreadyScannedTitle,
      message: (l) => l.errorDepartAlreadyScannedMessage,
      severity: ErrorSeverity.info,
      icon: Icons.check_circle_outline_rounded,
    ),
    'code-not-generated': _Entry(
      title: (l) => l.errorCodeNotGeneratedTitle,
      message: (l) => l.errorCodeNotGeneratedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.dialpad_rounded,
    ),
    'code-expired': _Entry(
      title: (l) => l.errorCodeExpiredTitle,
      message: (l) => l.errorCodeExpiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.timer_off_rounded,
    ),
    'code-incorrect': _Entry(
      title: (l) => l.errorCodeIncorrectTitle,
      message: (l) => l.errorCodeIncorrectMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.password_rounded,
    ),
    'too-many-attempts': _Entry(
      title: (l) => l.errorTooManyAttemptsTitle,
      message: (l) => l.errorTooManyAttemptsMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.hourglass_top_rounded,
    ),
    'too-many-refreshes': _Entry(
      title: (l) => l.errorTooManyRefreshesTitle,
      message: (l) => l.errorTooManyRefreshesMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.refresh_rounded,
    ),
    'invalid-timestamp': _Entry(
      title: (l) => l.errorInvalidTimestampTitle,
      message: (l) => l.errorInvalidTimestampMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.access_time_rounded,
    ),
    'invalid-window': _Entry(
      title: (l) => l.errorInvalidWindowTitle,
      message: (l) => l.errorInvalidWindowMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.schedule_rounded,
    ),

    // ─── Annulations / litiges ───────────────────────────────────────
    'already-cancelled': _Entry(
      title: (l) => l.errorAlreadyCancelledTitle,
      message: (l) => l.errorAlreadyCancelledMessage,
      severity: ErrorSeverity.info,
      icon: Icons.cancel_outlined,
    ),
    'active-transactions': _Entry(
      title: (l) => l.errorActiveTransactionsTitle,
      message: (l) => l.errorActiveTransactionsMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.pending_rounded,
    ),
    'invalid-status': _Entry(
      title: (l) => l.errorInvalidStatusTitle,
      message: (l) => l.errorInvalidStatusMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.error_outline_rounded,
    ),
    'not-pending-deletion': _Entry(
      title: (l) => l.errorNotPendingDeletionTitle,
      message: (l) => l.errorNotPendingDeletionMessage,
      severity: ErrorSeverity.info,
      icon: Icons.info_outline_rounded,
    ),

    // ─── Évaluations ─────────────────────────────────────────────────
    'already-rated': _Entry(
      title: (l) => l.errorAlreadyRatedTitle,
      message: (l) => l.errorAlreadyRatedMessage,
      severity: ErrorSeverity.info,
      icon: Icons.star_outline_rounded,
    ),
    'rating-window-expired': _Entry(
      title: (l) => l.errorRatingWindowExpiredTitle,
      message: (l) => l.errorRatingWindowExpiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.timer_off_rounded,
    ),

    // ─── Négociation ─────────────────────────────────────────────────
    // Trois codes déjà portés par `negotiation_bloc._handleCommissionResponse`
    // pour le règlement (par le voyageur) de la commission d'un accord cash.
    // `commission/failed` NE va PAS dans `_serverDetailCodes` : contrairement
    // à `commission/confirm-failed` (detail rédigé en prose côté serveur),
    // `r.error` y porte un code machine kebab-case
    // (`CashCommissionService.settleNegotiationCommission` : no-commission-card,
    // card-status-<statut Stripe>, card-declined, stripe-error) qui ne doit
    // jamais atteindre l'utilisateur brut (Ruling R35) — `lookup()` le traduit
    // via `_commissionFailureMessage` avant affichage.
    'commission/confirm-failed': _Entry(
      title: (l) => l.errorCommissionConfirmFailedTitle,
      message: (l) => l.errorCommissionConfirmFailedMessage,
      severity: ErrorSeverity.error,
      icon: Icons.error_outline_rounded,
    ),
    'commission/3ds-interrupted': _Entry(
      title: (l) => l.errorCommission3dsInterruptedTitle,
      message: (l) => l.errorCommission3dsInterruptedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.gpp_maybe_rounded,
    ),
    'commission/failed': _Entry(
      title: (l) => l.errorCommissionFailedTitle,
      message: (l) => l.errorCommissionFailedMessage,
      severity: ErrorSeverity.critical,
      icon: Icons.credit_card_off_rounded,
    ),
    'negotiation/commission-charge-failed': _Entry(
      title: (l) => l.errorNegotiationCommissionChargeFailedTitle,
      message: (l) => l.errorNegotiationCommissionChargeFailedMessage,
      severity: ErrorSeverity.critical,
      icon: Icons.account_balance_wallet_outlined,
    ),
    // Dépôt mobile money d'un fil de négociation (colis) :
    // `POST /negotiations/{id}/mobile-money/*` (`NegotiationDepositService`).
    // Tutoiement, l'expéditeur est le payeur sur ces écrans.
    //
    // 409 : le fil n'est pas (ou plus) en AWAITING_DEPOSIT quand l'expéditeur
    // renonce ou reprend le dépôt. Simple constat, comme
    // `mobile-money-payment-not-pending`.
    'negotiation/not-awaiting-deposit': _Entry(
      title: (l) => l.errorNegotiationNotAwaitingDepositTitle,
      message: (l) => l.errorNegotiationNotAwaitingDepositMessage,
      severity: ErrorSeverity.info,
      icon: Icons.info_outline_rounded,
    ),
    // 409 : l'opérateur a déjà accepté la demande, le renoncement est refusé
    // tant que la confirmation finale n'est pas tombée (aligné sur
    // `mobile-money-operation-in-progress`).
    'negotiation/deposit-in-flight': _Entry(
      title: (l) => l.errorNegotiationDepositInFlightTitle,
      message: (l) => l.errorNegotiationDepositInFlightMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.pending_rounded,
    ),
    // 422 : le voyageur n'a pas de compte de versement mobile money actif
    // dans la devise du fil au moment du dépôt.
    'negotiation/traveler-cannot-receive-mobile-money': _Entry(
      title: (l) => l.errorNegotiationTravelerCannotReceiveMobileMoneyTitle,
      message: (l) => l.errorNegotiationTravelerCannotReceiveMobileMoneyMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    // Refus du checkout d'un accord de prix négocié sur un trajet. Le payeur
    // est toujours l'expéditeur, d'où le vouvoiement.
    'bid-not-negotiated': _Entry(
      title: (l) => l.errorBidNotNegotiatedTitle,
      message: (l) => l.errorBidNotNegotiatedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.receipt_long_outlined,
    ),
    'bid-not-awaiting-payment': _Entry(
      title: (l) => l.errorBidNotAwaitingPaymentTitle,
      message: (l) => l.errorBidNotAwaitingPaymentMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.hourglass_empty_rounded,
    ),
    'bid-already-paid': _Entry(
      title: (l) => l.errorBidAlreadyPaidTitle,
      message: (l) => l.errorBidAlreadyPaidMessage,
      severity: ErrorSeverity.info,
      icon: Icons.check_circle_outline_rounded,
    ),
    'payment-already-completed': _Entry(
      title: (l) => l.errorPaymentAlreadyCompletedTitle,
      message: (l) => l.errorPaymentAlreadyCompletedMessage,
      severity: ErrorSeverity.info,
      icon: Icons.check_circle_outline_rounded,
    ),
    'traveler-stripe-invalid': _Entry(
      title: (l) => l.errorTravelerStripeInvalidTitle,
      message: (l) => l.errorTravelerStripeInvalidMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.credit_card_off_outlined,
    ),
    'payment-method/traveler-insufficient-funds-cash': _Entry(
      title: (l) => l.errorPaymentMethodTravelerInsufficientFundsCashTitle,
      message: (l) => l.errorPaymentMethodTravelerInsufficientFundsCashMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.account_balance_wallet_outlined,
    ),
    'payment-method/no-commission-card': _Entry(
      title: (l) => l.errorPaymentMethodNoCommissionCardTitle,
      message: (l) => l.errorPaymentMethodNoCommissionCardMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.credit_card_outlined,
    ),
    // 422 : le moyen de paiement demandé au checkout d'un colis n'est pas
    // dans l'ensemble calculé par le serveur pour ce fil (déclaré par
    // l'expéditeur, puis filtré par ce que le voyageur peut honorer).
    'payment-method/not-in-available-set': _Entry(
      title: (l) => l.errorPaymentMethodNotInAvailableSetTitle,
      message: (l) => l.errorPaymentMethodNotInAvailableSetMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    // 422 (back PR #295) : mobile money demandé alors que le voyageur n'a pas
    // de compte de versement dans la devise du fil. Contrairement à
    // `payment-method/card-capability-required`, qui a sa feuille dédiée
    // (`PaymentCapabilityBlock._byCode`), ce code n'a pas d'écran propre : il
    // est affiché via cette entrée du catalogue.
    'payment-method/mobile-money-capability-required': _Entry(
      title: (l) => l.errorPaymentMethodMobileMoneyCapabilityRequiredTitle,
      message: (l) => l.errorPaymentMethodMobileMoneyCapabilityRequiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),

    // ─── Devises et rechargement du portefeuille ─────────────────────
    // Sans ces entrées, ces codes retombaient sur le générique « Données
    // invalides » : le message du serveur, qui disait pourtant quoi faire,
    // n'atteignait jamais l'utilisateur.
    //
    // Seul `wallet-topup-stripe-error` appartient au rechargement. Les deux
    // autres viennent des parcours de paiement d'un colis :
    // `payment-method-unavailable-for-currency` est levé par
    // `BidService.resolvePaymentMethodFor` et `PaymentService.createEscrow`
    // pour la carte, désormais aussi par le rail mobile money (pawaPay)
    // pour la même raison de devise : le message reste donc générique au
    // moyen de paiement plutôt que de nommer la carte.
    // `unsupported-currency` par `CurrencyCatalog.resolve`.
    'wallet-topup-stripe-error': _Entry(
      title: (l) => l.errorWalletTopupStripeErrorTitle,
      message: (l) => l.errorWalletTopupStripeErrorMessage,
      severity: ErrorSeverity.error,
      icon: Icons.account_balance_wallet_outlined,
    ),
    // ─── Recharge du portefeuille par mobile money ───────────────────
    // `WalletMobileMoneyTopupService` (back). Principe retenu en relecture :
    // le detail du serveur n'est affiché que lorsqu'il porte une information
    // que l'app ne possède pas déjà. Sinon l'app écrit son propre message,
    // dans son ton (tutoiement, comme le reste du parcours de recharge).
    //
    // `topup-amount-out-of-range` et `topup-phone-unsupported` sont dans
    // `_serverDetailCodes` : le premier porte les bornes réelles dans la
    // devise de l'opérateur, le second la liste des opérateurs réellement
    // couverts pour ce numéro (même nature que
    // `mobile-money-account-unsupported`, déjà dans l'ensemble). Le texte
    // ci-dessous ne sert que de repli si le detail n'est pas exploitable.
    'topup-amount-out-of-range': _Entry(
      title: (l) => l.errorTopupAmountOutOfRangeTitle,
      message: (l) => l.errorTopupAmountOutOfRangeMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.rule_rounded,
    ),
    // `topup-already-pending` et `topup-phone-required` sont volontairement
    // absents de `_serverDetailCodes` : leur detail backend n'apporte rien
    // que l'app ne sache déjà, et il est rédigé en vouvoiement alors que tout
    // le parcours de recharge tutoie (« Valide le paiement sur ton
    // téléphone », « Payer avec un autre numéro »). L'app écrit donc son
    // propre texte plutôt que d'afficher le detail brut.
    'topup-already-pending': _Entry(
      title: (l) => l.errorTopupAlreadyPendingTitle,
      message: (l) => l.errorTopupAlreadyPendingMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.pending_rounded,
    ),
    'topup-phone-required': _Entry(
      title: (l) => l.errorTopupPhoneRequiredTitle,
      message: (l) => l.errorTopupPhoneRequiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    // Numéro reconnu mais inexploitable pour une recharge (réseau fermé,
    // devise non prise en charge, pays inconnu...). Dans
    // `_serverDetailCodes` : voir le commentaire de groupe ci-dessus.
    'topup-phone-unsupported': _Entry(
      title: (l) => l.errorTopupPhoneUnsupportedTitle,
      message: (l) => l.errorTopupPhoneUnsupportedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'topup-not-found': _Entry(
      title: (l) => l.errorTopupNotFoundTitle,
      message: (l) => l.errorTopupNotFoundMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.search_off_rounded,
    ),
    'payment-method-unavailable-for-currency': _Entry(
      title: (l) => l.errorPaymentMethodUnavailableForCurrencyTitle,
      message: (l) => l.errorPaymentMethodUnavailableForCurrencyMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.credit_card_off_outlined,
    ),
    'unsupported-currency': _Entry(
      title: (l) => l.errorUnsupportedCurrencyTitle,
      message: (l) => l.errorUnsupportedCurrencyMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.currency_exchange_outlined,
    ),

    // ─── Externes (Stripe, Google) ───────────────────────────────────
    // Les deux 409 du compte Connect. Le client crée désormais le compte
    // avant de demander le lien d'onboarding, mais un compte effacé côté
    // Stripe ou un client pas à jour peut encore les rencontrer : sans ces
    // entrées, l'utilisateur lit « L'état actuel ne permet pas cette action »
    // sur un écran qui ne lui propose qu'un seul bouton.
    'stripe-account-required': _Entry(
      title: (l) => l.errorStripeAccountRequiredTitle,
      message: (l) => l.errorStripeAccountRequiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.account_balance_outlined,
    ),
    'stripe-account-invalid': _Entry(
      title: (l) => l.errorStripeAccountInvalidTitle,
      message: (l) => l.errorStripeAccountInvalidMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.account_balance_outlined,
    ),
    'stripe-error': _Entry(
      title: (l) => l.errorStripeErrorTitle,
      message: (l) => l.errorStripeErrorMessage,
      severity: ErrorSeverity.critical,
      icon: Icons.credit_card_off_rounded,
    ),
    'google-timeout': _Entry(
      title: (l) => l.errorGoogleTimeoutTitle,
      message: (l) => l.errorGoogleTimeoutMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.location_off_rounded,
    ),

    // ─── Email OTP ───────────────────────────────────────────────────
    'otp-invalid': _Entry(
      title: (l) => l.errorOtpInvalidTitle,
      message: (l) => l.errorOtpInvalidMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.mark_email_unread_outlined,
    ),
    'otp-expired': _Entry(
      title: (l) => l.errorOtpExpiredTitle,
      message: (l) => l.errorOtpExpiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.timer_off_rounded,
    ),
    // Le budget d'essais est compté par adresse, pas par code : demander un
    // nouveau code ne le remet donc pas à zéro. L'ancien texte invitait pourtant
    // à le faire, envoyant l'utilisateur vers une action qui ne débloquait rien.
    'otp-attempts-exceeded': _Entry(
      title: (l) => l.errorOtpAttemptsExceededTitle,
      message: (l) => l.errorOtpAttemptsExceededMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.hourglass_top_rounded,
    ),
    'email-already-exists': _Entry(
      title: (l) => l.errorEmailAlreadyExistsTitle,
      message: (l) => l.errorEmailAlreadyExistsMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.email_outlined,
    ),
    // 409 au rattachement : l'adresse identifie le compte Firebase, elle
    // s'ajoute mais ne se remplace pas. À distinguer de « email-already-exists »,
    // qui vise une adresse prise par quelqu'un d'autre.
    'email-already-set': _Entry(
      title: (l) => l.errorEmailAlreadySetTitle,
      message: (l) => l.errorEmailAlreadySetMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.email_outlined,
    ),
    // Titre distinct de « Trop de tentatives » : ce cas vise les codes demandés,
    // l'autre les codes mal saisis. Un titre commun laissait croire à l'utilisateur
    // qu'il s'était trompé alors qu'il avait seulement trop cliqué sur « Renvoyer ».
    'rate-limit': _Entry(
      title: (l) => l.errorRateLimitTitle,
      message: (l) => l.errorRateLimitMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.speed_rounded,
    ),
    // Renvoyé quand l'envoi de l'email échoue chez le prestataire (503). Sans
    // cette entrée, l'écran affichait « Quelque chose s'est mal passé de notre
    // côté », qui ne dit pas que réessayer suffit souvent.
    'email-service-error': _Entry(
      title: (l) => l.errorEmailServiceErrorTitle,
      message: (l) => l.errorEmailServiceErrorMessage,
      severity: ErrorSeverity.error,
      icon: Icons.mark_email_unread_outlined,
    ),
    // Échec de création du jeton d'authentification côté serveur (500).
    'firebase-error': _Entry(
      title: (l) => l.errorFirebaseErrorTitle,
      message: (l) => l.errorFirebaseErrorMessage,
      severity: ErrorSeverity.error,
      icon: Icons.lock_reset_rounded,
    ),

    // ─── Codes promo ─────────────────────────────────────────────────
    'promo-not-found': _Entry(
      title: (l) => l.errorPromoNotFoundTitle,
      message: (l) => l.errorPromoNotFoundMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.discount_outlined,
    ),
    'promo-expired': _Entry(
      title: (l) => l.errorPromoExpiredTitle,
      message: (l) => l.errorPromoExpiredMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.timer_off_rounded,
    ),
    'promo-limit-reached': _Entry(
      title: (l) => l.errorPromoLimitReachedTitle,
      message: (l) => l.errorPromoLimitReachedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.block_rounded,
    ),
    'promo-not-eligible': _Entry(
      title: (l) => l.errorPromoNotEligibleTitle,
      message: (l) => l.errorPromoNotEligibleMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.do_not_disturb_alt_rounded,
    ),

    // ─── Parrainage ──────────────────────────────────────────────────
    'referral-code-not-found': _Entry(
      title: (l) => l.errorReferralCodeNotFoundTitle,
      message: (l) => l.errorReferralCodeNotFoundMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.person_search_rounded,
    ),
    'self-referral': _Entry(
      title: (l) => l.errorSelfReferralTitle,
      message: (l) => l.errorSelfReferralMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.block_rounded,
    ),
    'already-referred': _Entry(
      title: (l) => l.errorAlreadyReferredTitle,
      message: (l) => l.errorAlreadyReferredMessage,
      severity: ErrorSeverity.info,
      icon: Icons.check_circle_outline_rounded,
    ),

    // ─── Auth (parcours de connexion) ─────────────────────────────────
    'guest-session-failed': _Entry(
      title: (l) => l.errorGuestSessionFailedTitle,
      message: (l) => l.errorGuestSessionFailedMessage,
      severity: ErrorSeverity.error,
      icon: Icons.wifi_off_rounded,
    ),

    // ─── Utilisateur ─────────────────────────────────────────────────
    'user-not-found': _Entry(
      title: (l) => l.errorUserNotFoundTitle,
      message: (l) => l.errorUserNotFoundMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.person_off_rounded,
    ),

    // ─── Synthétiques (transport / interceptor) ──────────────────────
    'OFFLINE': _Entry(
      title: (l) => l.errorOfflineTitle,
      message: (l) => l.errorOfflineMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.signal_wifi_off_rounded,
    ),
    'TIMEOUT': _Entry(
      title: (l) => l.errorTimeoutTitle,
      message: (l) => l.errorTimeoutMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.hourglass_disabled_rounded,
    ),
    'RATE_LIMITED': _Entry(
      title: (l) => l.errorRateLimitedTitle,
      message: (l) => l.errorRateLimitedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.speed_rounded,
    ),
    'SERVER_ERROR': _Entry(
      title: (l) => l.errorServerErrorTitle,
      message: (l) => l.errorServerErrorMessage,
      severity: ErrorSeverity.error,
      icon: Icons.cloud_off_rounded,
    ),
    'CANCELLED': _Entry(
      title: (l) => l.errorCancelledTitle,
      message: (l) => l.errorCancelledMessage,
      severity: ErrorSeverity.info,
      icon: Icons.cancel_outlined,
    ),

    // ─── Signalements (ReportService.java) ─────────────────────────────
    // Ces trois codes 422/403 sont en pratique hors d'atteinte depuis l'UI
    // (incident_report_screen.dart n'envoie jamais un motif hors cible, ne
    // laisse pas signaler son propre profil, et IncidentPhotosCubit.maxPhotos
    // plafonne à 4 avant le MAX_PHOTOS = 5 du back), mais restent couverts
    // pour ne pas relayer un message serveur brut si le contrat évolue.
    'reason-not-applicable': _Entry(
      title: (l) => l.errorReportReasonNotApplicableTitle,
      message: (l) => l.errorReportReasonNotApplicableMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.rule_rounded,
    ),
    'cannot-report-self': _Entry(
      title: (l) => l.errorReportCannotReportSelfTitle,
      message: (l) => l.errorReportCannotReportSelfMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
    'too-many-photos': _Entry(
      title: (l) => l.errorReportTooManyPhotosTitle,
      message: (l) => l.errorReportTooManyPhotosMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.image_not_supported_outlined,
    ),
    'photo-not-owned': _Entry(
      title: (l) => l.errorReportPhotoNotOwnedTitle,
      message: (l) => l.errorReportPhotoNotOwnedMessage,
      severity: ErrorSeverity.warning,
      icon: Icons.flag_outlined,
    ),
  };

  /// Codes dont le `detail` renvoyé par le back est déjà rédigé pour
  /// l'utilisateur (ex: devise du portefeuille, réseau indisponible) et plus
  /// précis que le texte fixe du catalogue. Ensemble fermé : tout autre code
  /// garde son texte de catalogue même si le serveur fournit un detail.
  static const Set<String> _serverDetailCodes = {
    'mobile-money-account-unsupported',
    'topup-amount-out-of-range',
    'topup-phone-unsupported',
    // `ConfirmAcceptanceResponse.fail(...)` (confirmNegotiationCommissionAcceptance)
    // rédige une phrase ("PaymentIntent status: ...", "Erreur Stripe : ..."),
    // jamais un code machine — contrairement à `commission/failed` ci-dessous,
    // traité à part dans `lookup()`.
    'commission/confirm-failed',
  };

  /// Codes connus du catalogue, pour les tests de traduction.
  @visibleForTesting
  static Iterable<String> get debugCodes => _byCode.keys;

  /// Resolves an exception to its presentation, in [l10n] or, by default, in
  /// the current app language ([AppL10n.current]). Never returns null:
  /// always falls back to a generic message rather than leaking technical
  /// details to the user.
  static ErrorPresentation lookup(Object? error, {AppLocalizations? l10n}) {
    final l = l10n ?? AppL10n.current;
    if (error is AppException) {
      final entry = _byCode[error.code];
      if (entry != null) {
        final p = entry.resolve(l);
        // Ruling R35 : `r.error` de `commission/failed` est un code machine
        // kebab-case (jamais une phrase) — le traduire avant affichage plutôt
        // que de le relayer via `_serverDetailCodes` comme les autres codes.
        if (error.code == 'commission/failed') {
          return ErrorPresentation(
            title: p.title,
            message: _commissionFailureMessage(
              error.message.trim(),
              l,
              p.message,
            ),
            severity: p.severity,
            icon: p.icon,
          );
        }
        // Précédent : `_validationPresentation` construit déjà le message
        // depuis les violations du back plutôt que depuis un texte fixe.
        if (_serverDetailCodes.contains(error.code) &&
            _isUserFacingDetail(error.message)) {
          return ErrorPresentation(
            title: p.title,
            message: error.message.trim(),
            severity: p.severity,
            icon: p.icon,
          );
        }
        return p;
      }
      return _byType(error, l);
    }
    return _generic.resolve(l);
  }

  /// Traduit le code machine kebab-case renvoyé par
  /// `CashCommissionService.settleNegotiationCommission` (`r.error`) dans le
  /// cas `commission/failed`. Ruling R35 : ce code ne doit jamais atteindre
  /// l'utilisateur brut — trois codes connus ont chacun leur texte, tout
  /// `card-status-<statut Stripe>` (l'un des statuts terminaux inattendus de
  /// PaymentIntent) partage un repli générique, et [fallback] (le message de
  /// base du catalogue) couvre tout autre code, connu ou non, y compris un
  /// message vide.
  static String _commissionFailureMessage(
    String raw,
    AppLocalizations l,
    String fallback,
  ) {
    switch (raw) {
      case 'no-commission-card':
        return l.errorCommissionFailedNoCardMessage;
      case 'card-declined':
        return l.errorCommissionFailedCardDeclinedMessage;
      case 'stripe-error':
        return l.errorCommissionFailedStripeErrorMessage;
    }
    if (raw.startsWith('card-status-')) {
      return l.errorCommissionFailedCardStatusMessage;
    }
    return fallback;
  }

  /// Garde simple : un detail rédigé pour l'utilisateur est court, tient sur
  /// une ligne, et ne ressemble pas à une exception technique échappée
  /// jusqu'à l'UI.
  static bool _isUserFacingDetail(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty || trimmed.length > 200) return false;
    if (trimmed.startsWith('DioException') ||
        trimmed.startsWith('Exception') ||
        trimmed.startsWith('HttpException')) {
      return false;
    }
    return !trimmed.contains('\n') && !trimmed.contains('{');
  }

  /// Whether a given error has a dedicated entry in the catalog.
  /// Useful for tests and dev tooling — prod UI never branches on this.
  static bool isKnown(Object? error) {
    if (error is! AppException) return false;
    return _byCode.containsKey(error.code);
  }

  // ─── Type-based fallbacks ──────────────────────────────────────────

  static ErrorPresentation _byType(AppException error, AppLocalizations l) {
    if (error is OfflineException) return _byCode['OFFLINE']!.resolve(l);
    if (error is TimeoutException) return _byCode['TIMEOUT']!.resolve(l);
    if (error is RateLimitException) {
      return _byCode['RATE_LIMITED']!.resolve(l);
    }
    if (error is ServerException) return _byCode['SERVER_ERROR']!.resolve(l);
    if (error is UnauthorizedException) {
      return _byCode['unauthorized']!.resolve(l);
    }
    if (error is ForbiddenException) return _byCode['forbidden']!.resolve(l);
    if (error is NotFoundException) return _notFoundGeneric.resolve(l);
    if (error is ValidationException) {
      return _validationPresentation(error, l);
    }
    if (error is ConflictException) return _conflictGeneric.resolve(l);
    if (error is StorageException) return _storageGeneric.resolve(l);
    return _networkGeneric.resolve(l);
  }

  static final _Entry _notFoundGeneric = _Entry(
    title: (l) => l.errorNotFoundTitle,
    message: (l) => l.errorNotFoundMessage,
    severity: ErrorSeverity.warning,
    icon: Icons.search_off_rounded,
  );

  static final _Entry _validationGeneric = _Entry(
    title: (l) => l.errorValidationTitle,
    message: (l) => l.errorValidationMessage,
    severity: ErrorSeverity.warning,
    icon: Icons.rule_rounded,
  );

  /// Construit un message à partir des violations renvoyées par le backend
  /// (ex. « La capacité doit être d'au moins 1 kg ») au lieu du générique, pour
  /// que l'utilisateur sache exactement quel champ corriger.
  /// Les violations restent le texte du serveur ; elles seront traduites côté
  /// backend (spec 6.3).
  static ErrorPresentation _validationPresentation(
    ValidationException error,
    AppLocalizations l,
  ) {
    final errs = error.errors;
    if (errs == null || errs.isEmpty) return _validationGeneric.resolve(l);
    final messages = errs.values
        .expand((list) => list)
        .where((m) => m.trim().isNotEmpty)
        .toSet()
        .toList();
    if (messages.isEmpty) return _validationGeneric.resolve(l);
    return ErrorPresentation(
      title: l.errorValidationTitle,
      message: messages.join('\n'),
      severity: ErrorSeverity.warning,
      icon: Icons.rule_rounded,
    );
  }

  static final _Entry _conflictGeneric = _Entry(
    title: (l) => l.errorConflictTitle,
    message: (l) => l.errorConflictMessage,
    severity: ErrorSeverity.error,
    icon: Icons.error_outline_rounded,
  );

  static final _Entry _storageGeneric = _Entry(
    title: (l) => l.errorStorageTitle,
    message: (l) => l.errorStorageMessage,
    severity: ErrorSeverity.error,
    icon: Icons.sd_storage_outlined,
  );

  static final _Entry _networkGeneric = _Entry(
    title: (l) => l.errorNetworkTitle,
    message: (l) => l.errorNetworkMessage,
    severity: ErrorSeverity.error,
    icon: Icons.wifi_off_rounded,
  );

  static final _Entry _generic = _Entry(
    title: (l) => l.errorGenericTitle,
    message: (l) => l.errorGenericMessage,
    severity: ErrorSeverity.error,
    icon: Icons.error_outline_rounded,
  );
}
