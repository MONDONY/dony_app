import 'package:dony/core/error/app_exception.dart';
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

/// Resolves an [AppException] (or raw error) to a user-facing
/// [ErrorPresentation] in French.
///
/// Lookup order:
///   1. `error.code` matched against [_byCode] (back-end business codes).
///   2. Runtime type of the exception (Offline, Timeout, …).
///   3. Generic catch-all.
abstract final class ErrorCatalog {
  /// Business codes emitted by the Spring Boot back-end via
  /// `DonyBusinessException` → ProblemDetail `code`.
  /// Source: `dony-back/.../DonyBusinessException` invocations (29 codes).
  static const Map<String, ErrorPresentation> _byCode = {
    // ─── Auth / accès ────────────────────────────────────────────────
    'unauthorized': ErrorPresentation(
      title: 'Session expirée',
      message: 'Reconnecte-toi pour continuer.',
      severity: ErrorSeverity.error,
      icon: Icons.lock_outline,
    ),
    'reauth-required': ErrorPresentation(
      title: 'Reconnexion requise',
      message: 'Pour ta sécurité, identifie-toi à nouveau pour cette action.',
      severity: ErrorSeverity.error,
      icon: Icons.lock_reset_rounded,
    ),
    'forbidden': ErrorPresentation(
      title: 'Action non autorisée',
      message: "Tu n'as pas les droits nécessaires pour cette action.",
      severity: ErrorSeverity.warning,
      icon: Icons.block_rounded,
    ),
    'access-denied': ErrorPresentation(
      title: 'Accès refusé',
      message: 'Tu ne peux pas accéder à cette ressource.',
      severity: ErrorSeverity.warning,
      icon: Icons.do_not_disturb_alt_rounded,
    ),
    'account-banned': ErrorPresentation(
      title: 'Compte suspendu',
      message:
          'Ton compte a été suspendu. Contacte le support pour plus d\'informations.',
      severity: ErrorSeverity.critical,
      icon: Icons.gpp_bad_rounded,
    ),

    // ─── Annonces / trajets ──────────────────────────────────────────
    'announcement-not-found': ErrorPresentation(
      title: 'Trajet introuvable',
      message: 'Ce trajet n\'existe plus ou a été retiré.',
      severity: ErrorSeverity.warning,
      icon: Icons.search_off_rounded,
    ),
    'deletion-impossible': ErrorPresentation(
      title: 'Suppression impossible',
      message:
          "Un colis est déjà accepté sur ce trajet. Annule le voyage à la place : l'expéditeur sera remboursé.",
      severity: ErrorSeverity.critical,
      icon: Icons.event_busy_rounded,
    ),
    'pro-limit-reached': ErrorPresentation(
      title: 'Limite mensuelle atteinte',
      message:
          "Tu as atteint ta limite d'annonces ce mois-ci. Passe en PRO pour publier sans limite.",
      severity: ErrorSeverity.warning,
      icon: Icons.workspace_premium_outlined,
    ),
    'draft-limit-reached': ErrorPresentation(
      title: 'Limite de brouillons atteinte',
      message: 'Passe en PRO pour créer davantage de brouillons.',
      severity: ErrorSeverity.warning,
      icon: Icons.drafts_outlined,
    ),
    'not-a-draft': ErrorPresentation(
      title: 'Déjà publié',
      message: 'Ce trajet n\'est pas un brouillon.',
      severity: ErrorSeverity.warning,
      icon: Icons.info_outline_rounded,
    ),
    'publishing-suspended': ErrorPresentation(
      title: 'Publication suspendue',
      message: 'La publication est suspendue sur ton compte. Contacte le support.',
      severity: ErrorSeverity.critical,
      icon: Icons.gpp_bad_rounded,
    ),
    'kyc-not-verified': ErrorPresentation(
      title: 'Identité non vérifiée',
      message: 'Vérifie ton identité avant de publier un trajet.',
      severity: ErrorSeverity.warning,
      icon: Icons.badge_outlined,
    ),
    'departure-date-passed': ErrorPresentation(
      title: 'Date de départ passée',
      message: 'Modifie la date de départ avant de publier ce trajet.',
      severity: ErrorSeverity.warning,
      icon: Icons.event_busy_rounded,
    ),

    // ─── Colis / Bids ────────────────────────────────────────────────
    'bid-not-found': ErrorPresentation(
      title: 'Demande introuvable',
      message: 'Cette demande n\'existe plus.',
      severity: ErrorSeverity.warning,
      icon: Icons.search_off_rounded,
    ),
    // Le voyageur n'accepte que les profils vérifiés : c'est son choix, pas un
    // blocage de yadony. Le message oriente vers la vérification d'identité, qui
    // est la seule issue pour cet expéditeur.
    'contact-kyc-required': ErrorPresentation(
      title: 'Profil vérifié requis',
      message: 'Ce voyageur ne reçoit que des profils vérifiés. '
          'Vérifie ton identité pour lui envoyer une demande.',
      severity: ErrorSeverity.warning,
      icon: Icons.badge_outlined,
    ),
    'bid-not-accepted': ErrorPresentation(
      title: 'Demande non acceptée',
      message: 'Cette demande doit être acceptée par le voyageur avant cette étape.',
      severity: ErrorSeverity.warning,
      icon: Icons.pending_actions_rounded,
    ),
    'bid-not-delivered': ErrorPresentation(
      title: 'Colis non livré',
      message: 'Cette action nécessite que le colis ait été livré.',
      severity: ErrorSeverity.warning,
      icon: Icons.inventory_2_outlined,
    ),
    'invalid-bid-status': ErrorPresentation(
      title: 'État du colis invalide',
      message: 'Le statut actuel du colis ne permet pas cette action.',
      severity: ErrorSeverity.warning,
      icon: Icons.error_outline_rounded,
    ),
    'use-confirm-delivery': ErrorPresentation(
      title: 'Confirme la livraison',
      message:
          "Pour finaliser, utilise l'écran de confirmation de livraison du destinataire.",
      severity: ErrorSeverity.info,
      icon: Icons.check_circle_outline_rounded,
    ),

    // ─── Tracking / QR / codes ───────────────────────────────────────
    'qr-not-ready': ErrorPresentation(
      title: 'QR pas encore disponible',
      message:
          'Le QR sera disponible une fois que l\'expéditeur aura finalisé le paiement.',
      severity: ErrorSeverity.info,
      icon: Icons.qr_code_2_rounded,
    ),
    'code-not-generated': ErrorPresentation(
      title: 'Code non généré',
      message:
          'Aucun code de confirmation n\'a encore été généré pour cette livraison.',
      severity: ErrorSeverity.warning,
      icon: Icons.dialpad_rounded,
    ),
    'code-expired': ErrorPresentation(
      title: 'Code expiré',
      message: 'Ce code a expiré. Demande à l\'expéditeur d\'en générer un nouveau.',
      severity: ErrorSeverity.warning,
      icon: Icons.timer_off_rounded,
    ),
    'code-incorrect': ErrorPresentation(
      title: 'Code incorrect',
      message: 'Le code saisi est incorrect. Vérifie auprès de l\'expéditeur.',
      severity: ErrorSeverity.warning,
      icon: Icons.password_rounded,
    ),
    'too-many-attempts': ErrorPresentation(
      title: 'Trop de tentatives',
      message:
          'Tu as fait trop d\'essais. Patiente quelques minutes avant de réessayer.',
      severity: ErrorSeverity.warning,
      icon: Icons.hourglass_top_rounded,
    ),
    'too-many-refreshes': ErrorPresentation(
      title: 'Limite atteinte',
      message:
          'Tu as déjà rafraîchi le code plusieurs fois. Attends avant de regénérer.',
      severity: ErrorSeverity.warning,
      icon: Icons.refresh_rounded,
    ),
    'invalid-timestamp': ErrorPresentation(
      title: 'Horodatage invalide',
      message: 'L\'horodatage de la lecture est incohérent. Réessaie une fois en ligne.',
      severity: ErrorSeverity.warning,
      icon: Icons.access_time_rounded,
    ),
    'invalid-window': ErrorPresentation(
      title: 'Hors créneau',
      message: 'Cette action n\'est pas autorisée en dehors du créneau prévu.',
      severity: ErrorSeverity.warning,
      icon: Icons.schedule_rounded,
    ),

    // ─── Annulations / litiges ───────────────────────────────────────
    'already-cancelled': ErrorPresentation(
      title: 'Déjà annulé',
      message: 'Cet élément a déjà été annulé.',
      severity: ErrorSeverity.info,
      icon: Icons.cancel_outlined,
    ),
    'active-transactions': ErrorPresentation(
      title: 'Action impossible',
      message:
          'Des transactions sont en cours. Termine-les ou annule-les avant de continuer.',
      severity: ErrorSeverity.warning,
      icon: Icons.pending_rounded,
    ),
    'invalid-status': ErrorPresentation(
      title: 'État invalide',
      message: 'L\'état actuel ne permet pas cette action.',
      severity: ErrorSeverity.warning,
      icon: Icons.error_outline_rounded,
    ),
    'not-pending-deletion': ErrorPresentation(
      title: 'Suppression non demandée',
      message: 'Aucune demande de suppression de compte en attente.',
      severity: ErrorSeverity.info,
      icon: Icons.info_outline_rounded,
    ),

    // ─── Évaluations ─────────────────────────────────────────────────
    'already-rated': ErrorPresentation(
      title: 'Déjà noté',
      message: 'Tu as déjà laissé une note pour cette livraison.',
      severity: ErrorSeverity.info,
      icon: Icons.star_outline_rounded,
    ),
    'rating-window-expired': ErrorPresentation(
      title: 'Délai dépassé',
      message: 'La période pour noter cette livraison est expirée.',
      severity: ErrorSeverity.warning,
      icon: Icons.timer_off_rounded,
    ),

    // ─── Négociation ─────────────────────────────────────────────────
    'negotiation/commission-charge-failed': ErrorPresentation(
      title: 'Accord non validé',
      message:
          "Impossible de finaliser : la commission n'a pas pu être prélevée au voyageur (solde et carte indisponibles). L'accord n'est pas validé.",
      severity: ErrorSeverity.critical,
      icon: Icons.account_balance_wallet_outlined,
    ),
    'payment-method/traveler-insufficient-funds-cash': ErrorPresentation(
      title: 'Solde insuffisant',
      message:
          "Ton portefeuille n'a pas assez de fonds pour payer la commission Yadony en espèces. Recharge-le ou ajoute une carte.",
      severity: ErrorSeverity.warning,
      icon: Icons.account_balance_wallet_outlined,
    ),
    'payment-method/no-commission-card': ErrorPresentation(
      title: 'Carte requise',
      message:
          "Ajoute d'abord une carte de commission pour payer en espèces sans solde suffisant.",
      severity: ErrorSeverity.warning,
      icon: Icons.credit_card_outlined,
    ),

    // ─── Externes (Stripe, Google) ───────────────────────────────────
    'stripe-error': ErrorPresentation(
      title: 'Paiement refusé',
      message:
          'Le paiement n\'a pas pu être traité. Vérifie ta carte ou réessaie dans un instant.',
      severity: ErrorSeverity.critical,
      icon: Icons.credit_card_off_rounded,
    ),
    'google-timeout': ErrorPresentation(
      title: 'Service indisponible',
      message:
          'Le service de localisation est lent à répondre. Réessaie dans quelques secondes.',
      severity: ErrorSeverity.warning,
      icon: Icons.location_off_rounded,
    ),

    // ─── Email OTP ───────────────────────────────────────────────────
    'otp-invalid': ErrorPresentation(
      title: 'Code invalide',
      message: 'Le code saisi est incorrect ou a déjà été utilisé. Vérifie le code reçu par email.',
      severity: ErrorSeverity.warning,
      icon: Icons.mark_email_unread_outlined,
    ),
    'otp-expired': ErrorPresentation(
      title: 'Code expiré',
      message: 'Ce code a expiré. Reviens en arrière et demande un nouveau code.',
      severity: ErrorSeverity.warning,
      icon: Icons.timer_off_rounded,
    ),
    'otp-attempts-exceeded': ErrorPresentation(
      title: 'Trop de tentatives',
      message: 'Trop d\'essais incorrects. Reviens en arrière et demande un nouveau code.',
      severity: ErrorSeverity.warning,
      icon: Icons.hourglass_top_rounded,
    ),
    'email-already-exists': ErrorPresentation(
      title: 'Email déjà utilisé',
      message: 'Cette adresse email est déjà associée à un autre compte.',
      severity: ErrorSeverity.warning,
      icon: Icons.email_outlined,
    ),
    'rate-limit': ErrorPresentation(
      title: 'Trop de tentatives',
      message: 'Tu as demandé trop de codes. Attends 5 minutes avant de réessayer.',
      severity: ErrorSeverity.warning,
      icon: Icons.speed_rounded,
    ),

    // ─── Codes promo ─────────────────────────────────────────────────
    'promo-not-found': ErrorPresentation(
      title: 'Code promo introuvable',
      message: 'Ce code promo n\'existe pas. Vérifie la saisie et réessaie.',
      severity: ErrorSeverity.warning,
      icon: Icons.discount_outlined,
    ),
    'promo-expired': ErrorPresentation(
      title: 'Code promo expiré',
      message: 'Ce code promo n\'est plus valide (expiré ou pas encore actif).',
      severity: ErrorSeverity.warning,
      icon: Icons.timer_off_rounded,
    ),
    'promo-limit-reached': ErrorPresentation(
      title: 'Code promo épuisé',
      message:
          'Ce code promo a atteint sa limite d\'utilisation (globale ou par utilisateur).',
      severity: ErrorSeverity.warning,
      icon: Icons.block_rounded,
    ),
    'promo-not-eligible': ErrorPresentation(
      title: 'Code promo non applicable',
      message: 'Ce code promo n\'est pas disponible pour ton profil.',
      severity: ErrorSeverity.warning,
      icon: Icons.do_not_disturb_alt_rounded,
    ),

    // ─── Parrainage ──────────────────────────────────────────────────
    'referral-code-not-found': ErrorPresentation(
      title: 'Code introuvable',
      message:
          'Ce code de parrainage n\'existe pas. Vérifie la saisie et réessaie.',
      severity: ErrorSeverity.warning,
      icon: Icons.person_search_rounded,
    ),
    'self-referral': ErrorPresentation(
      title: 'Auto-parrainage interdit',
      message: 'Tu ne peux pas utiliser ton propre code de parrainage.',
      severity: ErrorSeverity.warning,
      icon: Icons.block_rounded,
    ),
    'already-referred': ErrorPresentation(
      title: 'Code déjà utilisé',
      message: 'Tu as déjà utilisé un code de parrainage.',
      severity: ErrorSeverity.info,
      icon: Icons.check_circle_outline_rounded,
    ),

    // ─── Utilisateur ─────────────────────────────────────────────────
    'user-not-found': ErrorPresentation(
      title: 'Utilisateur introuvable',
      message: 'Ce compte utilisateur n\'existe plus.',
      severity: ErrorSeverity.warning,
      icon: Icons.person_off_rounded,
    ),

    // ─── Synthétiques (transport / interceptor) ──────────────────────
    'OFFLINE': ErrorPresentation(
      title: 'Pas de connexion',
      message:
          'Vérifie ta connexion Internet puis réessaie. Tes lectures hors-ligne seront synchronisées à la reconnexion.',
      severity: ErrorSeverity.warning,
      icon: Icons.signal_wifi_off_rounded,
    ),
    'TIMEOUT': ErrorPresentation(
      title: 'Le serveur met du temps',
      message: 'La requête a pris trop de temps. Réessaie dans quelques secondes.',
      severity: ErrorSeverity.warning,
      icon: Icons.hourglass_disabled_rounded,
    ),
    'RATE_LIMITED': ErrorPresentation(
      title: 'Trop de requêtes',
      message:
          'Tu as fait trop d\'appels en peu de temps. Patiente un instant avant de réessayer.',
      severity: ErrorSeverity.warning,
      icon: Icons.speed_rounded,
    ),
    'SERVER_ERROR': ErrorPresentation(
      title: 'Erreur serveur',
      message:
          'Quelque chose s\'est mal passé de notre côté. On regarde ça, réessaie dans un instant.',
      severity: ErrorSeverity.error,
      icon: Icons.cloud_off_rounded,
    ),
    'CANCELLED': ErrorPresentation(
      title: 'Action annulée',
      message: 'L\'action a été annulée.',
      severity: ErrorSeverity.info,
      icon: Icons.cancel_outlined,
    ),
  };

