// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonOk => 'OK';

  @override
  String get commonClose => 'Fermer';

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String get settingsLanguagePhone => 'Langue du téléphone';

  @override
  String get errorMobileMoneyDisabledTitle => 'Mobile money indisponible';

  @override
  String get errorMobileMoneyDisabledMessage =>
      'Le paiement mobile money n\'est pas ouvert pour le moment. Choisis un autre moyen de paiement.';

  @override
  String get errorMobileMoneyPhoneRequiredTitle => 'Numéro manquant';

  @override
  String get errorMobileMoneyPhoneRequiredMessage =>
      'Indique le numéro mobile money à utiliser pour continuer.';

  @override
  String get errorMobileMoneyAccountUnsupportedTitle =>
      'Numéro non pris en charge';

  @override
  String get errorMobileMoneyAccountUnsupportedMessage =>
      'Ton numéro n\'est pas rattaché à un opérateur mobile money compatible, ou sa devise ne correspond pas à ta zone.';

  @override
  String get errorMobileMoneyAccountRequiredTitle =>
      'Compte de versement requis';

  @override
  String get errorMobileMoneyAccountRequiredMessage =>
      'Active ton versement mobile money avant d\'accepter cette offre.';

  @override
  String get errorMobileMoneyCurrencyMismatchTitle => 'Devise différente';

  @override
  String get errorMobileMoneyCurrencyMismatchMessage =>
      'Ton compte de versement mobile money n\'est pas dans la devise de ce trajet.';

  @override
  String get errorMobileMoneyNotAvailableTitle => 'Mobile money non proposé';

  @override
  String get errorMobileMoneyNotAvailableMessage =>
      'Ce voyageur n\'accepte pas le paiement mobile money.';

  @override
  String get errorMobileMoneyPayerUnsupportedTitle =>
      'Numéro non pris en charge';

  @override
  String get errorMobileMoneyPayerUnsupportedMessage =>
      'Vérifie le numéro qui doit payer, ou essaie avec un autre numéro.';

  @override
  String get errorMobileMoneyInvalidPhoneTitle => 'Numéro non reconnu';

  @override
  String get errorMobileMoneyInvalidPhoneMessage =>
      'Ce numéro n\'est reconnu par aucun opérateur mobile money. Vérifie-le et réessaie.';

  @override
  String get errorMobileMoneyDepositRejectedTitle => 'Paiement refusé';

  @override
  String get errorMobileMoneyDepositRejectedMessage =>
      'L\'opérateur a refusé la demande de paiement. Réessaie, éventuellement avec un autre numéro.';

  @override
  String get errorMobileMoneyPaymentExpiredTitle => 'Délai dépassé';

  @override
  String get errorMobileMoneyPaymentExpiredMessage =>
      'Le délai de paiement de 30 minutes est passé. Refais une offre au voyageur.';

  @override
  String get errorMobileMoneyPaymentNotPendingTitle => 'Paiement déjà traité';

  @override
  String get errorMobileMoneyPaymentNotPendingMessage =>
      'Ce paiement n\'est plus en attente.';

  @override
  String get errorMobileMoneyOperationInProgressTitle => 'Opération en cours';

  @override
  String get errorMobileMoneyOperationInProgressMessage =>
      'Une opération mobile money est déjà en cours pour cet envoi. Patiente quelques instants.';

  @override
  String get errorMobileMoneyProviderUnavailableTitle => 'Service indisponible';

  @override
  String get errorMobileMoneyProviderUnavailableMessage =>
      'Le service mobile money ne répond pas. Réessaie dans quelques minutes.';

  @override
  String get errorInvalidPaymentMethodTitle => 'Moyen de paiement invalide';

  @override
  String get errorInvalidPaymentMethodMessage =>
      'Ce moyen de paiement n\'est pas reconnu. Mets l\'application à jour.';

  @override
  String get errorRequestBudgetOutOfBoundsTitle => 'Budget trop élevé';

  @override
  String get errorRequestBudgetOutOfBoundsMessage =>
      'Ce budget dépasse le plafond autorisé pour cette devise. Réduis le montant puis réessaie.';

  @override
  String get errorRequestAlreadyAcceptedTitle => 'Ce colis est parti';

  @override
  String get errorRequestAlreadyAcceptedMessage =>
      'Un autre voyageur a réglé la commission avant toi, ce colis ne peut plus te revenir.';

  @override
  String get errorThreadNotAwaitingCommissionTitle => 'Ce colis est parti';

  @override
  String get errorThreadNotAwaitingCommissionMessage =>
      'Cette offre n\'attend plus de règlement, elle a été conclue autrement ou le délai est écoulé.';

  @override
  String get errorUnauthorizedTitle => 'Session expirée';

  @override
  String get errorUnauthorizedMessage => 'Reconnecte-toi pour continuer.';

  @override
  String get errorReauthRequiredTitle => 'Reconnexion requise';

  @override
  String get errorReauthRequiredMessage =>
      'Pour ta sécurité, identifie-toi à nouveau pour cette action.';

  @override
  String get errorForbiddenTitle => 'Action non autorisée';

  @override
  String get errorForbiddenMessage =>
      'Tu n\'as pas les droits nécessaires pour cette action.';

  @override
  String get errorAccessDeniedTitle => 'Accès refusé';

  @override
  String get errorAccessDeniedMessage =>
      'Tu ne peux pas accéder à cette ressource.';

  @override
  String get errorAccountBannedTitle => 'Compte suspendu';

  @override
  String get errorAccountBannedMessage =>
      'Ton compte a été suspendu. Contacte le support pour plus d\'informations.';

  @override
  String get errorAuthTokenUnavailableTitle => 'Authentification impossible';

  @override
  String get errorAuthTokenUnavailableMessage =>
      'Impossible de vérifier ton identité. Réessaie dans un instant.';

  @override
  String get errorAuthGenericErrorTitle => 'Connexion impossible';

  @override
  String get errorAuthGenericErrorMessage =>
      'Une erreur est survenue pendant la connexion. Réessaie.';

  @override
  String get errorPhoneOtpInvalidTitle => 'Code incorrect';

  @override
  String get errorPhoneOtpInvalidMessage =>
      'Le code de vérification saisi est incorrect.';

  @override
  String get errorPhoneOtpExpiredTitle => 'Code expiré';

  @override
  String get errorPhoneOtpExpiredMessage =>
      'Ce code a expiré. Demande un nouveau code.';

  @override
  String get errorPhoneOtpAttemptsExceededTitle => 'Trop de tentatives';

  @override
  String get errorPhoneOtpAttemptsExceededMessage =>
      'Trop de tentatives. Réessaie dans quelques minutes.';

  @override
  String get errorPhoneOtpRateLimitTitle => 'Trop de demandes';

  @override
  String get errorPhoneOtpRateLimitMessage =>
      'Trop de codes envoyés. Réessaie dans quelques minutes.';

  @override
  String get errorPhoneAlreadySetTitle => 'Numéro déjà défini';

  @override
  String get errorPhoneAlreadySetMessage =>
      'Un numéro est déjà associé à ce compte.';

  @override
  String get errorPhoneAlreadyExistsTitle => 'Numéro déjà utilisé';

  @override
  String get errorPhoneAlreadyExistsMessage =>
      'Ce numéro est déjà associé à un autre compte.';

  @override
  String get errorSmsOtpDisabledTitle => 'Indisponible';

  @override
  String get errorSmsOtpDisabledMessage =>
      'La connexion par téléphone n\'est pas encore disponible.';

  @override
  String get errorInvalidPhoneNumberTitle => 'Numéro injoignable';

  @override
  String get errorInvalidPhoneNumberMessage =>
      'Ce numéro ne peut pas recevoir de SMS. Vérifie l\'indicatif et le nombre de chiffres, puis réessaie.';

  @override
  String get errorAnnouncementNotFoundTitle => 'Trajet introuvable';

  @override
  String get errorAnnouncementNotFoundMessage =>
      'Ce trajet n\'existe plus ou a été retiré.';

  @override
  String get errorCurrencyMismatchTitle => 'Devise différente';

  @override
  String get errorCurrencyMismatchMessage =>
      'Ce trajet n\'est plus disponible dans ta devise. Change de pays dans Réglages pour le voir.';

  @override
  String get errorCountryRequiredTitle => 'Pays manquant';

  @override
  String get errorCountryRequiredMessage =>
      'Renseigne ton pays dans Réglages, rubrique Préférences, avant de créer ton compte de paiement. Il détermine ta devise et ne pourra plus être modifié ensuite.';

  @override
  String get errorCountryLockedTitle => 'Pays verrouillé';

  @override
  String get errorCountryLockedMessage =>
      'Impossible de changer de pays : un envoi est en cours, ton portefeuille n\'est pas vide, ou ton compte de paiement est déjà créé.';

  @override
  String get errorCountryUnsupportedTitle => 'Pays non desservi';

  @override
  String get errorCountryUnsupportedMessage =>
      'Yadony ne dessert pas encore ce pays. Choisis-en un autre.';

  @override
  String get errorDeletionImpossibleTitle => 'Suppression impossible';

  @override
  String get errorDeletionImpossibleMessage =>
      'Un colis est déjà accepté sur ce trajet. Annule le voyage à la place : l\'expéditeur sera remboursé.';

  @override
  String get errorProLimitReachedTitle => 'Limite mensuelle atteinte';

  @override
  String get errorProLimitReachedMessage =>
      'Tu as atteint ta limite d\'annonces ce mois-ci. Passe en PRO pour publier sans limite.';

  @override
  String get errorDraftLimitReachedTitle => 'Limite de brouillons atteinte';

  @override
  String get errorDraftLimitReachedMessage =>
      'Passe en PRO pour créer davantage de brouillons.';

  @override
  String get errorNotADraftTitle => 'Déjà publié';

  @override
  String get errorNotADraftMessage => 'Ce trajet n\'est pas un brouillon.';

  @override
  String get errorPublishingSuspendedTitle => 'Publication suspendue';

  @override
  String get errorPublishingSuspendedMessage =>
      'La publication est suspendue sur ton compte. Contacte le support.';

  @override
  String get errorKycNotVerifiedTitle => 'Identité non vérifiée';

  @override
  String get errorKycNotVerifiedMessage =>
      'Vérifie ton identité avant de publier un trajet.';

  @override
  String get errorDepartureDatePassedTitle => 'Date de départ passée';

  @override
  String get errorDepartureDatePassedMessage =>
      'Modifie la date de départ avant de publier ce trajet.';

  @override
  String get errorBidNotFoundTitle => 'Demande introuvable';

  @override
  String get errorBidNotFoundMessage => 'Cette demande n\'existe plus.';

  @override
  String get errorContactKycRequiredTitle => 'Profil vérifié requis';

  @override
  String get errorContactKycRequiredMessage =>
      'Ce voyageur ne reçoit que des profils vérifiés. Vérifie ton identité pour lui envoyer une demande.';

  @override
  String get errorBidNotAcceptedTitle => 'Demande non acceptée';

  @override
  String get errorBidNotAcceptedMessage =>
      'Cette demande doit être acceptée par le voyageur avant cette étape.';

  @override
  String get errorBidNotDeliveredTitle => 'Colis non livré';

  @override
  String get errorBidNotDeliveredMessage =>
      'Cette action nécessite que le colis ait été livré.';

  @override
  String get errorInvalidBidStatusTitle => 'État du colis invalide';

  @override
  String get errorInvalidBidStatusMessage =>
      'Le statut actuel du colis ne permet pas cette action.';

  @override
  String get errorUseConfirmDeliveryTitle => 'Confirme la livraison';

  @override
  String get errorUseConfirmDeliveryMessage =>
      'Pour finaliser, utilise l\'écran de confirmation de livraison du destinataire.';

  @override
  String get errorQrNotReadyTitle => 'QR pas encore disponible';

  @override
  String get errorQrNotReadyMessage =>
      'Le QR sera disponible une fois que l\'expéditeur aura finalisé le paiement.';

  @override
  String get errorDepartAlreadyScannedTitle => 'Départ déjà scanné';

  @override
  String get errorDepartAlreadyScannedMessage =>
      'Le départ de ce colis est déjà enregistré. Tu peux passer à l\'étape suivante.';

  @override
  String get errorCodeNotGeneratedTitle => 'Code non généré';

  @override
  String get errorCodeNotGeneratedMessage =>
      'Aucun code de confirmation n\'a encore été généré pour cette livraison.';

  @override
  String get errorCodeExpiredTitle => 'Code expiré';

  @override
  String get errorCodeExpiredMessage =>
      'Ce code a expiré. Demande à l\'expéditeur d\'en générer un nouveau.';

  @override
  String get errorCodeIncorrectTitle => 'Code incorrect';

  @override
  String get errorCodeIncorrectMessage =>
      'Le code saisi est incorrect. Vérifie auprès de l\'expéditeur.';

  @override
  String get errorTooManyAttemptsTitle => 'Trop de tentatives';

  @override
  String get errorTooManyAttemptsMessage =>
      'Tu as fait trop d\'essais. Patiente quelques minutes avant de réessayer.';

  @override
  String get errorTooManyRefreshesTitle => 'Limite atteinte';

  @override
  String get errorTooManyRefreshesMessage =>
      'Tu as déjà rafraîchi le code plusieurs fois. Attends avant de regénérer.';

  @override
  String get errorInvalidTimestampTitle => 'Horodatage invalide';

  @override
  String get errorInvalidTimestampMessage =>
      'L\'horodatage de la lecture est incohérent. Réessaie une fois en ligne.';

  @override
  String get errorInvalidWindowTitle => 'Hors créneau';

  @override
  String get errorInvalidWindowMessage =>
      'Cette action n\'est pas autorisée en dehors du créneau prévu.';

  @override
  String get errorAlreadyCancelledTitle => 'Déjà annulé';

  @override
  String get errorAlreadyCancelledMessage => 'Cet élément a déjà été annulé.';

  @override
  String get errorActiveTransactionsTitle => 'Action impossible';

  @override
  String get errorActiveTransactionsMessage =>
      'Des transactions sont en cours. Termine-les ou annule-les avant de continuer.';

  @override
  String get errorInvalidStatusTitle => 'État invalide';

  @override
  String get errorInvalidStatusMessage =>
      'L\'état actuel ne permet pas cette action.';

  @override
  String get errorNotPendingDeletionTitle => 'Suppression non demandée';

  @override
  String get errorNotPendingDeletionMessage =>
      'Aucune demande de suppression de compte en attente.';

  @override
  String get errorAlreadyRatedTitle => 'Déjà noté';

  @override
  String get errorAlreadyRatedMessage =>
      'Tu as déjà laissé une note pour cette livraison.';

  @override
  String get errorRatingWindowExpiredTitle => 'Délai dépassé';

  @override
  String get errorRatingWindowExpiredMessage =>
      'La période pour noter cette livraison est expirée.';

  @override
  String get errorNegotiationCommissionChargeFailedTitle => 'Accord non validé';

  @override
  String get errorNegotiationCommissionChargeFailedMessage =>
      'La commission n\'a pas pu être prélevée au voyageur. L\'accord n\'est pas validé. Il vient d\'être invité à recharger son portefeuille, réessaie ensuite.';

  @override
  String get errorNegotiationNotAwaitingDepositTitle => 'Aucun dépôt en cours';

  @override
  String get errorNegotiationNotAwaitingDepositMessage =>
      'Ce fil n\'attend pas de paiement mobile money.';

  @override
  String get errorNegotiationDepositInFlightTitle =>
      'Paiement en cours de validation';

  @override
  String get errorNegotiationDepositInFlightMessage =>
      'Ton opérateur traite encore le paiement, patiente quelques instants.';

  @override
  String get errorNegotiationTravelerCannotReceiveMobileMoneyTitle =>
      'Mobile money indisponible';

  @override
  String get errorNegotiationTravelerCannotReceiveMobileMoneyMessage =>
      'Le voyageur ne peut pas recevoir de versement mobile money dans cette devise. Choisis un autre moyen de paiement.';

  @override
  String get errorBidNotNegotiatedTitle => 'Rien à payer ici';

  @override
  String get errorBidNotNegotiatedMessage =>
      'Ce colis n\'est pas issu d\'une discussion de prix, il n\'y a pas de paiement à lancer depuis cet écran.';

  @override
  String get errorBidNotAwaitingPaymentTitle => 'Accord non payable';

  @override
  String get errorBidNotAwaitingPaymentMessage =>
      'Cette discussion n\'attend pas de paiement par carte. Rouvrez-la pour voir où elle en est.';

  @override
  String get errorBidAlreadyPaidTitle => 'Déjà payé';

  @override
  String get errorBidAlreadyPaidMessage =>
      'Ce colis est déjà payé. Actualisez pour voir son état à jour.';

  @override
  String get errorPaymentAlreadyCompletedTitle => 'Déjà payé';

  @override
  String get errorPaymentAlreadyCompletedMessage =>
      'Ce colis est déjà payé. Retrouvez-le dans vos envois pour suivre la suite.';

  @override
  String get errorTravelerStripeInvalidTitle => 'Voyageur non configuré';

  @override
  String get errorTravelerStripeInvalidMessage =>
      'Le voyageur n\'a pas terminé la configuration de ses paiements. Le paiement par carte est impossible pour l\'instant, contactez-le depuis la discussion.';

  @override
  String get errorPaymentMethodTravelerInsufficientFundsCashTitle =>
      'Solde insuffisant';

  @override
  String get errorPaymentMethodTravelerInsufficientFundsCashMessage =>
      'Ton portefeuille n\'a pas assez de fonds pour payer la commission Yadony en espèces. Recharge-le ou ajoute une carte.';

  @override
  String get errorPaymentMethodNoCommissionCardTitle => 'Carte requise';

  @override
  String get errorPaymentMethodNoCommissionCardMessage =>
      'Ajoute d\'abord une carte de commission pour payer en espèces sans solde suffisant.';

  @override
  String get errorPaymentMethodNotInAvailableSetTitle =>
      'Moyen de paiement non proposé';

  @override
  String get errorPaymentMethodNotInAvailableSetMessage =>
      'Ce moyen de paiement n\'est pas proposé pour cette offre. Choisis-en un autre.';

  @override
  String get errorPaymentMethodMobileMoneyCapabilityRequiredTitle =>
      'Mobile money indisponible';

  @override
  String get errorPaymentMethodMobileMoneyCapabilityRequiredMessage =>
      'Le voyageur n\'a pas de compte de versement mobile money dans cette devise.';

  @override
  String get errorWalletTopupStripeErrorTitle => 'Rechargement indisponible';

  @override
  String get errorWalletTopupStripeErrorMessage =>
      'Le rechargement n\'a pas pu être préparé. Réessaie dans un instant.';

  @override
  String get errorTopupAmountOutOfRangeTitle => 'Montant hors limites';

  @override
  String get errorTopupAmountOutOfRangeMessage =>
      'Ce montant ne respecte pas les limites de recharge autorisées. Ajuste le montant puis réessaie.';

  @override
  String get errorTopupAlreadyPendingTitle => 'Recharge déjà en cours';

  @override
  String get errorTopupAlreadyPendingMessage =>
      'Une recharge est déjà en cours. Valide-la sur ton téléphone, ou attends qu\'elle expire avant d\'en lancer une nouvelle.';

  @override
  String get errorTopupPhoneRequiredTitle => 'Numéro manquant';

  @override
  String get errorTopupPhoneRequiredMessage =>
      'Indique le numéro qui va payer la recharge.';

  @override
  String get errorTopupPhoneUnsupportedTitle => 'Numéro non pris en charge';

  @override
  String get errorTopupPhoneUnsupportedMessage =>
      'Ce numéro n\'est pas exploitable pour une recharge mobile money. Vérifie-le ou essaie avec un autre numéro.';

  @override
  String get errorTopupNotFoundTitle => 'Recharge introuvable';

  @override
  String get errorTopupNotFoundMessage =>
      'Cette recharge n\'existe plus ou son lien a expiré.';

  @override
  String get errorPaymentMethodUnavailableForCurrencyTitle =>
      'Moyen de paiement indisponible';

  @override
  String get errorPaymentMethodUnavailableForCurrencyMessage =>
      'Ce moyen de paiement n\'est pas proposé dans la devise de ce trajet.';

  @override
  String get errorUnsupportedCurrencyTitle => 'Devise non prise en charge';

  @override
  String get errorUnsupportedCurrencyMessage =>
      'Cette devise n\'est pas encore disponible. Vérifie la devise de ton compte dans les réglages.';

  @override
  String get errorStripeAccountRequiredTitle => 'Compte Stripe à créer';

  @override
  String get errorStripeAccountRequiredMessage =>
      'Ton compte de paiement n\'a pas encore été créé. Retape sur le bouton pour lancer l\'activation.';

  @override
  String get errorStripeAccountInvalidTitle => 'Compte de paiement invalide';

  @override
  String get errorStripeAccountInvalidMessage =>
      'Ton compte de paiement n\'est plus valide. Retape sur le bouton pour en créer un nouveau.';

  @override
  String get errorStripeErrorTitle => 'Paiement refusé';

  @override
  String get errorStripeErrorMessage =>
      'Le paiement n\'a pas pu être traité. Vérifie ta carte ou réessaie dans un instant.';

  @override
  String get errorGoogleTimeoutTitle => 'Service indisponible';

  @override
  String get errorGoogleTimeoutMessage =>
      'Le service de localisation est lent à répondre. Réessaie dans quelques secondes.';

  @override
  String get errorOtpInvalidTitle => 'Code invalide';

  @override
  String get errorOtpInvalidMessage =>
      'Le code saisi est incorrect ou a déjà été utilisé. Vérifie le code reçu par email.';

  @override
  String get errorOtpExpiredTitle => 'Code expiré';

  @override
  String get errorOtpExpiredMessage =>
      'Ce code a expiré. Reviens en arrière et demande un nouveau code.';

  @override
  String get errorOtpAttemptsExceededTitle => 'Trop de tentatives';

  @override
  String get errorOtpAttemptsExceededMessage =>
      'Trop d\'essais incorrects. Patiente quelques minutes, un nouveau code ne débloquera pas la saisie.';

  @override
  String get errorEmailAlreadyExistsTitle => 'Email déjà utilisé';

  @override
  String get errorEmailAlreadyExistsMessage =>
      'Cette adresse email est déjà associée à un autre compte.';

  @override
  String get errorEmailAlreadySetTitle => 'Adresse déjà définie';

  @override
  String get errorEmailAlreadySetMessage =>
      'Une adresse est déjà associée à ce compte et ne peut pas être remplacée.';

  @override
  String get errorRateLimitTitle => 'Trop de codes demandés';

  @override
  String get errorRateLimitMessage =>
      'Tu as demandé plusieurs codes coup sur coup. Attends quelques minutes avant d\'en redemander un.';

  @override
  String get errorEmailServiceErrorTitle => 'Envoi impossible';

  @override
  String get errorEmailServiceErrorMessage =>
      'L\'email n\'a pas pu être envoyé. Vérifie l\'adresse saisie et réessaie.';

  @override
  String get errorFirebaseErrorTitle => 'Connexion impossible';

  @override
  String get errorFirebaseErrorMessage =>
      'La connexion n\'a pas pu aboutir. Réessaie dans un instant.';

  @override
  String get errorPromoNotFoundTitle => 'Code promo introuvable';

  @override
  String get errorPromoNotFoundMessage =>
      'Ce code promo n\'existe pas. Vérifie la saisie et réessaie.';

  @override
  String get errorPromoExpiredTitle => 'Code promo expiré';

  @override
  String get errorPromoExpiredMessage =>
      'Ce code promo n\'est plus valide (expiré ou pas encore actif).';

  @override
  String get errorPromoLimitReachedTitle => 'Code promo épuisé';

  @override
  String get errorPromoLimitReachedMessage =>
      'Ce code promo a atteint sa limite d\'utilisation (globale ou par utilisateur).';

  @override
  String get errorPromoNotEligibleTitle => 'Code promo non applicable';

  @override
  String get errorPromoNotEligibleMessage =>
      'Ce code promo n\'est pas disponible pour ton profil.';

  @override
  String get errorReferralCodeNotFoundTitle => 'Code introuvable';

  @override
  String get errorReferralCodeNotFoundMessage =>
      'Ce code de parrainage n\'existe pas. Vérifie la saisie et réessaie.';

  @override
  String get errorSelfReferralTitle => 'Auto-parrainage interdit';

  @override
  String get errorSelfReferralMessage =>
      'Tu ne peux pas utiliser ton propre code de parrainage.';

  @override
  String get errorAlreadyReferredTitle => 'Code déjà utilisé';

  @override
  String get errorAlreadyReferredMessage =>
      'Tu as déjà utilisé un code de parrainage.';

  @override
  String get errorUserNotFoundTitle => 'Utilisateur introuvable';

  @override
  String get errorUserNotFoundMessage =>
      'Ce compte utilisateur n\'existe plus.';

  @override
  String get errorOfflineTitle => 'Pas de connexion';

  @override
  String get errorOfflineMessage =>
      'Vérifie ta connexion Internet puis réessaie. Tes lectures hors-ligne seront synchronisées à la reconnexion.';

  @override
  String get errorTimeoutTitle => 'Le serveur met du temps';

  @override
  String get errorTimeoutMessage =>
      'La requête a pris trop de temps. Réessaie dans quelques secondes.';

  @override
  String get errorRateLimitedTitle => 'Trop de requêtes';

  @override
  String get errorRateLimitedMessage =>
      'Tu as fait trop d\'appels en peu de temps. Patiente un instant avant de réessayer.';

  @override
  String get errorServerErrorTitle => 'Erreur serveur';

  @override
  String get errorServerErrorMessage =>
      'Quelque chose s\'est mal passé de notre côté. On regarde ça, réessaie dans un instant.';

  @override
  String get errorCancelledTitle => 'Action annulée';

  @override
  String get errorCancelledMessage => 'L\'action a été annulée.';

  @override
  String get errorNotFoundTitle => 'Introuvable';

  @override
  String get errorNotFoundMessage =>
      'Cette ressource est introuvable ou a été supprimée.';

  @override
  String get errorValidationTitle => 'Données invalides';

  @override
  String get errorValidationMessage =>
      'Vérifie les informations saisies puis réessaie.';

  @override
  String get errorConflictTitle => 'Action impossible';

  @override
  String get errorConflictMessage =>
      'L\'état actuel ne permet pas cette action.';

  @override
  String get errorStorageTitle => 'Stockage indisponible';

  @override
  String get errorStorageMessage =>
      'Impossible d\'accéder au stockage local. Redémarre l\'application.';

  @override
  String get errorNetworkTitle => 'Erreur réseau';

  @override
  String get errorNetworkMessage =>
      'Une erreur est survenue. Vérifie ta connexion et réessaie.';

  @override
  String get errorGenericTitle => 'Une erreur est survenue';

  @override
  String get errorGenericMessage =>
      'Réessaie dans un instant. Si le problème persiste, contacte le support.';

  @override
  String get networkFallbackSessionExpired => 'Session expirée';

  @override
  String get networkFallbackAccessDenied => 'Accès refusé';

  @override
  String get networkFallbackNotFound => 'Ressource introuvable';

  @override
  String get networkFallbackConflict => 'Conflit';

  @override
  String get networkFallbackInvalidData => 'Données invalides';

  @override
  String get networkFallbackInvalidRequest => 'Requête invalide';

  @override
  String get networkFallbackTooManyAttempts => 'Trop de tentatives';

  @override
  String get networkFallbackServerError => 'Erreur serveur';

  @override
  String get networkFallbackNetworkError => 'Erreur réseau';

  @override
  String get countryNameDe => 'Allemagne';

  @override
  String get countryNameAt => 'Autriche';

  @override
  String get countryNameBe => 'Belgique';

  @override
  String get countryNameCy => 'Chypre';

  @override
  String get countryNameHr => 'Croatie';

  @override
  String get countryNameEs => 'Espagne';

  @override
  String get countryNameEe => 'Estonie';

  @override
  String get countryNameFi => 'Finlande';

  @override
  String get countryNameFr => 'France';

  @override
  String get countryNameGr => 'Grèce';

  @override
  String get countryNameIe => 'Irlande';

  @override
  String get countryNameIt => 'Italie';

  @override
  String get countryNameLv => 'Lettonie';

  @override
  String get countryNameLt => 'Lituanie';

  @override
  String get countryNameLu => 'Luxembourg';

  @override
  String get countryNameMt => 'Malte';

  @override
  String get countryNameNl => 'Pays-Bas';

  @override
  String get countryNamePt => 'Portugal';

  @override
  String get countryNameGb => 'Royaume-Uni';

  @override
  String get countryNameSk => 'Slovaquie';

  @override
  String get countryNameSi => 'Slovénie';

  @override
  String get countryNameCh => 'Suisse';

  @override
  String get countryNameCa => 'Canada';

  @override
  String get countryNameUs => 'États-Unis';

  @override
  String get countryNameBj => 'Bénin';

  @override
  String get countryNameBf => 'Burkina Faso';

  @override
  String get countryNameCi => 'Côte d\'Ivoire';

  @override
  String get countryNameGw => 'Guinée-Bissau';

  @override
  String get countryNameMl => 'Mali';

  @override
  String get countryNameNe => 'Niger';

  @override
  String get countryNameSn => 'Sénégal';

  @override
  String get countryNameTg => 'Togo';

  @override
  String get countryNameCm => 'Cameroun';

  @override
  String get countryNameCf => 'Centrafrique';

  @override
  String get countryNameCg => 'Congo';

  @override
  String get countryNameGa => 'Gabon';

  @override
  String get countryNameGq => 'Guinée équatoriale';

  @override
  String get countryNameTd => 'Tchad';

  @override
  String get countryZoneEurope => 'Europe';

  @override
  String get countryZoneNorthAmerica => 'Amérique du Nord';

  @override
  String get countryZoneWestAfrica => 'Afrique de l\'Ouest';

  @override
  String get countryZoneCentralAfrica => 'Afrique centrale';

  @override
  String get errorGuestSessionFailedTitle => 'Navigation indisponible';

  @override
  String get errorGuestSessionFailedMessage =>
      'Impossible de démarrer la navigation sans compte. Vérifiez votre connexion.';

  @override
  String get authCountrySaveError =>
      'Impossible d’enregistrer le pays. Réessayez.';

  @override
  String get authCountryChoiceSaveError =>
      'Impossible d’enregistrer ce choix. Réessayez.';

  @override
  String get authPersonalInfoSaveError =>
      'Impossible d\'enregistrer ces informations. Réessayez.';

  @override
  String get authUserFallbackName => 'Utilisateur';

  @override
  String get authBiometricUnlockReason =>
      'Déverrouillez Yadony pour accéder à votre compte';

  @override
  String get authStepConsent => 'Confidentialité';

  @override
  String get authStepCountry => 'Pays';

  @override
  String get authStepIdentity => 'Identité';

  @override
  String get authStepPersonalInfo => 'Vos infos';

  @override
  String get authStepPayouts => 'Paiements';

  @override
  String get authMethodIllustrationLabel =>
      'Voyageur Yadony tenant un colis sécurisé';

  @override
  String get authMethodSecureBadge => 'Sécurisé';

  @override
  String get authMethodTitle => 'Connecte-toi en toute confiance';

  @override
  String get authMethodSubtitle =>
      'Tes échanges, ton paiement et ton suivi colis sont protégés à chaque étape.';

  @override
  String get authMethodContinueWithApple => 'Continuer avec Apple';

  @override
  String get authMethodContinueWithEmail => 'Continuer avec mon email';

  @override
  String get authMethodContinueWithPhone => 'Continuer avec mon téléphone';

  @override
  String get authMethodContinueWithGoogle => 'Continuer avec Google';

  @override
  String get authMethodOr => 'OU';

  @override
  String get authMethodGuestSemantics =>
      'Parcourir sans compte. Accès limité à la recherche. Connexion requise pour publier, contacter, réserver ou payer.';

  @override
  String get authMethodBrowseWithoutAccount => 'Parcourir sans compte';

  @override
  String get authMethodGuestNotice =>
      'Accès limité : recherche uniquement. Connexion requise pour publier, contacter, réserver ou payer.';

  @override
  String get authLegalPrefix => 'En continuant tu acceptes nos ';

  @override
  String get authLegalTermsLink => 'CGU';

  @override
  String get authLegalMiddle => ' et notre ';

  @override
  String get authLegalPrivacyLink => 'politique de confidentialité';

  @override
  String get authEmailStepLabel => 'Email';

  @override
  String get authEmailTitle => 'Ton adresse email';

  @override
  String get authEmailBody =>
      'Saisis ton adresse email pour recevoir un code de connexion.';

  @override
  String get authEmailFootnote =>
      'On protège ton accès sans partager ton email avec les voyageurs.';

  @override
  String get authEmailHint => 'exemple@email.com';

  @override
  String get authEmailSpamHint =>
      'Vérifie tes spams si tu ne reçois pas le code.';

  @override
  String get authEmailSendCode => 'Envoyer le code';

  @override
  String get authEmailPreferSms => 'Préfères le SMS ?';

  @override
  String get authPhoneDialCodeTitle => 'Indicatif pays';

  @override
  String get authPhoneStepLabel => 'Téléphone';

  @override
  String get authPhoneTitle => 'Ton numéro';

  @override
  String get authPhoneBody =>
      'On t’envoie un code à 6 chiffres par SMS pour vérifier que c’est bien toi.';

  @override
  String get authPhoneFootnote =>
      'Ton numéro sert uniquement à sécuriser ton compte et tes échanges Yadony.';

  @override
  String get authPhoneNumberLabel => 'NUMÉRO DE TÉLÉPHONE';

  @override
  String get authPhoneEnterNumber => 'Entrez votre numéro';

  @override
  String get authPhoneNumberTooShort => 'Numéro trop court';

  @override
  String get authPhoneGetSmsCode => 'Recevoir le code SMS';

  @override
  String get authPhoneContinueWithEmail => 'Continuer avec une adresse email';

  @override
  String get authOtpEnterSixDigits => 'Entrez le code à 6 chiffres';

  @override
  String get authOtpSessionExpired => 'Session expirée, veuillez recommencer';

  @override
  String get authOtpEmailVerified => 'Email vérifié avec succès !';

  @override
  String get authOtpPhoneAdded => 'Numéro ajouté avec succès !';

  @override
  String get authOtpStepEmail => 'Code email';

  @override
  String get authOtpStepSms => 'Code SMS';

  @override
  String get authOtpEmailTitle => 'Code reçu ?';

  @override
  String get authOtpPhoneTitle => 'Entrez le code';

  @override
  String authOtpCodeSentTo(String contact) {
    return 'Code envoyé à $contact';
  }

  @override
  String authOtpCodeSentToPhone(String contact) {
    return 'Code envoyé au $contact';
  }

  @override
  String get authOtpFootnote =>
      'Le code expire rapidement pour garder ton compte Yadony protégé.';

  @override
  String authOtpResendIn(int seconds) {
    return 'Renvoyer le code ($seconds s)';
  }

  @override
  String get authOtpResend => 'Renvoyer le code';

  @override
  String get authOtpVerify => 'Vérifier';

  @override
  String get authDialCodeSearchHint => 'Rechercher un pays ou un indicatif';

  @override
  String get authDialCodeNoMatch => 'Aucun pays ne correspond';

  @override
  String get authFlowIllustrationLabel => 'Connexion sécurisée Yadony';

  @override
  String get authFlowProtectedBadge => 'Connexion protégée';

  @override
  String get authFlowSkipForNow => 'Passer pour l\'instant';

  @override
  String get authRequiredTitle => 'Connexion requise';

  @override
  String get authRequiredSignIn => 'Se connecter';

  @override
  String get authRequiredKeepExploring => 'Continuer à explorer';

  @override
  String get authRequiredFreeSearchTitle => 'Recherche libre';

  @override
  String get authRequiredFreeSearchBody =>
      'Tu peux consulter les demandes et comparer les trajets.';

  @override
  String get authRequiredProtectedTitle => 'Actions protégées';

  @override
  String get authRequiredOfferSubtitle =>
      'Connecte-toi pour proposer ton trajet en toute sécurité.';

  @override
  String get authRequiredOfferBody =>
      'La connexion protège les échanges, les propositions et le suivi du colis.';

  @override
  String get authRequiredReportSubtitle =>
      'Connecte-toi pour signaler une annonce.';

  @override
  String get authRequiredReportBody =>
      'Les signalements sont reliés à un compte pour éviter les abus et mieux protéger la communauté.';

  @override
  String get authRequiredExploreSubtitle =>
      'Connecte-toi pour utiliser cette action.';

  @override
  String get authRequiredExploreBody =>
      'Publier, contacter, réserver ou payer nécessite un compte Yadony.';

  @override
  String get authOnboardingHandoffEyebrow => 'Étape 1';

  @override
  String get authOnboardingHandoffTitle => 'Préparez votre envoi.';

  @override
  String get authOnboardingHandoffSubtitle =>
      'Indiquez la destination, le format du colis et trouvez un voyageur disponible.';

  @override
  String get authOnboardingHandoffStep1Title => 'Créer l’annonce';

  @override
  String get authOnboardingHandoffStep1Subtitle =>
      'Départ, arrivée, taille du colis.';

  @override
  String get authOnboardingHandoffStep2Title => 'Choisir un voyageur';

  @override
  String get authOnboardingHandoffStep2Subtitle =>
      'Profil, trajet et disponibilité.';

  @override
  String get authOnboardingHandoffStep3Title => 'Remettre le colis';

  @override
  String get authOnboardingHandoffStep3Subtitle =>
      'Le parcours commence au scan.';

  @override
  String get authOnboardingSecurityEyebrow => 'Sécurité';

  @override
  String get authOnboardingSecurityTitle => 'Chaque remise est encadrée.';

  @override
  String get authOnboardingSecuritySubtitle =>
      'Yadony protège les profils, le paiement et les étapes importantes du colis.';

  @override
  String get authOnboardingChipVerifiedIdentity => 'Identité vérifiée';

  @override
  String get authOnboardingChipPaymentOnHold => 'Paiement bloqué';

  @override
  String get authOnboardingChipTrackingQr => 'QR de suivi';

  @override
  String get authOnboardingChipProofOfDropOff => 'Preuve de remise';

  @override
  String get authOnboardingTrackingEyebrow => 'Temps réel';

  @override
  String get authOnboardingTrackingTitle => 'Gardez le fil du colis.';

  @override
  String get authOnboardingTrackingSubtitle =>
      'Le suivi avance à chaque scan, du départ jusqu’à la confirmation d’arrivée.';

  @override
  String get authOnboardingTrackingStep1Title => 'Remis';

  @override
  String get authOnboardingTrackingStep1Subtitle =>
      'Le colis est confié au voyageur.';

  @override
  String get authOnboardingTrackingStep2Title => 'Départ, transit, arrivée';

  @override
  String get authOnboardingTrackingStep2Subtitle =>
      'Chaque scan met le suivi à jour.';

  @override
  String get authOnboardingTrackingStep3Title => 'Livraison';

  @override
  String get authOnboardingTrackingStep3Subtitle =>
      'La réception confirme la fin du trajet.';

  @override
  String get authOnboardingDestinationsEyebrow => 'Destinations';

  @override
  String get authOnboardingDestinationsTitle => 'Vos colis voyagent plus loin.';

  @override
  String get authOnboardingDestinationsSubtitle =>
      'Yadony relie les pays disponibles avec des voyageurs qui font déjà le trajet.';

  @override
  String get authOnboardingDestinationsStep6Title => 'Remettre à l’arrivée';

  @override
  String get authOnboardingDestinationsStep6Subtitle =>
      'Le destinataire confirme la réception.';

  @override
  String get authOnboardingDestinationsStep7Title => 'Libérer le paiement';

  @override
  String get authOnboardingDestinationsStep7Subtitle =>
      'Le voyageur est payé après succès.';

  @override
  String get authOnboardingChipAfrica => 'Afrique';

  @override
  String get authOnboardingChipAvailableCountries => 'Pays disponibles';

  @override
  String get authOnboardingImageLabel => 'Scène d’onboarding Yadony';

  @override
  String get authOnboardingSkip => 'Passer';

  @override
  String get authOnboardingRouteDropOff => 'Remis';

  @override
  String get authOnboardingRouteDeparture => 'Départ';

  @override
  String get authOnboardingRouteTransit => 'Transit';

  @override
  String get authOnboardingRouteArrival => 'Arrivée';

  @override
  String get authOnboardingRouteDelivery => 'Livraison';

  @override
  String get authOnboardingGetStarted => 'Commencer';

  @override
  String get authOnboardingNext => 'Suivant';

  @override
  String get authOnboardingLegalPrefix => 'En continuant, vous acceptez nos ';

  @override
  String get authOnboardingLegalTermsLink => 'CGU';

  @override
  String get authOnboardingLegalMiddle => ' et notre ';

  @override
  String get authOnboardingLegalPrivacyLink => 'politique de confidentialité';

  @override
  String get authCountryTitle => 'Dans quel pays es-tu ?';

  @override
  String get authCountrySubtitle =>
      'Devise, trajets et disponibilité seront adaptés à ton pays.';

  @override
  String get authCountryFieldLabel => 'Pays';

  @override
  String get authCountryFieldHint => 'Ex : Sénégal, France, Canada';

  @override
  String get authCountryFieldHelper =>
      'Tape ton pays puis choisis une suggestion.';

  @override
  String get authCountrySaving => 'Enregistrement du pays...';

  @override
  String get authCountryDeleteDialogTitle =>
      'Supprimer définitivement le compte ?';

  @override
  String get authCountryDeleteDialogMessage =>
      'Ton compte Yadony et tes données associées seront supprimés. Cette action est irréversible.';

  @override
  String get authCountryDeleteDialogConfirm => 'Confirmer la suppression';

  @override
  String get authCountryUnavailableTitle =>
      'Yadony n’est pas encore disponible dans ce pays';

  @override
  String get authCountryUnavailableBody =>
      'Tu peux continuer pour envoyer des colis. Les trajets et la prise de colis resteront indisponibles depuis ce compte.';

  @override
  String get authCountryContinueAsSender =>
      'Je souhaite continuer et envoyer des colis';

  @override
  String get authCountryDeleteAccount => 'Supprimer mon compte';

  @override
  String authCountryOptionSavingLabel(String country, String currency) {
    return 'Pays sélectionné : $country, devise $currency. Enregistrement en cours.';
  }

  @override
  String authCountryOptionSelectLabel(String country, String currency) {
    return 'Sélectionner $country, devise $currency';
  }

  @override
  String get authPersonalInfoCountryNotSet => 'Non renseigné';

  @override
  String get authPersonalInfoGaugeLabel => 'Informations';

  @override
  String get authPersonalInfoTitle => 'Vos informations';

  @override
  String get authPersonalInfoBody =>
      'Votre nom légal, tel qu’il figure sur votre pièce d’identité. Le reste vous sera demandé une seule fois, par Stripe.';

  @override
  String get authPersonalInfoFootnote =>
      'Jamais partagées avec les autres membres, jamais affichées publiquement.';

  @override
  String get authPersonalInfoIdentitySection => 'Identité';

  @override
  String get authPersonalInfoFirstName => 'Prénom';

  @override
  String get authPersonalInfoLastName => 'Nom';

  @override
  String get authPersonalInfoCountrySection => 'Pays';

  @override
  String get authPersonalInfoCountryField => 'Pays';

  @override
  String authPersonalInfoCountrySemantics(String country) {
    return 'Pays de résidence : $country. Déterminé à l’inscription, non modifiable ici.';
  }

  @override
  String get authPersonalInfoCountryMissingSemantics =>
      'Pays de résidence non renseigné. Déterminé à l’inscription, non modifiable ici.';

  @override
  String get authReferralGaugeLabel => 'Parrainage';

  @override
  String get authReferralTitle => 'Tu as été invité par un ami ?';

  @override
  String get authReferralBody =>
      'Entre son code pour qu’il soit récompensé à ta première livraison.';

  @override
  String get authReferralFootnote =>
      'Cette étape est facultative. Tu peux entrer dans Yadony sans code.';

  @override
  String get authReferralCodeLabel => 'Code parrain';

  @override
  String get authReferralCodeHint => 'Ex : JEAN0234';

  @override
  String get authReferralApply => 'Appliquer le code';

  @override
  String get authReferralSuccessTitle => 'Code appliqué !';

  @override
  String get authReferralSuccessBody =>
      'Ton ami sera récompensé dès que tu complètes ta première livraison.';

  @override
  String get authReferralSuccessFootnote =>
      'Ton compte Yadony est prêt. Tu peux commencer à rechercher, envoyer ou suivre tes colis.';

  @override
  String get authReferralContinueHome => 'Continuer vers l\'accueil';

  @override
  String get authConsentTitle => 'Une dernière chose';

  @override
  String get authConsentBody =>
      'Pour améliorer Yadony, on aimerait mesurer comment l\'app est utilisée. C\'est anonyme et facultatif.';

  @override
  String get authConsentFootnote =>
      'Jamais tes paiements, ton identité ou ton numéro. Tu peux changer d’avis dans Réglages.';

  @override
  String get authConsentPointScreens =>
      'Écrans visités et fonctionnalités utilisées';

  @override
  String get authConsentPointGestures => 'Gestes pour repérer ce qui bloque';

  @override
  String get authConsentPointNeverPersonal =>
      'Jamais tes paiements, identité ou numéro';

  @override
  String get authConsentPointChangeAnytime =>
      'Modifiable à tout moment dans Réglages';

  @override
  String get authConsentAccept => 'Accepter';

  @override
  String get authConsentDecline => 'Non merci';

  @override
  String get authLocalSwitchAccountTitle => 'Changer de compte ?';

  @override
  String get authLocalSwitchAccountMessage =>
      'Vous allez être déconnecté de ce compte. Vous devrez vous reconnecter et reconfigurer votre code PIN.';

  @override
  String get authLocalOtherAccount => 'Autre compte';

  @override
  String get authLocalEnterPin => 'Saisissez votre code PIN';

  @override
  String get authLocalLastAttempt => 'Dernière tentative avant blocage';

  @override
  String authLocalAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tentatives restantes',
      one: '$count tentative restante',
    );
    return '$_temp0';
  }

  @override
  String authLocalRetryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Réessayez dans $seconds secondes',
      one: 'Réessayez dans $seconds seconde',
    );
    return '$_temp0';
  }

  @override
  String get countryNameCd => 'RD Congo';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonClearFilters => 'Effacer les filtres';

  @override
  String get parcelSizeSmall => 'Petit';

  @override
  String get parcelSizeMedium => 'Moyen';

  @override
  String get parcelSizeLarge => 'Grand';

  @override
  String get cityClearCity => 'Effacer la ville';

  @override
  String get cityChooseCity => 'Choisir une ville';

  @override
  String get cityRecentSection => 'RÉCENTS';

  @override
  String get cityDepartureLabel => 'Départ';

  @override
  String get cityArrivalLabel => 'Arrivée';

  @override
  String get citySwapLabel => 'Interchanger départ et arrivée';

  @override
  String get shellTabActivity => 'Activités';

  @override
  String get shellTabSearch => 'Rechercher';

  @override
  String get shellTabMessages => 'Messages';

  @override
  String get shellTabProfile => 'Moi';

  @override
  String get shellOrbTracking => 'Suivi';

  @override
  String get shellOrbQrScanner => 'Lecteur QR';

  @override
  String get shellPlaceholderConfirmPayment => 'Confirmer paiement';

  @override
  String get shellPlaceholderAdmin => 'Admin';

  @override
  String get shellRequestsTitle => 'Demandes';

  @override
  String get shellPrivacyPolicyTitle => 'Politique de confidentialité';

  @override
  String homeCorridorFrom(String dep) {
    return 'Départ de $dep';
  }

  @override
  String homeCorridorTo(String arr) {
    return 'Vers $arr';
  }

  @override
  String get homeCorridorAll => 'Tous les corridors';

  @override
  String get homePullToList => 'Tirer pour voir la liste';

  @override
  String homePullToTravelers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tirer pour voir les $count voyageurs',
      one: 'Tirer pour voir le voyageur',
    );
    return '$_temp0';
  }

  @override
  String homePullToParcels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tirer pour voir les $count colis',
      one: 'Tirer pour voir le colis',
    );
    return '$_temp0';
  }

  @override
  String get homePullToMap => 'Tirer vers le bas pour voir la carte';

  @override
  String homeCrossParcels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colis cherchent un voyageur',
      one: '$count colis cherche un voyageur',
    );
    return '$_temp0';
  }

  @override
  String homeCrossParcelsRoute(int count, String dep, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colis cherchent un voyageur sur $dep → $arr',
      one: '$count colis cherche un voyageur sur $dep → $arr',
    );
    return '$_temp0';
  }

  @override
  String homeCrossParcelsFrom(int count, String dep) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colis cherchent un voyageur au départ de $dep',
      one: '$count colis cherche un voyageur au départ de $dep',
    );
    return '$_temp0';
  }

  @override
  String homeCrossParcelsTo(int count, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colis cherchent un voyageur vers $arr',
      one: '$count colis cherche un voyageur vers $arr',
    );
    return '$_temp0';
  }

  @override
  String homeCrossTravelers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs passent',
      one: '$count voyageur passe',
    );
    return '$_temp0';
  }

  @override
  String homeCrossTravelersRoute(int count, String dep, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs passent sur $dep → $arr',
      one: '$count voyageur passe sur $dep → $arr',
    );
    return '$_temp0';
  }

  @override
  String homeCrossTravelersFrom(int count, String dep) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs passent au départ de $dep',
      one: '$count voyageur passe au départ de $dep',
    );
    return '$_temp0';
  }

  @override
  String homeCrossTravelersTo(int count, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs passent vers $arr',
      one: '$count voyageur passe vers $arr',
    );
    return '$_temp0';
  }

  @override
  String homeAlertTrip(String dep, String arr) {
    return 'M\'alerter dès qu\'un trajet apparaît sur $dep → $arr';
  }

  @override
  String homeAlertParcel(String dep, String arr) {
    return 'M\'alerter dès qu\'un colis apparaît sur $dep → $arr';
  }

  @override
  String get homeLocateError => 'Impossible de te localiser. Réessaie.';

  @override
  String get homeMaxWeightTitle => 'Poids max du colis';

  @override
  String get homeParcelSizeTitle => 'Taille du colis';

  @override
  String homeListTravelersNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs à proximité',
      one: '$count voyageur à proximité',
    );
    return '$_temp0';
  }

  @override
  String homeListTravelersRoute(int count, String dep, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs pour $dep → $arr',
      one: '$count voyageur pour $dep → $arr',
    );
    return '$_temp0';
  }

  @override
  String homeListTravelersCorridor(int count, String corridor) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs · $corridor',
      one: '$count voyageur · $corridor',
    );
    return '$_temp0';
  }

  @override
  String homeListParcelsMatching(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colis compatibles',
      one: '$count colis compatible',
    );
    return '$_temp0';
  }

  @override
  String homeListParcelsRoute(int count, String dep, String arr) {
    return '$count colis à transporter pour $dep → $arr';
  }

  @override
  String homeListParcelsCorridor(int count, String corridor) {
    return '$count colis à transporter · $corridor';
  }

  @override
  String get homeListSubtitleNoTraveler =>
      'Personne ne propose ce trajet pour l\'instant';

  @override
  String get homeListSubtitleTravelersCanCarry =>
      'Ils peuvent emporter ton colis';

  @override
  String get homeListSubtitleActiveTripsUnknown => 'Avec tes trajets actifs';

  @override
  String homeListSubtitleActiveTrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Avec tes $count trajets actifs',
      one: 'Avec ton trajet actif',
    );
    return '$_temp0';
  }

  @override
  String get homeListSubtitleNoRequest =>
      'Aucune demande d\'envoi pour l\'instant';

  @override
  String get homeListSubtitleYouCanCarry =>
      'Tu peux les emporter sur ton trajet';

  @override
  String get homeSort => 'Trier';

  @override
  String get homeConnectionErrorTitle => 'Connexion impossible';

  @override
  String get homeRequestsLoadError =>
      'Impossible de charger les demandes. Vérifie ta connexion puis réessaie.';

  @override
  String get homeEmptyParcelsFiltered => 'Aucun colis avec ces filtres';

  @override
  String get homeEmptyParcelsSoon => 'Demandes bientôt disponibles';

  @override
  String get homeEmptyParcelsFilteredHint =>
      'Modifie ou supprime tes filtres pour voir plus de demandes.';

  @override
  String get homeEmptyParcelsSoonHint =>
      'Tu pourras bientôt consulter les demandes d\'envoi postées par les expéditeurs.';

  @override
  String get homeTripsLoadError =>
      'Impossible de charger les trajets. Vérifie ta connexion puis réessaie.';

  @override
  String get homeEmptyTravelersNearby => 'Aucun voyageur à proximité';

  @override
  String get homeEmptyTravelersFiltered => 'Aucun voyageur avec ces filtres';

  @override
  String get homeEmptyTravelersRoute => 'Aucun voyageur sur ce corridor';

  @override
  String get homeEmptyNearbyHint =>
      'Élargis ta zone ou désactive \"Près de moi\"';

  @override
  String get homeEmptyTravelersFilteredHint =>
      'Modifie tes filtres pour voir plus de voyageurs.';

  @override
  String get homeEmptyTravelersRouteHint =>
      'De nouveaux trajets sont publiés chaque jour. Reviens bientôt.';

  @override
  String get homeMapButton => 'Carte';

  @override
  String homeRadiusKm(int km) {
    return 'Rayon · $km km';
  }

  @override
  String get homeDepartureDateTitle => 'Date de départ';

  @override
  String get commonDateToday => 'Aujourd\'hui';

  @override
  String get commonDateThisWeek => 'Cette semaine';

  @override
  String get commonDateThisMonthLong => 'Ce mois-ci';

  @override
  String get homeChooseDate => 'Choisir une date';

  @override
  String get homeMinRatingTitle => 'Note minimum';

  @override
  String get homeRatingOnlyFive => '★ 5.0 uniquement';

  @override
  String homeRatingAndUp(String rating) {
    return '★ $rating et plus';
  }

  @override
  String get homeWeightCapacityTitle => 'Capacité kilo';

  @override
  String get homeMaxPriceTitle => 'Prix maximum';

  @override
  String get homeAnyPrice => 'Tous les prix';

  @override
  String get homeComposerTitleTrips => 'Filtrer les trajets';

  @override
  String get homeComposerTitleParcels => 'Filtrer les colis';

  @override
  String get homeComposerClearAll => 'Tout effacer';

  @override
  String get homeComposerSectionPhrase => 'EN UNE PHRASE';

  @override
  String get homeComposerSectionWhere => 'OÙ';

  @override
  String get homeComposerSectionWhen => 'QUAND';

  @override
  String get homeComposerSectionAroundMe => 'AUTOUR DE MOI';

  @override
  String get homeComposerSearch => 'Rechercher';

  @override
  String homeComposerSearchWithCount(int count) {
    return 'Rechercher ($count)';
  }

  @override
  String get homeComposerSectionWeightPrice => 'POIDS ET PRIX';

  @override
  String get homeComposerSectionContents => 'MON COLIS CONTIENT';

  @override
  String get homeComposerContentHint => 'Rechercher un type de contenu…';

  @override
  String get homeComposerSectionQuickFilters => 'FILTRES RAPIDES';

  @override
  String get homeComposerMinRating => 'Note ≥ 4.5';

  @override
  String get homeComposerWeekend => 'Week-end';

  @override
  String get homeComposerVerifiedIdentity => 'Identité vérifiée';

  @override
  String get homeComposerSectionUrgency => 'URGENCE DU DÉPART';

  @override
  String get homeComposerUrgencyHint =>
      'Filtrer les trajets selon leur proximité de départ';

  @override
  String get homeComposerSectionMaxWeight => 'POIDS MAXIMAL';

  @override
  String get homeComposerSectionParcelSize => 'TAILLE DU COLIS';

  @override
  String get homeComposerForMyTrips => 'Pour mes trajets';

  @override
  String get homeComposerAlertTip =>
      'Astuce, tu peux être prévenu des nouveaux colis compatibles depuis Réglages, Notifications.';

  @override
  String get homeComposerAroundMe => 'Autour de moi';

  @override
  String get homeComposerLocating => 'Localisation en cours…';

  @override
  String get homeRecapTitle => 'RÉGLÉ DEPUIS VOTRE PHRASE';

  @override
  String get homeRecapArrival => 'Arrivée';

  @override
  String get homeRecapDeparture => 'Départ';

  @override
  String get homeRecapWhen => 'Quand';

  @override
  String get homeRecapMinWeight => 'Poids minimum';

  @override
  String homeRecapFieldLine(String label, String value) {
    return '$label : $value';
  }

  @override
  String homeUnresolvedPriceQuestion(String phrase) {
    return '« $phrase », c\'est combien ?';
  }

  @override
  String get homeUnresolvedCityUnknown => 'Vers quelle ville ?';

  @override
  String get homeUnresolvedCityAmbiguous => 'Quelle ville exactement ?';

  @override
  String get homeUnresolvedDateQuestion => 'Quand voulez-vous partir ?';

  @override
  String homeUnresolvedUpTo(String price) {
    return 'Jusqu\'à $price/kg';
  }

  @override
  String get homeUnresolvedAnyPrice => 'Peu importe le prix';

  @override
  String get commonDateThisMonth => 'Ce mois';

  @override
  String get homeUnresolvedAnyTime => 'Peu importe';

  @override
  String get homePhraseHint => '20 kilos à Bamako en mars';

  @override
  String get homeSectionOptional => 'Facultatif';

  @override
  String get homeModeSelectorSending => 'J\'envoie un colis';

  @override
  String get homeModeSelectorTraveling => 'Je voyage';

  @override
  String homeModeSelectorTravelersAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs disponibles',
      one: '$count voyageur disponible',
    );
    return '$_temp0';
  }

  @override
  String get homeModeSelectorTravelersSubtitle => 'Voyageurs disponibles';

  @override
  String homeModeSelectorParcelsToCarry(int count) {
    return '$count colis à transporter';
  }

  @override
  String get homeModeSelectorParcelsSubtitle => 'Colis à transporter';

  @override
  String get homeFilterChipsDate => 'Date';

  @override
  String get homeFilterChipsAnyDate => 'Toutes dates';

  @override
  String get homeFilterChipsRating => 'Note';

  @override
  String get homeFilterChipsWeight => 'Kilos';

  @override
  String get homeFilterChipsPrice => 'Prix';

  @override
  String get homeFilterChipsSize => 'Taille';

  @override
  String get homeFilterChipsUrgent => '🔥 Urgent';

  @override
  String get homeFilterFieldsExactDate => 'DATE PRÉCISE';

  @override
  String get homeFilterFieldsMaxPrice => 'PRIX MAX';

  @override
  String get homeFilterFieldsAll => 'Tous';

  @override
  String get homeFilterFieldsChoose => 'Choisir';

  @override
  String get homeFilterFieldsMinWeight => 'POIDS MIN';

  @override
  String get homeFilterFieldsMinWeightTitle => 'Poids minimum du trajet';

  @override
  String get homeFilterFieldsTransportMode => 'Mode de transport';

  @override
  String get homeMapOpenPrice => 'Libre';

  @override
  String get homeMapRequests => 'Demandes';

  @override
  String get homeMapNoRequestsNearby => 'Aucune demande dans ce rayon';

  @override
  String get homeMapNoRequestsYet => 'Aucune demande pour le moment';

  @override
  String get homeMapEmptyNearbyHint =>
      'Élargis ta zone ou désactive “Près de moi”';

  @override
  String get homeMapEmptyHint =>
      'Reviens dans un instant, de nouvelles demandes sont publiées chaque jour';

  @override
  String get homeGuidancePublishTrip => 'Publier mon trajet';

  @override
  String get homeGuidancePublishParcel => 'Publier un colis';

  @override
  String get homeGuidanceCreateAlert => 'Créer une alerte';

  @override
  String get homeGuidanceVerifyIdentity => 'Vérifier mon identité';

  @override
  String get homeGuidanceHowItWorks => 'Comment ça marche ?';

  @override
  String get homeGuidanceDontShowAgain => 'Ne plus afficher';

  @override
  String get homeNoActiveTripTitle => 'Aucun trajet actif';

  @override
  String get homeNoActiveTripBody =>
      'Ce filtre ne montre que les colis compatibles avec tes trajets à venir. Publie un trajet pour t\'en servir.';

  @override
  String get homeNoActiveTripPublish => 'Publier un trajet';

  @override
  String get homeFilterFieldsTransport => 'TRANSPORT';

  @override
  String get homeFilterFieldsDate => 'DATE';

  @override
  String get homeNearMeTitle => 'Près de moi';

  @override
  String get homeNearMeConfirm => 'Activer le filtre';

  @override
  String get homeNearMeExplanation =>
      'On garde uniquement les annonces dont le point de remise est dans ce rayon autour de toi.';

  @override
  String get homeLocationPermissionOpenSettings => 'Ouvrir les réglages';

  @override
  String get homeLocationPermissionServiceOffTitle => 'Localisation désactivée';

  @override
  String get homeLocationPermissionDeniedTitle => 'Accès à la position refusé';

  @override
  String get homeLocationPermissionServiceOffBody =>
      'Active la localisation de ton téléphone pour voir ce qui est près de toi.';

  @override
  String get homeLocationPermissionDeniedBody =>
      'Autorise l\'accès à ta position dans les réglages pour utiliser « Près de moi » et te situer sur la carte.';

  @override
  String get shellTermsTitle => 'CGU';
}
