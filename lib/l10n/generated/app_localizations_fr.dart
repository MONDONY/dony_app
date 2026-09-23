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
  String get authCountryGaugeLabel => 'Pays';

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
  String get authPersonalInfoContinue => 'Continuer';

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
  String get authConsentGaugeLabel => 'Confidentialité';

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
  String get authLocalCancel => 'Annuler';

  @override
  String get authLocalContinue => 'Continuer';

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
}