  /// Resolves an exception to its presentation. Never returns null:
  /// always falls back to a generic message rather than leaking technical
  /// details to the user.
  static ErrorPresentation lookup(Object? error) {
    if (error is AppException) {
      final byCode = _byCode[error.code];
      if (byCode != null) return byCode;
      return _byType(error);
    }
    return _generic;
  }

  /// Whether a given error has a dedicated entry in the catalog.
  /// Useful for tests and dev tooling — prod UI never branches on this.
  static bool isKnown(Object? error) {
    if (error is! AppException) return false;
    return _byCode.containsKey(error.code);
  }

  // ─── Type-based fallbacks ──────────────────────────────────────────

  static ErrorPresentation _byType(AppException error) {
    if (error is OfflineException) return _byCode['OFFLINE']!;
    if (error is TimeoutException) return _byCode['TIMEOUT']!;
    if (error is RateLimitException) return _byCode['RATE_LIMITED']!;
    if (error is ServerException) return _byCode['SERVER_ERROR']!;
    if (error is UnauthorizedException) return _byCode['unauthorized']!;
    if (error is ForbiddenException) return _byCode['forbidden']!;
    if (error is NotFoundException) return _notFoundGeneric;
    if (error is ValidationException) return _validationPresentation(error);
    if (error is ConflictException) return _conflictGeneric;
    if (error is StorageException) return _storageGeneric;
    return _networkGeneric;
  }

