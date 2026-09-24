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
  String get errorFirebaseInvalidPhoneNumberTitle => 'Numéro invalide';

  @override
  String get errorFirebaseInvalidPhoneNumberMessage =>
      'Vérifie le numéro saisi et réessaie.';

  @override
  String get errorFirebaseCodeIncorrectTitle => 'Code incorrect';

  @override
  String get errorFirebaseCodeIncorrectMessage =>
      'Le code de vérification saisi est incorrect.';

  @override
  String get errorFirebaseCodeExpiredTitle => 'Code expiré';

  @override
  String get errorFirebaseCodeExpiredMessage =>
      'Ce code a expiré. Demande un nouveau code.';

  @override
  String get errorFirebaseTooManyAttemptsTitle => 'Trop de tentatives';

  @override
  String get errorFirebaseTooManyAttemptsMessage =>
      'Trop de tentatives. Réessaie dans quelques minutes.';

  @override
  String get errorFirebaseSessionExpiredTitle => 'Session expirée';

  @override
  String get errorFirebaseSessionExpiredMessage =>
      'Ta session a expiré. Recommence la connexion.';

  @override
  String get errorFirebaseNetworkRequestFailedTitle => 'Erreur réseau';

  @override
  String get errorFirebaseNetworkRequestFailedMessage =>
      'Impossible de joindre les serveurs Google. Vérifie ta connexion.';

  @override
  String get errorFirebaseAppVerificationFailedTitle =>
      'Vérification impossible';

  @override
  String get errorFirebaseAppVerificationFailedMessage =>
      'La vérification de l\'application a échoué. Réinstalle l\'app depuis TestFlight ou le Store puis réessaie.';

  @override
  String get errorFirebaseAuthErrorTitle => 'Erreur de connexion';

  @override
  String get errorFirebaseAuthErrorMessage =>
      'La connexion a échoué. Réessaie dans un instant.';

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
  String get errorPhoneAlreadyRegisteredTitle => 'Numéro déjà utilisé';

  @override
  String get errorPhoneAlreadyRegisteredMessage =>
      'Ce numéro est déjà associé à un compte';

  @override
  String get errorAuthGenericErrorTitle => 'Une erreur est survenue';

  @override
  String get errorAuthGenericErrorMessage =>
      'Une erreur est survenue. Réessayez.';

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

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get commonShare => 'Partager';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonSeeAll => 'Voir tout';

  @override
  String commonDateAtTime(String date, String time) {
    return '$date à $time';
  }

  @override
  String commonListPair(String first, String second) {
    return '$first et $second';
  }

  @override
  String commonListLast(String head, String last) {
    return '$head et $last';
  }

  @override
  String get tripKgFree => 'Kg libre';

  @override
  String get tripFixedPrice => 'Prix ferme';

  @override
  String get tripTravelerFallbackName => 'Voyageur';

  @override
  String get tripTransportPlane => 'Avion';

  @override
  String get tripTransportCar => 'Voiture';

  @override
  String get tripTransportTrain => 'Train';

  @override
  String get tripTransportBus => 'Bus';

  @override
  String get tripTransportBoat => 'Bateau';

  @override
  String get tripTransportOther => 'Autre';

  @override
  String get tripUrgencyVeryUrgent => '< 3j';

  @override
  String get tripUrgencyUrgent => '3–7j';

  @override
  String get tripUrgencySoon => '7–14j';

  @override
  String get tripUrgencyLater => '14j+';

  @override
  String get tripCapacitySuitcase23 => '1 valise 23 kg';

  @override
  String get tripCapacitySuitcase32 => '1 valise 32 kg';

  @override
  String get tripCapacityCustom => 'Personnalisé';

  @override
  String get tripPublishTitle => 'Publier un trajet';

  @override
  String get tripPublishEditTitle => 'Modifier le trajet';

  @override
  String get tripPublishDedicatedTitle => 'Créer le trajet pour cette demande';

  @override
  String get tripPublishSubmitDedicated => 'Confirmer le trajet';

  @override
  String get tripPublishPreviewButton => 'Aperçu';

  @override
  String get tripPublishFieldDepartureCityRequired =>
      'Ville de départ obligatoire';

  @override
  String get tripPublishFieldArrivalCityRequired =>
      'Ville d\'arrivée obligatoire';

  @override
  String get tripPublishFieldDepartureDateRequired =>
      'Date de départ obligatoire';

  @override
  String get tripPublishFieldDepartureTimeRequired =>
      'Heure de départ obligatoire';

  @override
  String get tripPublishFieldTransportModeRequired =>
      'Mode de transport obligatoire';

  @override
  String get tripPublishFieldHandoverDeadlineRequired =>
      'Date limite de dépôt obligatoire';

  @override
  String get tripPublishFieldPickupAddressRequired =>
      'Lieu de remise du colis obligatoire';

  @override
  String get tripPublishFieldDeliveryAddressRequired =>
      'Lieu de récupération obligatoire';

  @override
  String get tripPublishHandoverDeadlineInvalid =>
      'La date limite doit précéder le départ.';

  @override
  String get tripPublishHandoverDeadlineBeforeDeparture =>
      'La date limite de dépôt doit précéder le départ';

  @override
  String get tripPublishOfferSentWithTrip =>
      'Offre envoyée avec le trajet associé.';

  @override
  String get tripPublishTripLinked =>
      'Trajet lié. L\'expéditeur peut désormais payer.';

  @override
  String get tripPublishSuccessTitleEdit => 'Trajet modifié !';

  @override
  String get tripPublishSuccessTitleCreate => 'Trajet publié !';

  @override
  String tripPublishSuccessSubtitle(String departureCity, String arrivalCity) {
    return 'Ton trajet $departureCity → $arrivalCity est en ligne.';
  }

  @override
  String get tripPublishSuccessCta => 'Voir mon trajet';

  @override
  String get tripPublishSuccessShareCta => 'Partager mon affiche';

  @override
  String get tripPublishMonthlyLimitTitle => 'Limite mensuelle atteinte';

  @override
  String get tripPublishDraftLimitTitle => 'Limite de brouillons atteinte';

  @override
  String get tripPublishTemplatesLabel => 'Mes modèles';

  @override
  String get tripPublishTemplatesHint =>
      'Applique un modèle pour pré-remplir le trajet';

  @override
  String tripPublishTemplateAppliedMessage(String label) {
    return 'Modèle « $label » appliqué';
  }

  @override
  String tripPublishTemplateChipGrid(String label) {
    return '$label · grille';
  }

  @override
  String get tripPublishDropoffSectionLabel => 'DÉPÔT DES COLIS';

  @override
  String get tripPublishHandoverDeadlineLabel => 'Date limite de dépôt';

  @override
  String get tripPublishHandoverDeadlineSubtitle =>
      'Jusqu\'à quand les expéditeurs peuvent te remettre leurs colis';

  @override
  String get tripPublishHandoverDeadlineChoose => 'Choisir';

  @override
  String get tripPublishLockedBannerTitle => 'Trajet dédié à la demande';

  @override
  String get tripPublishLockedBannerSubtitle =>
      'Corridor, capacité et prix sont verrouillés. La date doit rester dans la fenêtre de tolérance de l\'expéditeur.';

  @override
  String get requestPublishIntroTitle => 'Publier un colis';

  @override
  String get tripPublishIntroVerifiedTextTrip =>
      'Identité vérifiée. Vous pouvez publier votre trajet en toute sécurité.';

  @override
  String get requestPublishIntroVerifiedText =>
      'Identité vérifiée. Vous pouvez publier votre demande d\'envoi en toute sécurité.';

  @override
  String get tripPublishIntroEngagementsTitleTrip =>
      'Vos engagements de voyageur';

  @override
  String get tripPublishIntroEngagementsIntroTrip =>
      'En publiant, vous vous engagez à :';

  @override
  String get tripPublishIntroRuleTripCarry =>
      'Transporter le colis **vous-même**, sans le confier à un tiers.';

  @override
  String get tripPublishIntroRuleTripSchedule =>
      'Respecter la **date** et l\'**itinéraire** annoncés.';

  @override
  String get tripPublishIntroRuleTripScan =>
      '**Lire le QR** à la remise et à la livraison.';

  @override
  String get tripPublishIntroRuleTripContent =>
      'N\'accepter que des **contenus autorisés**, jamais d\'objet illicite.';

  @override
  String get tripPublishIntroRuleTripHandover =>
      'Remettre le colis **au bon destinataire**, en main propre.';

  @override
  String get tripPublishIntroWhyTitleTrip => 'Pourquoi publier';

  @override
  String get tripPublishIntroWhyBulletTripVisibility =>
      'Visible par des milliers d\'expéditeurs de la diaspora.';

  @override
  String get tripPublishIntroWhyBulletTripEarnings =>
      'Rentabilisez vos kilos libres à chaque voyage.';

  @override
  String get tripPublishIntroWhyBulletTripReputation =>
      'Bâtissez une réputation avec les avis reçus.';

  @override
  String get requestPublishIntroEngagementsTitle =>
      'Vos engagements d\'expéditeur';

  @override
  String get requestPublishIntroEngagementsIntro =>
      'En envoyant un colis, vous certifiez :';

  @override
  String get requestPublishIntroRuleLicit =>
      'N\'envoyer que des **contenus licites** et autorisés.';

  @override
  String get requestPublishIntroRuleForbidden =>
      'Aucun **objet interdit** (espèces, armes, produits dangereux…).';

  @override
  String get requestPublishIntroRuleHonest =>
      'Décrire **honnêtement** le contenu et sa valeur si le voyageur la demande.';

  @override
  String get requestPublishIntroRulePackaging =>
      '**Emballer soigneusement** et décrire précisément le contenu.';

  @override
  String get requestPublishIntroRuleHandover =>
      'Être présent à la **remise** et indiquer le bon destinataire.';

  @override
  String get requestPublishIntroWhyTitle => 'Comment ça marche';

  @override
  String get requestPublishIntroWhyBulletCarried =>
      'Un voyageur transporte votre colis dans ses bagages.';

  @override
  String get requestPublishIntroWhyBulletPayment =>
      'Paiement sécurisé, libéré à la livraison confirmée.';

  @override
  String get requestPublishIntroWhyBulletTracking =>
      'Suivi par QR de la remise jusqu\'à la réception.';

  @override
  String tripPublishIntroVerifyCallout(String identity, String path) {
    return 'Avant de publier, votre **$identity**. Rendez-vous dans $path pour la valider (2 min).';
  }

  @override
  String get tripPublishIntroVerifyIdentity => 'identité doit être vérifiée';

  @override
  String get tripPublishIntroVerifyPath => 'Profil › Vérifications';

  @override
  String get tripPublishIntroVerifyButton => 'Vérifier mon identité';

  @override
  String tripPublishIntroVerifyHint(String continueLabel) {
    return 'Le bouton devient « $continueLabel » une fois l\'identité vérifiée.';
  }

  @override
  String get tripPublishIntroStripeTitle => 'Activez les paiements par carte';

  @override
  String get tripPublishIntroStripeSubtitle =>
      'Configurez votre compte Stripe pour que vos expéditeurs paient par carte, et recevez plus de colis.';

  @override
  String get tripPublishPricingModeKg => 'Au kilo';

  @override
  String get tripPublishPricingModeMixed => 'Grille + kilo';

  @override
  String get tripPublishPricePerKgSectionLabel => 'Prix par kg';

  @override
  String get tripPublishKgPriceToggleTitle => 'Tarif au kilo';

  @override
  String get tripPublishKgPriceToggleSubtitle => 'Optionnel en mode grille';

  @override
  String get tripPublishCustomPriceChipLabel => 'Autre prix';

  @override
  String get tripPublishCustomPriceFieldHint => 'ex: 12';

  @override
  String get tripPublishPriceSelectPrompt =>
      'Sélectionnez un prix pour voir l\'estimation';

  @override
  String get tripPublishUnlimitedCapacityEstimateNote =>
      'Capacité illimitée : estimation selon la demande';

  @override
  String tripPublishPriceEstimateLine(String travelerNet, String senderTotal) {
    return 'Vous touchez $travelerNet · l\'expéditeur paie $senderTotal';
  }

  @override
  String tripPublishGridCommissionNotice(String percent) {
    return 'Yadony ajoute $percent % sur chaque article et sur le prix au kilo';
  }

  @override
  String get tripPublishNegotiableToggleTitle =>
      'J\'accepte les propositions de prix';

  @override
  String get tripPublishNegotiableToggleSubtitle =>
      'Les expéditeurs pourront vous proposer un montant, vous restez libre de refuser';

  @override
  String get tripPublishPaymentMethodsSectionLabel =>
      'Modes de paiement acceptés';

  @override
  String get tripPublishCardPaymentTitle => 'Carte bancaire (Stripe)';

  @override
  String get tripPublishCardPaymentSubtitle => 'Paiement sécurisé par défaut';

  @override
  String get tripPublishCashLabel => 'Espèces';

  @override
  String get tripPublishCashSubtitle =>
      'Commission prélevée au voyageur à la remise';

  @override
  String get tripPublishAcceptedContentSectionLabel => 'Ce que j\'accepte';

  @override
  String get tripPublishRefusedContentSectionLabel => 'Ce que je refuse';

  @override
  String get tripPublishRefusedContentHint =>
      'Ex: Liquides, Denrées périssables…';

  @override
  String get tripPublishNoteToSendersSectionLabel => 'Note aux expéditeurs';

  @override
  String get tripPublishNoteToSendersHint =>
      'Ex: Je préfère les colis bien emballés. Contactez-moi avant le départ.';

  @override
  String get tripPublishCashOnlyBannerWithConnect =>
      'Publiez en espèces dès maintenant. Connectez Stripe pour accepter aussi la carte.';

  @override
  String get tripPublishCashOnlyBannerNoConnect =>
      'Le paiement par carte n\'est pas encore disponible dans votre pays. Vos trajets sont publiés en espèces.';

  @override
  String get tripPublishActivateCardPaymentsCta =>
      'Activer les paiements par carte';

  @override
  String get tripPublishCardNotConfiguredSubtitle =>
      'Non configuré, activez pour proposer le paiement sécurisé';

  @override
  String get tripPublishActivatePayoutCta => 'Activer le versement';

  @override
  String get tripPublishMobileMoneyIneligibleSubtitle =>
      'Disponible pour les trajets en XOF ou XAF';

  @override
  String get tripPublishMobileMoneyInactiveSubtitle =>
      'Active d\'abord ton versement mobile money';

  @override
  String get tripPublishLockedPriceNoteTitle => 'Prix fixé par la négociation';

  @override
  String get tripPublishLockedPriceNoteSubtitle =>
      'Le montant de ce colis a été convenu avec l\'expéditeur, non modifiable ici.';

  @override
  String get tripPublishAgreedPriceLabel => 'Prix total convenu';

  @override
  String get tripPublishGridPreviewLabel => 'Votre grille';

  @override
  String tripPublishGridPreviewSeeAll(int count) {
    return 'Voir les $count articles';
  }

  @override
  String get tripPublishGridPreviewNote =>
      'Ces prix viennent de votre profil. Les modifier les change sur tous vos trajets.';

  @override
  String get tripPublishGridSheetTitle => 'Votre grille de prix';

  @override
  String get tripPublishGridSheetSubtitle => 'Valable sur tous vos trajets';

  @override
  String get tripPublishGridSheetEditCta => 'Modifier ma grille';

  @override
  String tripPublishGridSheetCommissionNote(String percent) {
    return 'Prix payés par l\'expéditeur, commission Yadony de $percent % comprise.';
  }

  @override
  String get tripPublishGridEmptyTitle => 'Votre grille est vide';

  @override
  String get tripPublishGridEmptySubtitle =>
      'Ajoutez au moins une étiquette pour que les expéditeurs réservent article par article.';

  @override
  String get tripPublishGridComposeCta => 'Composer ma grille';

  @override
  String get tripPublishCorridorConfirmedBadge => 'Confirmé';

  @override
  String get tripPublishRouteSectionLabel => 'Trajet';

  @override
  String get tripPublishDepartureCityLabel => 'Ville de départ';

  @override
  String get tripPublishArrivalCityLabel => 'Ville d\'arrivée';

  @override
  String get tripPublishDepartureTimeLabel => 'Heure de départ';

  @override
  String get tripPublishArrivalTimeOptionalLabel =>
      'Heure d\'arrivée (optionnel)';

  @override
  String get tripPublishClearArrivalTimeTooltip =>
      'Effacer l\'heure d\'arrivée';

  @override
  String get tripPublishDepartureDateLabel => 'Date de départ';

  @override
  String get tripPublishUrgentDepartureWarning =>
      '🔥 Départ proche · ce trajet sera signalé urgent';

  @override
  String get tripPublishCapacityAvailableLabel => 'Capacité disponible';

  @override
  String tripPublishSuitcaseCount(int count, int kg) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valises de $kg kg',
      one: '$count valise de $kg kg',
    );
    return '$_temp0';
  }

  @override
  String tripPublishYouOfferKg(int kg) {
    return 'Vous offrez $kg kg';
  }

  @override
  String get tripPublishDecreaseQuantityTooltip => 'Diminuer la quantité';

  @override
  String get tripPublishIncreaseQuantityTooltip => 'Augmenter la quantité';

  @override
  String get tripPublishUnlimitedCapacityTitle => 'Capacité illimitée';

  @override
  String get tripPublishUnlimitedCapacitySubtitle =>
      'Vendu au kilo · l\'expéditeur choisit son poids';

  @override
  String get tripPublishCapacityKgFieldLabel => 'Capacité (kg)';

  @override
  String get tripPublishCapacityKgFieldHint =>
      'Indiquez la capacité totale que vous offrez';

  @override
  String tripPublishCurrencySemanticsLabel(
    String currencyName,
    String currencyCode,
  ) {
    return 'Devise de publication : $currencyName, $currencyCode. Les utilisateurs dans une autre devise voient un prix converti. Le paiement reste dans cette devise. Bouton, modifier la devise.';
  }

  @override
  String tripPublishCurrencyBannerTitle(
    String currencyName,
    String currencyCode,
  ) {
    return 'Publié en $currencyName ($currencyCode)';
  }

  @override
  String get tripPublishCurrencyBannerSubtitle =>
      'Les utilisateurs dans une autre devise voient un prix converti. Le paiement reste dans cette devise.';

  @override
  String get tripPublishCurrencyChangeCta => 'Changer';

  @override
  String get tripPublishPlacesCapacityStepLabel => 'Lieux & capacité';

  @override
  String get tripPublishPriceConditionsStepLabel => 'Prix & conditions';

  @override
  String get tripPublishHandoverLocationsLabel => 'Lieux de remise';

  @override
  String get tripPublishHandoverLocationsSubtitle =>
      'Précisez l\'endroit exact de remise et récupération';

  @override
  String get tripPublishLockedCapacityNote => 'Capacité fixée par la demande';

  @override
  String addressGpsPosition(String lat, String lng) {
    return 'Position GPS ($lat, $lng)';
  }

  @override
  String get addressGpsDisabledTitle => 'GPS désactivé';

  @override
  String get addressLocationDeniedTitle => 'Localisation refusée';

  @override
  String get addressLocationDeniedForeverTitle =>
      'Localisation définitivement refusée';

  @override
  String get addressGpsDisabledMessage =>
      'Activez la géolocalisation dans vos paramètres système.';

  @override
  String get addressLocationDeniedMessage =>
      'Activez la localisation dans vos paramètres pour utiliser cette fonctionnalité.';

  @override
  String get addressOpenSettingsButton => 'Ouvrir les paramètres';

  @override
  String get addressPositionUnavailableTitle => 'Position indisponible';

  @override
  String get addressPositionUnavailableMessage =>
      'Impossible de récupérer votre position pour le moment. Réessayez.';

  @override
  String get addressReverseGeocodeFailedTitle => 'Adresse introuvable';

  @override
  String get addressReverseGeocodeFailedMessage =>
      'Impossible de convertir votre position en adresse. Réessayez.';

  @override
  String get addressSelectFailedMessage =>
      'Impossible de sélectionner cette adresse. Réessayez.';

  @override
  String get addressSearchHint => 'Rechercher une adresse…';

  @override
  String get addressConfirmButton => 'Confirmer cette adresse';

  @override
  String get addressOfflineTitle => 'Connexion requise';

  @override
  String get addressOfflineSubtitle =>
      'Vérifiez votre connexion pour rechercher une adresse.';

  @override
  String get addressSearchErrorTitle => 'Erreur';

  @override
  String get addressSearchErrorSubtitle =>
      'Impossible de rechercher une adresse. Réessayez.';

  @override
  String get addressNoResultsTitle => 'Aucun résultat';

  @override
  String get addressNoResultsSubtitle =>
      'Essayez « Utiliser ma position actuelle ».';

  @override
  String get addressUseCurrentLocation => 'Utiliser ma position actuelle';

  @override
  String get addressRecentSearchesHeader => 'RECHERCHES RÉCENTES';

  @override
  String get addressSavedAddressesHeader => 'MES ADRESSES ENREGISTRÉES';

  @override
  String get addressAddNewTitle => 'Ajouter une adresse';

  @override
  String get addressAddNewSubtitle => 'Enregistrer pour la prochaine fois';

  @override
  String get addressDefaultBadge => 'Par défaut';

  @override
  String get addressPickupSheetTitle => '📦  Adresse de remise';

  @override
  String get addressDeliverySheetTitle => '🗺️  Adresse de livraison';

  @override
  String get addressFieldRequiredError => 'Adresse obligatoire';

  @override
  String get addressFieldSearchHint => 'Tapez pour rechercher une adresse…';

  @override
  String get addressFieldNoResultsHint =>
      'Aucun résultat, essayez \"Ma position actuelle\"';

  @override
  String get addressOfflineInlineMessage =>
      'Connexion requise pour la recherche d\'adresse';

  @override
  String get addressSelectorDropoffLabel => 'Choisir une adresse de remise';

  @override
  String get addressSelectorDropoffSubtitle =>
      'Où tu récupères les colis des expéditeurs';

  @override
  String get addressSelectorDeliveryLabel => 'Choisir une adresse de livraison';

  @override
  String get addressSelectorDeliverySubtitle =>
      'Où tu déposes les colis à destination';

  @override
  String get tripPosterTimePattern => 'HH\'h\'mm';

  @override
  String get tripPosterDepartureLabel => 'Départ';

  @override
  String get tripPosterDeadlineLabel => 'Dernier dépôt';

  @override
  String get tripPosterCapacityLabel => 'Place disponible';

  @override
  String get tripPosterHandoverLabel => 'Remise';

  @override
  String get tripPosterPickupLabel => 'Récupération';

  @override
  String tripPosterFromPrice(String price) {
    return 'dès $price';
  }

  @override
  String get tripPosterUnitPerItem => 'l\'article';

  @override
  String get tripPosterUnitPerKg => 'le kilo';

  @override
  String get tripPosterPriceUnavailable => 'Prix indisponible';

  @override
  String tripPosterPricePerKg(String price) {
    return '$price le kilo';
  }

  @override
  String tripPosterPriceFromItem(String price) {
    return 'dès $price l\'article';
  }

  @override
  String get tripPosterTagline =>
      'Paiement sécurisé, suivi du colis, voyageurs vérifiés';

  @override
  String get tripPosterTitle => 'Mon affiche';

  @override
  String get tripPosterNotFoundTitle => 'Trajet introuvable';

  @override
  String get tripPosterNotFoundDescription =>
      'Impossible de charger ce trajet pour le moment.';

  @override
  String tripPosterCaptionCorridor(String departure, String arrival) {
    return '$departure vers $arrival';
  }

  @override
  String tripPosterCaptionDeparture(String day) {
    return 'Départ le $day';
  }

  @override
  String tripPosterCaptionDeadline(String deadline) {
    return 'Dernier dépôt le $deadline';
  }

  @override
  String tripPosterCaptionHandover(String address) {
    return 'Remise : $address';
  }

  @override
  String tripPosterCaptionPickup(String address) {
    return 'Récupération : $address';
  }

  @override
  String get tripPosterCaptionCta => 'Réservez vos kilos ici :';

  @override
  String get tripPosterCaptionFooter =>
      'Paiement sécurisé, suivi du colis, voyageur vérifié.';

  @override
  String tripPosterShareSubject(String departure, String arrival) {
    return 'Trajet $departure vers $arrival';
  }

  @override
  String get tripPosterShareError => 'Impossible de partager l\'affiche';

  @override
  String get tripPosterSaveError => 'Impossible d\'enregistrer l\'affiche';

  @override
  String get tripPosterSaveSuccess => 'Affiche enregistrée dans votre galerie';

  @override
  String get tripPosterCaptionCopied => 'Légende copiée';

  @override
  String get tripPosterLinkCopiedMessage => 'Lien copié';

  @override
  String get tripPosterInstructions =>
      'Postez cette affiche comme d\'habitude, puis collez la légende dans le texte de votre publication. Le lien y devient cliquable, ce qui n\'est pas le cas d\'une adresse écrite sur l\'image.';

  @override
  String get tripPosterShareButton => 'Partager l\'affiche';

  @override
  String get tripPosterCopyCaptionButton => 'Copier la légende';

  @override
  String get tripPosterCopyLinkButton => 'Copier le lien';

  @override
  String get tripPosterSaveButton => 'Enregistrer dans la galerie';

  @override
  String get errorAnnouncementUpdateBlockedTitle => 'Modification impossible';

  @override
  String get errorAnnouncementUpdateBlockedMessage =>
      'Des colis sont déjà acceptés pour ce trajet';

  @override
  String get tripTemplateListTitle => 'Mes modèles de trajet';

  @override
  String get tripTemplateNewLabel => 'Nouveau modèle';

  @override
  String get tripTemplateLoadErrorTitle => 'Erreur de chargement';

  @override
  String get tripTemplateLoadErrorFallback => 'Une erreur est survenue.';

  @override
  String get tripTemplateEmptyTitle => 'Aucun modèle';

  @override
  String get tripTemplateEmptyDescription =>
      'Crée des modèles de trajet réutilisables pour publier tes annonces en quelques secondes.';

  @override
  String get tripTemplateCreateAction => 'Créer un modèle';

  @override
  String get tripTemplateGridPriceLabel => 'prix à la grille';

  @override
  String get tripTemplateDeleteDialogTitle => 'Supprimer le modèle';

  @override
  String tripTemplateDeleteDialogMessage(String label) {
    return 'Es-tu sûr de vouloir supprimer \"$label\" ? Cette action est irréversible.';
  }

  @override
  String get tripTemplateScheduleRecurrenceAction => 'Programmer la récurrence';

  @override
  String get tripTemplateNameSectionLabel => 'NOM DU MODÈLE';

  @override
  String get tripTemplateNameFieldLabel => 'Nom';

  @override
  String get tripTemplateNameFieldHint => 'Ex : Mon Paris → Dakar';

  @override
  String get tripTemplateTripSectionLabel => 'TRAJET';

  @override
  String get tripTemplateTransportSectionLabel => 'MODE DE TRANSPORT';

  @override
  String get tripTemplateScheduleSectionLabel => 'HORAIRES';

  @override
  String get tripTemplateDepartureTimeFieldLabel => 'Heure de départ';

  @override
  String get tripTemplateDepartureShortLabel => 'Départ';

  @override
  String get tripTemplateArrivalTimeFieldLabel => 'Heure d\'arrivée';

  @override
  String get tripTemplateArrivalShortLabel => 'Arrivée';

  @override
  String get tripTemplateHandoverDeadlineSectionLabel => 'DÉLAI DE REMISE';

  @override
  String get tripTemplateHandoverDeadlineHint =>
      'Au plus tard combien de jours avant le départ le colis doit être remis ?';

  @override
  String get tripTemplateHandoverNone => 'Aucun';

  @override
  String get tripTemplateHandoverSameDay => 'Le jour même';

  @override
  String tripTemplateHandoverDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours avant',
      one: '$count jour avant',
    );
    return '$_temp0';
  }

  @override
  String tripTemplateOptionalSuffix(String label) {
    return '$label (optionnel)';
  }

  @override
  String tripTemplateClearFieldSemantic(String label) {
    return 'Effacer $label';
  }

  @override
  String get tripTemplateEditTitle => 'Modifier le modèle';

  @override
  String get tripTemplateSaveButton => 'Enregistrer le modèle';

  @override
  String get tripTemplateUpdatedMessage => 'Modèle mis à jour';

  @override
  String get tripTemplateSavedMessage => 'Modèle enregistré';

  @override
  String get tripTemplateRecurrenceActivatedMessage =>
      'Récurrence activée. Tes trajets seront publiés automatiquement.';

  @override
  String get tripTemplateRecurrenceTitle => 'Trajet récurrent';

  @override
  String get tripTemplateActivateRecurrenceButton => 'Activer la récurrence';

  @override
  String get tripTemplateNoPricePerKgWarning =>
      'Ce modèle n\'a pas de prix au kilo';

  @override
  String get tripTemplateRepeatDaysSectionLabel => 'JOURS DE RÉPÉTITION';

  @override
  String get tripTemplateRecurrenceDepartureTimeSectionLabel =>
      'HEURE DE DÉPART';

  @override
  String get tripTemplateOptionalTimeHint => 'Optionnel : choisir une heure';

  @override
  String get tripTemplateClearTimeSemantic => 'Effacer l\'heure de départ';

  @override
  String get tripTemplateLocationsSectionLabel => 'LIEUX';

  @override
  String get tripTemplatePickupFieldLabel => 'Lieu de remise du colis *';

  @override
  String get tripTemplateDeliveryFieldLabel => 'Lieu de récupération *';

  @override
  String get tripTemplateActiveLabel => 'Récurrence active';

  @override
  String get tripTemplateActiveDescription =>
      'Publie automatiquement les trajets à venir';

  @override
  String get contentCategoryDocuments => 'Documents & administratif';

  @override
  String get contentCategoryDryFood => 'Alimentation sèche';

  @override
  String get contentCategoryFreshFood => 'Produits frais / périssables';

  @override
  String get contentCategoryCosmetics => 'Cosmétiques & parfums';

  @override
  String get contentCategoryClothing => 'Vêtements & tissus';

  @override
  String get contentCategoryShoes => 'Chaussures';

  @override
  String get contentCategoryTraditionalMedicine => 'Médicaments traditionnels';

  @override
  String get contentCategoryElectronics => 'Téléphone & électronique';

  @override
  String get contentCategoryBooks => 'Livres';

  @override
  String get contentCategoryGifts => 'Cadeaux & jouets';

  @override
  String get contentCategoryOther => 'Autre';

  @override
  String contentCategoryAdd(String label) {
    return 'Ajouter « $label »';
  }

  @override
  String get contentCategoryRemove => 'Retirer cette catégorie';

  @override
  String get paymentMethodCard => 'Carte';

  @override
  String get paymentMethodCash => 'Espèces';

  @override
  String get paymentMethodMobileMoney => 'Mobile money';

  @override
  String requestThreadYouReceive(String amount) {
    return 'Tu reçois $amount';
  }

  @override
  String requestThreadYouPay(String amount) {
    return 'Tu paies $amount';
  }

  @override
  String requestWeightRange(String min, String max) {
    return 'Entre $min et $max kg';
  }

  @override
  String get requestSenderFallbackName => 'Utilisateur Yadony';

  @override
  String get requestBudgetRequired => 'Indiquez un budget pour continuer';

  @override
  String requestTimeJustNow(String verb) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'créée à l\'instant',
      'other': 'publiée à l\'instant',
    });
    return '$_temp0';
  }

  @override
  String requestTimeMinutesAgo(String verb, int minutes) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'créée il y a $minutes min',
      'other': 'publiée il y a $minutes min',
    });
    return '$_temp0';
  }

  @override
  String requestTimeHoursAgo(String verb, int hours) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'créée il y a $hours h',
      'other': 'publiée il y a $hours h',
    });
    return '$_temp0';
  }

  @override
  String requestTimeYesterday(String verb, String time) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'créée hier, $time',
      'other': 'publiée hier, $time',
    });
    return '$_temp0';
  }

  @override
  String requestTimeOn(String verb, String date) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'créée le $date',
      'other': 'publiée le $date',
    });
    return '$_temp0';
  }

  @override
  String get contentCategoryHintDefault => 'Ajouter un type de contenu…';

  @override
  String get requestCreateEditWarningTitle => 'Modifier votre demande ?';

  @override
  String get requestCreateEditWarningMessage =>
      'Des voyageurs négocient actuellement cette demande. La modifier annulera toutes les offres en cours. Ils devront vous reproposer un trajet.';

  @override
  String get requestCreateEditWarningConfirm => 'Modifier quand même';

  @override
  String get requestCreateStepTitleEdit => 'Modifier la demande';

  @override
  String get requestCreateStepTitleTrip => 'Le trajet';

  @override
  String get requestCreateStepTitlePackage => 'Le colis';

  @override
  String get requestCreateStepTitleBudget => 'Le budget';

  @override
  String get requestCreateDraftSavedTitle => 'Brouillon enregistré !';

  @override
  String get requestCreateEditedTitle => 'Demande modifiée !';

  @override
  String get requestCreatePublishedTitle => 'Demande publiée !';

  @override
  String get requestCreateDraftSavedSubtitle =>
      'Vous pourrez la publier quand vous le souhaitez.';

  @override
  String get requestCreateEditedSubtitle => 'Vos modifications sont en ligne.';

  @override
  String get requestCreatePublishedSubtitle =>
      'Les voyageurs sont notifiés. Vous recevrez des offres très vite.';

  @override
  String get requestCreateViewDraftCta => 'Voir mon brouillon';

  @override
  String get requestCreateViewRequestCta => 'Voir ma demande';

  @override
  String get requestCreateGenericError => 'Erreur lors de la création';

  @override
  String get requestCreateDraftLimitTitle => 'Limite de brouillons atteinte';

  @override
  String get requestCreateCguPrefix => 'En publiant, vous acceptez les ';

  @override
  String get requestCreateCguLink => 'CGU';

  @override
  String get requestCreatePublishingLabel => 'Publication…';

  @override
  String get requestCreatePreviewButton => 'Aperçu';

  @override
  String get requestCreateDepartureRequired => 'Ville de départ obligatoire';

  @override
  String get requestCreateArrivalRequired => 'Ville d\'arrivée obligatoire';

  @override
  String get requestCreateArrivalSameAsDeparture =>
      'Choisissez une ville différente du départ';

  @override
  String get requestCreateDateRequired => 'Date de départ obligatoire';

  @override
  String get requestCreateToleranceExactHint =>
      'Seuls les voyageurs partant exactement ce jour-là pourront répondre.';

  @override
  String requestCreateToleranceGenericHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '± $count jours autour de votre date. Plus de souplesse, plus de voyageurs.',
      one:
          '± $count jour autour de votre date. Plus de souplesse, plus de voyageurs.',
    );
    return '$_temp0';
  }

  @override
  String requestCreateToleranceRangeHint(String from, String to) {
    return 'Les voyageurs partant du $from au $to pourront répondre.';
  }

  @override
  String get requestCreateAirplaneOnlyMode => 'seul mode disponible';

  @override
  String get requestCreateTrajetSectionLabel => 'TRAJET';

  @override
  String get requestCreateTrajetQuestion => 'D\'où vers où ?';

  @override
  String get requestCreateDateFieldLabel => 'Date';

  @override
  String get requestCreateToleranceFieldLabel => 'Souplesse';

  @override
  String get requestCreateUrgentDateHint =>
      '🔥 Date proche, cette demande sera signalée urgente';

  @override
  String requestCreateToleranceShort(int count) {
    return '± $count j';
  }

  @override
  String get requestCreateDateExact => 'Date exacte';

  @override
  String requestCreateDateFlex(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '± $count jours',
      one: '± $count jour',
    );
    return '$_temp0';
  }

  @override
  String requestCreateMaxCategories(int max) {
    return 'Maximum $max catégories';
  }

  @override
  String get requestCreateCategoryRequired =>
      'Choisissez au moins une catégorie';

  @override
  String get requestCreateAutrePrecisionTitle =>
      'Précisez le contenu (optionnel)';

  @override
  String get requestCreateAutrePrecisionSubtitle =>
      'Ça aide le voyageur à savoir ce qu\'il transporte.';

  @override
  String get requestCreateAutrePrecisionValidate => 'Valider';

  @override
  String get requestCreateAutrePrecisionHint => 'Ex. Instruments de musique';

  @override
  String get requestCreateStep2Title => 'Décrivez votre colis';

  @override
  String get requestCreateStep2Subtitle =>
      'Ces infos aident les voyageurs à savoir s\'ils peuvent transporter votre envoi.';

  @override
  String get requestCreateWeightLabel => 'Poids approximatif';

  @override
  String get requestCreateContentLabel => 'Contenu';

  @override
  String get requestCreateContentHint =>
      'Tapez pour chercher, ou écrivez votre propre catégorie.';

  @override
  String get requestCreateDescriptionLabel => 'Description (optionnel)';

  @override
  String get requestCreateDescriptionHint =>
      'Précisions utiles : fragile, contenu exact, instructions de remise…';

  @override
  String get requestCreateWeightInvalid => 'Valeur invalide';

  @override
  String get requestCreateBudgetSubtitle =>
      'Vérifiez votre demande, puis indiquez le budget à montrer aux voyageurs.';

  @override
  String get requestCreatePriceModeLabel => 'Comment fixer le prix ?';

  @override
  String get requestCreatePriceModeOpenTitle => 'J\'ouvre aux offres';

  @override
  String get requestCreatePriceModeOpenSubtitle =>
      'Les voyageurs proposent leur prix, vous choisissez.';

  @override
  String get requestCreatePriceModeFixedTitle => 'Je fixe mon prix';

  @override
  String get requestCreatePriceModeFixedSubtitle =>
      'Un montant ferme, sans négociation.';

  @override
  String get requestCreateCurrencyLabel => 'Devise';

  @override
  String get requestCreateBudgetLabelNegotiable => 'Budget indicatif';

  @override
  String get requestCreateBudgetLabelFixed => 'Votre prix';

  @override
  String get requestCreateBudgetHintNegotiable =>
      'Donnez un ordre d\'idée pour attirer plus d\'offres, sans vous engager.';

  @override
  String get requestCreateBudgetHintFixed =>
      'Les voyageurs verront ce montant et pourront l\'accepter tel quel.';

  @override
  String get requestCreatePromoLabel => 'Code promo (optionnel)';

  @override
  String get requestCreatePromoHint => 'Ex: WELCOME10';

  @override
  String get requestCreatePromoAppliedFallback => 'Code appliqué';

  @override
  String get requestCreatePaymentAcceptedLabel => 'Paiement accepté';

  @override
  String get requestCreatePaymentHint =>
      'Choisissez comment vous paierez le voyageur.';

  @override
  String get requestCreateKeepOnePaymentMethod =>
      'Gardez au moins un mode de paiement.';

  @override
  String get requestCreatePublishInfoBanner =>
      'Une fois publiée, les voyageurs sur ce trajet sont prévenus. Vous recevrez une notification à la première offre.';

  @override
  String get requestCreateBudgetInputHint => 'Ex. 40,00';

  @override
  String get requestCreateBudgetEmpty => 'Indiquez un budget';

  @override
  String requestCreateBudgetRange(String min, String max) {
    return 'Entre $min et $max';
  }

  @override
  String requestCreateCommissionLabel(String rate) {
    return 'Commission Yadony ($rate %)';
  }

  @override
  String get requestCreatePromoBoostLabel =>
      'Grâce au code promo, le voyageur touche';

  @override
  String get requestCreateTravelerReceivesLabel => 'Le voyageur touchera';

  @override
  String requestCreateCurrencySemanticLabel(String name, String code) {
    return 'Devise de la demande : $name, $code. Bouton, modifier la devise.';
  }

  @override
  String get requestCreateChangeCurrency => 'Changer';

  @override
  String get requestCreatePhotoUnsupported =>
      'Image non supportée ou trop volumineuse';

  @override
  String get requestCreateTakePhoto => 'Prendre une photo';

  @override
  String get requestCreatePickFromGallery => 'Choisir dans la galerie';

  @override
  String get requestCreatePhotosLabel => 'Photos du colis';

  @override
  String get requestCreatePhotosHint =>
      'Visibles par les voyageurs. Ajoutées à l\'offre quand un trajet est lié.';

  @override
  String get requestCreateAddPhotoSemantic => 'Ajouter une photo du colis';

  @override
  String get requestCreatePhotoUploadFailed => 'Échec de l\'upload de la photo';

  @override
  String requestCreatePhotoUploadFailedWithReason(String reason) {
    return 'Échec : $reason';
  }

  @override
  String get requestCreateRetryPhotoUpload => 'Réessayer l\'envoi de la photo';

  @override
  String get requestCreateAddPhotoTitle => 'Ajouter une photo';

  @override
  String get requestCreateAddPhotoSubtitle =>
      'Fortement recommandé, rassure le voyageur';

  @override
  String get requestCreateRemovePhoto => 'Supprimer cette photo';

  @override
  String get requestCreateCompleteDetailsTitle => 'Vérifie & complète';

  @override
  String get requestCreateDetailsSaved => 'Détails enregistrés';

  @override
  String get requestCreateRecipientSection => 'Destinataire';

  @override
  String get requestCreateRecipientNameLabel => 'Nom complet';

  @override
  String get requestCreateRequiredField => 'Requis';

  @override
  String get requestCreateRecipientPhoneLabel => 'Téléphone';

  @override
  String get requestCreateRecipientPhoneFormat => 'Format E.164 (+221…)';

  @override
  String get requestCreateRecipientCityLabel => 'Ville / commune';

  @override
  String get requestCreateRecipientCityHint => 'Ex. Dakar (optionnel)';

  @override
  String get requestCreatePaymentMethodSection => 'Mode de paiement';

  @override
  String get requestCreateSendingLabel => 'Envoi…';

  @override
  String get requestCreateContinueToPayment => 'Continuer vers le paiement';

  @override
  String get requestCreateRecapTitle => 'Récapitulatif';

  @override
  String get requestCreateRecapTrip => 'Trajet';

  @override
  String get requestCreateRecapTravelDate => 'Date du voyage';

  @override
  String get requestCreateRecapWeight => 'Poids';

  @override
  String get requestCreateRecapSize => 'Taille';

  @override
  String get requestCreateRecapPrice => 'Prix à payer';

  @override
  String get requestDetailTitle => 'Ma demande';

  @override
  String get requestDetailNoticeActionFailed =>
      'Une erreur est survenue. Réessaie dans un instant.';

  @override
  String get requestDetailNoticeInvitationSent =>
      'Invitation envoyée. Le voyageur est prévenu.';

  @override
  String get requestDetailNoticeInvitationRefused =>
      'Ce voyageur ne peut pas être invité.';

  @override
  String get requestDetailNoticeInvitationNotInvitable =>
      'Cette demande n\'accepte plus d\'invitations.';

  @override
  String get requestDetailNoticeInvitationLimitReached =>
      'Limite d\'invitations atteinte pour cette demande.';

  @override
  String requestDetailShareMessage(
    String weight,
    String departure,
    String arrival,
    String date,
  ) {
    return 'J\'envoie un colis de $weight kg $departure → $arrival autour du $date. Tu voyages sur cet axe ? Réponds à ma demande sur Yadony.';
  }

  @override
  String get requestDetailMoreActionsTooltip => 'Plus d\'actions';

  @override
  String get requestDetailCancelDialogTitle => 'Annuler cette demande ?';

  @override
  String get requestDetailCancelDialogMessage =>
      'Cette action est irréversible. Les voyageurs ne pourront plus y répondre.';

  @override
  String get requestDetailErrorNotFoundTitle => 'Cette demande n\'existe plus';

  @override
  String get requestDetailErrorNotFoundMessage =>
      'Elle a peut-être été annulée ou supprimée.';

  @override
  String get requestDetailErrorLoadTitle => 'Impossible de charger ta demande';

  @override
  String get requestDetailErrorLoadMessage =>
      'Vérifie ta connexion, puis réessaie. Ta demande n\'a pas été modifiée.';

  @override
  String get requestTravelerFallbackNameLower => 'le voyageur';

  @override
  String get requestListTitle => 'Mes demandes';

  @override
  String get requestListErrorFallback => 'Erreur';

  @override
  String get requestListEmptyTitle => 'Tu n\'as encore rien envoyé';

  @override
  String get requestListEmptyDescription =>
      'Publie ta première demande et reçois des offres de voyageurs en quelques heures.';

  @override
  String get requestListEmptyCta => '+ Publier ma première demande';

  @override
  String get requestListSearchHint => 'Ville, catégorie…';

  @override
  String get requestListFilterAllLabel => 'Toutes';

  @override
  String get requestListFilterOpenLabel => 'Ouvertes';

  @override
  String get requestListFilterClosedLabel => 'Non abouties';

  @override
  String get requestListFilterDraftLabel => 'Brouillons';

  @override
  String get requestListEmptySearchResult =>
      'Aucun résultat pour cette recherche';

  @override
  String get requestListEmptyOpen => 'Aucune demande ouverte';

  @override
  String get requestListEmptyClosed => 'Aucune demande non aboutie';

  @override
  String get requestListEmptyDraft => 'Aucun brouillon';

  @override
  String get requestListEmptyAll => 'Aucune demande';

  @override
  String get requestListNewFab => 'Nouvelle demande';

  @override
  String get requestListEditCta => 'Modifier →';

  @override
  String get requestListStatusDraft => 'BROUILLON';

  @override
  String get requestListStatusOpen => 'OUVERTE';

  @override
  String get requestListStatusNegotiating => 'NÉGOCIATION';

  @override
  String get requestListStatusAccepted => 'ACCEPTÉE';

  @override
  String get requestListStatusCompleted => 'LIVRÉE';

  @override
  String get requestListStatusExpired => 'EXPIRÉE';

  @override
  String get requestListStatusCancelled => 'ANNULÉE';

  @override
  String get requestListTimeJustNow => 'à l\'instant';

  @override
  String requestListTimeMinutesAgo(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String requestListTimeHoursAgo(int hours) {
    return 'il y a ${hours}h';
  }

  @override
  String requestListTimeDaysAgo(int days) {
    return 'il y a ${days}j';
  }

  @override
  String get requestEnvoyerHubTitle => 'Envoyer';

  @override
  String get requestEnvoyerHubNewButton => '+ Nouveau';

  @override
  String requestDetailViews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vues',
      one: '$count vue',
    );
    return '$_temp0';
  }

  @override
  String requestDetailTravelersWillSee(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs la verront',
      one: '$count voyageur la verra',
    );
    return '$_temp0';
  }

  @override
  String requestDetailTravelersOnRouteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs sur ton axe',
      one: '$count voyageur sur ton axe',
    );
    return '$_temp0';
  }

  @override
  String get requestDetailNotVisibleTitle => 'Pas encore visible';

  @override
  String get requestDetailNotVisibleMessage =>
      'Publie ta demande pour que les voyageurs puissent te proposer un prix.';

  @override
  String requestDetailCashCommissionTitle(String name) {
    return '$name règle sa commission Yadony';
  }

  @override
  String get requestDetailCashCommissionMessage =>
      'Accord en espèces trouvé. Tant que ce n\'est pas fait, tu peux encore choisir quelqu\'un d\'autre.';

  @override
  String get requestDetailFinalizeTitle => 'Finalise pour réserver sa place';

  @override
  String get requestDetailFinalizeMessage =>
      'Ton argent reste bloqué chez Yadony jusqu\'à la remise du colis.';

  @override
  String get requestDetailExpiredTitle => 'Date dépassée sans accord';

  @override
  String get requestDetailExpiredMessage =>
      'Aucun voyageur n\'a été retenu à temps. Tes infos sont gardées, il suffit de choisir de nouvelles dates.';

  @override
  String get requestDetailCancelledTitle => 'Tu as annulé cette demande';

  @override
  String get requestDetailCancelledMessage =>
      'Les voyageurs ne peuvent plus y répondre.';

  @override
  String get requestDetailNoSearchTitle =>
      'Impossible de charger les voyageurs pour le moment';

  @override
  String get requestDetailNoSearchMessage =>
      'Réessaie plus tard, ou partage directement ta demande en attendant.';

  @override
  String get requestDetailOffersReceivedTitle => 'Offres reçues';

  @override
  String get requestDetailSingleChoiceTitle => 'Un seul choix';

  @override
  String get requestDetailSingleChoiceMessage =>
      'Les autres candidats seront déclinés automatiquement.';

  @override
  String get requestDetailInterestedTravelersTitle => 'Voyageurs intéressés';

  @override
  String get requestDetailOffersTitle => 'Offres';

  @override
  String get requestDetailSelectedOfferTitle => 'Offre retenue';

  @override
  String get requestDetailTripNotCompletedTitle => 'Ce trajet n\'a pas abouti';

  @override
  String get requestDetailTripNotCompletedMessage =>
      'Le voyageur n\'a pas pu assurer la livraison. Publie une demande similaire pour retrouver quelqu\'un.';

  @override
  String get requestDetailYourTravelerFallback => 'ton voyageur';

  @override
  String get requestDetailStubCashPaid => 'réglé en main propre';

  @override
  String get requestDetailStubCashPending =>
      'à régler en main propre à la remise';

  @override
  String get requestDetailStubPaidToTraveler => 'versé au voyageur';

  @override
  String get requestDetailStubHeldByYadony => 'payé, bloqué chez Yadony';

  @override
  String get requestTravelerFallbackName => 'Le voyageur';

  @override
  String requestTravelerAddingTrip(String name) {
    return '$name ajoute son trajet';
  }

  @override
  String get requestOfferDealFound => 'Accord trouvé';

  @override
  String get requestOfferCashDealCommissionPending =>
      'Accord en espèces, commission en attente';

  @override
  String get requestOfferAvailableForParcel => 'Disponible pour ton colis';

  @override
  String get requestOfferChooseCta => 'Choisir';

  @override
  String get requestOfferYourTurn => 'À toi de répondre';

  @override
  String get requestOfferRespondCta => 'Répondre';

  @override
  String requestOfferWaitingFor(String name) {
    return 'En attente de $name';
  }

  @override
  String get requestOfferYouPayCaption => 'tu paies';

  @override
  String requestAvailableKg(String weight) {
    return '$weight kg libres';
  }

  @override
  String get requestDetailMenuUnpublishLabel => 'Dépublier';

  @override
  String get requestDetailMenuUnpublishConsequence =>
      'Redevient un brouillon, invisible des voyageurs';

  @override
  String get requestDetailMenuDuplicateLabel => 'Dupliquer la demande';

  @override
  String get requestDetailMenuDuplicateConsequence =>
      'Même colis, nouvelles dates ou nouveau trajet';

  @override
  String get requestDetailMenuCancelLabel => 'Annuler la demande';

  @override
  String get requestDetailMenuCancelConsequence => 'Irréversible';

  @override
  String get requestTravelersOnRouteTitle => 'Voyageurs sur ton axe';

  @override
  String requestNoTravelersTitle(String corridor) {
    return 'Aucun voyageur sur $corridor pour l\'instant';
  }

  @override
  String get requestNoTravelersMessage =>
      'Les trajets arrivent souvent la semaine du départ. On te prévient dès qu\'un voyageur publie.';

  @override
  String get requestNoTravelersAlertCta => 'Être alerté des nouveaux trajets';

  @override
  String get requestNoTravelersWidenDatesCta => 'Élargir mes dates';

  @override
  String requestStatusOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offres',
      one: '$count offre',
    );
    return '$_temp0';
  }

  @override
  String requestStatusCandidates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count candidats',
      one: '$count candidat',
    );
    return '$_temp0';
  }

  @override
  String get requestStatusDraft => 'Brouillon';

  @override
  String get requestStatusLive => 'En ligne';

  @override
  String get requestStatusPendingCommission => 'En attente';

  @override
  String get requestStatusToFinalize => 'À finaliser';

  @override
  String get requestStatusConfirmed => 'Confirmée';

  @override
  String get requestStatusDelivered => 'Livrée';

  @override
  String get requestStatusExpired => 'Expirée';

  @override
  String get requestStatusCancelled => 'Annulée';

  @override
  String get requestDetailPublishCta => 'Publier';

  @override
  String get requestDetailOpenThreadCta => 'Ouvrir la discussion';

  @override
  String get requestDetailPayCta => 'Payer';

  @override
  String requestDetailPayCtaWithAmount(String amount) {
    return 'Payer $amount';
  }

  @override
  String get requestDetailTrackParcelCta => 'Suivre mon colis';

  @override
  String requestDetailRateCta(String name) {
    return 'Noter $name';
  }

  @override
  String get requestDetailRepublishCta => 'Republier avec de nouvelles dates';

  @override
  String get requestDetailPublishSimilarCta => 'Publier une demande similaire';

  @override
  String get requestDetailMessageCta => 'Message';

  @override
  String requestTicketRouteSemantic(
    String departure,
    String arrival,
    String date,
  ) {
    return '$departure vers $arrival, $date';
  }

  @override
  String get requestTicketPriceUndefined => 'Prix à définir';

  @override
  String get requestTicketNegotiable => 'négociable';

  @override
  String get requestTicketFixedPrice => 'prix ferme';

  @override
  String get requestTicketViewPhotosSemantic => 'Voir les photos du colis';

  @override
  String get requestProgressDealAndPayment => 'Accord et paiement';

  @override
  String requestProgressHandoverTo(String name) {
    return 'Remise du colis à $name';
  }

  @override
  String get requestProgressInTransit => 'En voyage';

  @override
  String requestProgressDeliveryTo(String city) {
    return 'Livraison à $city';
  }

  @override
  String requestYourParcelWeight(String weight) {
    return 'ton colis : $weight kg';
  }

  @override
  String get requestTravelerInvited => 'Invité';

  @override
  String get requestTravelerInviteCta => 'Inviter';

  @override
  String get requestDetailLoadingSemantic => 'Chargement de ta demande';

  @override
  String requestToleranceDays(int days) {
    return '±${days}j';
  }

  @override
  String requestReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avis',
      one: '$count avis',
    );
    return '$_temp0';
  }

  @override
  String get requestPublicTitle => 'Demande d\'envoi';

  @override
  String get requestDescriptionLabel => 'Description';

  @override
  String get requestPublicReportTooltip => 'Signaler';

  @override
  String get requestPublicReportSheetTitle => 'Signaler la demande';

  @override
  String get requestPublicReportReasonProhibited => 'Contenu interdit';

  @override
  String get requestPublicReportReasonScam => 'Arnaque / fraude';

  @override
  String get requestPublicReportReasonInappropriate => 'Contenu inapproprié';

  @override
  String get requestPublicReportReasonOther => 'Autre raison';

  @override
  String get requestPublicReportSuccess => 'Demande signalée. Merci.';

  @override
  String get requestPublicReportError =>
      'Impossible de signaler pour le moment';

  @override
  String get requestPublicBadge => 'DEMANDE D\'ENVOI';

  @override
  String get requestPublicFirmPriceBadge => 'PRIX FERME';

  @override
  String requestPublicDesiredDate(String date, String tolerance) {
    return 'le $date ($tolerance)';
  }

  @override
  String get requestPublicParcelHintBag => 'Sac';

  @override
  String get requestPublicParcelHintBox => 'Carton';

  @override
  String get requestPublicParcelHintSuitcase => 'Valise';

  @override
  String get requestPublicCategoriesLabel => 'CATÉGORIES';

  @override
  String get requestPublicBudget => 'Budget';

  @override
  String get requestPublicZonesLabel => 'Zones';

  @override
  String get requestPublicPickupLabel => 'Pickup';

  @override
  String get requestPublicDeliveryLabel => 'Livraison';

  @override
  String get requestPublicPaymentTitle => 'Mode de paiement souhaité';

  @override
  String get requestPublicPaymentSubtitle => 'Accepté par l\'expéditeur';

  @override
  String get requestPublicProposeTripCta => 'Proposer mon trajet';

  @override
  String get requestPublicViewNegotiationCta => 'Voir ma négociation';

  @override
  String get requestPublicViewProposalCta => 'Voir ma proposition';

  @override
  String get requestPublicTakePackageCta => 'Prendre ce colis';

  @override
  String requestPublicTakeAt(String price) {
    return 'Prendre à $price · Prix ferme';
  }

  @override
  String get requestPublicOfferConfirmed => 'Offre confirmée';

  @override
  String get requestSearchTitle => 'Demandes ouvertes';

  @override
  String get requestSearchEmptyMessage =>
      'Aucune demande ne correspond à votre filtre';

  @override
  String requestSearchBudgetLine(String amount) {
    return 'Budget: $amount';
  }

  @override
  String requestListYourTripOn(String date) {
    return 'Ton trajet du $date';
  }

  @override
  String get requestBudgetFreeLabel => 'Budget libre';

  @override
  String get requestFavoriteToggleError => 'Action impossible, réessaie';

  @override
  String requestSenderShipmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count envois',
      one: '$count envoi',
    );
    return '$_temp0';
  }

  @override
  String requestMatchingBudgetPerKg(String amount) {
    return 'Budget $amount/kg';
  }

  @override
  String get requestPreviewTitle => 'Aperçu de votre demande';

  @override
  String get requestPreviewPublishCta => 'Publier ma demande';

  @override
  String get requestPreviewSaveDraftCta => 'Enregistrer en brouillon';

  @override
  String requestPreviewPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '$count photo',
    );
    return '$_temp0';
  }

  @override
  String get requestPreviewDropoffLabel => 'Remise';

  @override
  String get requestPreviewPaymentLabel => 'Paiement';

  @override
  String get requestPreviewOpenToOffers => 'Ouvert aux offres';

  @override
  String requestPreviewBudgetIndicative(String amount) {
    return 'Budget indicatif : $amount';
  }

  @override
  String requestPreviewFixedPrice(String amount) {
    return 'Prix ferme : $amount';
  }

  @override
  String requestCarouselSeeAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Voir les $count demandes',
      one: 'Voir la demande',
    );
    return '$_temp0';
  }

  @override
  String get requestCarouselEmptyTitle => 'Aucune demande à proximité';

  @override
  String get requestCarouselWidenZoneCta => 'Élargir la zone';

  @override
  String get requestStatusChipOpen => 'Ouverte';

  @override
  String get requestStatusChipNegotiating => 'En négociation';

  @override
  String get requestStatusChipAccepted => 'Acceptée';

  @override
  String get requestSenderProfileTitle => 'Profil expéditeur';

  @override
  String get requestSenderMoreOptionsTooltip => 'Plus d\'options';

  @override
  String get requestSenderVerifiedIdentity => 'Identité vérifiée';

  @override
  String get requestSenderNewMember => 'Nouveau membre';

  @override
  String get requestPickerModifyTripCta => 'Modifier le trajet';

  @override
  String get requestPickerPriceUnavailable => 'Indisponible';

  @override
  String get requestPickerCashEnabled => 'Liquide activé';

  @override
  String get requestPickerCashDisabled => 'Liquide désactivé';

  @override
  String requestPickerKgAvailable(String kg) {
    return '$kg kg dispo';
  }

  @override
  String get requestPickerLoadErrorMessage =>
      'Impossible de charger tes trajets';

  @override
  String get requestPickerNoMatchTitle => 'Aucun de tes trajets ne correspond';

  @override
  String get requestPickerMatchingTitle => 'Tes trajets compatibles';

  @override
  String get requestPickerEmptyCreateHint =>
      'Crée un trajet correspondant à cette demande';

  @override
  String get requestPickerCreateTripCta => 'Créer un nouveau trajet';

  @override
  String get requestCarouselCardPriceFree => 'Libre';

  @override
  String get requestPreviewPhotosLabel => 'Photos';

  @override
  String get requestCreateRecapTransport => 'Transport';

  @override
  String get requestCreateRecapPackage => 'Colis';

  @override
  String get listingDeleteTripConfirmTitle => 'Supprimer ce trajet ?';

  @override
  String get listingDeleteTripCancelledMessage =>
      'Cette action est irréversible. Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.';

  @override
  String get listingDeleteTripActiveMessage =>
      'Cette action est irréversible. Le trajet ne sera plus visible pour les expéditeurs.';

  @override
  String get listingTripDetailTitle => 'Détail du trajet';

  @override
  String get listingTripDeletedMessage => 'Trajet supprimé';

  @override
  String get listingAnnouncementGoneMessage => 'Cette annonce n\'existe plus';

  @override
  String get listingHeroTripLabel => 'Trajet';

  @override
  String get listingPickupLocationsTitle => 'Lieux de remise';

  @override
  String get listingHandoverDeadlineTitle => 'Dépôt des colis';

  @override
  String get listingCapacityAvailableLabel => 'Capacité dispo.';

  @override
  String get listingPricingModeLabel => 'Tarification';

  @override
  String get listingPricePerKgLabel => 'Prix par kg';

  @override
  String get listingPriceGridShort => 'Grille';

  @override
  String get listingPriceUnavailableShort => 'Indisponible';

  @override
  String listingSeeRequestsButton(int count) {
    return 'Voir les demandes ($count)';
  }

  @override
  String get listingEditTripButton => 'Modifier ce trajet';

  @override
  String get listingCancelTripButton => 'Annuler ce trajet';

  @override
  String get listingDeleteTripButton => 'Supprimer ce trajet';

  @override
  String get listingTripLockedMessage => 'Ce trajet ne peut plus être modifié.';

  @override
  String get listingStatusActive => 'Actif';

  @override
  String get listingStatusFull => 'Complet';

  @override
  String get listingStatusCompleted => 'Terminé';

  @override
  String get listingStatusCancelled => 'Annulé';

  @override
  String listingHandoverUntil(String date) {
    return 'Jusqu\'au $date';
  }

  @override
  String get listingSearchDestinationHint => 'Rechercher une destination…';

  @override
  String get listingFilterAllChip => 'Tous';

  @override
  String get listingFilterDraftsChip => 'Brouillons';

  @override
  String get listingFilterActiveChip => 'Actifs';

  @override
  String get listingFilterCompletedChip => 'Terminés';

  @override
  String get listingFilterCancelledChip => 'Annulés';

  @override
  String get listingHeaderTitle => 'Mes trajets';

  @override
  String get listingNewTripPill => '+ Nouveau';

  @override
  String get listingLoadErrorTitle => 'Impossible de charger vos trajets';

  @override
  String get listingEmptyNoTripsTitle => 'Aucun trajet à venir';

  @override
  String get listingEmptyDraftTitle => 'Aucun brouillon';

  @override
  String get listingEmptyActiveTitle => 'Aucun trajet actif';

  @override
  String get listingEmptyCompletedTitle => 'Aucun historique';

  @override
  String get listingEmptyCancelledTitle => 'Aucune annulation';

  @override
  String get listingEmptyAllTitle => 'Aucun trajet trouvé';

  @override
  String get listingEmptyNoTripsDesc =>
      'Publiez votre premier trajet et commencez à transporter des colis.';

  @override
  String get listingEmptyDraftDesc =>
      'Vos trajets enregistrés sans publication apparaîtront ici.';

  @override
  String get listingEmptyActiveDesc =>
      'Vos trajets en cours et à venir apparaîtront ici.';

  @override
  String get listingEmptyCompletedDesc =>
      'Vos trajets passés et terminés apparaîtront ici.';

  @override
  String get listingEmptyCancelledDesc =>
      'Vos trajets annulés apparaîtront ici.';

  @override
  String get listingEmptyAllDesc =>
      'Aucun trajet ne correspond à votre recherche.';

  @override
  String get listingHeroTripLabelCaps => 'TRAJET';

  @override
  String get listingCapacityAvailableSuffix => 'disponibles';

  @override
  String get listingPricingSuffixTarifaire => 'tarifaire';

  @override
  String get listingPricingSuffixPrix => 'prix';

  @override
  String listingAcceptedParcels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'colis acceptés',
      one: 'colis accepté',
    );
    return '$_temp0';
  }

  @override
  String get listingPendingParcelsLabel => 'en attente';

  @override
  String get listingPaymentsAcceptedTitle => 'Paiements acceptés';

  @override
  String get listingCashOnlyNudgeMessage =>
      'Trajet en espèces uniquement. Beaucoup d\'expéditeurs préfèrent payer par carte, activez cette option pour augmenter vos chances de recevoir des colis.';

  @override
  String get listingActivateCardPaymentsButton =>
      'Activer les paiements par carte';

  @override
  String get listingAcceptedContentTitle => 'Ce que j\'accepte';

  @override
  String get listingRefusedContentTitle => 'Ce que je refuse';

  @override
  String get listingSenderNoteTitle => 'Note aux expéditeurs';

  @override
  String get listingBadgeActive => '● ACTIF';

  @override
  String get listingBadgeDraft => '✎ BROUILLON';

  @override
  String get listingBadgeFull => '● COMPLET';

  @override
  String get listingBadgeInProgress => '● EN COURS';

  @override
  String get listingBadgeCompleted => '✓ TERMINÉ';

  @override
  String get listingBadgeCancelled => '✕ ANNULÉ';

  @override
  String listingReservedKgLabel(String kg) {
    return '$kg kg réservés';
  }

  @override
  String listingOpenKgLabel(String kg) {
    return '$kg kg ouverts';
  }

  @override
  String get listingPickupParcelTitleShort => 'Remise colis';

  @override
  String get listingDeliveryPickupTitle => 'Récupération';

  @override
  String get listingAlreadyHasParcelMessage =>
      'Vous avez déjà un colis sur ce trajet';

  @override
  String get listingSeeMyParcelButton => 'Voir mon colis';

  @override
  String get listingMakeRequestButton => 'Faire une demande';

  @override
  String get listingNegotiableTripPrefix => 'Trajet négociable · ';

  @override
  String get listingProposePriceLink => 'Proposer un prix';

  @override
  String get listingPricePerKiloLabel => 'par kilo';

  @override
  String listingApproxPricePerKg(String price) {
    return 'environ $price/kg';
  }

  @override
  String listingApproxPrice(String price) {
    return 'environ $price';
  }

  @override
  String get listingDepositDeadlineLabel => 'date limite de dépôt';

  @override
  String get listingPriceGridLabel => 'Grille tarifaire';

  @override
  String listingItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '$count article',
    );
    return '$_temp0';
  }

  @override
  String get listingPricePerItemTitle => 'Tarif par article';

  @override
  String listingSeeAllPricesButton(int count) {
    return 'Voir tous les tarifs ($count)';
  }

  @override
  String get listingPickupParcelTitle => 'Remise du colis';

  @override
  String get listingReportTripLink => 'Signaler ce trajet';

  @override
  String get listingBlockTravelerLink => 'Bloquer ce voyageur';

  @override
  String get listingFavoriteAddedMessage => 'Trajet ajouté aux favoris';

  @override
  String get listingFavoriteRemovedMessage => 'Trajet retiré des favoris';

  @override
  String get listingFavoriteToggleErrorMessage =>
      'Impossible de modifier les favoris';

  @override
  String listingKgAvailableLabel(String kg) {
    return '$kg kg dispo';
  }

  @override
  String get listingIdentityBadge => 'Identité';

  @override
  String get listingCategoriesAcceptedTitle => 'Types de colis acceptés';

  @override
  String get listingTravelerMessageTitle => 'Message du voyageur';

  @override
  String get listingRouteLabel => 'Itinéraire';

  @override
  String get listingCashOnlyWarningBold => 'Trajet en espèces uniquement. ';

  @override
  String get listingCashOnlyWarningBody =>
      'Le paiement se fait en main propre au voyageur, Yadony ne séquestre pas votre argent et ne peut pas le rembourser automatiquement en cas de litige.';

  @override
  String get listingNewRatingLabel => 'Nouveau';

  @override
  String listingTravelerTrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '· $count trajets',
      one: '· $count trajet',
    );
    return '$_temp0';
  }

  @override
  String get listingPreviewTitle => 'Aperçu de votre annonce';

  @override
  String get listingPublishButton => 'Publier l\'annonce';

  @override
  String get listingSaveDraftButton => 'Enregistrer comme brouillon';

  @override
  String get listingPreviewDepartureLabel => 'Départ';

  @override
  String get listingRowLabelPickup => 'Remise';

  @override
  String get listingRowLabelCapacity => 'Capacité';

  @override
  String get listingRowLabelPayment => 'Paiement';

  @override
  String get listingPaymentCardCash => 'Carte + Espèces';

  @override
  String get listingPaymentCardOnly => 'Carte uniquement';

  @override
  String get listingRowLabelAccept => 'Accepte';

  @override
  String get listingRowLabelRefuse => 'Refuse';

  @override
  String get listingRowLabelNote => 'Note';

  @override
  String get listingPriceTooLowWarning =>
      'Prix bas. Vous pourrez le modifier après publication.';

  @override
  String get listingPriceTooHighWarning =>
      'Prix élevé. Vous pourrez le modifier après publication.';

  @override
  String get listingStatusInProgress => 'En cours';

  @override
  String listingDateTodayLabel(String date) {
    return 'Aujourd\'hui · $date';
  }

  @override
  String listingDateTomorrowLabel(String date) {
    return 'Demain · $date';
  }

  @override
  String listingDateInDaysLabel(int days, String date) {
    return 'Départ dans $days jours · $date';
  }

  @override
  String get listingRetryActionMessage => 'Action impossible, réessaie';

  @override
  String listingAcceptedBidsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count acceptées',
      one: '$count acceptée',
    );
    return '$_temp0';
  }

  @override
  String listingPendingBidsCount(int count) {
    return '$count en attente';
  }

  @override
  String listingSoldOfTotalLabel(String sold, String total) {
    return '$sold vendus sur $total';
  }

  @override
  String listingAvailableKgLabel(String kg) {
    return '$kg disponibles';
  }

  @override
  String listingSoldLabel(String kg) {
    return '$kg vendus';
  }

  @override
  String listingEarnedLabel(String price) {
    return '$price gagnés';
  }

  @override
  String get listingBidStatusAccepted => 'Demande acceptée';

  @override
  String get listingBidStatusOnTrip => 'Colis sur ce trajet';

  @override
  String get listingBidStatusArrived => 'Arrivé';

  @override
  String get listingBidStatusPending => 'Demande en attente';

  @override
  String get listingYourTripPill => 'Votre trajet';

  @override
  String get listingProBadge => 'PRO';

  @override
  String get listingNoTravelersNearbyTitle => 'Aucun voyageur à proximité';

  @override
  String get listingNoTravelersNearbyDesc =>
      'Essaie d\'augmenter le rayon ou de changer de date.';

  @override
  String get listingSeeAnnouncementButton => 'Voir l\'annonce';

  @override
  String listingSeeAnnouncementsCountButton(int count) {
    return 'Voir les $count annonces';
  }

  @override
  String listingRouteDeparturesFrom(String city) {
    return 'Départs depuis $city';
  }

  @override
  String listingRouteArrivalsTo(String city) {
    return 'Arrivées à $city';
  }

  @override
  String listingRouteTrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trajets',
      one: '$count trajet',
    );
    return '$_temp0';
  }

  @override
  String get listingNoTripsOnRoute => 'Aucun trajet disponible sur cette route';

  @override
  String listingSameAddressTravelers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs disponibles à cette adresse',
      one: '$count voyageur disponible à cette adresse',
    );
    return '$_temp0';
  }

  @override
  String get listingAddressFallback => 'Adresse';

  @override
  String get listingNearMeDeactivateTooltip => 'Désactiver « Près de moi »';

  @override
  String get listingNearMeActivateTooltip => 'Voir les voyageurs près de moi';

  @override
  String get listingFilterTripsTitle => 'Filtrer les trajets';

  @override
  String get listingResetFiltersButton => 'Réinitialiser';

  @override
  String listingSearchButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rechercher · $count filtres',
      one: 'Rechercher · $count filtre',
      zero: 'Rechercher',
    );
    return '$_temp0';
  }

  @override
  String get listingQuickFiltersTitle => 'FILTRES RAPIDES';

  @override
  String get listingKiloProChip => 'Kilo Pro';

  @override
  String get listingRatingChip => 'Note ≥ 4.5';

  @override
  String get listingWeekendChip => 'Week-end';

  @override
  String get listingContentContainsTitle => 'MON COLIS CONTIENT';

  @override
  String get listingDepartureUrgencyTitle => 'URGENCE DU DÉPART';

  @override
  String get listingDepartureUrgencyDesc =>
      'Filtrer les trajets selon leur proximité de départ';

  @override
  String get listingDeleteTripAssociatedRequestsMessage =>
      'Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.';

  @override
  String get listingDeadlineLabel => 'Date limite';

  @override
  String get listingInstructionsCardTitle => 'Instructions du voyageur';

  @override
  String get listingRowLabelDate => 'Date';

  @override
  String get listingRowLabelPrice => 'Prix';

  @override
  String listingPriceEstimateSuffix(String amount) {
    return ' · estimation $amount net';
  }

  @override
  String get bidCreateSendProposalButton => 'Envoyer ma proposition';

  @override
  String bidCreateConfirmCashButton(String amount) {
    return 'Confirmer $amount en espèces';
  }

  @override
  String bidCreateConfirmMobileMoneyButton(String amount) {
    return 'Confirmer $amount par mobile money';
  }

  @override
  String bidCreateLockAndPayButton(String amount) {
    return 'Bloquer $amount & payer';
  }

  @override
  String get bidCreateDescriptionRequiredError => 'Description obligatoire';

  @override
  String get bidCreateRecipientNameRequiredError =>
      'Nom du destinataire obligatoire';

  @override
  String get bidCreateRecipientPhoneRequiredError =>
      'Téléphone du destinataire obligatoire';

  @override
  String get bidCreatePriceRequiredError =>
      'Indiquez le prix que vous proposez';

  @override
  String get bidCreateProposalSentMessage =>
      'Proposition envoyée, le voyageur va vous répondre.';

  @override
  String get bidCreateOfferSentTitle => 'Offre envoyée !';

  @override
  String get bidCreateCashSuccessSubtitle =>
      'Paiement en espèces : si le voyageur accepte, tu remets le montant en main propre à la remise du colis. En cas d\'annulation après la remise, Yadony ne peut pas te rembourser immédiatement mais s\'assurera que le voyageur te restitue ton argent.';

  @override
  String get bidCreateMobileMoneySuccessSubtitle =>
      'Paiement mobile money : si le voyageur accepte, tu recevras une notification et auras 30 minutes pour valider le paiement sur ton téléphone. Le montant est gardé en sécurité par Yadony jusqu\'à la livraison.';

  @override
  String get bidCreateReviewPendingSubtitle =>
      'Le voyageur va examiner ta demande.';

  @override
  String get bidCreateSeeMyShipmentButton => 'Voir mon envoi';

  @override
  String get bidCreateArticlesSectionLabel => 'ARTICLES';

  @override
  String bidCreateSelectedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles sélectionnés',
      one: '$count article sélectionné',
    );
    return '$_temp0';
  }

  @override
  String bidCreateSubtotalLabel(String amount) {
    return 'Sous-total : $amount';
  }

  @override
  String get bidCreateChooseItemsLabel => 'Choisir mes articles';

  @override
  String get bidCreateItemsRequiredHint => 'Requis : au moins 1 article';

  @override
  String get bidCreatePhotosSectionLabel => 'PHOTOS DU COLIS (OPTIONNEL)';

  @override
  String get bidCreateDescriptionSectionLabel => 'DESCRIPTION (AU VOYAGEUR)';

  @override
  String get bidCreateDescriptionHint =>
      'Médicaments pour diabète + 2 tee-shirts enfants';

  @override
  String get bidCreateRecipientSectionLabel => 'DESTINATAIRE';

  @override
  String get bidCreateRecipientNameLabel => 'Prénom et nom du destinataire';

  @override
  String get bidCreateRecipientNameHint => 'ex: Amadou Diallo';

  @override
  String get bidCreateRecipientPhoneLabel => 'Téléphone du destinataire';

  @override
  String get bidCreateRecipientPhoneHint => 'ex: +221 77 000 00 00';

  @override
  String get bidCreatePromoSectionLabel => 'CODE PROMO (OPTIONNEL)';

  @override
  String get bidCreatePromoCodeHint => 'Ex: WELCOME10';

  @override
  String get bidCreatePromoAppliedDefaultLabel => 'Code appliqué';

  @override
  String get bidCreateYourProposalSectionLabel => 'VOTRE PROPOSITION';

  @override
  String bidCreateProposedPriceLabel(String symbol) {
    return 'Prix proposé ($symbol)';
  }

  @override
  String bidCreateSuggestedPriceLabel(String amount) {
    return 'Suggéré : $amount';
  }

  @override
  String get bidCreatePaymentMethodSectionLabel => 'MODE DE PAIEMENT';

  @override
  String get bidCreatePaymentMethodHint =>
      'Si le voyageur accepte votre prix, vous réglerez de cette façon.';

  @override
  String get bidCreateContentSectionLabel => 'CONTENU DU COLIS';

  @override
  String get bidCreateContentHintText =>
      'Ces suggestions sont les contenus acceptés par le voyageur. Si le contenu de votre colis n\'y figure pas, ajoutez-le : ce sera au voyageur de décider s\'il accepte votre colis ou non.';

  @override
  String get bidCreateRefusedByTravelerSectionLabel => 'REFUSÉ PAR LE VOYAGEUR';

  @override
  String get bidCreateHowToPayTitle => 'Comment veux-tu payer ?';

  @override
  String get bidCreateChoosePaymentSubtitle =>
      'Choisis le mode de paiement pour cette demande.';

  @override
  String get bidCreatePaymentNotConfirmedError =>
      'Paiement non confirmé, réessayez';

  @override
  String bidCreateShipmentToLabel(String city) {
    return 'Envoi vers $city';
  }

  @override
  String get bidCreateOfferPaidTitle => 'Offre payée !';

  @override
  String get bidCreateOfferPaidSubtitle =>
      'Ton paiement est bloqué et sécurisé jusqu\'à la livraison confirmée. Le voyageur est notifié de ta demande.';

  @override
  String get bidCreateWeightLabel => 'Poids du colis';

  @override
  String get bidCreateWeightLabelOptional => 'Poids du colis (optionnel)';

  @override
  String get bidCreateFreeKgHint => 'Kilo libre : choisissez votre poids';

  @override
  String get bidCreateNoCapacityAvailable => 'Aucune capacité disponible';

  @override
  String get bidCreateDisclaimerTitle => 'Disclaimer douane.';

  @override
  String get bidCreateDisclaimerBody =>
      'Pas d\'armes, drogues, liquides inflammables ou espèces. Le voyageur peut refuser au contrôle douanier.';

  @override
  String get bidCreateDisclaimerAcceptLabel => 'Je signe & j\'accepte';

  @override
  String get bidCreateCardModeSubtitle => 'Bloqué jusqu\'à la livraison';

  @override
  String get bidCreateMobileMoneySubtitle => 'Orange Money, Wave, MTN';

  @override
  String get bidCreateCashModeSubtitle => 'En main propre, à la remise';

  @override
  String get bidCreateEscrowTag => 'Séquestre';

  @override
  String get bidCreateHandToHandTag => 'En main propre';

  @override
  String get bidCreateCardModeBody =>
      'Bloqué par Yadony dès maintenant, versé au voyageur quand le destinataire confirme la livraison.';

  @override
  String get bidCreateMobileMoneyModeBody =>
      'Après l\'accord du voyageur, tu reçois une demande de paiement sur ton téléphone. Le montant est bloqué par Yadony jusqu\'à la livraison.';

  @override
  String get bidCreateCashModeBody =>
      'Tu remets la somme au voyageur le jour où tu lui confies le colis.';

  @override
  String get bidCreateRefundAssurance => 'Remboursé si le colis n\'arrive pas';

  @override
  String get bidCreateCashEscrowWarning =>
      'Paiement en espèces : pas de séquestre, vous payez le voyageur directement, sans garantie de remboursement par Yadony.';

  @override
  String get bidCreateArticlesLineLabel => 'Articles';

  @override
  String get bidCreatePromoDiscountLabel => 'Réduction code promo';

  @override
  String get bidCreateTotalLabel => 'Total';

  @override
  String get bidCreatePromoBadge => 'Promo';

  @override
  String get bidCreateServiceFeeIncludedLabel => 'Commission Yadony incluse';

  @override
  String get bidCreatePhotosVisibleHint =>
      'Visibles par le voyageur, elles rassurent sur le contenu.';

  @override
  String get bidCreatePayerPhoneLabel => 'Numéro qui paiera (facultatif)';

  @override
  String get bidCreatePayerPhoneHintWithProfile =>
      'Par défaut, ton numéro Yadony. Tu recevras la demande de paiement sur ce numéro.';

  @override
  String get bidCreatePayerPhoneHintNoProfile =>
      'Ton compte n\'a pas de numéro : indique celui qui paiera. Tu recevras la demande de paiement dessus.';

  @override
  String get bidCreateCustomItemsSectionTitle => 'Articles hors grille';

  @override
  String get bidCreateCustomItemsSectionHint =>
      'Ajoutez ce que le voyageur n\'a pas tarifé, et proposez votre prix pour chaque article.';

  @override
  String get bidCreateCustomItemsEmpty => 'Aucun article pour le moment.';

  @override
  String get bidCreateCustomItemsTotalLabel => 'Total des articles hors grille';

  @override
  String get bidCreateAddItemButton => 'Ajouter un article';

  @override
  String get bidCreateRemoveItemTooltip => 'Retirer cet article';

  @override
  String get bidCreateAddItemSheetSubtitle =>
      'Décrivez l\'article et indiquez le prix que vous proposez pour son transport.';

  @override
  String get bidCreateAddItemConfirmButton => 'Ajouter';

  @override
  String get bidCreateCustomItemLabelField => 'Article';

  @override
  String get bidCreateCustomItemLabelHint => 'Sac de riz, boubou, médicaments';

  @override
  String get bidCreateCustomItemQuantityField => 'Quantité';

  @override
  String bidCreateCustomItemPriceField(String symbol) {
    return 'Prix ($symbol)';
  }

  @override
  String get bidCreateGridSheetTitle => 'Articles disponibles';

  @override
  String get bidCreateGridSheetConfirmButton => 'Confirmer la sélection';

  @override
  String bidCreateGridItemSemanticSelected(
    String label,
    String price,
    int quantity,
  ) {
    return '$label, $price l\'unité, $quantity sélectionné';
  }

  @override
  String bidCreateGridItemSemanticUnit(String label, String price) {
    return '$label, $price l\'unité';
  }

  @override
  String bidCreateGridItemRemoveSemantic(String label) {
    return 'Retirer un $label';
  }

  @override
  String bidCreateGridItemAddSemantic(String label) {
    return 'Ajouter un $label';
  }

  @override
  String get bidCreatePriceTooLowHint =>
      'Prix bas : risque de méfiance de l\'expéditeur';

  @override
  String get bidCreatePriceTooHighHint =>
      'Prix élevé : peu de demandes attendues';

  @override
  String bidCreateMarketPriceCorridor(String corridor) {
    return 'Marché $corridor : ';
  }

  @override
  String get bidCreateMarketPriceLabel => 'Marché ';

  @override
  String get bidCreateCompetitivePriceSuffix => ' · Votre prix est compétitif.';

  @override
  String bidCreateDisclaimerSigned(String dateTime) {
    return 'Disclaimer signé le $dateTime';
  }

  @override
  String get tripPublishCashCommissionIntro =>
      'Vous ne pourrez accepter un colis en espèces que si la commission Yadony peut être prélevée ';

  @override
  String get tripPublishCashCommissionHighlight =>
      'sur votre portefeuille en priorité';

  @override
  String get tripPublishCashCommissionOutro =>
      '. À défaut, il faudra le recharger ou enregistrer une carte valide au moment d’accepter.';

  @override
  String get negotiationStageToPay => 'à payer';

  @override
  String get negotiationStageAwaitingPayment => 'attente paiement';

  @override
  String get negotiationStageDealAgreed => 'accord conclu';

  @override
  String get negotiationStageClosed => 'terminé';

  @override
  String get negotiationStageProposal => 'proposition';

  @override
  String get bidSenderFallbackName => 'Expéditeur';

  @override
  String bidTravelerTrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trajets',
      one: '$count trajet',
    );
    return '$_temp0';
  }

  @override
  String bidSenderShipments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count envois',
      one: '$count envoi',
    );
    return '$_temp0';
  }

  @override
  String bidSubmittedOn(String date) {
    return 'Soumis le $date';
  }

  @override
  String get negotiationThreadTitle => 'Discussion de prix';

  @override
  String get negotiationThreadErrorTitle => 'Discussion indisponible';

  @override
  String get negotiationThreadYouWouldReceive => 'Vous recevriez';

  @override
  String get negotiationThreadYouWouldPay => 'Vous paieriez';

  @override
  String negotiationThreadRoundLabel(int round, int maxRounds) {
    return 'Tour $round sur $maxRounds';
  }

  @override
  String get negotiationThreadParcelSectionTitle => 'Le colis';

  @override
  String get negotiationThreadExchangesTitle => 'Échanges';

  @override
  String get negotiationThreadKindProposal => 'Proposition';

  @override
  String get negotiationThreadKindCounter => 'Contre-offre';

  @override
  String get negotiationThreadKindAccepted => 'Acceptée';

  @override
  String get negotiationThreadKindRejected => 'Refusée';

  @override
  String get negotiationThreadPayHint =>
      'Prix accepté. Réglez maintenant pour réserver votre place, le montant reste bloqué jusqu\'à la livraison.';

  @override
  String get negotiationThreadPayButton => 'Payer';

  @override
  String get negotiationThreadAwaitingSenderPaymentHint =>
      'Prix accepté. En attente du paiement de l\'expéditeur.';

  @override
  String get negotiationThreadCashTravelerHint =>
      'Prix accepté. Paiement en espèces, il vous reste à régler la commission Yadony.';

  @override
  String get negotiationThreadCashSenderHint =>
      'Prix accepté. Paiement en espèces, en attente du voyageur, vous n\'avez rien à régler ici.';

  @override
  String get negotiationThreadClosedAccepted =>
      'Prix accepté. Rendez-vous sur votre colis pour la suite.';

  @override
  String get negotiationThreadClosedRejected => 'Proposition refusée.';

  @override
  String get negotiationThreadClosedExpired => 'Proposition expirée.';

  @override
  String get negotiationThreadClosedDefault => 'Négociation terminée.';

  @override
  String negotiationThreadWaitingForReply(String name) {
    return 'En attente de la réponse de $name.';
  }

  @override
  String get negotiationThreadCounterpartyFallback => 'votre interlocuteur';

  @override
  String get negotiationThreadAcceptButton => 'Accepter';

  @override
  String get negotiationThreadCounterButton => 'Contre-proposer';

  @override
  String get negotiationThreadRejectButton => 'Refuser';

  @override
  String get negotiationThreadCounterSubtitle =>
      'Indiquez le montant total que vous proposez. Votre interlocuteur pourra l\'accepter ou répondre à son tour.';

  @override
  String get negotiationThreadCounterSubmitButton => 'Envoyer ma contre-offre';

  @override
  String negotiationThreadCounterAmountLabel(String symbol) {
    return 'Montant proposé ($symbol)';
  }

  @override
  String get negotiationThreadCounterMessageLabel => 'Message (facultatif)';

  @override
  String get negotiationThreadCounterMessageHint =>
      'Expliquez votre proposition';

  @override
  String get negotiationThreadPaymentNotConfirmed =>
      'Paiement non confirmé, réessayez';

  @override
  String get negotiationThreadPaymentContextLabel =>
      'Prix négocié de votre colis';

  @override
  String get travelerProfileLoadErrorTitle => 'Erreur de chargement';

  @override
  String get travelerProfileLoadErrorDescription =>
      'Impossible de charger le détail';

  @override
  String get profileSheetMoreOptionsTooltip => 'Plus d\'options';

  @override
  String get profileSheetReviewsTitle => 'Évaluations';

  @override
  String get profileSheetNoReviewsYet => 'Aucune évaluation pour l\'instant.';

  @override
  String get profileSheetSeeMoreReviews => 'Voir plus';

  @override
  String get profileSheetProBadge => 'Compte PRO';

  @override
  String get profileSheetVerifiedBadge => 'Identité vérifiée';

  @override
  String get travelerProfileTripsLabel => 'Trajets';

  @override
  String get travelerProfileDeliveryLabel => 'Livraison';

  @override
  String get travelerProfilePhoneHiddenLabel =>
      'Numéro révélé après acceptation';

  @override
  String get travelerProfileSubscribeLabel => 'S\'abonner à ce voyageur';

  @override
  String get senderProfilePhoneHiddenLabel =>
      '📞 Numéro révélé après acceptation';

  @override
  String get senderProfilePhoneLoadingLabel =>
      'Numéro en cours de récupération…';

  @override
  String get senderProfileShipmentsLabel => 'Envois';

  @override
  String blockMenuEntryLabel(String name) {
    return 'Bloquer $name';
  }

  @override
  String blockSuccessMessage(String name) {
    return '$name a été bloqué(e)';
  }

  @override
  String blockConfirmTitle(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String get blockConfirmBody =>
      'Il·elle ne pourra plus voir tes annonces ni t\'envoyer d\'offre. Tu ne verras plus les siennes non plus. Tu pourras le·la débloquer à tout moment dans Confidentialité.';

  @override
  String get blockConfirmButton => 'Bloquer';

  @override
  String get bidTravelerRoleTag => 'VOYAGEUR';

  @override
  String get voyageurCardCallSemanticLabel => 'Appeler';

  @override
  String get voyageurCardOpenChatSemanticLabel => 'Ouvrir la discussion';
}