  static const ErrorPresentation _notFoundGeneric = ErrorPresentation(
    title: 'Introuvable',
    message: 'Cette ressource est introuvable ou a été supprimée.',
    severity: ErrorSeverity.warning,
    icon: Icons.search_off_rounded,
  );

  static const ErrorPresentation _validationGeneric = ErrorPresentation(
    title: 'Données invalides',
    message: 'Vérifie les informations saisies puis réessaie.',
    severity: ErrorSeverity.warning,
    icon: Icons.rule_rounded,
  );

  /// Construit un message à partir des violations renvoyées par le backend
  /// (ex. « La capacité doit être d'au moins 1 kg ») au lieu du générique, pour
  /// que l'utilisateur sache exactement quel champ corriger.
  static ErrorPresentation _validationPresentation(ValidationException error) {
    final errs = error.errors;
    if (errs == null || errs.isEmpty) return _validationGeneric;
    final messages = errs.values
        .expand((list) => list)
        .where((m) => m.trim().isNotEmpty)
        .toSet()
        .toList();
    if (messages.isEmpty) return _validationGeneric;
    return ErrorPresentation(
      title: 'Données invalides',
      message: messages.join('\n'),
      severity: ErrorSeverity.warning,
      icon: Icons.rule_rounded,
    );
  }

  static const ErrorPresentation _conflictGeneric = ErrorPresentation(
    title: 'Action impossible',
    message: 'L\'état actuel ne permet pas cette action.',
    severity: ErrorSeverity.error,
    icon: Icons.error_outline_rounded,
  );

  static const ErrorPresentation _storageGeneric = ErrorPresentation(
    title: 'Stockage indisponible',
    message: 'Impossible d\'accéder au stockage local. Redémarre l\'application.',
    severity: ErrorSeverity.error,
    icon: Icons.sd_storage_outlined,
  );

  static const ErrorPresentation _networkGeneric = ErrorPresentation(
    title: 'Erreur réseau',
    message: 'Une erreur est survenue. Vérifie ta connexion et réessaie.',
    severity: ErrorSeverity.error,
    icon: Icons.wifi_off_rounded,
  );

  static const ErrorPresentation _generic = ErrorPresentation(
    title: 'Une erreur est survenue',
    message: 'Réessaie dans un instant. Si le problème persiste, contacte le support.',
    severity: ErrorSeverity.error,
    icon: Icons.error_outline_rounded,
  );
}
