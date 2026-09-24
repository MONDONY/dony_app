import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Bouton de confirmation générique
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Bouton qui ferme une boîte de dialogue
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// Ligne Réglages › Langue
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguageTitle;

  /// Choix de langue qui suit la langue du téléphone
  ///
  /// In fr, this message translates to:
  /// **'Langue du téléphone'**
  String get settingsLanguagePhone;

  /// No description provided for @errorMobileMoneyDisabledTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mobile money indisponible'**
  String get errorMobileMoneyDisabledTitle;

  /// No description provided for @errorMobileMoneyDisabledMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement mobile money n\'est pas ouvert pour le moment. Choisis un autre moyen de paiement.'**
  String get errorMobileMoneyDisabledMessage;

  /// No description provided for @errorMobileMoneyPhoneRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro manquant'**
  String get errorMobileMoneyPhoneRequiredTitle;

  /// No description provided for @errorMobileMoneyPhoneRequiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Indique le numéro mobile money à utiliser pour continuer.'**
  String get errorMobileMoneyPhoneRequiredMessage;

  /// No description provided for @errorMobileMoneyAccountUnsupportedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro non pris en charge'**
  String get errorMobileMoneyAccountUnsupportedTitle;

  /// No description provided for @errorMobileMoneyAccountUnsupportedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ton numéro n\'est pas rattaché à un opérateur mobile money compatible, ou sa devise ne correspond pas à ta zone.'**
  String get errorMobileMoneyAccountUnsupportedMessage;

  /// No description provided for @errorMobileMoneyAccountRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte de versement requis'**
  String get errorMobileMoneyAccountRequiredTitle;

  /// No description provided for @errorMobileMoneyAccountRequiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Active ton versement mobile money avant d\'accepter cette offre.'**
  String get errorMobileMoneyAccountRequiredMessage;

  /// No description provided for @errorMobileMoneyCurrencyMismatchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Devise différente'**
  String get errorMobileMoneyCurrencyMismatchTitle;

  /// No description provided for @errorMobileMoneyCurrencyMismatchMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ton compte de versement mobile money n\'est pas dans la devise de ce trajet.'**
  String get errorMobileMoneyCurrencyMismatchMessage;

  /// No description provided for @errorMobileMoneyNotAvailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mobile money non proposé'**
  String get errorMobileMoneyNotAvailableTitle;

  /// No description provided for @errorMobileMoneyNotAvailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce voyageur n\'accepte pas le paiement mobile money.'**
  String get errorMobileMoneyNotAvailableMessage;

  /// No description provided for @errorMobileMoneyPayerUnsupportedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro non pris en charge'**
  String get errorMobileMoneyPayerUnsupportedTitle;

  /// No description provided for @errorMobileMoneyPayerUnsupportedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie le numéro qui doit payer, ou essaie avec un autre numéro.'**
  String get errorMobileMoneyPayerUnsupportedMessage;

  /// No description provided for @errorMobileMoneyInvalidPhoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro non reconnu'**
  String get errorMobileMoneyInvalidPhoneTitle;

  /// No description provided for @errorMobileMoneyInvalidPhoneMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro n\'est reconnu par aucun opérateur mobile money. Vérifie-le et réessaie.'**
  String get errorMobileMoneyInvalidPhoneMessage;

  /// No description provided for @errorMobileMoneyDepositRejectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paiement refusé'**
  String get errorMobileMoneyDepositRejectedTitle;

  /// No description provided for @errorMobileMoneyDepositRejectedMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'opérateur a refusé la demande de paiement. Réessaie, éventuellement avec un autre numéro.'**
  String get errorMobileMoneyDepositRejectedMessage;

  /// No description provided for @errorMobileMoneyPaymentExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Délai dépassé'**
  String get errorMobileMoneyPaymentExpiredTitle;

  /// No description provided for @errorMobileMoneyPaymentExpiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le délai de paiement de 30 minutes est passé. Refais une offre au voyageur.'**
  String get errorMobileMoneyPaymentExpiredMessage;

  /// No description provided for @errorMobileMoneyPaymentNotPendingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paiement déjà traité'**
  String get errorMobileMoneyPaymentNotPendingTitle;

  /// No description provided for @errorMobileMoneyPaymentNotPendingMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce paiement n\'est plus en attente.'**
  String get errorMobileMoneyPaymentNotPendingMessage;

  /// No description provided for @errorMobileMoneyOperationInProgressTitle.
  ///
  /// In fr, this message translates to:
  /// **'Opération en cours'**
  String get errorMobileMoneyOperationInProgressTitle;

  /// No description provided for @errorMobileMoneyOperationInProgressMessage.
  ///
  /// In fr, this message translates to:
  /// **'Une opération mobile money est déjà en cours pour cet envoi. Patiente quelques instants.'**
  String get errorMobileMoneyOperationInProgressMessage;

  /// No description provided for @errorMobileMoneyProviderUnavailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Service indisponible'**
  String get errorMobileMoneyProviderUnavailableTitle;

  /// No description provided for @errorMobileMoneyProviderUnavailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le service mobile money ne répond pas. Réessaie dans quelques minutes.'**
  String get errorMobileMoneyProviderUnavailableMessage;

  /// No description provided for @errorInvalidPaymentMethodTitle.
  ///
  /// In fr, this message translates to:
  /// **'Moyen de paiement invalide'**
  String get errorInvalidPaymentMethodTitle;

  /// No description provided for @errorInvalidPaymentMethodMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce moyen de paiement n\'est pas reconnu. Mets l\'application à jour.'**
  String get errorInvalidPaymentMethodMessage;

  /// No description provided for @errorRequestBudgetOutOfBoundsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Budget trop élevé'**
  String get errorRequestBudgetOutOfBoundsTitle;

  /// No description provided for @errorRequestBudgetOutOfBoundsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce budget dépasse le plafond autorisé pour cette devise. Réduis le montant puis réessaie.'**
  String get errorRequestBudgetOutOfBoundsMessage;

  /// No description provided for @errorRequestAlreadyAcceptedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce colis est parti'**
  String get errorRequestAlreadyAcceptedTitle;

  /// No description provided for @errorRequestAlreadyAcceptedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Un autre voyageur a réglé la commission avant toi, ce colis ne peut plus te revenir.'**
  String get errorRequestAlreadyAcceptedMessage;

  /// No description provided for @errorThreadNotAwaitingCommissionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce colis est parti'**
  String get errorThreadNotAwaitingCommissionTitle;

  /// No description provided for @errorThreadNotAwaitingCommissionMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette offre n\'attend plus de règlement, elle a été conclue autrement ou le délai est écoulé.'**
  String get errorThreadNotAwaitingCommissionMessage;

  /// No description provided for @errorUnauthorizedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée'**
  String get errorUnauthorizedTitle;

  /// No description provided for @errorUnauthorizedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Reconnecte-toi pour continuer.'**
  String get errorUnauthorizedMessage;

  /// No description provided for @errorReauthRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion requise'**
  String get errorReauthRequiredTitle;

  /// No description provided for @errorReauthRequiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Pour ta sécurité, identifie-toi à nouveau pour cette action.'**
  String get errorReauthRequiredMessage;

  /// No description provided for @errorForbiddenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Action non autorisée'**
  String get errorForbiddenTitle;

  /// No description provided for @errorForbiddenMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'as pas les droits nécessaires pour cette action.'**
  String get errorForbiddenMessage;

  /// No description provided for @errorAccessDeniedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé'**
  String get errorAccessDeniedTitle;

  /// No description provided for @errorAccessDeniedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu ne peux pas accéder à cette ressource.'**
  String get errorAccessDeniedMessage;

  /// No description provided for @errorAccountBannedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte suspendu'**
  String get errorAccountBannedTitle;

  /// No description provided for @errorAccountBannedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ton compte a été suspendu. Contacte le support pour plus d\'informations.'**
  String get errorAccountBannedMessage;

  /// No description provided for @errorAuthTokenUnavailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Authentification impossible'**
  String get errorAuthTokenUnavailableTitle;

  /// No description provided for @errorAuthTokenUnavailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de vérifier ton identité. Réessaie dans un instant.'**
  String get errorAuthTokenUnavailableMessage;

  /// No description provided for @errorAuthGenericErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible'**
  String get errorAuthGenericErrorTitle;

  /// No description provided for @errorAuthGenericErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue pendant la connexion. Réessaie.'**
  String get errorAuthGenericErrorMessage;

  /// No description provided for @errorPhoneOtpInvalidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect'**
  String get errorPhoneOtpInvalidTitle;

  /// No description provided for @errorPhoneOtpInvalidMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le code de vérification saisi est incorrect.'**
  String get errorPhoneOtpInvalidMessage;

  /// No description provided for @errorPhoneOtpExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code expiré'**
  String get errorPhoneOtpExpiredTitle;

  /// No description provided for @errorPhoneOtpExpiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a expiré. Demande un nouveau code.'**
  String get errorPhoneOtpExpiredMessage;

  /// No description provided for @errorPhoneOtpAttemptsExceededTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives'**
  String get errorPhoneOtpAttemptsExceededTitle;

  /// No description provided for @errorPhoneOtpAttemptsExceededMessage.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessaie dans quelques minutes.'**
  String get errorPhoneOtpAttemptsExceededMessage;

  /// No description provided for @errorPhoneOtpRateLimitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes'**
  String get errorPhoneOtpRateLimitTitle;

  /// No description provided for @errorPhoneOtpRateLimitMessage.
  ///
  /// In fr, this message translates to:
  /// **'Trop de codes envoyés. Réessaie dans quelques minutes.'**
  String get errorPhoneOtpRateLimitMessage;

  /// No description provided for @errorPhoneAlreadySetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro déjà défini'**
  String get errorPhoneAlreadySetTitle;

  /// No description provided for @errorPhoneAlreadySetMessage.
  ///
  /// In fr, this message translates to:
  /// **'Un numéro est déjà associé à ce compte.'**
  String get errorPhoneAlreadySetMessage;

  /// No description provided for @errorPhoneAlreadyExistsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro déjà utilisé'**
  String get errorPhoneAlreadyExistsTitle;

  /// No description provided for @errorPhoneAlreadyExistsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro est déjà associé à un autre compte.'**
  String get errorPhoneAlreadyExistsMessage;

  /// No description provided for @errorSmsOtpDisabledTitle.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get errorSmsOtpDisabledTitle;

  /// No description provided for @errorSmsOtpDisabledMessage.
  ///
  /// In fr, this message translates to:
  /// **'La connexion par téléphone n\'est pas encore disponible.'**
  String get errorSmsOtpDisabledMessage;

  /// No description provided for @errorInvalidPhoneNumberTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro injoignable'**
  String get errorInvalidPhoneNumberTitle;

  /// No description provided for @errorInvalidPhoneNumberMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro ne peut pas recevoir de SMS. Vérifie l\'indicatif et le nombre de chiffres, puis réessaie.'**
  String get errorInvalidPhoneNumberMessage;

  /// No description provided for @errorAnnouncementNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trajet introuvable'**
  String get errorAnnouncementNotFoundTitle;

  /// No description provided for @errorAnnouncementNotFoundMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet n\'existe plus ou a été retiré.'**
  String get errorAnnouncementNotFoundMessage;

  /// No description provided for @errorCurrencyMismatchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Devise différente'**
  String get errorCurrencyMismatchTitle;

  /// No description provided for @errorCurrencyMismatchMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet n\'est plus disponible dans ta devise. Change de pays dans Réglages pour le voir.'**
  String get errorCurrencyMismatchMessage;

  /// No description provided for @errorCountryRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pays manquant'**
  String get errorCountryRequiredTitle;

  /// No description provided for @errorCountryRequiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Renseigne ton pays dans Réglages, rubrique Préférences, avant de créer ton compte de paiement. Il détermine ta devise et ne pourra plus être modifié ensuite.'**
  String get errorCountryRequiredMessage;

  /// No description provided for @errorCountryLockedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pays verrouillé'**
  String get errorCountryLockedTitle;

  /// No description provided for @errorCountryLockedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de changer de pays : un envoi est en cours, ton portefeuille n\'est pas vide, ou ton compte de paiement est déjà créé.'**
  String get errorCountryLockedMessage;

  /// No description provided for @errorCountryUnsupportedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pays non desservi'**
  String get errorCountryUnsupportedTitle;

  /// No description provided for @errorCountryUnsupportedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Yadony ne dessert pas encore ce pays. Choisis-en un autre.'**
  String get errorCountryUnsupportedMessage;

  /// No description provided for @errorDeletionImpossibleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible'**
  String get errorDeletionImpossibleTitle;

  /// No description provided for @errorDeletionImpossibleMessage.
  ///
  /// In fr, this message translates to:
  /// **'Un colis est déjà accepté sur ce trajet. Annule le voyage à la place : l\'expéditeur sera remboursé.'**
  String get errorDeletionImpossibleMessage;

  /// No description provided for @errorProLimitReachedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Limite mensuelle atteinte'**
  String get errorProLimitReachedTitle;

  /// No description provided for @errorProLimitReachedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as atteint ta limite d\'annonces ce mois-ci. Passe en PRO pour publier sans limite.'**
  String get errorProLimitReachedMessage;

  /// No description provided for @errorDraftLimitReachedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Limite de brouillons atteinte'**
  String get errorDraftLimitReachedTitle;

  /// No description provided for @errorDraftLimitReachedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Passe en PRO pour créer davantage de brouillons.'**
  String get errorDraftLimitReachedMessage;

  /// No description provided for @errorNotADraftTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déjà publié'**
  String get errorNotADraftTitle;

  /// No description provided for @errorNotADraftMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet n\'est pas un brouillon.'**
  String get errorNotADraftMessage;

  /// No description provided for @errorPublishingSuspendedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Publication suspendue'**
  String get errorPublishingSuspendedTitle;

  /// No description provided for @errorPublishingSuspendedMessage.
  ///
  /// In fr, this message translates to:
  /// **'La publication est suspendue sur ton compte. Contacte le support.'**
  String get errorPublishingSuspendedMessage;

  /// No description provided for @errorKycNotVerifiedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Identité non vérifiée'**
  String get errorKycNotVerifiedTitle;

  /// No description provided for @errorKycNotVerifiedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie ton identité avant de publier un trajet.'**
  String get errorKycNotVerifiedMessage;

  /// No description provided for @errorDepartureDatePassedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Date de départ passée'**
  String get errorDepartureDatePassedTitle;

  /// No description provided for @errorDepartureDatePassedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Modifie la date de départ avant de publier ce trajet.'**
  String get errorDepartureDatePassedMessage;

  /// No description provided for @errorBidNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande introuvable'**
  String get errorBidNotFoundTitle;

  /// No description provided for @errorBidNotFoundMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande n\'existe plus.'**
  String get errorBidNotFoundMessage;

  /// No description provided for @errorContactKycRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil vérifié requis'**
  String get errorContactKycRequiredTitle;

  /// No description provided for @errorContactKycRequiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce voyageur ne reçoit que des profils vérifiés. Vérifie ton identité pour lui envoyer une demande.'**
  String get errorContactKycRequiredMessage;

  /// No description provided for @errorBidNotAcceptedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande non acceptée'**
  String get errorBidNotAcceptedTitle;

  /// No description provided for @errorBidNotAcceptedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande doit être acceptée par le voyageur avant cette étape.'**
  String get errorBidNotAcceptedMessage;

  /// No description provided for @errorBidNotDeliveredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Colis non livré'**
  String get errorBidNotDeliveredTitle;

  /// No description provided for @errorBidNotDeliveredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette action nécessite que le colis ait été livré.'**
  String get errorBidNotDeliveredMessage;

  /// No description provided for @errorInvalidBidStatusTitle.
  ///
  /// In fr, this message translates to:
  /// **'État du colis invalide'**
  String get errorInvalidBidStatusTitle;

  /// No description provided for @errorInvalidBidStatusMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le statut actuel du colis ne permet pas cette action.'**
  String get errorInvalidBidStatusMessage;

  /// No description provided for @errorUseConfirmDeliveryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirme la livraison'**
  String get errorUseConfirmDeliveryTitle;

  /// No description provided for @errorUseConfirmDeliveryMessage.
  ///
  /// In fr, this message translates to:
  /// **'Pour finaliser, utilise l\'écran de confirmation de livraison du destinataire.'**
  String get errorUseConfirmDeliveryMessage;

  /// No description provided for @errorQrNotReadyTitle.
  ///
  /// In fr, this message translates to:
  /// **'QR pas encore disponible'**
  String get errorQrNotReadyTitle;

  /// No description provided for @errorQrNotReadyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le QR sera disponible une fois que l\'expéditeur aura finalisé le paiement.'**
  String get errorQrNotReadyMessage;

  /// No description provided for @errorDepartAlreadyScannedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Départ déjà scanné'**
  String get errorDepartAlreadyScannedTitle;

  /// No description provided for @errorDepartAlreadyScannedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le départ de ce colis est déjà enregistré. Tu peux passer à l\'étape suivante.'**
  String get errorDepartAlreadyScannedMessage;

  /// No description provided for @errorCodeNotGeneratedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code non généré'**
  String get errorCodeNotGeneratedTitle;

  /// No description provided for @errorCodeNotGeneratedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun code de confirmation n\'a encore été généré pour cette livraison.'**
  String get errorCodeNotGeneratedMessage;

  /// No description provided for @errorCodeExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code expiré'**
  String get errorCodeExpiredTitle;

  /// No description provided for @errorCodeExpiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a expiré. Demande à l\'expéditeur d\'en générer un nouveau.'**
  String get errorCodeExpiredMessage;

  /// No description provided for @errorCodeIncorrectTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect'**
  String get errorCodeIncorrectTitle;

  /// No description provided for @errorCodeIncorrectMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le code saisi est incorrect. Vérifie auprès de l\'expéditeur.'**
  String get errorCodeIncorrectMessage;

  /// No description provided for @errorTooManyAttemptsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives'**
  String get errorTooManyAttemptsTitle;

  /// No description provided for @errorTooManyAttemptsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as fait trop d\'essais. Patiente quelques minutes avant de réessayer.'**
  String get errorTooManyAttemptsMessage;

  /// No description provided for @errorTooManyRefreshesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Limite atteinte'**
  String get errorTooManyRefreshesTitle;

  /// No description provided for @errorTooManyRefreshesMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà rafraîchi le code plusieurs fois. Attends avant de regénérer.'**
  String get errorTooManyRefreshesMessage;

  /// No description provided for @errorInvalidTimestampTitle.
  ///
  /// In fr, this message translates to:
  /// **'Horodatage invalide'**
  String get errorInvalidTimestampTitle;

  /// No description provided for @errorInvalidTimestampMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'horodatage de la lecture est incohérent. Réessaie une fois en ligne.'**
  String get errorInvalidTimestampMessage;

  /// No description provided for @errorInvalidWindowTitle.
  ///
  /// In fr, this message translates to:
  /// **'Hors créneau'**
  String get errorInvalidWindowTitle;

  /// No description provided for @errorInvalidWindowMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette action n\'est pas autorisée en dehors du créneau prévu.'**
  String get errorInvalidWindowMessage;

  /// No description provided for @errorAlreadyCancelledTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déjà annulé'**
  String get errorAlreadyCancelledTitle;

  /// No description provided for @errorAlreadyCancelledMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément a déjà été annulé.'**
  String get errorAlreadyCancelledMessage;

  /// No description provided for @errorActiveTransactionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible'**
  String get errorActiveTransactionsTitle;

  /// No description provided for @errorActiveTransactionsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Des transactions sont en cours. Termine-les ou annule-les avant de continuer.'**
  String get errorActiveTransactionsMessage;

  /// No description provided for @errorInvalidStatusTitle.
  ///
  /// In fr, this message translates to:
  /// **'État invalide'**
  String get errorInvalidStatusTitle;

  /// No description provided for @errorInvalidStatusMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'état actuel ne permet pas cette action.'**
  String get errorInvalidStatusMessage;

  /// No description provided for @errorNotPendingDeletionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suppression non demandée'**
  String get errorNotPendingDeletionTitle;

  /// No description provided for @errorNotPendingDeletionMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande de suppression de compte en attente.'**
  String get errorNotPendingDeletionMessage;

  /// No description provided for @errorAlreadyRatedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déjà noté'**
  String get errorAlreadyRatedTitle;

  /// No description provided for @errorAlreadyRatedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà laissé une note pour cette livraison.'**
  String get errorAlreadyRatedMessage;

  /// No description provided for @errorRatingWindowExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Délai dépassé'**
  String get errorRatingWindowExpiredTitle;

  /// No description provided for @errorRatingWindowExpiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'La période pour noter cette livraison est expirée.'**
  String get errorRatingWindowExpiredMessage;

  /// No description provided for @errorNegotiationCommissionChargeFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accord non validé'**
  String get errorNegotiationCommissionChargeFailedTitle;

  /// No description provided for @errorNegotiationCommissionChargeFailedMessage.
  ///
  /// In fr, this message translates to:
  /// **'La commission n\'a pas pu être prélevée au voyageur. L\'accord n\'est pas validé. Il vient d\'être invité à recharger son portefeuille, réessaie ensuite.'**
  String get errorNegotiationCommissionChargeFailedMessage;

  /// No description provided for @errorNegotiationNotAwaitingDepositTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun dépôt en cours'**
  String get errorNegotiationNotAwaitingDepositTitle;

  /// No description provided for @errorNegotiationNotAwaitingDepositMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce fil n\'attend pas de paiement mobile money.'**
  String get errorNegotiationNotAwaitingDepositMessage;

  /// No description provided for @errorNegotiationDepositInFlightTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paiement en cours de validation'**
  String get errorNegotiationDepositInFlightTitle;

  /// No description provided for @errorNegotiationDepositInFlightMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ton opérateur traite encore le paiement, patiente quelques instants.'**
  String get errorNegotiationDepositInFlightMessage;

  /// No description provided for @errorNegotiationTravelerCannotReceiveMobileMoneyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mobile money indisponible'**
  String get errorNegotiationTravelerCannotReceiveMobileMoneyTitle;

  /// No description provided for @errorNegotiationTravelerCannotReceiveMobileMoneyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur ne peut pas recevoir de versement mobile money dans cette devise. Choisis un autre moyen de paiement.'**
  String get errorNegotiationTravelerCannotReceiveMobileMoneyMessage;

  /// No description provided for @errorBidNotNegotiatedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien à payer ici'**
  String get errorBidNotNegotiatedTitle;

  /// No description provided for @errorBidNotNegotiatedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce colis n\'est pas issu d\'une discussion de prix, il n\'y a pas de paiement à lancer depuis cet écran.'**
  String get errorBidNotNegotiatedMessage;

  /// No description provided for @errorBidNotAwaitingPaymentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accord non payable'**
  String get errorBidNotAwaitingPaymentTitle;

  /// No description provided for @errorBidNotAwaitingPaymentMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette discussion n\'attend pas de paiement par carte. Rouvrez-la pour voir où elle en est.'**
  String get errorBidNotAwaitingPaymentMessage;

  /// No description provided for @errorBidAlreadyPaidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déjà payé'**
  String get errorBidAlreadyPaidTitle;

  /// No description provided for @errorBidAlreadyPaidMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce colis est déjà payé. Actualisez pour voir son état à jour.'**
  String get errorBidAlreadyPaidMessage;

  /// No description provided for @errorPaymentAlreadyCompletedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déjà payé'**
  String get errorPaymentAlreadyCompletedTitle;

  /// No description provided for @errorPaymentAlreadyCompletedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce colis est déjà payé. Retrouvez-le dans vos envois pour suivre la suite.'**
  String get errorPaymentAlreadyCompletedMessage;

  /// No description provided for @errorTravelerStripeInvalidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Voyageur non configuré'**
  String get errorTravelerStripeInvalidTitle;

  /// No description provided for @errorTravelerStripeInvalidMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur n\'a pas terminé la configuration de ses paiements. Le paiement par carte est impossible pour l\'instant, contactez-le depuis la discussion.'**
  String get errorTravelerStripeInvalidMessage;

  /// No description provided for @errorPaymentMethodTravelerInsufficientFundsCashTitle.
  ///
  /// In fr, this message translates to:
  /// **'Solde insuffisant'**
  String get errorPaymentMethodTravelerInsufficientFundsCashTitle;

  /// No description provided for @errorPaymentMethodTravelerInsufficientFundsCashMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ton portefeuille n\'a pas assez de fonds pour payer la commission Yadony en espèces. Recharge-le ou ajoute une carte.'**
  String get errorPaymentMethodTravelerInsufficientFundsCashMessage;

  /// No description provided for @errorPaymentMethodNoCommissionCardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Carte requise'**
  String get errorPaymentMethodNoCommissionCardTitle;

  /// No description provided for @errorPaymentMethodNoCommissionCardMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute d\'abord une carte de commission pour payer en espèces sans solde suffisant.'**
  String get errorPaymentMethodNoCommissionCardMessage;

  /// No description provided for @errorPaymentMethodNotInAvailableSetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Moyen de paiement non proposé'**
  String get errorPaymentMethodNotInAvailableSetTitle;

  /// No description provided for @errorPaymentMethodNotInAvailableSetMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce moyen de paiement n\'est pas proposé pour cette offre. Choisis-en un autre.'**
  String get errorPaymentMethodNotInAvailableSetMessage;

  /// No description provided for @errorPaymentMethodMobileMoneyCapabilityRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mobile money indisponible'**
  String get errorPaymentMethodMobileMoneyCapabilityRequiredTitle;

  /// No description provided for @errorPaymentMethodMobileMoneyCapabilityRequiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur n\'a pas de compte de versement mobile money dans cette devise.'**
  String get errorPaymentMethodMobileMoneyCapabilityRequiredMessage;

  /// No description provided for @errorWalletTopupStripeErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rechargement indisponible'**
  String get errorWalletTopupStripeErrorTitle;

  /// No description provided for @errorWalletTopupStripeErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le rechargement n\'a pas pu être préparé. Réessaie dans un instant.'**
  String get errorWalletTopupStripeErrorMessage;

  /// No description provided for @errorTopupAmountOutOfRangeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Montant hors limites'**
  String get errorTopupAmountOutOfRangeTitle;

  /// No description provided for @errorTopupAmountOutOfRangeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce montant ne respecte pas les limites de recharge autorisées. Ajuste le montant puis réessaie.'**
  String get errorTopupAmountOutOfRangeMessage;

  /// No description provided for @errorTopupAlreadyPendingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recharge déjà en cours'**
  String get errorTopupAlreadyPendingTitle;

  /// No description provided for @errorTopupAlreadyPendingMessage.
  ///
  /// In fr, this message translates to:
  /// **'Une recharge est déjà en cours. Valide-la sur ton téléphone, ou attends qu\'elle expire avant d\'en lancer une nouvelle.'**
  String get errorTopupAlreadyPendingMessage;

  /// No description provided for @errorTopupPhoneRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro manquant'**
  String get errorTopupPhoneRequiredTitle;

  /// No description provided for @errorTopupPhoneRequiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Indique le numéro qui va payer la recharge.'**
  String get errorTopupPhoneRequiredMessage;

  /// No description provided for @errorTopupPhoneUnsupportedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro non pris en charge'**
  String get errorTopupPhoneUnsupportedTitle;

  /// No description provided for @errorTopupPhoneUnsupportedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro n\'est pas exploitable pour une recharge mobile money. Vérifie-le ou essaie avec un autre numéro.'**
  String get errorTopupPhoneUnsupportedMessage;

  /// No description provided for @errorTopupNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recharge introuvable'**
  String get errorTopupNotFoundTitle;

  /// No description provided for @errorTopupNotFoundMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette recharge n\'existe plus ou son lien a expiré.'**
  String get errorTopupNotFoundMessage;

  /// No description provided for @errorPaymentMethodUnavailableForCurrencyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Moyen de paiement indisponible'**
  String get errorPaymentMethodUnavailableForCurrencyTitle;

  /// No description provided for @errorPaymentMethodUnavailableForCurrencyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce moyen de paiement n\'est pas proposé dans la devise de ce trajet.'**
  String get errorPaymentMethodUnavailableForCurrencyMessage;

  /// No description provided for @errorUnsupportedCurrencyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Devise non prise en charge'**
  String get errorUnsupportedCurrencyTitle;

  /// No description provided for @errorUnsupportedCurrencyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette devise n\'est pas encore disponible. Vérifie la devise de ton compte dans les réglages.'**
  String get errorUnsupportedCurrencyMessage;

  /// No description provided for @errorStripeAccountRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte Stripe à créer'**
  String get errorStripeAccountRequiredTitle;

  /// No description provided for @errorStripeAccountRequiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ton compte de paiement n\'a pas encore été créé. Retape sur le bouton pour lancer l\'activation.'**
  String get errorStripeAccountRequiredMessage;

  /// No description provided for @errorStripeAccountInvalidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte de paiement invalide'**
  String get errorStripeAccountInvalidTitle;

  /// No description provided for @errorStripeAccountInvalidMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ton compte de paiement n\'est plus valide. Retape sur le bouton pour en créer un nouveau.'**
  String get errorStripeAccountInvalidMessage;

  /// No description provided for @errorStripeErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paiement refusé'**
  String get errorStripeErrorTitle;

  /// No description provided for @errorStripeErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement n\'a pas pu être traité. Vérifie ta carte ou réessaie dans un instant.'**
  String get errorStripeErrorMessage;

  /// No description provided for @errorGoogleTimeoutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Service indisponible'**
  String get errorGoogleTimeoutTitle;

  /// No description provided for @errorGoogleTimeoutMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le service de localisation est lent à répondre. Réessaie dans quelques secondes.'**
  String get errorGoogleTimeoutMessage;

  /// No description provided for @errorOtpInvalidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code invalide'**
  String get errorOtpInvalidTitle;

  /// No description provided for @errorOtpInvalidMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le code saisi est incorrect ou a déjà été utilisé. Vérifie le code reçu par email.'**
  String get errorOtpInvalidMessage;

  /// No description provided for @errorOtpExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code expiré'**
  String get errorOtpExpiredTitle;

  /// No description provided for @errorOtpExpiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a expiré. Reviens en arrière et demande un nouveau code.'**
  String get errorOtpExpiredMessage;

  /// No description provided for @errorOtpAttemptsExceededTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives'**
  String get errorOtpAttemptsExceededTitle;

  /// No description provided for @errorOtpAttemptsExceededMessage.
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais incorrects. Patiente quelques minutes, un nouveau code ne débloquera pas la saisie.'**
  String get errorOtpAttemptsExceededMessage;

  /// No description provided for @errorEmailAlreadyExistsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Email déjà utilisé'**
  String get errorEmailAlreadyExistsTitle;

  /// No description provided for @errorEmailAlreadyExistsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse email est déjà associée à un autre compte.'**
  String get errorEmailAlreadyExistsMessage;

  /// No description provided for @errorEmailAlreadySetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Adresse déjà définie'**
  String get errorEmailAlreadySetTitle;

  /// No description provided for @errorEmailAlreadySetMessage.
  ///
  /// In fr, this message translates to:
  /// **'Une adresse est déjà associée à ce compte et ne peut pas être remplacée.'**
  String get errorEmailAlreadySetMessage;

  /// No description provided for @errorRateLimitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trop de codes demandés'**
  String get errorRateLimitTitle;

  /// No description provided for @errorRateLimitMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as demandé plusieurs codes coup sur coup. Attends quelques minutes avant d\'en redemander un.'**
  String get errorRateLimitMessage;

  /// No description provided for @errorEmailServiceErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoi impossible'**
  String get errorEmailServiceErrorTitle;

  /// No description provided for @errorEmailServiceErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'email n\'a pas pu être envoyé. Vérifie l\'adresse saisie et réessaie.'**
  String get errorEmailServiceErrorMessage;

  /// No description provided for @errorFirebaseErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible'**
  String get errorFirebaseErrorTitle;

  /// No description provided for @errorFirebaseErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'La connexion n\'a pas pu aboutir. Réessaie dans un instant.'**
  String get errorFirebaseErrorMessage;

  /// No description provided for @errorPromoNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code promo introuvable'**
  String get errorPromoNotFoundTitle;

  /// No description provided for @errorPromoNotFoundMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce code promo n\'existe pas. Vérifie la saisie et réessaie.'**
  String get errorPromoNotFoundMessage;

  /// No description provided for @errorPromoExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code promo expiré'**
  String get errorPromoExpiredTitle;

  /// No description provided for @errorPromoExpiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce code promo n\'est plus valide (expiré ou pas encore actif).'**
  String get errorPromoExpiredMessage;

  /// No description provided for @errorPromoLimitReachedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code promo épuisé'**
  String get errorPromoLimitReachedTitle;

  /// No description provided for @errorPromoLimitReachedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce code promo a atteint sa limite d\'utilisation (globale ou par utilisateur).'**
  String get errorPromoLimitReachedMessage;

  /// No description provided for @errorPromoNotEligibleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code promo non applicable'**
  String get errorPromoNotEligibleTitle;

  /// No description provided for @errorPromoNotEligibleMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce code promo n\'est pas disponible pour ton profil.'**
  String get errorPromoNotEligibleMessage;

  /// No description provided for @errorReferralCodeNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code introuvable'**
  String get errorReferralCodeNotFoundTitle;

  /// No description provided for @errorReferralCodeNotFoundMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce code de parrainage n\'existe pas. Vérifie la saisie et réessaie.'**
  String get errorReferralCodeNotFoundMessage;

  /// No description provided for @errorSelfReferralTitle.
  ///
  /// In fr, this message translates to:
  /// **'Auto-parrainage interdit'**
  String get errorSelfReferralTitle;

  /// No description provided for @errorSelfReferralMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu ne peux pas utiliser ton propre code de parrainage.'**
  String get errorSelfReferralMessage;

  /// No description provided for @errorAlreadyReferredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code déjà utilisé'**
  String get errorAlreadyReferredTitle;

  /// No description provided for @errorAlreadyReferredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà utilisé un code de parrainage.'**
  String get errorAlreadyReferredMessage;

  /// No description provided for @errorUserNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur introuvable'**
  String get errorUserNotFoundTitle;

  /// No description provided for @errorUserNotFoundMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte utilisateur n\'existe plus.'**
  String get errorUserNotFoundMessage;

  /// No description provided for @errorOfflineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion'**
  String get errorOfflineTitle;

  /// No description provided for @errorOfflineMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie ta connexion Internet puis réessaie. Tes lectures hors-ligne seront synchronisées à la reconnexion.'**
  String get errorOfflineMessage;

  /// No description provided for @errorTimeoutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur met du temps'**
  String get errorTimeoutTitle;

  /// No description provided for @errorTimeoutMessage.
  ///
  /// In fr, this message translates to:
  /// **'La requête a pris trop de temps. Réessaie dans quelques secondes.'**
  String get errorTimeoutMessage;

  /// No description provided for @errorRateLimitedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trop de requêtes'**
  String get errorRateLimitedTitle;

  /// No description provided for @errorRateLimitedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as fait trop d\'appels en peu de temps. Patiente un instant avant de réessayer.'**
  String get errorRateLimitedMessage;

  /// No description provided for @errorServerErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Erreur serveur'**
  String get errorServerErrorTitle;

  /// No description provided for @errorServerErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Quelque chose s\'est mal passé de notre côté. On regarde ça, réessaie dans un instant.'**
  String get errorServerErrorMessage;

  /// No description provided for @errorCancelledTitle.
  ///
  /// In fr, this message translates to:
  /// **'Action annulée'**
  String get errorCancelledTitle;

  /// No description provided for @errorCancelledMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'action a été annulée.'**
  String get errorCancelledMessage;

  /// No description provided for @errorNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Introuvable'**
  String get errorNotFoundTitle;

  /// No description provided for @errorNotFoundMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette ressource est introuvable ou a été supprimée.'**
  String get errorNotFoundMessage;

  /// No description provided for @errorValidationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Données invalides'**
  String get errorValidationTitle;

  /// No description provided for @errorValidationMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie les informations saisies puis réessaie.'**
  String get errorValidationMessage;

  /// No description provided for @errorConflictTitle.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible'**
  String get errorConflictTitle;

  /// No description provided for @errorConflictMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'état actuel ne permet pas cette action.'**
  String get errorConflictMessage;

  /// No description provided for @errorStorageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Stockage indisponible'**
  String get errorStorageTitle;

  /// No description provided for @errorStorageMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'accéder au stockage local. Redémarre l\'application.'**
  String get errorStorageMessage;

  /// No description provided for @errorNetworkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Erreur réseau'**
  String get errorNetworkTitle;

  /// No description provided for @errorNetworkMessage.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Vérifie ta connexion et réessaie.'**
  String get errorNetworkMessage;

  /// No description provided for @errorGenericTitle.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errorGenericTitle;

  /// No description provided for @errorGenericMessage.
  ///
  /// In fr, this message translates to:
  /// **'Réessaie dans un instant. Si le problème persiste, contacte le support.'**
  String get errorGenericMessage;

  /// No description provided for @networkFallbackSessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée'**
  String get networkFallbackSessionExpired;

  /// No description provided for @networkFallbackAccessDenied.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé'**
  String get networkFallbackAccessDenied;

  /// No description provided for @networkFallbackNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Ressource introuvable'**
  String get networkFallbackNotFound;

  /// No description provided for @networkFallbackConflict.
  ///
  /// In fr, this message translates to:
  /// **'Conflit'**
  String get networkFallbackConflict;

  /// No description provided for @networkFallbackInvalidData.
  ///
  /// In fr, this message translates to:
  /// **'Données invalides'**
  String get networkFallbackInvalidData;

  /// No description provided for @networkFallbackInvalidRequest.
  ///
  /// In fr, this message translates to:
  /// **'Requête invalide'**
  String get networkFallbackInvalidRequest;

  /// No description provided for @networkFallbackTooManyAttempts.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives'**
  String get networkFallbackTooManyAttempts;

  /// No description provided for @networkFallbackServerError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur serveur'**
  String get networkFallbackServerError;

  /// No description provided for @networkFallbackNetworkError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur réseau'**
  String get networkFallbackNetworkError;

  /// No description provided for @countryNameDe.
  ///
  /// In fr, this message translates to:
  /// **'Allemagne'**
  String get countryNameDe;

  /// No description provided for @countryNameAt.
  ///
  /// In fr, this message translates to:
  /// **'Autriche'**
  String get countryNameAt;

  /// No description provided for @countryNameBe.
  ///
  /// In fr, this message translates to:
  /// **'Belgique'**
  String get countryNameBe;

  /// No description provided for @countryNameCy.
  ///
  /// In fr, this message translates to:
  /// **'Chypre'**
  String get countryNameCy;

  /// No description provided for @countryNameHr.
  ///
  /// In fr, this message translates to:
  /// **'Croatie'**
  String get countryNameHr;

  /// No description provided for @countryNameEs.
  ///
  /// In fr, this message translates to:
  /// **'Espagne'**
  String get countryNameEs;

  /// No description provided for @countryNameEe.
  ///
  /// In fr, this message translates to:
  /// **'Estonie'**
  String get countryNameEe;

  /// No description provided for @countryNameFi.
  ///
  /// In fr, this message translates to:
  /// **'Finlande'**
  String get countryNameFi;

  /// No description provided for @countryNameFr.
  ///
  /// In fr, this message translates to:
  /// **'France'**
  String get countryNameFr;

  /// No description provided for @countryNameGr.
  ///
  /// In fr, this message translates to:
  /// **'Grèce'**
  String get countryNameGr;

  /// No description provided for @countryNameIe.
  ///
  /// In fr, this message translates to:
  /// **'Irlande'**
  String get countryNameIe;

  /// No description provided for @countryNameIt.
  ///
  /// In fr, this message translates to:
  /// **'Italie'**
  String get countryNameIt;

  /// No description provided for @countryNameLv.
  ///
  /// In fr, this message translates to:
  /// **'Lettonie'**
  String get countryNameLv;

  /// No description provided for @countryNameLt.
  ///
  /// In fr, this message translates to:
  /// **'Lituanie'**
  String get countryNameLt;

  /// No description provided for @countryNameLu.
  ///
  /// In fr, this message translates to:
  /// **'Luxembourg'**
  String get countryNameLu;

  /// No description provided for @countryNameMt.
  ///
  /// In fr, this message translates to:
  /// **'Malte'**
  String get countryNameMt;

  /// No description provided for @countryNameNl.
  ///
  /// In fr, this message translates to:
  /// **'Pays-Bas'**
  String get countryNameNl;

  /// No description provided for @countryNamePt.
  ///
  /// In fr, this message translates to:
  /// **'Portugal'**
  String get countryNamePt;

  /// No description provided for @countryNameGb.
  ///
  /// In fr, this message translates to:
  /// **'Royaume-Uni'**
  String get countryNameGb;

  /// No description provided for @countryNameSk.
  ///
  /// In fr, this message translates to:
  /// **'Slovaquie'**
  String get countryNameSk;

  /// No description provided for @countryNameSi.
  ///
  /// In fr, this message translates to:
  /// **'Slovénie'**
  String get countryNameSi;

  /// No description provided for @countryNameCh.
  ///
  /// In fr, this message translates to:
  /// **'Suisse'**
  String get countryNameCh;

  /// No description provided for @countryNameCa.
  ///
  /// In fr, this message translates to:
  /// **'Canada'**
  String get countryNameCa;

  /// No description provided for @countryNameUs.
  ///
  /// In fr, this message translates to:
  /// **'États-Unis'**
  String get countryNameUs;

  /// No description provided for @countryNameBj.
  ///
  /// In fr, this message translates to:
  /// **'Bénin'**
  String get countryNameBj;

  /// No description provided for @countryNameBf.
  ///
  /// In fr, this message translates to:
  /// **'Burkina Faso'**
  String get countryNameBf;

  /// No description provided for @countryNameCi.
  ///
  /// In fr, this message translates to:
  /// **'Côte d\'Ivoire'**
  String get countryNameCi;

  /// No description provided for @countryNameGw.
  ///
  /// In fr, this message translates to:
  /// **'Guinée-Bissau'**
  String get countryNameGw;

  /// No description provided for @countryNameMl.
  ///
  /// In fr, this message translates to:
  /// **'Mali'**
  String get countryNameMl;

  /// No description provided for @countryNameNe.
  ///
  /// In fr, this message translates to:
  /// **'Niger'**
  String get countryNameNe;

  /// No description provided for @countryNameSn.
  ///
  /// In fr, this message translates to:
  /// **'Sénégal'**
  String get countryNameSn;

  /// No description provided for @countryNameTg.
  ///
  /// In fr, this message translates to:
  /// **'Togo'**
  String get countryNameTg;

  /// No description provided for @countryNameCm.
  ///
  /// In fr, this message translates to:
  /// **'Cameroun'**
  String get countryNameCm;

  /// No description provided for @countryNameCf.
  ///
  /// In fr, this message translates to:
  /// **'Centrafrique'**
  String get countryNameCf;

  /// No description provided for @countryNameCg.
  ///
  /// In fr, this message translates to:
  /// **'Congo'**
  String get countryNameCg;

  /// No description provided for @countryNameGa.
  ///
  /// In fr, this message translates to:
  /// **'Gabon'**
  String get countryNameGa;

  /// No description provided for @countryNameGq.
  ///
  /// In fr, this message translates to:
  /// **'Guinée équatoriale'**
  String get countryNameGq;

  /// No description provided for @countryNameTd.
  ///
  /// In fr, this message translates to:
  /// **'Tchad'**
  String get countryNameTd;

  /// No description provided for @countryZoneEurope.
  ///
  /// In fr, this message translates to:
  /// **'Europe'**
  String get countryZoneEurope;

  /// No description provided for @countryZoneNorthAmerica.
  ///
  /// In fr, this message translates to:
  /// **'Amérique du Nord'**
  String get countryZoneNorthAmerica;

  /// No description provided for @countryZoneWestAfrica.
  ///
  /// In fr, this message translates to:
  /// **'Afrique de l\'Ouest'**
  String get countryZoneWestAfrica;

  /// No description provided for @countryZoneCentralAfrica.
  ///
  /// In fr, this message translates to:
  /// **'Afrique centrale'**
  String get countryZoneCentralAfrica;

  /// No description provided for @errorGuestSessionFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Navigation indisponible'**
  String get errorGuestSessionFailedTitle;

  /// No description provided for @errorGuestSessionFailedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de démarrer la navigation sans compte. Vérifiez votre connexion.'**
  String get errorGuestSessionFailedMessage;

  /// No description provided for @authCountrySaveError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer le pays. Réessayez.'**
  String get authCountrySaveError;

  /// No description provided for @authCountryChoiceSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer ce choix. Réessayez.'**
  String get authCountryChoiceSaveError;

  /// No description provided for @authPersonalInfoSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer ces informations. Réessayez.'**
  String get authPersonalInfoSaveError;

  /// No description provided for @authUserFallbackName.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get authUserFallbackName;

  /// No description provided for @authBiometricUnlockReason.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouillez Yadony pour accéder à votre compte'**
  String get authBiometricUnlockReason;

  /// No description provided for @authStepConsent.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get authStepConsent;

  /// No description provided for @authStepCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get authStepCountry;

  /// No description provided for @authStepIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get authStepIdentity;

  /// No description provided for @authStepPersonalInfo.
  ///
  /// In fr, this message translates to:
  /// **'Vos infos'**
  String get authStepPersonalInfo;

  /// No description provided for @authStepPayouts.
  ///
  /// In fr, this message translates to:
  /// **'Paiements'**
  String get authStepPayouts;

  /// No description provided for @authMethodIllustrationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Voyageur Yadony tenant un colis sécurisé'**
  String get authMethodIllustrationLabel;

  /// No description provided for @authMethodSecureBadge.
  ///
  /// In fr, this message translates to:
  /// **'Sécurisé'**
  String get authMethodSecureBadge;

  /// No description provided for @authMethodTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connecte-toi en toute confiance'**
  String get authMethodTitle;

  /// No description provided for @authMethodSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Tes échanges, ton paiement et ton suivi colis sont protégés à chaque étape.'**
  String get authMethodSubtitle;

  /// No description provided for @authMethodContinueWithApple.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Apple'**
  String get authMethodContinueWithApple;

  /// No description provided for @authMethodContinueWithEmail.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec mon email'**
  String get authMethodContinueWithEmail;

  /// No description provided for @authMethodContinueWithPhone.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec mon téléphone'**
  String get authMethodContinueWithPhone;

  /// No description provided for @authMethodContinueWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get authMethodContinueWithGoogle;

  /// No description provided for @authMethodOr.
  ///
  /// In fr, this message translates to:
  /// **'OU'**
  String get authMethodOr;

  /// No description provided for @authMethodGuestSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Parcourir sans compte. Accès limité à la recherche. Connexion requise pour publier, contacter, réserver ou payer.'**
  String get authMethodGuestSemantics;

  /// No description provided for @authMethodBrowseWithoutAccount.
  ///
  /// In fr, this message translates to:
  /// **'Parcourir sans compte'**
  String get authMethodBrowseWithoutAccount;

  /// No description provided for @authMethodGuestNotice.
  ///
  /// In fr, this message translates to:
  /// **'Accès limité : recherche uniquement. Connexion requise pour publier, contacter, réserver ou payer.'**
  String get authMethodGuestNotice;

  /// No description provided for @authLegalPrefix.
  ///
  /// In fr, this message translates to:
  /// **'En continuant tu acceptes nos '**
  String get authLegalPrefix;

  /// No description provided for @authLegalTermsLink.
  ///
  /// In fr, this message translates to:
  /// **'CGU'**
  String get authLegalTermsLink;

  /// No description provided for @authLegalMiddle.
  ///
  /// In fr, this message translates to:
  /// **' et notre '**
  String get authLegalMiddle;

  /// No description provided for @authLegalPrivacyLink.
  ///
  /// In fr, this message translates to:
  /// **'politique de confidentialité'**
  String get authLegalPrivacyLink;

  /// No description provided for @authEmailStepLabel.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get authEmailStepLabel;

  /// No description provided for @authEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton adresse email'**
  String get authEmailTitle;

  /// No description provided for @authEmailBody.
  ///
  /// In fr, this message translates to:
  /// **'Saisis ton adresse email pour recevoir un code de connexion.'**
  String get authEmailBody;

  /// No description provided for @authEmailFootnote.
  ///
  /// In fr, this message translates to:
  /// **'On protège ton accès sans partager ton email avec les voyageurs.'**
  String get authEmailFootnote;

  /// No description provided for @authEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'exemple@email.com'**
  String get authEmailHint;

  /// No description provided for @authEmailSpamHint.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie tes spams si tu ne reçois pas le code.'**
  String get authEmailSpamHint;

  /// No description provided for @authEmailSendCode.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le code'**
  String get authEmailSendCode;

  /// No description provided for @authEmailPreferSms.
  ///
  /// In fr, this message translates to:
  /// **'Préfères le SMS ?'**
  String get authEmailPreferSms;

  /// No description provided for @authPhoneDialCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif pays'**
  String get authPhoneDialCodeTitle;

  /// No description provided for @authPhoneStepLabel.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get authPhoneStepLabel;

  /// No description provided for @authPhoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton numéro'**
  String get authPhoneTitle;

  /// No description provided for @authPhoneBody.
  ///
  /// In fr, this message translates to:
  /// **'On t’envoie un code à 6 chiffres par SMS pour vérifier que c’est bien toi.'**
  String get authPhoneBody;

  /// No description provided for @authPhoneFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Ton numéro sert uniquement à sécuriser ton compte et tes échanges Yadony.'**
  String get authPhoneFootnote;

  /// No description provided for @authPhoneNumberLabel.
  ///
  /// In fr, this message translates to:
  /// **'NUMÉRO DE TÉLÉPHONE'**
  String get authPhoneNumberLabel;

  /// No description provided for @authPhoneEnterNumber.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre numéro'**
  String get authPhoneEnterNumber;

  /// No description provided for @authPhoneNumberTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Numéro trop court'**
  String get authPhoneNumberTooShort;

  /// No description provided for @authPhoneGetSmsCode.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir le code SMS'**
  String get authPhoneGetSmsCode;

  /// No description provided for @authPhoneContinueWithEmail.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec une adresse email'**
  String get authPhoneContinueWithEmail;

  /// No description provided for @authOtpEnterSixDigits.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code à 6 chiffres'**
  String get authOtpEnterSixDigits;

  /// No description provided for @authOtpSessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée, veuillez recommencer'**
  String get authOtpSessionExpired;

  /// No description provided for @authOtpEmailVerified.
  ///
  /// In fr, this message translates to:
  /// **'Email vérifié avec succès !'**
  String get authOtpEmailVerified;

  /// No description provided for @authOtpPhoneAdded.
  ///
  /// In fr, this message translates to:
  /// **'Numéro ajouté avec succès !'**
  String get authOtpPhoneAdded;

  /// No description provided for @authOtpStepEmail.
  ///
  /// In fr, this message translates to:
  /// **'Code email'**
  String get authOtpStepEmail;

  /// No description provided for @authOtpStepSms.
  ///
  /// In fr, this message translates to:
  /// **'Code SMS'**
  String get authOtpStepSms;

  /// No description provided for @authOtpEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code reçu ?'**
  String get authOtpEmailTitle;

  /// No description provided for @authOtpPhoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code'**
  String get authOtpPhoneTitle;

  /// No description provided for @authOtpCodeSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé à {contact}'**
  String authOtpCodeSentTo(String contact);

  /// No description provided for @authOtpCodeSentToPhone.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé au {contact}'**
  String authOtpCodeSentToPhone(String contact);

  /// No description provided for @authOtpFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Le code expire rapidement pour garder ton compte Yadony protégé.'**
  String get authOtpFootnote;

  /// No description provided for @authOtpResendIn.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code ({seconds} s)'**
  String authOtpResendIn(int seconds);

  /// No description provided for @authOtpResend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get authOtpResend;

  /// No description provided for @authOtpVerify.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get authOtpVerify;

  /// No description provided for @authDialCodeSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pays ou un indicatif'**
  String get authDialCodeSearchHint;

  /// No description provided for @authDialCodeNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pays ne correspond'**
  String get authDialCodeNoMatch;

  /// No description provided for @authFlowIllustrationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Connexion sécurisée Yadony'**
  String get authFlowIllustrationLabel;

  /// No description provided for @authFlowProtectedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Connexion protégée'**
  String get authFlowProtectedBadge;

  /// No description provided for @authFlowSkipForNow.
  ///
  /// In fr, this message translates to:
  /// **'Passer pour l\'instant'**
  String get authFlowSkipForNow;

  /// No description provided for @authRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion requise'**
  String get authRequiredTitle;

  /// No description provided for @authRequiredSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authRequiredSignIn;

  /// No description provided for @authRequiredKeepExploring.
  ///
  /// In fr, this message translates to:
  /// **'Continuer à explorer'**
  String get authRequiredKeepExploring;

  /// No description provided for @authRequiredFreeSearchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recherche libre'**
  String get authRequiredFreeSearchTitle;

  /// No description provided for @authRequiredFreeSearchBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux consulter les demandes et comparer les trajets.'**
  String get authRequiredFreeSearchBody;

  /// No description provided for @authRequiredProtectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Actions protégées'**
  String get authRequiredProtectedTitle;

  /// No description provided for @authRequiredOfferSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connecte-toi pour proposer ton trajet en toute sécurité.'**
  String get authRequiredOfferSubtitle;

  /// No description provided for @authRequiredOfferBody.
  ///
  /// In fr, this message translates to:
  /// **'La connexion protège les échanges, les propositions et le suivi du colis.'**
  String get authRequiredOfferBody;

  /// No description provided for @authRequiredReportSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connecte-toi pour signaler une annonce.'**
  String get authRequiredReportSubtitle;

  /// No description provided for @authRequiredReportBody.
  ///
  /// In fr, this message translates to:
  /// **'Les signalements sont reliés à un compte pour éviter les abus et mieux protéger la communauté.'**
  String get authRequiredReportBody;

  /// No description provided for @authRequiredExploreSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connecte-toi pour utiliser cette action.'**
  String get authRequiredExploreSubtitle;

  /// No description provided for @authRequiredExploreBody.
  ///
  /// In fr, this message translates to:
  /// **'Publier, contacter, réserver ou payer nécessite un compte Yadony.'**
  String get authRequiredExploreBody;

  /// No description provided for @authOnboardingHandoffEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'Étape 1'**
  String get authOnboardingHandoffEyebrow;

  /// No description provided for @authOnboardingHandoffTitle.
  ///
  /// In fr, this message translates to:
  /// **'Préparez votre envoi.'**
  String get authOnboardingHandoffTitle;

  /// No description provided for @authOnboardingHandoffSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez la destination, le format du colis et trouvez un voyageur disponible.'**
  String get authOnboardingHandoffSubtitle;

  /// No description provided for @authOnboardingHandoffStep1Title.
  ///
  /// In fr, this message translates to:
  /// **'Créer l’annonce'**
  String get authOnboardingHandoffStep1Title;

  /// No description provided for @authOnboardingHandoffStep1Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Départ, arrivée, taille du colis.'**
  String get authOnboardingHandoffStep1Subtitle;

  /// No description provided for @authOnboardingHandoffStep2Title.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un voyageur'**
  String get authOnboardingHandoffStep2Title;

  /// No description provided for @authOnboardingHandoffStep2Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil, trajet et disponibilité.'**
  String get authOnboardingHandoffStep2Subtitle;

  /// No description provided for @authOnboardingHandoffStep3Title.
  ///
  /// In fr, this message translates to:
  /// **'Remettre le colis'**
  String get authOnboardingHandoffStep3Title;

  /// No description provided for @authOnboardingHandoffStep3Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le parcours commence au scan.'**
  String get authOnboardingHandoffStep3Subtitle;

  /// No description provided for @authOnboardingSecurityEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get authOnboardingSecurityEyebrow;

  /// No description provided for @authOnboardingSecurityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chaque remise est encadrée.'**
  String get authOnboardingSecurityTitle;

  /// No description provided for @authOnboardingSecuritySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Yadony protège les profils, le paiement et les étapes importantes du colis.'**
  String get authOnboardingSecuritySubtitle;

  /// No description provided for @authOnboardingChipVerifiedIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité vérifiée'**
  String get authOnboardingChipVerifiedIdentity;

  /// No description provided for @authOnboardingChipPaymentOnHold.
  ///
  /// In fr, this message translates to:
  /// **'Paiement bloqué'**
  String get authOnboardingChipPaymentOnHold;

  /// No description provided for @authOnboardingChipTrackingQr.
  ///
  /// In fr, this message translates to:
  /// **'QR de suivi'**
  String get authOnboardingChipTrackingQr;

  /// No description provided for @authOnboardingChipProofOfDropOff.
  ///
  /// In fr, this message translates to:
  /// **'Preuve de remise'**
  String get authOnboardingChipProofOfDropOff;

  /// No description provided for @authOnboardingTrackingEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'Temps réel'**
  String get authOnboardingTrackingEyebrow;

  /// No description provided for @authOnboardingTrackingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gardez le fil du colis.'**
  String get authOnboardingTrackingTitle;

  /// No description provided for @authOnboardingTrackingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le suivi avance à chaque scan, du départ jusqu’à la confirmation d’arrivée.'**
  String get authOnboardingTrackingSubtitle;

  /// No description provided for @authOnboardingTrackingStep1Title.
  ///
  /// In fr, this message translates to:
  /// **'Remis'**
  String get authOnboardingTrackingStep1Title;

  /// No description provided for @authOnboardingTrackingStep1Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le colis est confié au voyageur.'**
  String get authOnboardingTrackingStep1Subtitle;

  /// No description provided for @authOnboardingTrackingStep2Title.
  ///
  /// In fr, this message translates to:
  /// **'Départ, transit, arrivée'**
  String get authOnboardingTrackingStep2Title;

  /// No description provided for @authOnboardingTrackingStep2Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Chaque scan met le suivi à jour.'**
  String get authOnboardingTrackingStep2Subtitle;

  /// No description provided for @authOnboardingTrackingStep3Title.
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get authOnboardingTrackingStep3Title;

  /// No description provided for @authOnboardingTrackingStep3Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'La réception confirme la fin du trajet.'**
  String get authOnboardingTrackingStep3Subtitle;

  /// No description provided for @authOnboardingDestinationsEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'Destinations'**
  String get authOnboardingDestinationsEyebrow;

  /// No description provided for @authOnboardingDestinationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos colis voyagent plus loin.'**
  String get authOnboardingDestinationsTitle;

  /// No description provided for @authOnboardingDestinationsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Yadony relie les pays disponibles avec des voyageurs qui font déjà le trajet.'**
  String get authOnboardingDestinationsSubtitle;

  /// No description provided for @authOnboardingDestinationsStep6Title.
  ///
  /// In fr, this message translates to:
  /// **'Remettre à l’arrivée'**
  String get authOnboardingDestinationsStep6Title;

  /// No description provided for @authOnboardingDestinationsStep6Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le destinataire confirme la réception.'**
  String get authOnboardingDestinationsStep6Subtitle;

  /// No description provided for @authOnboardingDestinationsStep7Title.
  ///
  /// In fr, this message translates to:
  /// **'Libérer le paiement'**
  String get authOnboardingDestinationsStep7Title;

  /// No description provided for @authOnboardingDestinationsStep7Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur est payé après succès.'**
  String get authOnboardingDestinationsStep7Subtitle;

  /// No description provided for @authOnboardingChipAfrica.
  ///
  /// In fr, this message translates to:
  /// **'Afrique'**
  String get authOnboardingChipAfrica;

  /// No description provided for @authOnboardingChipAvailableCountries.
  ///
  /// In fr, this message translates to:
  /// **'Pays disponibles'**
  String get authOnboardingChipAvailableCountries;

  /// No description provided for @authOnboardingImageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Scène d’onboarding Yadony'**
  String get authOnboardingImageLabel;

  /// No description provided for @authOnboardingSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get authOnboardingSkip;

  /// No description provided for @authOnboardingRouteDropOff.
  ///
  /// In fr, this message translates to:
  /// **'Remis'**
  String get authOnboardingRouteDropOff;

  /// No description provided for @authOnboardingRouteDeparture.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get authOnboardingRouteDeparture;

  /// No description provided for @authOnboardingRouteTransit.
  ///
  /// In fr, this message translates to:
  /// **'Transit'**
  String get authOnboardingRouteTransit;

  /// No description provided for @authOnboardingRouteArrival.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée'**
  String get authOnboardingRouteArrival;

  /// No description provided for @authOnboardingRouteDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get authOnboardingRouteDelivery;

  /// No description provided for @authOnboardingGetStarted.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get authOnboardingGetStarted;

  /// No description provided for @authOnboardingNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get authOnboardingNext;

  /// No description provided for @authOnboardingLegalPrefix.
  ///
  /// In fr, this message translates to:
  /// **'En continuant, vous acceptez nos '**
  String get authOnboardingLegalPrefix;

  /// No description provided for @authOnboardingLegalTermsLink.
  ///
  /// In fr, this message translates to:
  /// **'CGU'**
  String get authOnboardingLegalTermsLink;

  /// No description provided for @authOnboardingLegalMiddle.
  ///
  /// In fr, this message translates to:
  /// **' et notre '**
  String get authOnboardingLegalMiddle;

  /// No description provided for @authOnboardingLegalPrivacyLink.
  ///
  /// In fr, this message translates to:
  /// **'politique de confidentialité'**
  String get authOnboardingLegalPrivacyLink;

  /// No description provided for @authCountryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dans quel pays es-tu ?'**
  String get authCountryTitle;

  /// No description provided for @authCountrySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Devise, trajets et disponibilité seront adaptés à ton pays.'**
  String get authCountrySubtitle;

  /// No description provided for @authCountryFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get authCountryFieldLabel;

  /// No description provided for @authCountryFieldHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Sénégal, France, Canada'**
  String get authCountryFieldHint;

  /// No description provided for @authCountryFieldHelper.
  ///
  /// In fr, this message translates to:
  /// **'Tape ton pays puis choisis une suggestion.'**
  String get authCountryFieldHelper;

  /// No description provided for @authCountrySaving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement du pays...'**
  String get authCountrySaving;

  /// No description provided for @authCountryDeleteDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement le compte ?'**
  String get authCountryDeleteDialogTitle;

  /// No description provided for @authCountryDeleteDialogMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ton compte Yadony et tes données associées seront supprimés. Cette action est irréversible.'**
  String get authCountryDeleteDialogMessage;

  /// No description provided for @authCountryDeleteDialogConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la suppression'**
  String get authCountryDeleteDialogConfirm;

  /// No description provided for @authCountryUnavailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Yadony n’est pas encore disponible dans ce pays'**
  String get authCountryUnavailableTitle;

  /// No description provided for @authCountryUnavailableBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux continuer pour envoyer des colis. Les trajets et la prise de colis resteront indisponibles depuis ce compte.'**
  String get authCountryUnavailableBody;

  /// No description provided for @authCountryContinueAsSender.
  ///
  /// In fr, this message translates to:
  /// **'Je souhaite continuer et envoyer des colis'**
  String get authCountryContinueAsSender;

  /// No description provided for @authCountryDeleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get authCountryDeleteAccount;

  /// No description provided for @authCountryOptionSavingLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pays sélectionné : {country}, devise {currency}. Enregistrement en cours.'**
  String authCountryOptionSavingLabel(String country, String currency);

  /// No description provided for @authCountryOptionSelectLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner {country}, devise {currency}'**
  String authCountryOptionSelectLabel(String country, String currency);

  /// No description provided for @authPersonalInfoCountryNotSet.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get authPersonalInfoCountryNotSet;

  /// No description provided for @authPersonalInfoGaugeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get authPersonalInfoGaugeLabel;

  /// No description provided for @authPersonalInfoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos informations'**
  String get authPersonalInfoTitle;

  /// No description provided for @authPersonalInfoBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom légal, tel qu’il figure sur votre pièce d’identité. Le reste vous sera demandé une seule fois, par Stripe.'**
  String get authPersonalInfoBody;

  /// No description provided for @authPersonalInfoFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Jamais partagées avec les autres membres, jamais affichées publiquement.'**
  String get authPersonalInfoFootnote;

  /// No description provided for @authPersonalInfoIdentitySection.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get authPersonalInfoIdentitySection;

  /// No description provided for @authPersonalInfoFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get authPersonalInfoFirstName;

  /// No description provided for @authPersonalInfoLastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get authPersonalInfoLastName;

  /// No description provided for @authPersonalInfoCountrySection.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get authPersonalInfoCountrySection;

  /// No description provided for @authPersonalInfoCountryField.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get authPersonalInfoCountryField;

  /// No description provided for @authPersonalInfoCountrySemantics.
  ///
  /// In fr, this message translates to:
  /// **'Pays de résidence : {country}. Déterminé à l’inscription, non modifiable ici.'**
  String authPersonalInfoCountrySemantics(String country);

  /// No description provided for @authPersonalInfoCountryMissingSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Pays de résidence non renseigné. Déterminé à l’inscription, non modifiable ici.'**
  String get authPersonalInfoCountryMissingSemantics;

  /// No description provided for @authReferralGaugeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Parrainage'**
  String get authReferralGaugeLabel;

  /// No description provided for @authReferralTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu as été invité par un ami ?'**
  String get authReferralTitle;

  /// No description provided for @authReferralBody.
  ///
  /// In fr, this message translates to:
  /// **'Entre son code pour qu’il soit récompensé à ta première livraison.'**
  String get authReferralBody;

  /// No description provided for @authReferralFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Cette étape est facultative. Tu peux entrer dans Yadony sans code.'**
  String get authReferralFootnote;

  /// No description provided for @authReferralCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code parrain'**
  String get authReferralCodeLabel;

  /// No description provided for @authReferralCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : JEAN0234'**
  String get authReferralCodeHint;

  /// No description provided for @authReferralApply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer le code'**
  String get authReferralApply;

  /// No description provided for @authReferralSuccessTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code appliqué !'**
  String get authReferralSuccessTitle;

  /// No description provided for @authReferralSuccessBody.
  ///
  /// In fr, this message translates to:
  /// **'Ton ami sera récompensé dès que tu complètes ta première livraison.'**
  String get authReferralSuccessBody;

  /// No description provided for @authReferralSuccessFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Ton compte Yadony est prêt. Tu peux commencer à rechercher, envoyer ou suivre tes colis.'**
  String get authReferralSuccessFootnote;

  /// No description provided for @authReferralContinueHome.
  ///
  /// In fr, this message translates to:
  /// **'Continuer vers l\'accueil'**
  String get authReferralContinueHome;

  /// No description provided for @authConsentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Une dernière chose'**
  String get authConsentTitle;

  /// No description provided for @authConsentBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour améliorer Yadony, on aimerait mesurer comment l\'app est utilisée. C\'est anonyme et facultatif.'**
  String get authConsentBody;

  /// No description provided for @authConsentFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Jamais tes paiements, ton identité ou ton numéro. Tu peux changer d’avis dans Réglages.'**
  String get authConsentFootnote;

  /// No description provided for @authConsentPointScreens.
  ///
  /// In fr, this message translates to:
  /// **'Écrans visités et fonctionnalités utilisées'**
  String get authConsentPointScreens;

  /// No description provided for @authConsentPointGestures.
  ///
  /// In fr, this message translates to:
  /// **'Gestes pour repérer ce qui bloque'**
  String get authConsentPointGestures;

  /// No description provided for @authConsentPointNeverPersonal.
  ///
  /// In fr, this message translates to:
  /// **'Jamais tes paiements, identité ou numéro'**
  String get authConsentPointNeverPersonal;

  /// No description provided for @authConsentPointChangeAnytime.
  ///
  /// In fr, this message translates to:
  /// **'Modifiable à tout moment dans Réglages'**
  String get authConsentPointChangeAnytime;

  /// No description provided for @authConsentAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get authConsentAccept;

  /// No description provided for @authConsentDecline.
  ///
  /// In fr, this message translates to:
  /// **'Non merci'**
  String get authConsentDecline;

  /// No description provided for @authLocalSwitchAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer de compte ?'**
  String get authLocalSwitchAccountTitle;

  /// No description provided for @authLocalSwitchAccountMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous allez être déconnecté de ce compte. Vous devrez vous reconnecter et reconfigurer votre code PIN.'**
  String get authLocalSwitchAccountMessage;

  /// No description provided for @authLocalOtherAccount.
  ///
  /// In fr, this message translates to:
  /// **'Autre compte'**
  String get authLocalOtherAccount;

  /// No description provided for @authLocalEnterPin.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre code PIN'**
  String get authLocalEnterPin;

  /// No description provided for @authLocalLastAttempt.
  ///
  /// In fr, this message translates to:
  /// **'Dernière tentative avant blocage'**
  String get authLocalLastAttempt;

  /// No description provided for @authLocalAttemptsLeft.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} tentative restante} other{{count} tentatives restantes}}'**
  String authLocalAttemptsLeft(int count);

  /// No description provided for @authLocalRetryIn.
  ///
  /// In fr, this message translates to:
  /// **'{seconds, plural, =1{Réessayez dans {seconds} seconde} other{Réessayez dans {seconds} secondes}}'**
  String authLocalRetryIn(int seconds);

  /// No description provided for @countryNameCd.
  ///
  /// In fr, this message translates to:
  /// **'RD Congo'**
  String get countryNameCd;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get commonContinue;

  /// No description provided for @commonApply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get commonApply;

  /// No description provided for @commonClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get commonClear;

  /// No description provided for @commonRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// No description provided for @commonConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get commonConfirm;

  /// No description provided for @commonClearFilters.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les filtres'**
  String get commonClearFilters;

  /// No description provided for @parcelSizeSmall.
  ///
  /// In fr, this message translates to:
  /// **'Petit'**
  String get parcelSizeSmall;

  /// No description provided for @parcelSizeMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get parcelSizeMedium;

  /// No description provided for @parcelSizeLarge.
  ///
  /// In fr, this message translates to:
  /// **'Grand'**
  String get parcelSizeLarge;

  /// No description provided for @cityClearCity.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la ville'**
  String get cityClearCity;

  /// No description provided for @cityChooseCity.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une ville'**
  String get cityChooseCity;

  /// No description provided for @cityRecentSection.
  ///
  /// In fr, this message translates to:
  /// **'RÉCENTS'**
  String get cityRecentSection;

  /// No description provided for @cityDepartureLabel.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get cityDepartureLabel;

  /// No description provided for @cityArrivalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée'**
  String get cityArrivalLabel;

  /// No description provided for @citySwapLabel.
  ///
  /// In fr, this message translates to:
  /// **'Interchanger départ et arrivée'**
  String get citySwapLabel;

  /// No description provided for @shellTabActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get shellTabActivity;

  /// No description provided for @shellTabSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get shellTabSearch;

  /// No description provided for @shellTabMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get shellTabMessages;

  /// No description provided for @shellTabProfile.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get shellTabProfile;

  /// No description provided for @shellOrbTracking.
  ///
  /// In fr, this message translates to:
  /// **'Suivi'**
  String get shellOrbTracking;

  /// No description provided for @shellOrbQrScanner.
  ///
  /// In fr, this message translates to:
  /// **'Lecteur QR'**
  String get shellOrbQrScanner;

  /// No description provided for @shellPlaceholderConfirmPayment.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer paiement'**
  String get shellPlaceholderConfirmPayment;

  /// No description provided for @shellPlaceholderAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get shellPlaceholderAdmin;

  /// Titre par défaut de l'écran des demandes reçues sur une annonce
  ///
  /// In fr, this message translates to:
  /// **'Demandes'**
  String get shellRequestsTitle;

  /// No description provided for @shellPrivacyPolicyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get shellPrivacyPolicyTitle;

  /// No description provided for @homeCorridorFrom.
  ///
  /// In fr, this message translates to:
  /// **'Départ de {dep}'**
  String homeCorridorFrom(String dep);

  /// No description provided for @homeCorridorTo.
  ///
  /// In fr, this message translates to:
  /// **'Vers {arr}'**
  String homeCorridorTo(String arr);

  /// No description provided for @homeCorridorAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous les corridors'**
  String get homeCorridorAll;

  /// No description provided for @homePullToList.
  ///
  /// In fr, this message translates to:
  /// **'Tirer pour voir la liste'**
  String get homePullToList;

  /// No description provided for @homePullToTravelers.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Tirer pour voir le voyageur} other{Tirer pour voir les {count} voyageurs}}'**
  String homePullToTravelers(int count);

  /// No description provided for @homePullToParcels.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Tirer pour voir le colis} other{Tirer pour voir les {count} colis}}'**
  String homePullToParcels(int count);

  /// No description provided for @homePullToMap.
  ///
  /// In fr, this message translates to:
  /// **'Tirer vers le bas pour voir la carte'**
  String get homePullToMap;

  /// No description provided for @homeCrossParcels.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} colis cherche un voyageur} other{{count} colis cherchent un voyageur}}'**
  String homeCrossParcels(int count);

  /// No description provided for @homeCrossParcelsRoute.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} colis cherche un voyageur sur {dep} → {arr}} other{{count} colis cherchent un voyageur sur {dep} → {arr}}}'**
  String homeCrossParcelsRoute(int count, String dep, String arr);

  /// No description provided for @homeCrossParcelsFrom.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} colis cherche un voyageur au départ de {dep}} other{{count} colis cherchent un voyageur au départ de {dep}}}'**
  String homeCrossParcelsFrom(int count, String dep);

  /// No description provided for @homeCrossParcelsTo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} colis cherche un voyageur vers {arr}} other{{count} colis cherchent un voyageur vers {arr}}}'**
  String homeCrossParcelsTo(int count, String arr);

  /// No description provided for @homeCrossTravelers.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur passe} other{{count} voyageurs passent}}'**
  String homeCrossTravelers(int count);

  /// No description provided for @homeCrossTravelersRoute.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur passe sur {dep} → {arr}} other{{count} voyageurs passent sur {dep} → {arr}}}'**
  String homeCrossTravelersRoute(int count, String dep, String arr);

  /// No description provided for @homeCrossTravelersFrom.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur passe au départ de {dep}} other{{count} voyageurs passent au départ de {dep}}}'**
  String homeCrossTravelersFrom(int count, String dep);

  /// No description provided for @homeCrossTravelersTo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur passe vers {arr}} other{{count} voyageurs passent vers {arr}}}'**
  String homeCrossTravelersTo(int count, String arr);

  /// No description provided for @homeAlertTrip.
  ///
  /// In fr, this message translates to:
  /// **'M\'alerter dès qu\'un trajet apparaît sur {dep} → {arr}'**
  String homeAlertTrip(String dep, String arr);

  /// No description provided for @homeAlertParcel.
  ///
  /// In fr, this message translates to:
  /// **'M\'alerter dès qu\'un colis apparaît sur {dep} → {arr}'**
  String homeAlertParcel(String dep, String arr);

  /// No description provided for @homeLocateError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de te localiser. Réessaie.'**
  String get homeLocateError;

  /// No description provided for @homeMaxWeightTitle.
  ///
  /// In fr, this message translates to:
  /// **'Poids max du colis'**
  String get homeMaxWeightTitle;

  /// No description provided for @homeParcelSizeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Taille du colis'**
  String get homeParcelSizeTitle;

  /// No description provided for @homeListTravelersNearby.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur à proximité} other{{count} voyageurs à proximité}}'**
  String homeListTravelersNearby(int count);

  /// No description provided for @homeListTravelersRoute.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur pour {dep} → {arr}} other{{count} voyageurs pour {dep} → {arr}}}'**
  String homeListTravelersRoute(int count, String dep, String arr);

  /// No description provided for @homeListTravelersCorridor.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur · {corridor}} other{{count} voyageurs · {corridor}}}'**
  String homeListTravelersCorridor(int count, String corridor);

  /// No description provided for @homeListParcelsMatching.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} colis compatible} other{{count} colis compatibles}}'**
  String homeListParcelsMatching(int count);

  /// No description provided for @homeListParcelsRoute.
  ///
  /// In fr, this message translates to:
  /// **'{count} colis à transporter pour {dep} → {arr}'**
  String homeListParcelsRoute(int count, String dep, String arr);

  /// No description provided for @homeListParcelsCorridor.
  ///
  /// In fr, this message translates to:
  /// **'{count} colis à transporter · {corridor}'**
  String homeListParcelsCorridor(int count, String corridor);

  /// No description provided for @homeListSubtitleNoTraveler.
  ///
  /// In fr, this message translates to:
  /// **'Personne ne propose ce trajet pour l\'instant'**
  String get homeListSubtitleNoTraveler;

  /// No description provided for @homeListSubtitleTravelersCanCarry.
  ///
  /// In fr, this message translates to:
  /// **'Ils peuvent emporter ton colis'**
  String get homeListSubtitleTravelersCanCarry;

  /// No description provided for @homeListSubtitleActiveTripsUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Avec tes trajets actifs'**
  String get homeListSubtitleActiveTripsUnknown;

  /// No description provided for @homeListSubtitleActiveTrips.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Avec ton trajet actif} other{Avec tes {count} trajets actifs}}'**
  String homeListSubtitleActiveTrips(int count);

  /// No description provided for @homeListSubtitleNoRequest.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande d\'envoi pour l\'instant'**
  String get homeListSubtitleNoRequest;

  /// No description provided for @homeListSubtitleYouCanCarry.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux les emporter sur ton trajet'**
  String get homeListSubtitleYouCanCarry;

  /// No description provided for @homeSort.
  ///
  /// In fr, this message translates to:
  /// **'Trier'**
  String get homeSort;

  /// No description provided for @homeConnectionErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible'**
  String get homeConnectionErrorTitle;

  /// No description provided for @homeRequestsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les demandes. Vérifie ta connexion puis réessaie.'**
  String get homeRequestsLoadError;

  /// No description provided for @homeEmptyParcelsFiltered.
  ///
  /// In fr, this message translates to:
  /// **'Aucun colis avec ces filtres'**
  String get homeEmptyParcelsFiltered;

  /// No description provided for @homeEmptyParcelsSoon.
  ///
  /// In fr, this message translates to:
  /// **'Demandes bientôt disponibles'**
  String get homeEmptyParcelsSoon;

  /// No description provided for @homeEmptyParcelsFilteredHint.
  ///
  /// In fr, this message translates to:
  /// **'Modifie ou supprime tes filtres pour voir plus de demandes.'**
  String get homeEmptyParcelsFilteredHint;

  /// No description provided for @homeEmptyParcelsSoonHint.
  ///
  /// In fr, this message translates to:
  /// **'Tu pourras bientôt consulter les demandes d\'envoi postées par les expéditeurs.'**
  String get homeEmptyParcelsSoonHint;

  /// No description provided for @homeTripsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les trajets. Vérifie ta connexion puis réessaie.'**
  String get homeTripsLoadError;

  /// No description provided for @homeEmptyTravelersNearby.
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyageur à proximité'**
  String get homeEmptyTravelersNearby;

  /// No description provided for @homeEmptyTravelersFiltered.
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyageur avec ces filtres'**
  String get homeEmptyTravelersFiltered;

  /// No description provided for @homeEmptyTravelersRoute.
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyageur sur ce corridor'**
  String get homeEmptyTravelersRoute;

  /// No description provided for @homeEmptyNearbyHint.
  ///
  /// In fr, this message translates to:
  /// **'Élargis ta zone ou désactive \"Près de moi\"'**
  String get homeEmptyNearbyHint;

  /// No description provided for @homeEmptyTravelersFilteredHint.
  ///
  /// In fr, this message translates to:
  /// **'Modifie tes filtres pour voir plus de voyageurs.'**
  String get homeEmptyTravelersFilteredHint;

  /// No description provided for @homeEmptyTravelersRouteHint.
  ///
  /// In fr, this message translates to:
  /// **'De nouveaux trajets sont publiés chaque jour. Reviens bientôt.'**
  String get homeEmptyTravelersRouteHint;

  /// Pastille flottante de l'accueil qui ouvre la vue carte
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get homeMapButton;

  /// No description provided for @homeRadiusKm.
  ///
  /// In fr, this message translates to:
  /// **'Rayon · {km} km'**
  String homeRadiusKm(int km);

  /// No description provided for @homeDepartureDateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Date de départ'**
  String get homeDepartureDateTitle;

  /// No description provided for @commonDateToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get commonDateToday;

  /// No description provided for @commonDateThisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get commonDateThisWeek;

  /// No description provided for @commonDateThisMonthLong.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois-ci'**
  String get commonDateThisMonthLong;

  /// No description provided for @homeChooseDate.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get homeChooseDate;

  /// No description provided for @homeMinRatingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Note minimum'**
  String get homeMinRatingTitle;

  /// No description provided for @homeRatingOnlyFive.
  ///
  /// In fr, this message translates to:
  /// **'★ 5.0 uniquement'**
  String get homeRatingOnlyFive;

  /// No description provided for @homeRatingAndUp.
  ///
  /// In fr, this message translates to:
  /// **'★ {rating} et plus'**
  String homeRatingAndUp(String rating);

  /// No description provided for @homeWeightCapacityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Capacité kilo'**
  String get homeWeightCapacityTitle;

  /// No description provided for @homeMaxPriceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Prix maximum'**
  String get homeMaxPriceTitle;

  /// No description provided for @homeAnyPrice.
  ///
  /// In fr, this message translates to:
  /// **'Tous les prix'**
  String get homeAnyPrice;

  /// No description provided for @homeComposerTitleTrips.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les trajets'**
  String get homeComposerTitleTrips;

  /// No description provided for @homeComposerTitleParcels.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les colis'**
  String get homeComposerTitleParcels;

  /// No description provided for @homeComposerClearAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get homeComposerClearAll;

  /// No description provided for @homeComposerSectionPhrase.
  ///
  /// In fr, this message translates to:
  /// **'EN UNE PHRASE'**
  String get homeComposerSectionPhrase;

  /// No description provided for @homeComposerSectionWhere.
  ///
  /// In fr, this message translates to:
  /// **'OÙ'**
  String get homeComposerSectionWhere;

  /// No description provided for @homeComposerSectionWhen.
  ///
  /// In fr, this message translates to:
  /// **'QUAND'**
  String get homeComposerSectionWhen;

  /// No description provided for @homeComposerSectionAroundMe.
  ///
  /// In fr, this message translates to:
  /// **'AUTOUR DE MOI'**
  String get homeComposerSectionAroundMe;

  /// No description provided for @homeComposerSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get homeComposerSearch;

  /// No description provided for @homeComposerSearchWithCount.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher ({count})'**
  String homeComposerSearchWithCount(int count);

  /// No description provided for @homeComposerSectionWeightPrice.
  ///
  /// In fr, this message translates to:
  /// **'POIDS ET PRIX'**
  String get homeComposerSectionWeightPrice;

  /// No description provided for @homeComposerSectionContents.
  ///
  /// In fr, this message translates to:
  /// **'MON COLIS CONTIENT'**
  String get homeComposerSectionContents;

  /// No description provided for @homeComposerContentHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un type de contenu…'**
  String get homeComposerContentHint;

  /// No description provided for @homeComposerSectionQuickFilters.
  ///
  /// In fr, this message translates to:
  /// **'FILTRES RAPIDES'**
  String get homeComposerSectionQuickFilters;

  /// No description provided for @homeComposerMinRating.
  ///
  /// In fr, this message translates to:
  /// **'Note ≥ 4.5'**
  String get homeComposerMinRating;

  /// No description provided for @homeComposerWeekend.
  ///
  /// In fr, this message translates to:
  /// **'Week-end'**
  String get homeComposerWeekend;

  /// No description provided for @homeComposerVerifiedIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité vérifiée'**
  String get homeComposerVerifiedIdentity;

  /// No description provided for @homeComposerSectionUrgency.
  ///
  /// In fr, this message translates to:
  /// **'URGENCE DU DÉPART'**
  String get homeComposerSectionUrgency;

  /// No description provided for @homeComposerUrgencyHint.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les trajets selon leur proximité de départ'**
  String get homeComposerUrgencyHint;

  /// No description provided for @homeComposerSectionMaxWeight.
  ///
  /// In fr, this message translates to:
  /// **'POIDS MAXIMAL'**
  String get homeComposerSectionMaxWeight;

  /// No description provided for @homeComposerSectionParcelSize.
  ///
  /// In fr, this message translates to:
  /// **'TAILLE DU COLIS'**
  String get homeComposerSectionParcelSize;

  /// No description provided for @homeComposerForMyTrips.
  ///
  /// In fr, this message translates to:
  /// **'Pour mes trajets'**
  String get homeComposerForMyTrips;

  /// No description provided for @homeComposerAlertTip.
  ///
  /// In fr, this message translates to:
  /// **'Astuce, tu peux être prévenu des nouveaux colis compatibles depuis Réglages, Notifications.'**
  String get homeComposerAlertTip;

  /// No description provided for @homeComposerAroundMe.
  ///
  /// In fr, this message translates to:
  /// **'Autour de moi'**
  String get homeComposerAroundMe;

  /// No description provided for @homeComposerLocating.
  ///
  /// In fr, this message translates to:
  /// **'Localisation en cours…'**
  String get homeComposerLocating;

  /// No description provided for @homeRecapTitle.
  ///
  /// In fr, this message translates to:
  /// **'RÉGLÉ DEPUIS VOTRE PHRASE'**
  String get homeRecapTitle;

  /// No description provided for @homeRecapArrival.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée'**
  String get homeRecapArrival;

  /// No description provided for @homeRecapDeparture.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get homeRecapDeparture;

  /// No description provided for @homeRecapWhen.
  ///
  /// In fr, this message translates to:
  /// **'Quand'**
  String get homeRecapWhen;

  /// No description provided for @homeRecapMinWeight.
  ///
  /// In fr, this message translates to:
  /// **'Poids minimum'**
  String get homeRecapMinWeight;

  /// No description provided for @homeRecapFieldLine.
  ///
  /// In fr, this message translates to:
  /// **'{label} : {value}'**
  String homeRecapFieldLine(String label, String value);

  /// No description provided for @homeUnresolvedPriceQuestion.
  ///
  /// In fr, this message translates to:
  /// **'« {phrase} », c\'est combien ?'**
  String homeUnresolvedPriceQuestion(String phrase);

  /// No description provided for @homeUnresolvedCityUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Vers quelle ville ?'**
  String get homeUnresolvedCityUnknown;

  /// No description provided for @homeUnresolvedCityAmbiguous.
  ///
  /// In fr, this message translates to:
  /// **'Quelle ville exactement ?'**
  String get homeUnresolvedCityAmbiguous;

  /// No description provided for @homeUnresolvedDateQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Quand voulez-vous partir ?'**
  String get homeUnresolvedDateQuestion;

  /// No description provided for @homeUnresolvedUpTo.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'à {price}/kg'**
  String homeUnresolvedUpTo(String price);

  /// No description provided for @homeUnresolvedAnyPrice.
  ///
  /// In fr, this message translates to:
  /// **'Peu importe le prix'**
  String get homeUnresolvedAnyPrice;

  /// No description provided for @commonDateThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois'**
  String get commonDateThisMonth;

  /// No description provided for @homeUnresolvedAnyTime.
  ///
  /// In fr, this message translates to:
  /// **'Peu importe'**
  String get homeUnresolvedAnyTime;

  /// No description provided for @homePhraseHint.
  ///
  /// In fr, this message translates to:
  /// **'20 kilos à Bamako en mars'**
  String get homePhraseHint;

  /// No description provided for @homeSectionOptional.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif'**
  String get homeSectionOptional;

  /// No description provided for @homeModeSelectorSending.
  ///
  /// In fr, this message translates to:
  /// **'J\'envoie un colis'**
  String get homeModeSelectorSending;

  /// No description provided for @homeModeSelectorTraveling.
  ///
  /// In fr, this message translates to:
  /// **'Je voyage'**
  String get homeModeSelectorTraveling;

  /// No description provided for @homeModeSelectorTravelersAvailable.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur disponible} other{{count} voyageurs disponibles}}'**
  String homeModeSelectorTravelersAvailable(int count);

  /// No description provided for @homeModeSelectorTravelersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Voyageurs disponibles'**
  String get homeModeSelectorTravelersSubtitle;

  /// No description provided for @homeModeSelectorParcelsToCarry.
  ///
  /// In fr, this message translates to:
  /// **'{count} colis à transporter'**
  String homeModeSelectorParcelsToCarry(int count);

  /// No description provided for @homeModeSelectorParcelsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Colis à transporter'**
  String get homeModeSelectorParcelsSubtitle;

  /// Puce de filtre de l'accueil : date personnalisée choisie mais pas encore renseignée
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get homeFilterChipsDate;

  /// No description provided for @homeFilterChipsAnyDate.
  ///
  /// In fr, this message translates to:
  /// **'Toutes dates'**
  String get homeFilterChipsAnyDate;

  /// No description provided for @homeFilterChipsRating.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get homeFilterChipsRating;

  /// No description provided for @homeFilterChipsWeight.
  ///
  /// In fr, this message translates to:
  /// **'Kilos'**
  String get homeFilterChipsWeight;

  /// No description provided for @homeFilterChipsPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get homeFilterChipsPrice;

  /// No description provided for @homeFilterChipsSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get homeFilterChipsSize;

  /// No description provided for @homeFilterChipsUrgent.
  ///
  /// In fr, this message translates to:
  /// **'🔥 Urgent'**
  String get homeFilterChipsUrgent;

  /// No description provided for @homeFilterFieldsExactDate.
  ///
  /// In fr, this message translates to:
  /// **'DATE PRÉCISE'**
  String get homeFilterFieldsExactDate;

  /// No description provided for @homeFilterFieldsMaxPrice.
  ///
  /// In fr, this message translates to:
  /// **'PRIX MAX'**
  String get homeFilterFieldsMaxPrice;

  /// Valeur d'un champ de filtre (prix max, mode de transport) quand aucun filtre n'est choisi
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get homeFilterFieldsAll;

  /// No description provided for @homeFilterFieldsChoose.
  ///
  /// In fr, this message translates to:
  /// **'Choisir'**
  String get homeFilterFieldsChoose;

  /// No description provided for @homeFilterFieldsMinWeight.
  ///
  /// In fr, this message translates to:
  /// **'POIDS MIN'**
  String get homeFilterFieldsMinWeight;

  /// No description provided for @homeFilterFieldsMinWeightTitle.
  ///
  /// In fr, this message translates to:
  /// **'Poids minimum du trajet'**
  String get homeFilterFieldsMinWeightTitle;

  /// No description provided for @homeFilterFieldsTransportMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode de transport'**
  String get homeFilterFieldsTransportMode;

  /// Marqueur de carte : la demande n'a pas de prix cible, le prix est libre
  ///
  /// In fr, this message translates to:
  /// **'Libre'**
  String get homeMapOpenPrice;

  /// No description provided for @homeMapRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes'**
  String get homeMapRequests;

  /// No description provided for @homeMapNoRequestsNearby.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande dans ce rayon'**
  String get homeMapNoRequestsNearby;

  /// No description provided for @homeMapNoRequestsYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande pour le moment'**
  String get homeMapNoRequestsYet;

  /// No description provided for @homeMapEmptyNearbyHint.
  ///
  /// In fr, this message translates to:
  /// **'Élargis ta zone ou désactive “Près de moi”'**
  String get homeMapEmptyNearbyHint;

  /// No description provided for @homeMapEmptyHint.
  ///
  /// In fr, this message translates to:
  /// **'Reviens dans un instant, de nouvelles demandes sont publiées chaque jour'**
  String get homeMapEmptyHint;

  /// No description provided for @homeGuidancePublishTrip.
  ///
  /// In fr, this message translates to:
  /// **'Publier mon trajet'**
  String get homeGuidancePublishTrip;

  /// No description provided for @homeGuidancePublishParcel.
  ///
  /// In fr, this message translates to:
  /// **'Publier un colis'**
  String get homeGuidancePublishParcel;

  /// No description provided for @homeGuidanceCreateAlert.
  ///
  /// In fr, this message translates to:
  /// **'Créer une alerte'**
  String get homeGuidanceCreateAlert;

  /// No description provided for @homeGuidanceVerifyIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier mon identité'**
  String get homeGuidanceVerifyIdentity;

  /// No description provided for @homeGuidanceHowItWorks.
  ///
  /// In fr, this message translates to:
  /// **'Comment ça marche ?'**
  String get homeGuidanceHowItWorks;

  /// No description provided for @homeGuidanceDontShowAgain.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus afficher'**
  String get homeGuidanceDontShowAgain;

  /// No description provided for @homeNoActiveTripTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun trajet actif'**
  String get homeNoActiveTripTitle;

  /// No description provided for @homeNoActiveTripBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce filtre ne montre que les colis compatibles avec tes trajets à venir. Publie un trajet pour t\'en servir.'**
  String get homeNoActiveTripBody;

  /// No description provided for @homeNoActiveTripPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier un trajet'**
  String get homeNoActiveTripPublish;

  /// No description provided for @homeFilterFieldsTransport.
  ///
  /// In fr, this message translates to:
  /// **'TRANSPORT'**
  String get homeFilterFieldsTransport;

  /// No description provided for @homeFilterFieldsDate.
  ///
  /// In fr, this message translates to:
  /// **'DATE'**
  String get homeFilterFieldsDate;

  /// No description provided for @homeNearMeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Près de moi'**
  String get homeNearMeTitle;

  /// No description provided for @homeNearMeConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Activer le filtre'**
  String get homeNearMeConfirm;

  /// No description provided for @homeNearMeExplanation.
  ///
  /// In fr, this message translates to:
  /// **'On garde uniquement les annonces dont le point de remise est dans ce rayon autour de toi.'**
  String get homeNearMeExplanation;

  /// No description provided for @homeLocationPermissionOpenSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get homeLocationPermissionOpenSettings;

  /// No description provided for @homeLocationPermissionServiceOffTitle.
  ///
  /// In fr, this message translates to:
  /// **'Localisation désactivée'**
  String get homeLocationPermissionServiceOffTitle;

  /// No description provided for @homeLocationPermissionDeniedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès à la position refusé'**
  String get homeLocationPermissionDeniedTitle;

  /// No description provided for @homeLocationPermissionServiceOffBody.
  ///
  /// In fr, this message translates to:
  /// **'Active la localisation de ton téléphone pour voir ce qui est près de toi.'**
  String get homeLocationPermissionServiceOffBody;

  /// No description provided for @homeLocationPermissionDeniedBody.
  ///
  /// In fr, this message translates to:
  /// **'Autorise l\'accès à ta position dans les réglages pour utiliser « Près de moi » et te situer sur la carte.'**
  String get homeLocationPermissionDeniedBody;

  /// Titre de l'écran des conditions générales d'utilisation (/legal/terms)
  ///
  /// In fr, this message translates to:
  /// **'CGU'**
  String get shellTermsTitle;

  /// Bouton générique qui enregistre une modification
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// Bouton générique qui supprime un élément
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonDelete;

  /// Bouton générique qui ouvre l'édition d'un élément
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// Bouton générique de retour en arrière
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get commonBack;

  /// Bouton générique d'envoi
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get commonSend;

  /// Bouton générique de partage
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get commonShare;

  /// Bouton générique de copie (presse-papiers)
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get commonCopy;

  /// Bouton générique qui déplie une liste tronquée
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get commonSeeAll;

  /// Date et heure accolées, sans mot en dur dans un motif de formatage
  ///
  /// In fr, this message translates to:
  /// **'{date} à {time}'**
  String commonDateAtTime(String date, String time);

  /// Liste de deux éléments jointe pour l'affichage
  ///
  /// In fr, this message translates to:
  /// **'{first} et {second}'**
  String commonListPair(String first, String second);

  /// Liste de trois éléments ou plus : tête déjà jointe par des virgules, et dernier élément
  ///
  /// In fr, this message translates to:
  /// **'{head} et {last}'**
  String commonListLast(String head, String last);

  /// Trajet sans capacité fixée : le voyageur accepte le kilo au fil de l'eau
  ///
  /// In fr, this message translates to:
  /// **'Kg libre'**
  String get tripKgFree;

  /// Trajet dont le prix n'est pas négociable
  ///
  /// In fr, this message translates to:
  /// **'Prix ferme'**
  String get tripFixedPrice;

  /// Nom affiché quand le voyageur n'a pas de displayName exploitable
  ///
  /// In fr, this message translates to:
  /// **'Voyageur'**
  String get tripTravelerFallbackName;

  /// No description provided for @tripTransportPlane.
  ///
  /// In fr, this message translates to:
  /// **'Avion'**
  String get tripTransportPlane;

  /// No description provided for @tripTransportCar.
  ///
  /// In fr, this message translates to:
  /// **'Voiture'**
  String get tripTransportCar;

  /// No description provided for @tripTransportTrain.
  ///
  /// In fr, this message translates to:
  /// **'Train'**
  String get tripTransportTrain;

  /// No description provided for @tripTransportBus.
  ///
  /// In fr, this message translates to:
  /// **'Bus'**
  String get tripTransportBus;

  /// No description provided for @tripTransportBoat.
  ///
  /// In fr, this message translates to:
  /// **'Bateau'**
  String get tripTransportBoat;

  /// No description provided for @tripTransportOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get tripTransportOther;

  /// No description provided for @tripUrgencyVeryUrgent.
  ///
  /// In fr, this message translates to:
  /// **'< 3j'**
  String get tripUrgencyVeryUrgent;

  /// No description provided for @tripUrgencyUrgent.
  ///
  /// In fr, this message translates to:
  /// **'3–7j'**
  String get tripUrgencyUrgent;

  /// No description provided for @tripUrgencySoon.
  ///
  /// In fr, this message translates to:
  /// **'7–14j'**
  String get tripUrgencySoon;

  /// No description provided for @tripUrgencyLater.
  ///
  /// In fr, this message translates to:
  /// **'14j+'**
  String get tripUrgencyLater;

  /// No description provided for @tripCapacitySuitcase23.
  ///
  /// In fr, this message translates to:
  /// **'1 valise 23 kg'**
  String get tripCapacitySuitcase23;

  /// No description provided for @tripCapacitySuitcase32.
  ///
  /// In fr, this message translates to:
  /// **'1 valise 32 kg'**
  String get tripCapacitySuitcase32;

  /// No description provided for @tripCapacityCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get tripCapacityCustom;

  /// Titre de l'écran de publication d'un trajet (AppBar en création, et intro voyageur)
  ///
  /// In fr, this message translates to:
  /// **'Publier un trajet'**
  String get tripPublishTitle;

  /// Titre de l'AppBar en mode édition d'un trajet
  ///
  /// In fr, this message translates to:
  /// **'Modifier le trajet'**
  String get tripPublishEditTitle;

  /// Titre de l'AppBar quand le trajet est créé pour une demande de colis verrouillée
  ///
  /// In fr, this message translates to:
  /// **'Créer le trajet pour cette demande'**
  String get tripPublishDedicatedTitle;

  /// Bouton de soumission du trajet dédié à une demande de colis
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le trajet'**
  String get tripPublishSubmitDedicated;

  /// Bouton qui ouvre l'aperçu du trajet avant publication
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get tripPublishPreviewButton;

  /// Erreur de validation : ville de départ manquante à l'étape Trajet
  ///
  /// In fr, this message translates to:
  /// **'Ville de départ obligatoire'**
  String get tripPublishFieldDepartureCityRequired;

  /// Erreur de validation : ville d'arrivée manquante à l'étape Trajet
  ///
  /// In fr, this message translates to:
  /// **'Ville d\'arrivée obligatoire'**
  String get tripPublishFieldArrivalCityRequired;

  /// Erreur de validation : date de départ manquante à l'étape Trajet
  ///
  /// In fr, this message translates to:
  /// **'Date de départ obligatoire'**
  String get tripPublishFieldDepartureDateRequired;

  /// Erreur de validation : heure de départ manquante à l'étape Trajet
  ///
  /// In fr, this message translates to:
  /// **'Heure de départ obligatoire'**
  String get tripPublishFieldDepartureTimeRequired;

  /// Erreur de validation : mode de transport manquant à l'étape Trajet
  ///
  /// In fr, this message translates to:
  /// **'Mode de transport obligatoire'**
  String get tripPublishFieldTransportModeRequired;

  /// Erreur de validation : date limite de dépôt des colis manquante à l'étape Trajet
  ///
  /// In fr, this message translates to:
  /// **'Date limite de dépôt obligatoire'**
  String get tripPublishFieldHandoverDeadlineRequired;

  /// Erreur de validation : lieu de remise du colis manquant à l'étape Lieux & Capacité
  ///
  /// In fr, this message translates to:
  /// **'Lieu de remise du colis obligatoire'**
  String get tripPublishFieldPickupAddressRequired;

  /// Erreur de validation : lieu de récupération du colis manquant à l'étape Lieux & Capacité
  ///
  /// In fr, this message translates to:
  /// **'Lieu de récupération obligatoire'**
  String get tripPublishFieldDeliveryAddressRequired;

  /// Erreur affichée sous la ligne date limite de dépôt quand elle est postérieure au départ
  ///
  /// In fr, this message translates to:
  /// **'La date limite doit précéder le départ.'**
  String get tripPublishHandoverDeadlineInvalid;

  /// Snackbar d'erreur à la soumission quand la date limite de dépôt est postérieure au départ
  ///
  /// In fr, this message translates to:
  /// **'La date limite de dépôt doit précéder le départ'**
  String get tripPublishHandoverDeadlineBeforeDeparture;

  /// Confirmation quand un trajet dédié est créé avec une nouvelle offre, sans fil de négociation existant
  ///
  /// In fr, this message translates to:
  /// **'Offre envoyée avec le trajet associé.'**
  String get tripPublishOfferSentWithTrip;

  /// Confirmation quand un trajet dédié est lié à un fil de négociation existant
  ///
  /// In fr, this message translates to:
  /// **'Trajet lié. L\'expéditeur peut désormais payer.'**
  String get tripPublishTripLinked;

  /// Titre de l'écran de succès après modification d'un trajet
  ///
  /// In fr, this message translates to:
  /// **'Trajet modifié !'**
  String get tripPublishSuccessTitleEdit;

  /// Titre de l'écran de succès après publication d'un trajet
  ///
  /// In fr, this message translates to:
  /// **'Trajet publié !'**
  String get tripPublishSuccessTitleCreate;

  /// Sous-titre de l'écran de succès, avec le corridor du trajet publié
  ///
  /// In fr, this message translates to:
  /// **'Ton trajet {departureCity} → {arrivalCity} est en ligne.'**
  String tripPublishSuccessSubtitle(String departureCity, String arrivalCity);

  /// CTA principal de l'écran de succès de publication d'un trajet
  ///
  /// In fr, this message translates to:
  /// **'Voir mon trajet'**
  String get tripPublishSuccessCta;

  /// CTA secondaire de l'écran de succès (partager l'affiche du trajet), absent en mode édition
  ///
  /// In fr, this message translates to:
  /// **'Partager mon affiche'**
  String get tripPublishSuccessShareCta;

  /// Titre du dialogue quand la limite mensuelle de publications PRO est atteinte
  ///
  /// In fr, this message translates to:
  /// **'Limite mensuelle atteinte'**
  String get tripPublishMonthlyLimitTitle;

  /// Titre du dialogue quand la limite de brouillons est atteinte
  ///
  /// In fr, this message translates to:
  /// **'Limite de brouillons atteinte'**
  String get tripPublishDraftLimitTitle;

  /// Titre de la barre de suggestion des modèles de trajet enregistrés
  ///
  /// In fr, this message translates to:
  /// **'Mes modèles'**
  String get tripPublishTemplatesLabel;

  /// Texte d'aide sous le titre de la barre de suggestion des modèles de trajet
  ///
  /// In fr, this message translates to:
  /// **'Applique un modèle pour pré-remplir le trajet'**
  String get tripPublishTemplatesHint;

  /// Confirmation après application d'un modèle de trajet, avec son nom
  ///
  /// In fr, this message translates to:
  /// **'Modèle « {label} » appliqué'**
  String tripPublishTemplateAppliedMessage(String label);

  /// Puce d'un modèle de trajet tarifé par la grille de prix, avec son nom
  ///
  /// In fr, this message translates to:
  /// **'{label} · grille'**
  String tripPublishTemplateChipGrid(String label);

  /// Titre de section (étape Trajet) pour la date limite de dépôt des colis
  ///
  /// In fr, this message translates to:
  /// **'DÉPÔT DES COLIS'**
  String get tripPublishDropoffSectionLabel;

  /// Libellé de la ligne date limite de dépôt des colis
  ///
  /// In fr, this message translates to:
  /// **'Date limite de dépôt'**
  String get tripPublishHandoverDeadlineLabel;

  /// Sous-titre de la ligne date limite de dépôt des colis
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'à quand les expéditeurs peuvent te remettre leurs colis'**
  String get tripPublishHandoverDeadlineSubtitle;

  /// Valeur affichée sur la ligne date limite de dépôt tant qu'aucune date n'est choisie
  ///
  /// In fr, this message translates to:
  /// **'Choisir'**
  String get tripPublishHandoverDeadlineChoose;

  /// Titre du bandeau affiché quand le trajet est créé pour une demande de colis verrouillée
  ///
  /// In fr, this message translates to:
  /// **'Trajet dédié à la demande'**
  String get tripPublishLockedBannerTitle;

  /// Texte du bandeau affiché quand le trajet est créé pour une demande de colis verrouillée
  ///
  /// In fr, this message translates to:
  /// **'Corridor, capacité et prix sont verrouillés. La date doit rester dans la fenêtre de tolérance de l\'expéditeur.'**
  String get tripPublishLockedBannerSubtitle;

  /// Titre de l'intro de publication, rôle expéditeur
  ///
  /// In fr, this message translates to:
  /// **'Publier un colis'**
  String get requestPublishIntroTitle;

  /// Encart vert de l'intro quand l'identité est déjà vérifiée, rôle voyageur
  ///
  /// In fr, this message translates to:
  /// **'Identité vérifiée. Vous pouvez publier votre trajet en toute sécurité.'**
  String get tripPublishIntroVerifiedTextTrip;

  /// Encart vert de l'intro quand l'identité est déjà vérifiée, rôle expéditeur
  ///
  /// In fr, this message translates to:
  /// **'Identité vérifiée. Vous pouvez publier votre demande d\'envoi en toute sécurité.'**
  String get requestPublishIntroVerifiedText;

  /// Titre de la section des engagements de l'intro, rôle voyageur
  ///
  /// In fr, this message translates to:
  /// **'Vos engagements de voyageur'**
  String get tripPublishIntroEngagementsTitleTrip;

  /// Phrase d'introduction de la liste des engagements, rôle voyageur
  ///
  /// In fr, this message translates to:
  /// **'En publiant, vous vous engagez à :'**
  String get tripPublishIntroEngagementsIntroTrip;

  /// Engagement voyageur : transporter le colis soi-même (** = segment en gras)
  ///
  /// In fr, this message translates to:
  /// **'Transporter le colis **vous-même**, sans le confier à un tiers.'**
  String get tripPublishIntroRuleTripCarry;

  /// Engagement voyageur : respecter la date et l'itinéraire (** = segments en gras)
  ///
  /// In fr, this message translates to:
  /// **'Respecter la **date** et l\'**itinéraire** annoncés.'**
  String get tripPublishIntroRuleTripSchedule;

  /// Engagement voyageur : scanner le QR à la remise et à la livraison (** = segment en gras)
  ///
  /// In fr, this message translates to:
  /// **'**Lire le QR** à la remise et à la livraison.'**
  String get tripPublishIntroRuleTripScan;

  /// Engagement voyageur : n'accepter que des contenus autorisés (** = segment en gras)
  ///
  /// In fr, this message translates to:
  /// **'N\'accepter que des **contenus autorisés**, jamais d\'objet illicite.'**
  String get tripPublishIntroRuleTripContent;

  /// Engagement voyageur : remettre le colis au bon destinataire (** = segment en gras)
  ///
  /// In fr, this message translates to:
  /// **'Remettre le colis **au bon destinataire**, en main propre.'**
  String get tripPublishIntroRuleTripHandover;

  /// Titre de la section « pourquoi publier », rôle voyageur
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi publier'**
  String get tripPublishIntroWhyTitleTrip;

  /// Puce « pourquoi publier », rôle voyageur : visibilité
  ///
  /// In fr, this message translates to:
  /// **'Visible par des milliers d\'expéditeurs de la diaspora.'**
  String get tripPublishIntroWhyBulletTripVisibility;

  /// Puce « pourquoi publier », rôle voyageur : revenus
  ///
  /// In fr, this message translates to:
  /// **'Rentabilisez vos kilos libres à chaque voyage.'**
  String get tripPublishIntroWhyBulletTripEarnings;

  /// Puce « pourquoi publier », rôle voyageur : réputation
  ///
  /// In fr, this message translates to:
  /// **'Bâtissez une réputation avec les avis reçus.'**
  String get tripPublishIntroWhyBulletTripReputation;

  /// Titre de la section des engagements de l'intro, rôle expéditeur
  ///
  /// In fr, this message translates to:
  /// **'Vos engagements d\'expéditeur'**
  String get requestPublishIntroEngagementsTitle;

  /// Phrase d'introduction de la liste des engagements, rôle expéditeur
  ///
  /// In fr, this message translates to:
  /// **'En envoyant un colis, vous certifiez :'**
  String get requestPublishIntroEngagementsIntro;

  /// Engagement expéditeur : contenus licites uniquement (** = segment en gras)
  ///
  /// In fr, this message translates to:
  /// **'N\'envoyer que des **contenus licites** et autorisés.'**
  String get requestPublishIntroRuleLicit;

  /// Engagement expéditeur : aucun objet interdit (** = segment en gras)
  ///
  /// In fr, this message translates to:
  /// **'Aucun **objet interdit** (espèces, armes, produits dangereux…).'**
  String get requestPublishIntroRuleForbidden;

  /// Engagement expéditeur : description honnête du contenu (** = segment en gras)
  ///
  /// In fr, this message translates to:
  /// **'Décrire **honnêtement** le contenu et sa valeur si le voyageur la demande.'**
  String get requestPublishIntroRuleHonest;

  /// Engagement expéditeur : emballage soigné (** = segment en gras)
  ///
  /// In fr, this message translates to:
  /// **'**Emballer soigneusement** et décrire précisément le contenu.'**
  String get requestPublishIntroRulePackaging;

  /// Engagement expéditeur : présence à la remise (** = segment en gras)
  ///
  /// In fr, this message translates to:
  /// **'Être présent à la **remise** et indiquer le bon destinataire.'**
  String get requestPublishIntroRuleHandover;

  /// Titre de la section « comment ça marche », rôle expéditeur
  ///
  /// In fr, this message translates to:
  /// **'Comment ça marche'**
  String get requestPublishIntroWhyTitle;

  /// Puce « comment ça marche », rôle expéditeur : transport
  ///
  /// In fr, this message translates to:
  /// **'Un voyageur transporte votre colis dans ses bagages.'**
  String get requestPublishIntroWhyBulletCarried;

  /// Puce « comment ça marche », rôle expéditeur : paiement séquestré
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé, libéré à la livraison confirmée.'**
  String get requestPublishIntroWhyBulletPayment;

  /// Puce « comment ça marche », rôle expéditeur : suivi QR
  ///
  /// In fr, this message translates to:
  /// **'Suivi par QR de la remise jusqu\'à la réception.'**
  String get requestPublishIntroWhyBulletTracking;

  /// Encart d'invite à vérifier son identité avant de publier un trajet. Le segment en gras (identity) et le chemin souligné (path) sont insérés par paramètre puis découpés au rendu
  ///
  /// In fr, this message translates to:
  /// **'Avant de publier, votre **{identity}**. Rendez-vous dans {path} pour la valider (2 min).'**
  String tripPublishIntroVerifyCallout(String identity, String path);

  /// Segment en gras (paramètre identity) de l'encart d'invite à vérifier son identité
  ///
  /// In fr, this message translates to:
  /// **'identité doit être vérifiée'**
  String get tripPublishIntroVerifyIdentity;

  /// Chemin de menu en gras souligné (paramètre path), dans l'encart d'invite à vérifier son identité
  ///
  /// In fr, this message translates to:
  /// **'Profil › Vérifications'**
  String get tripPublishIntroVerifyPath;

  /// Bouton qui ouvre le portail KYC depuis l'intro de publication
  ///
  /// In fr, this message translates to:
  /// **'Vérifier mon identité'**
  String get tripPublishIntroVerifyButton;

  /// Texte sous le bouton de vérification, tant que l'identité n'est pas vérifiée
  ///
  /// In fr, this message translates to:
  /// **'Le bouton devient « {continueLabel} » une fois l\'identité vérifiée.'**
  String tripPublishIntroVerifyHint(String continueLabel);

  /// Titre du rappel Stripe (voyageur) dans l'intro de publication d'un trajet
  ///
  /// In fr, this message translates to:
  /// **'Activez les paiements par carte'**
  String get tripPublishIntroStripeTitle;

  /// Texte du rappel Stripe (voyageur) dans l'intro de publication d'un trajet
  ///
  /// In fr, this message translates to:
  /// **'Configurez votre compte Stripe pour que vos expéditeurs paient par carte, et recevez plus de colis.'**
  String get tripPublishIntroStripeSubtitle;

  /// Option « au kilo » du toggle de mode de tarification, étape Prix & conditions
  ///
  /// In fr, this message translates to:
  /// **'Au kilo'**
  String get tripPublishPricingModeKg;

  /// Option « grille + kilo » du toggle de mode de tarification
  ///
  /// In fr, this message translates to:
  /// **'Grille + kilo'**
  String get tripPublishPricingModeMixed;

  /// Libellé de la section prix au kg, réutilisé comme libellé du champ de prix personnalisé
  ///
  /// In fr, this message translates to:
  /// **'Prix par kg'**
  String get tripPublishPricePerKgSectionLabel;

  /// Titre du toggle « Tarif au kilo », visible en mode grille
  ///
  /// In fr, this message translates to:
  /// **'Tarif au kilo'**
  String get tripPublishKgPriceToggleTitle;

  /// Sous-titre du toggle « Tarif au kilo »
  ///
  /// In fr, this message translates to:
  /// **'Optionnel en mode grille'**
  String get tripPublishKgPriceToggleSubtitle;

  /// Libellé de la puce « Autre prix » du sélecteur de prix au kg
  ///
  /// In fr, this message translates to:
  /// **'Autre prix'**
  String get tripPublishCustomPriceChipLabel;

  /// Indice du champ de saisie du prix personnalisé au kg
  ///
  /// In fr, this message translates to:
  /// **'ex: 12'**
  String get tripPublishCustomPriceFieldHint;

  /// Invite affichée tant qu'aucun prix au kg n'est sélectionné
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un prix pour voir l\'estimation'**
  String get tripPublishPriceSelectPrompt;

  /// Note affichée à la place de l'estimation quand la capacité est Kg libre
  ///
  /// In fr, this message translates to:
  /// **'Capacité illimitée : estimation selon la demande'**
  String get tripPublishUnlimitedCapacityEstimateNote;

  /// Ligne d'estimation du prix au kg, montants déjà formatés dans la devise
  ///
  /// In fr, this message translates to:
  /// **'Vous touchez {travelerNet} · l\'expéditeur paie {senderTotal}'**
  String tripPublishPriceEstimateLine(String travelerNet, String senderTotal);

  /// Note sous l'aperçu de grille en mode mixte, percent déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'Yadony ajoute {percent} % sur chaque article et sur le prix au kilo'**
  String tripPublishGridCommissionNotice(String percent);

  /// Titre du toggle d'ouverture aux propositions de prix des expéditeurs
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les propositions de prix'**
  String get tripPublishNegotiableToggleTitle;

  /// Sous-titre du toggle d'ouverture aux propositions de prix
  ///
  /// In fr, this message translates to:
  /// **'Les expéditeurs pourront vous proposer un montant, vous restez libre de refuser'**
  String get tripPublishNegotiableToggleSubtitle;

  /// Libellé de la section des moyens de paiement acceptés
  ///
  /// In fr, this message translates to:
  /// **'Modes de paiement acceptés'**
  String get tripPublishPaymentMethodsSectionLabel;

  /// Titre de la ligne paiement par carte, Stripe configuré ou non
  ///
  /// In fr, this message translates to:
  /// **'Carte bancaire (Stripe)'**
  String get tripPublishCardPaymentTitle;

  /// Sous-titre de la ligne paiement par carte quand Stripe est configuré
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé par défaut'**
  String get tripPublishCardPaymentSubtitle;

  /// Titre de la ligne paiement en espèces
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get tripPublishCashLabel;

  /// Sous-titre de la ligne paiement en espèces
  ///
  /// In fr, this message translates to:
  /// **'Commission prélevée au voyageur à la remise'**
  String get tripPublishCashSubtitle;

  /// Libellé de la section des contenus acceptés
  ///
  /// In fr, this message translates to:
  /// **'Ce que j\'accepte'**
  String get tripPublishAcceptedContentSectionLabel;

  /// Libellé de la section des contenus refusés
  ///
  /// In fr, this message translates to:
  /// **'Ce que je refuse'**
  String get tripPublishRefusedContentSectionLabel;

  /// Indice du combobox des contenus refusés
  ///
  /// In fr, this message translates to:
  /// **'Ex: Liquides, Denrées périssables…'**
  String get tripPublishRefusedContentHint;

  /// Libellé de la section note libre aux expéditeurs
  ///
  /// In fr, this message translates to:
  /// **'Note aux expéditeurs'**
  String get tripPublishNoteToSendersSectionLabel;

  /// Indice du champ de note libre aux expéditeurs
  ///
  /// In fr, this message translates to:
  /// **'Ex: Je préfère les colis bien emballés. Contactez-moi avant le départ.'**
  String get tripPublishNoteToSendersHint;

  /// Bannière quand Stripe n'est pas configuré mais disponible dans le pays
  ///
  /// In fr, this message translates to:
  /// **'Publiez en espèces dès maintenant. Connectez Stripe pour accepter aussi la carte.'**
  String get tripPublishCashOnlyBannerWithConnect;

  /// Bannière quand Stripe n'est pas disponible dans le pays du voyageur
  ///
  /// In fr, this message translates to:
  /// **'Le paiement par carte n\'est pas encore disponible dans votre pays. Vos trajets sont publiés en espèces.'**
  String get tripPublishCashOnlyBannerNoConnect;

  /// CTA vers l'onboarding Stripe Connect depuis la bannière espèces uniquement
  ///
  /// In fr, this message translates to:
  /// **'Activer les paiements par carte'**
  String get tripPublishActivateCardPaymentsCta;

  /// Sous-titre de la ligne carte verrouillée quand Stripe n'est pas configuré
  ///
  /// In fr, this message translates to:
  /// **'Non configuré, activez pour proposer le paiement sécurisé'**
  String get tripPublishCardNotConfiguredSubtitle;

  /// Bouton d'activation du versement mobile money
  ///
  /// In fr, this message translates to:
  /// **'Activer le versement'**
  String get tripPublishActivatePayoutCta;

  /// Sous-titre mobile money quand la devise n'est pas éligible
  ///
  /// In fr, this message translates to:
  /// **'Disponible pour les trajets en XOF ou XAF'**
  String get tripPublishMobileMoneyIneligibleSubtitle;

  /// Sous-titre mobile money quand le compte de versement n'est pas actif
  ///
  /// In fr, this message translates to:
  /// **'Active d\'abord ton versement mobile money'**
  String get tripPublishMobileMoneyInactiveSubtitle;

  /// Titre de la note remplacant la section prix quand le prix est verrouillé
  ///
  /// In fr, this message translates to:
  /// **'Prix fixé par la négociation'**
  String get tripPublishLockedPriceNoteTitle;

  /// Sous-titre de la note prix verrouillé
  ///
  /// In fr, this message translates to:
  /// **'Le montant de ce colis a été convenu avec l\'expéditeur, non modifiable ici.'**
  String get tripPublishLockedPriceNoteSubtitle;

  /// Libellé de la carte affichant le prix total convenu (trajet dédié)
  ///
  /// In fr, this message translates to:
  /// **'Prix total convenu'**
  String get tripPublishAgreedPriceLabel;

  /// Libellé au-dessus de l'aperçu de grille, étape Prix & conditions
  ///
  /// In fr, this message translates to:
  /// **'Votre grille'**
  String get tripPublishGridPreviewLabel;

  /// Bouton pour ouvrir la feuille listant tous les articles de la grille
  ///
  /// In fr, this message translates to:
  /// **'Voir les {count} articles'**
  String tripPublishGridPreviewSeeAll(int count);

  /// Note sous l'aperçu de grille rappelant que la grille est un réglage de profil
  ///
  /// In fr, this message translates to:
  /// **'Ces prix viennent de votre profil. Les modifier les change sur tous vos trajets.'**
  String get tripPublishGridPreviewNote;

  /// Titre de la feuille listant tous les articles de la grille
  ///
  /// In fr, this message translates to:
  /// **'Votre grille de prix'**
  String get tripPublishGridSheetTitle;

  /// Sous-titre de la feuille de grille complète
  ///
  /// In fr, this message translates to:
  /// **'Valable sur tous vos trajets'**
  String get tripPublishGridSheetSubtitle;

  /// Bouton sticky de la feuille de grille complète
  ///
  /// In fr, this message translates to:
  /// **'Modifier ma grille'**
  String get tripPublishGridSheetEditCta;

  /// Note sous la liste d'articles de la feuille de grille complète
  ///
  /// In fr, this message translates to:
  /// **'Prix payés par l\'expéditeur, commission Yadony de {percent} % comprise.'**
  String tripPublishGridSheetCommissionNote(String percent);

  /// Titre de la carte affichée quand le voyageur choisit le mode grille sans étiquette
  ///
  /// In fr, this message translates to:
  /// **'Votre grille est vide'**
  String get tripPublishGridEmptyTitle;

  /// Sous-titre de la carte grille vide
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins une étiquette pour que les expéditeurs réservent article par article.'**
  String get tripPublishGridEmptySubtitle;

  /// Bouton de la carte grille vide, ouvre l'écran de grille du profil
  ///
  /// In fr, this message translates to:
  /// **'Composer ma grille'**
  String get tripPublishGridComposeCta;

  /// Badge sur l'aperçu du corridor une fois départ et arrivée sélectionnés
  ///
  /// In fr, this message translates to:
  /// **'Confirmé'**
  String get tripPublishCorridorConfirmedBadge;

  /// Libellé de section « Trajet », aussi utilisé comme libellé d'étape du stepper
  ///
  /// In fr, this message translates to:
  /// **'Trajet'**
  String get tripPublishRouteSectionLabel;

  /// Libellé du champ ville de départ verrouillé (corridor fixé par une demande)
  ///
  /// In fr, this message translates to:
  /// **'Ville de départ'**
  String get tripPublishDepartureCityLabel;

  /// Libellé du champ ville d'arrivée verrouillé (corridor fixé par une demande)
  ///
  /// In fr, this message translates to:
  /// **'Ville d\'arrivée'**
  String get tripPublishArrivalCityLabel;

  /// Libellé du champ heure de départ obligatoire
  ///
  /// In fr, this message translates to:
  /// **'Heure de départ'**
  String get tripPublishDepartureTimeLabel;

  /// Libellé du champ heure d'arrivée, optionnel
  ///
  /// In fr, this message translates to:
  /// **'Heure d\'arrivée (optionnel)'**
  String get tripPublishArrivalTimeOptionalLabel;

  /// Tooltip du bouton d'effacement de l'heure d'arrivée
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'heure d\'arrivée'**
  String get tripPublishClearArrivalTimeTooltip;

  /// Libellé du champ date de départ
  ///
  /// In fr, this message translates to:
  /// **'Date de départ'**
  String get tripPublishDepartureDateLabel;

  /// Feedback informatif sous la date de départ quand elle est proche (tiret cadratin d'origine remplacé par un point médian, interdit par les tests arb)
  ///
  /// In fr, this message translates to:
  /// **'🔥 Départ proche · ce trajet sera signalé urgent'**
  String get tripPublishUrgentDepartureWarning;

  /// Titre de la section capacité disponible, réutilisé dans lieux_capacite_step
  ///
  /// In fr, this message translates to:
  /// **'Capacité disponible'**
  String get tripPublishCapacityAvailableLabel;

  /// Quantité de valises et leur poids unitaire, sous le total offert (mode presets valise)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} valise de {kg} kg} other{{count} valises de {kg} kg}}'**
  String tripPublishSuitcaseCount(int count, int kg);

  /// Titre affichant le poids total offert (mode presets valise)
  ///
  /// In fr, this message translates to:
  /// **'Vous offrez {kg} kg'**
  String tripPublishYouOfferKg(int kg);

  /// Semantics du bouton moins du compteur de valises
  ///
  /// In fr, this message translates to:
  /// **'Diminuer la quantité'**
  String get tripPublishDecreaseQuantityTooltip;

  /// Semantics du bouton plus du compteur de valises
  ///
  /// In fr, this message translates to:
  /// **'Augmenter la quantité'**
  String get tripPublishIncreaseQuantityTooltip;

  /// Titre de la carte info capacité Kg libre
  ///
  /// In fr, this message translates to:
  /// **'Capacité illimitée'**
  String get tripPublishUnlimitedCapacityTitle;

  /// Sous-titre de la carte info capacité Kg libre
  ///
  /// In fr, this message translates to:
  /// **'Vendu au kilo · l\'expéditeur choisit son poids'**
  String get tripPublishUnlimitedCapacitySubtitle;

  /// Libellé du champ de saisie libre de la capacité personnalisée
  ///
  /// In fr, this message translates to:
  /// **'Capacité (kg)'**
  String get tripPublishCapacityKgFieldLabel;

  /// Aide sous le champ de capacité personnalisée
  ///
  /// In fr, this message translates to:
  /// **'Indiquez la capacité totale que vous offrez'**
  String get tripPublishCapacityKgFieldHint;

  /// Semantics complet de la bannière de sélection de devise
  ///
  /// In fr, this message translates to:
  /// **'Devise de publication : {currencyName}, {currencyCode}. Les utilisateurs dans une autre devise voient un prix converti. Le paiement reste dans cette devise. Bouton, modifier la devise.'**
  String tripPublishCurrencySemanticsLabel(
    String currencyName,
    String currencyCode,
  );

  /// Titre visible de la bannière de sélection de devise
  ///
  /// In fr, this message translates to:
  /// **'Publié en {currencyName} ({currencyCode})'**
  String tripPublishCurrencyBannerTitle(
    String currencyName,
    String currencyCode,
  );

  /// Sous-titre visible de la bannière de sélection de devise
  ///
  /// In fr, this message translates to:
  /// **'Les utilisateurs dans une autre devise voient un prix converti. Le paiement reste dans cette devise.'**
  String get tripPublishCurrencyBannerSubtitle;

  /// Bouton « Changer » de la bannière de sélection de devise
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get tripPublishCurrencyChangeCta;

  /// Libellé d'étape du stepper de publication (étape 1)
  ///
  /// In fr, this message translates to:
  /// **'Lieux & capacité'**
  String get tripPublishPlacesCapacityStepLabel;

  /// Libellé d'étape du stepper de publication (étape 2)
  ///
  /// In fr, this message translates to:
  /// **'Prix & conditions'**
  String get tripPublishPriceConditionsStepLabel;

  /// Titre de la section lieux de remise et de récupération
  ///
  /// In fr, this message translates to:
  /// **'Lieux de remise'**
  String get tripPublishHandoverLocationsLabel;

  /// Sous-titre de la section lieux de remise et de récupération
  ///
  /// In fr, this message translates to:
  /// **'Précisez l\'endroit exact de remise et récupération'**
  String get tripPublishHandoverLocationsSubtitle;

  /// Note sous la capacité verrouillée (flux trajet dédié)
  ///
  /// In fr, this message translates to:
  /// **'Capacité fixée par la demande'**
  String get tripPublishLockedCapacityNote;

  /// Libellé de repli utilisé comme adresse quand le géocodage inverse échoue : coordonnées brutes formatées (address_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Position GPS ({lat}, {lng})'**
  String addressGpsPosition(String lat, String lng);

  /// Titre de la sheet d'info quand le service de localisation est coupé (sélecteurs d'adresse et champ d'adresse)
  ///
  /// In fr, this message translates to:
  /// **'GPS désactivé'**
  String get addressGpsDisabledTitle;

  /// Titre de la sheet d'info quand la permission de localisation est refusée (sélecteurs d'adresse et champ d'adresse)
  ///
  /// In fr, this message translates to:
  /// **'Localisation refusée'**
  String get addressLocationDeniedTitle;

  /// Titre de la sheet d'info quand la permission de localisation est refusée définitivement (sélecteurs d'adresse et champ d'adresse)
  ///
  /// In fr, this message translates to:
  /// **'Localisation définitivement refusée'**
  String get addressLocationDeniedForeverTitle;

  /// Message de la sheet d'info GPS désactivé (sélecteurs d'adresse et champ d'adresse)
  ///
  /// In fr, this message translates to:
  /// **'Activez la géolocalisation dans vos paramètres système.'**
  String get addressGpsDisabledMessage;

  /// Message de la sheet d'info permission de localisation refusée (sélecteurs d'adresse et champ d'adresse)
  ///
  /// In fr, this message translates to:
  /// **'Activez la localisation dans vos paramètres pour utiliser cette fonctionnalité.'**
  String get addressLocationDeniedMessage;

  /// Bouton de la sheet d'info localisation/GPS (sélecteurs d'adresse et champ d'adresse)
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les paramètres'**
  String get addressOpenSettingsButton;

  /// Titre de la sheet d'info quand aucun fix GPS n'est disponible (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Position indisponible'**
  String get addressPositionUnavailableTitle;

  /// Message de la sheet d'info position indisponible (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de récupérer votre position pour le moment. Réessayez.'**
  String get addressPositionUnavailableMessage;

  /// Titre de la sheet d'info quand le géocodage inverse échoue après 3 tentatives (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Adresse introuvable'**
  String get addressReverseGeocodeFailedTitle;

  /// Message de la sheet d'info géocodage inverse en échec (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de convertir votre position en adresse. Réessayez.'**
  String get addressReverseGeocodeFailedMessage;

  /// SnackBar affiché quand la résolution d'une suggestion échoue (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de sélectionner cette adresse. Réessayez.'**
  String get addressSelectFailedMessage;

  /// Placeholder du champ de recherche inline des sélecteurs d'adresse pickup/delivery
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une adresse…'**
  String get addressSearchHint;

  /// Bouton de validation des sélecteurs d'adresse pickup/delivery
  ///
  /// In fr, this message translates to:
  /// **'Confirmer cette adresse'**
  String get addressConfirmButton;

  /// Titre de l'état vide hors ligne de la recherche d'adresse (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Connexion requise'**
  String get addressOfflineTitle;

  /// Sous-titre de l'état vide hors ligne de la recherche d'adresse (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre connexion pour rechercher une adresse.'**
  String get addressOfflineSubtitle;

  /// Titre de l'état d'erreur de la recherche d'adresse (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get addressSearchErrorTitle;

  /// Sous-titre de l'état d'erreur de la recherche d'adresse (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de rechercher une adresse. Réessayez.'**
  String get addressSearchErrorSubtitle;

  /// Titre de l'état vide sans résultat de la recherche d'adresse (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get addressNoResultsTitle;

  /// Sous-titre de l'état vide sans résultat de la recherche d'adresse (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Essayez « Utiliser ma position actuelle ».'**
  String get addressNoResultsSubtitle;

  /// Libellé du bouton GPS (sélecteurs d'adresse pickup/delivery et champ d'adresse)
  ///
  /// In fr, this message translates to:
  /// **'Utiliser ma position actuelle'**
  String get addressUseCurrentLocation;

  /// En-tête de section des adresses récentes (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'RECHERCHES RÉCENTES'**
  String get addressRecentSearchesHeader;

  /// En-tête de section des adresses enregistrées (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'MES ADRESSES ENREGISTRÉES'**
  String get addressSavedAddressesHeader;

  /// Titre de la tuile d'ajout d'adresse (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une adresse'**
  String get addressAddNewTitle;

  /// Sous-titre de la tuile d'ajout d'adresse (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer pour la prochaine fois'**
  String get addressAddNewSubtitle;

  /// Badge sur l'adresse enregistrée par défaut (sélecteurs d'adresse pickup/delivery)
  ///
  /// In fr, this message translates to:
  /// **'Par défaut'**
  String get addressDefaultBadge;

  /// Titre du sélecteur d'adresse de remise (pickup_address_picker_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'📦  Adresse de remise'**
  String get addressPickupSheetTitle;

  /// Titre du sélecteur d'adresse de livraison (delivery_address_picker_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'🗺️  Adresse de livraison'**
  String get addressDeliverySheetTitle;

  /// Message de validation quand le champ d'adresse obligatoire est vide (address_picker_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Adresse obligatoire'**
  String get addressFieldRequiredError;

  /// Placeholder du champ d'adresse une fois focalisé (address_picker_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tapez pour rechercher une adresse…'**
  String get addressFieldSearchHint;

  /// Message affiché quand la recherche du champ d'adresse ne renvoie rien (address_picker_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat, essayez \"Ma position actuelle\"'**
  String get addressFieldNoResultsHint;

  /// Message inline hors ligne sous le champ d'adresse (address_picker_field.dart et address_suggest_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Connexion requise pour la recherche d\'adresse'**
  String get addressOfflineInlineMessage;

  /// Libellé de la carte vide du sélecteur d'adresse de remise (address_selector_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Choisir une adresse de remise'**
  String get addressSelectorDropoffLabel;

  /// Sous-titre de la carte vide du sélecteur d'adresse de remise (address_selector_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Où tu récupères les colis des expéditeurs'**
  String get addressSelectorDropoffSubtitle;

  /// Libellé de la carte vide du sélecteur d'adresse de livraison (address_selector_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Choisir une adresse de livraison'**
  String get addressSelectorDeliveryLabel;

  /// Sous-titre de la carte vide du sélecteur d'adresse de livraison (address_selector_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Où tu déposes les colis à destination'**
  String get addressSelectorDeliverySubtitle;

  /// Motif intl DateFormat, pas un texte : heure de l'échéance de l'affiche du trajet (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'HH\'h\'mm'**
  String get tripPosterTimePattern;

  /// Libellé de la ligne date de départ sur l'affiche du trajet (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get tripPosterDepartureLabel;

  /// Libellé de la ligne date limite de dépôt sur l'affiche du trajet (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Dernier dépôt'**
  String get tripPosterDeadlineLabel;

  /// Libellé de la ligne capacité disponible sur l'affiche du trajet (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Place disponible'**
  String get tripPosterCapacityLabel;

  /// Libellé du lieu de remise (pickupAddress) sur l'affiche du trajet (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remise'**
  String get tripPosterHandoverLabel;

  /// Libellé du lieu de récupération (deliveryAddress) sur l'affiche du trajet (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Récupération'**
  String get tripPosterPickupLabel;

  /// Montant affiché en grand sur l'affiche quand le trajet a une grille de prix (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'dès {price}'**
  String tripPosterFromPrice(String price);

  /// Unité affichée à côté du prix quand il s'agit d'un tarif à l'article (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'l\'article'**
  String get tripPosterUnitPerItem;

  /// Unité affichée à côté du prix quand il s'agit d'un tarif au kilo (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'le kilo'**
  String get tripPosterUnitPerKg;

  /// Prix affiché quand ni la grille ni le tarif au kilo ne sont renseignés (trip_poster_card.dart, trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix indisponible'**
  String get tripPosterPriceUnavailable;

  /// Tarif au kilo secondaire sous le prix de grille (trip_poster_card.dart), et phrase de prix de la légende partageable (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'{price} le kilo'**
  String tripPosterPricePerKg(String price);

  /// Phrase de prix à l'article dans la légende partageable de l'affiche (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'dès {price} l\'article'**
  String tripPosterPriceFromItem(String price);

  /// Accroche en pied de l'affiche du trajet (trip_poster_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé, suivi du colis, voyageurs vérifiés'**
  String get tripPosterTagline;

  /// Titre de l'écran d'aperçu de l'affiche du trajet (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mon affiche'**
  String get tripPosterTitle;

  /// Titre de l'état vide quand le trajet de l'affiche ne charge pas (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet introuvable'**
  String get tripPosterNotFoundTitle;

  /// Description de l'état vide quand le trajet de l'affiche ne charge pas (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger ce trajet pour le moment.'**
  String get tripPosterNotFoundDescription;

  /// Première ligne de la légende partageable : corridor du trajet (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'{departure} vers {arrival}'**
  String tripPosterCaptionCorridor(String departure, String arrival);

  /// Ligne date de départ de la légende partageable (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Départ le {day}'**
  String tripPosterCaptionDeparture(String day);

  /// Ligne date limite de dépôt de la légende partageable (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Dernier dépôt le {deadline}'**
  String tripPosterCaptionDeadline(String deadline);

  /// Ligne lieu de remise de la légende partageable (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remise : {address}'**
  String tripPosterCaptionHandover(String address);

  /// Ligne lieu de récupération de la légende partageable (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Récupération : {address}'**
  String tripPosterCaptionPickup(String address);

  /// Appel à l'action avant le lien, dans la légende partageable (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Réservez vos kilos ici :'**
  String get tripPosterCaptionCta;

  /// Dernière ligne de la légende partageable (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé, suivi du colis, voyageur vérifié.'**
  String get tripPosterCaptionFooter;

  /// Objet du partage système de l'affiche (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet {departure} vers {arrival}'**
  String tripPosterShareSubject(String departure, String arrival);

  /// Message d'échec du partage de l'affiche (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de partager l\'affiche'**
  String get tripPosterShareError;

  /// Message d'échec de l'enregistrement de l'affiche dans la galerie (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer l\'affiche'**
  String get tripPosterSaveError;

  /// Message de succès de l'enregistrement de l'affiche dans la galerie (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Affiche enregistrée dans votre galerie'**
  String get tripPosterSaveSuccess;

  /// Confirmation après copie de la légende de l'affiche (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Légende copiée'**
  String get tripPosterCaptionCopied;

  /// Confirmation après copie du lien de l'affiche (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lien copié'**
  String get tripPosterLinkCopiedMessage;

  /// Texte d'instructions sous l'aperçu de l'affiche (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Postez cette affiche comme d\'habitude, puis collez la légende dans le texte de votre publication. Le lien y devient cliquable, ce qui n\'est pas le cas d\'une adresse écrite sur l\'image.'**
  String get tripPosterInstructions;

  /// Bouton de partage de l'affiche (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Partager l\'affiche'**
  String get tripPosterShareButton;

  /// Bouton de copie de la légende de l'affiche (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Copier la légende'**
  String get tripPosterCopyCaptionButton;

  /// Bouton de copie du lien de l'affiche (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get tripPosterCopyLinkButton;

  /// Bouton d'enregistrement de l'affiche dans la galerie (trip_poster_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer dans la galerie'**
  String get tripPosterSaveButton;

  /// Titre du catalogue d'erreurs pour le code announcement-update-blocked : modification refusée car des colis sont déjà acceptés (error_catalog.dart, announcement_bloc.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modification impossible'**
  String get errorAnnouncementUpdateBlockedTitle;

  /// Message du catalogue d'erreurs pour le code announcement-update-blocked (error_catalog.dart, announcement_bloc.dart)
  ///
  /// In fr, this message translates to:
  /// **'Des colis sont déjà acceptés pour ce trajet'**
  String get errorAnnouncementUpdateBlockedMessage;

  /// Titre de l'écran liste des modèles de trajet (trip_templates_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mes modèles de trajet'**
  String get tripTemplateListTitle;

  /// Tooltip du bouton d'ajout de la liste des modèles (trip_templates_screen.dart) et titre de l'écran d'édition en mode création (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Nouveau modèle'**
  String get tripTemplateNewLabel;

  /// Titre de l'état d'erreur de la liste des modèles de trajet (trip_templates_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get tripTemplateLoadErrorTitle;

  /// Description de repli de l'état d'erreur, quand le serveur n'a pas fourni de message (trip_templates_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue.'**
  String get tripTemplateLoadErrorFallback;

  /// Titre de l'état vide de la liste des modèles de trajet (trip_templates_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun modèle'**
  String get tripTemplateEmptyTitle;

  /// Description de l'état vide de la liste des modèles de trajet (trip_templates_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Crée des modèles de trajet réutilisables pour publier tes annonces en quelques secondes.'**
  String get tripTemplateEmptyDescription;

  /// Bouton d'action de l'état vide de la liste des modèles de trajet (trip_templates_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Créer un modèle'**
  String get tripTemplateCreateAction;

  /// Repli affiché à la place du tarif au kilo quand le modèle vend à la grille (trip_templates_screen.dart, trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'prix à la grille'**
  String get tripTemplateGridPriceLabel;

  /// Titre du dialogue de confirmation de suppression d'un modèle (trip_templates_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le modèle'**
  String get tripTemplateDeleteDialogTitle;

  /// Message du dialogue de confirmation de suppression d'un modèle (trip_templates_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir supprimer \"{label}\" ? Cette action est irréversible.'**
  String tripTemplateDeleteDialogMessage(String label);

  /// Entrée du menu d'une carte modèle pour programmer sa récurrence (trip_templates_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Programmer la récurrence'**
  String get tripTemplateScheduleRecurrenceAction;

  /// Titre de section, étape Trajet du formulaire de modèle (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'NOM DU MODÈLE'**
  String get tripTemplateNameSectionLabel;

  /// Libellé du champ nom du modèle (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get tripTemplateNameFieldLabel;

  /// Placeholder du champ nom du modèle (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ex : Mon Paris → Dakar'**
  String get tripTemplateNameFieldHint;

  /// Titre de section, étape Trajet du formulaire de modèle (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'TRAJET'**
  String get tripTemplateTripSectionLabel;

  /// Titre de section, étape Trajet du formulaire de modèle (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'MODE DE TRANSPORT'**
  String get tripTemplateTransportSectionLabel;

  /// Titre de section, étape Trajet du formulaire de modèle (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'HORAIRES'**
  String get tripTemplateScheduleSectionLabel;

  /// Libellé complet du champ heure de départ, utilisé au placeholder et en annonce d'accessibilité (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Heure de départ'**
  String get tripTemplateDepartureTimeFieldLabel;

  /// Libellé court affiché en préfixe une fois l'heure de départ posée (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get tripTemplateDepartureShortLabel;

  /// Libellé complet du champ heure d'arrivée, utilisé au placeholder et en annonce d'accessibilité (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Heure d\'arrivée'**
  String get tripTemplateArrivalTimeFieldLabel;

  /// Libellé court affiché en préfixe une fois l'heure d'arrivée posée (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Arrivée'**
  String get tripTemplateArrivalShortLabel;

  /// Titre de section, étape Trajet du formulaire de modèle (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'DÉLAI DE REMISE'**
  String get tripTemplateHandoverDeadlineSectionLabel;

  /// Texte d'aide sous le titre de la section délai de remise (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Au plus tard combien de jours avant le départ le colis doit être remis ?'**
  String get tripTemplateHandoverDeadlineHint;

  /// Choix de délai de remise : aucun délai mémorisé (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get tripTemplateHandoverNone;

  /// Choix de délai de remise : le jour du départ (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le jour même'**
  String get tripTemplateHandoverSameDay;

  /// Choix de délai de remise : N jours avant le départ (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} jour avant} other{{count} jours avant}}'**
  String tripTemplateHandoverDaysBefore(int count);

  /// Placeholder d'un champ heure tant qu'aucune heure n'est posée (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'{label} (optionnel)'**
  String tripTemplateOptionalSuffix(String label);

  /// Libellé d'accessibilité du bouton d'effacement d'un champ heure (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Effacer {label}'**
  String tripTemplateClearFieldSemantic(String label);

  /// Titre de l'écran d'édition d'un modèle existant (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modifier le modèle'**
  String get tripTemplateEditTitle;

  /// Bouton de la dernière étape du formulaire de modèle (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le modèle'**
  String get tripTemplateSaveButton;

  /// Confirmation après mise à jour d'un modèle existant (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modèle mis à jour'**
  String get tripTemplateUpdatedMessage;

  /// Confirmation après création d'un nouveau modèle (trip_template_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modèle enregistré'**
  String get tripTemplateSavedMessage;

  /// Confirmation après activation d'une récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Récurrence activée. Tes trajets seront publiés automatiquement.'**
  String get tripTemplateRecurrenceActivatedMessage;

  /// Titre de l'écran de programmation d'une récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet récurrent'**
  String get tripTemplateRecurrenceTitle;

  /// Bouton de validation de l'écran de récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Activer la récurrence'**
  String get tripTemplateActivateRecurrenceButton;

  /// Avertissement quand le modèle source n'a pas de prix au kilo éditable (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ce modèle n\'a pas de prix au kilo'**
  String get tripTemplateNoPricePerKgWarning;

  /// Titre de section de l'écran de récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'JOURS DE RÉPÉTITION'**
  String get tripTemplateRepeatDaysSectionLabel;

  /// Titre de section de l'écran de récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'HEURE DE DÉPART'**
  String get tripTemplateRecurrenceDepartureTimeSectionLabel;

  /// Placeholder du champ heure de départ tant qu'aucune heure n'est posée (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Optionnel : choisir une heure'**
  String get tripTemplateOptionalTimeHint;

  /// Libellé d'accessibilité du bouton d'effacement de l'heure de départ (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'heure de départ'**
  String get tripTemplateClearTimeSemantic;

  /// Titre de section de l'écran de récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'LIEUX'**
  String get tripTemplateLocationsSectionLabel;

  /// Libellé du champ adresse de remise de l'écran de récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lieu de remise du colis *'**
  String get tripTemplatePickupFieldLabel;

  /// Libellé du champ adresse de récupération de l'écran de récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lieu de récupération *'**
  String get tripTemplateDeliveryFieldLabel;

  /// Titre du bloc bascule d'activation de la récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Récurrence active'**
  String get tripTemplateActiveLabel;

  /// Sous-titre du bloc bascule d'activation de la récurrence (trip_recurrence_edit_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publie automatiquement les trajets à venir'**
  String get tripTemplateActiveDescription;

  /// Traduction affichée du code catalogue DOCUMENTS — ContentCategory.label reste la valeur envoyée/stockée, en français (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Documents & administratif'**
  String get contentCategoryDocuments;

  /// Traduction affichée du code catalogue ALIMENTATION_SECHE (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Alimentation sèche'**
  String get contentCategoryDryFood;

  /// Traduction affichée du code catalogue PRODUITS_FRAIS (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Produits frais / périssables'**
  String get contentCategoryFreshFood;

  /// Traduction affichée du code catalogue COSMETIQUES (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cosmétiques & parfums'**
  String get contentCategoryCosmetics;

  /// Traduction affichée du code catalogue VETEMENTS (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vêtements & tissus'**
  String get contentCategoryClothing;

  /// Traduction affichée du code catalogue CHAUSSURES (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Chaussures'**
  String get contentCategoryShoes;

  /// Traduction affichée du code catalogue MEDICAMENTS_TRADITIONNELS (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Médicaments traditionnels'**
  String get contentCategoryTraditionalMedicine;

  /// Traduction affichée du code catalogue ELECTRONIQUE (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Téléphone & électronique'**
  String get contentCategoryElectronics;

  /// Traduction affichée du code catalogue LIVRES (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livres'**
  String get contentCategoryBooks;

  /// Traduction affichée du code catalogue CADEAUX (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cadeaux & jouets'**
  String get contentCategoryGifts;

  /// Traduction affichée du code catalogue AUTRE (content_category_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get contentCategoryOther;

  /// Ligne « Ajouter … » du sélecteur de catégories pour un libellé libre (content_category_selector.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter « {label} »'**
  String contentCategoryAdd(String label);

  /// Libellé d'accessibilité du bouton de suppression d'un tag catégorie (content_category_selector.dart)
  ///
  /// In fr, this message translates to:
  /// **'Retirer cette catégorie'**
  String get contentCategoryRemove;

  /// Libellé affiché du moyen de paiement STRIPE (package_request_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get paymentMethodCard;

  /// Libellé affiché du moyen de paiement CASH (package_request_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get paymentMethodCash;

  /// Libellé affiché du moyen de paiement MOBILE_MONEY (package_request_labels.dart) — identique dans les deux langues
  ///
  /// In fr, this message translates to:
  /// **'Mobile money'**
  String get paymentMethodMobileMoney;

  /// Prix net vu par le voyageur dans le fil de négociation (package_request_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu reçois {amount}'**
  String requestThreadYouReceive(String amount);

  /// Prix brut vu par l'expéditeur dans le fil de négociation (package_request_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu paies {amount}'**
  String requestThreadYouPay(String amount);

  /// Fourchette de poids autorisée pour une demande d'envoi (package_request_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'Entre {min} et {max} kg'**
  String requestWeightRange(String min, String max);

  /// Nom de repli d'un profil expéditeur sans nom (package_request_labels.dart, package_request_search_item.dart)
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur Yadony'**
  String get requestSenderFallbackName;

  /// Erreur de soumission de l'étape 3 du wizard de demande sans budget saisi (package_request_form_bloc.dart)
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un budget pour continuer'**
  String get requestBudgetRequired;

  /// Libellé relatif : demande créée/publiée à l'instant (request_time_label.dart)
  ///
  /// In fr, this message translates to:
  /// **'{verb, select, created{créée à l\'instant} other{publiée à l\'instant}}'**
  String requestTimeJustNow(String verb);

  /// Libellé relatif : il y a N minutes (request_time_label.dart)
  ///
  /// In fr, this message translates to:
  /// **'{verb, select, created{créée il y a {minutes} min} other{publiée il y a {minutes} min}}'**
  String requestTimeMinutesAgo(String verb, int minutes);

  /// Libellé relatif : il y a N heures, même jour (request_time_label.dart)
  ///
  /// In fr, this message translates to:
  /// **'{verb, select, created{créée il y a {hours} h} other{publiée il y a {hours} h}}'**
  String requestTimeHoursAgo(String verb, int hours);

  /// Libellé relatif : hier à telle heure (request_time_label.dart)
  ///
  /// In fr, this message translates to:
  /// **'{verb, select, created{créée hier, {time}} other{publiée hier, {time}}}'**
  String requestTimeYesterday(String verb, String time);

  /// Libellé relatif : à telle date, plus ancien qu'hier (request_time_label.dart)
  ///
  /// In fr, this message translates to:
  /// **'{verb, select, created{créée le {date}} other{publiée le {date}}}'**
  String requestTimeOn(String verb, String date);

  /// Texte d'indication par défaut du champ de sélection de catégories, quand l'appelant ne le surcharge pas (content_category_selector.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un type de contenu…'**
  String get contentCategoryHintDefault;

  /// Titre du dialogue de confirmation avant d'éditer une demande en négociation (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modifier votre demande ?'**
  String get requestCreateEditWarningTitle;

  /// Message du dialogue de confirmation avant d'éditer une demande en négociation (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Des voyageurs négocient actuellement cette demande. La modifier annulera toutes les offres en cours. Ils devront vous reproposer un trajet.'**
  String get requestCreateEditWarningMessage;

  /// Bouton de confirmation du dialogue d'édition d'une demande en négociation (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modifier quand même'**
  String get requestCreateEditWarningConfirm;

  /// Titre de l'app bar, étape 1 en mode édition (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modifier la demande'**
  String get requestCreateStepTitleEdit;

  /// Titre de l'app bar, étape 1 en création (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le trajet'**
  String get requestCreateStepTitleTrip;

  /// Titre de l'app bar, étape 2 (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le colis'**
  String get requestCreateStepTitlePackage;

  /// Titre de l'app bar, étape 3 (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le budget'**
  String get requestCreateStepTitleBudget;

  /// Titre de l'écran succès après enregistrement d'un brouillon (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Brouillon enregistré !'**
  String get requestCreateDraftSavedTitle;

  /// Titre de l'écran succès après édition d'une demande (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande modifiée !'**
  String get requestCreateEditedTitle;

  /// Titre de l'écran succès après publication d'une demande (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande publiée !'**
  String get requestCreatePublishedTitle;

  /// Sous-titre de l'écran succès après enregistrement d'un brouillon (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez la publier quand vous le souhaitez.'**
  String get requestCreateDraftSavedSubtitle;

  /// Sous-titre de l'écran succès après édition d'une demande (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vos modifications sont en ligne.'**
  String get requestCreateEditedSubtitle;

  /// Sous-titre de l'écran succès après publication d'une demande (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Les voyageurs sont notifiés. Vous recevrez des offres très vite.'**
  String get requestCreatePublishedSubtitle;

  /// CTA de l'écran succès, brouillon (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir mon brouillon'**
  String get requestCreateViewDraftCta;

  /// CTA de l'écran succès, demande publiée/modifiée (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir ma demande'**
  String get requestCreateViewRequestCta;

  /// Message d'erreur de repli si la soumission échoue sans exception typée (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création'**
  String get requestCreateGenericError;

  /// Titre du dialogue quand la limite de brouillons (compte gratuit) est atteinte (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Limite de brouillons atteinte'**
  String get requestCreateDraftLimitTitle;

  /// Préfixe de la mention légale au-dessus du CTA de publication (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'En publiant, vous acceptez les '**
  String get requestCreateCguPrefix;

  /// Lien tappable vers les CGU, dans la mention légale de publication (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'CGU'**
  String get requestCreateCguLink;

  /// Libellé du CTA sticky pendant la soumission (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publication…'**
  String get requestCreatePublishingLabel;

  /// Libellé du CTA sticky à la dernière étape, avant soumission (package_request_create_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get requestCreatePreviewButton;

  /// Erreur de validation : ville de départ manquante (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ville de départ obligatoire'**
  String get requestCreateDepartureRequired;

  /// Erreur de validation : ville d'arrivée manquante (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ville d\'arrivée obligatoire'**
  String get requestCreateArrivalRequired;

  /// Erreur de validation : ville d'arrivée identique au départ (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une ville différente du départ'**
  String get requestCreateArrivalSameAsDeparture;

  /// Erreur de validation : date de départ manquante (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date de départ obligatoire'**
  String get requestCreateDateRequired;

  /// Explication de la tolérance de date quand elle vaut 0 (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'Seuls les voyageurs partant exactement ce jour-là pourront répondre.'**
  String get requestCreateToleranceExactHint;

  /// Explication de la tolérance de date avant sélection d'une date de départ (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{± {count} jour autour de votre date. Plus de souplesse, plus de voyageurs.} other{± {count} jours autour de votre date. Plus de souplesse, plus de voyageurs.}}'**
  String requestCreateToleranceGenericHint(int count);

  /// Explication de la tolérance de date une fois une date de départ choisie (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'Les voyageurs partant du {from} au {to} pourront répondre.'**
  String requestCreateToleranceRangeHint(String from, String to);

  /// Sous-texte du bloc mode de transport verrouillé sur avion (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'seul mode disponible'**
  String get requestCreateAirplaneOnlyMode;

  /// Libellé de section en tête de l'étape 1 (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'TRAJET'**
  String get requestCreateTrajetSectionLabel;

  /// Titre de l'étape 1 (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'D\'où vers où ?'**
  String get requestCreateTrajetQuestion;

  /// Libellé du champ date et texte de repli tant qu'aucune date n'est choisie (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get requestCreateDateFieldLabel;

  /// Libellé du champ de tolérance de date (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'Souplesse'**
  String get requestCreateToleranceFieldLabel;

  /// Feedback informatif sous la date quand elle est proche (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'🔥 Date proche, cette demande sera signalée urgente'**
  String get requestCreateUrgentDateHint;

  /// Libellé compact du pill de tolérance de date sélectionnée (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'± {count} j'**
  String requestCreateToleranceShort(int count);

  /// Option "tolérance 0" de la feuille de sélection de tolérance de date (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date exacte'**
  String get requestCreateDateExact;

  /// Options de tolérance de date non nulles de la feuille de sélection (step_1_trajet_colis.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{± {count} jour} other{± {count} jours}}'**
  String requestCreateDateFlex(int count);

  /// Erreur : nombre maximal de catégories dépassé (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Maximum {max} catégories'**
  String requestCreateMaxCategories(int max);

  /// Erreur de validation : aucune catégorie de contenu choisie (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Choisissez au moins une catégorie'**
  String get requestCreateCategoryRequired;

  /// Titre de la feuille de précision libre après sélection de "Autre" (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Précisez le contenu (optionnel)'**
  String get requestCreateAutrePrecisionTitle;

  /// Sous-titre de la feuille de précision libre après sélection de "Autre" (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ça aide le voyageur à savoir ce qu\'il transporte.'**
  String get requestCreateAutrePrecisionSubtitle;

  /// Bouton de la feuille de précision libre après sélection de "Autre" (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get requestCreateAutrePrecisionValidate;

  /// Texte d'indication du champ de précision libre (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ex. Instruments de musique'**
  String get requestCreateAutrePrecisionHint;

  /// Titre de l'étape 2 (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre colis'**
  String get requestCreateStep2Title;

  /// Sous-titre de l'étape 2 (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ces infos aident les voyageurs à savoir s\'ils peuvent transporter votre envoi.'**
  String get requestCreateStep2Subtitle;

  /// Libellé du champ poids (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Poids approximatif'**
  String get requestCreateWeightLabel;

  /// Libellé du champ de sélection des catégories de contenu (step_2_details.dart) ; réutilisé pour la ligne contenu de l'aperçu et des cartes récapitulatives (package_request_preview_sheet.dart, wizard_summary_card.dart, complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Contenu'**
  String get requestCreateContentLabel;

  /// Texte d'aide sous le libellé "Contenu" (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tapez pour chercher, ou écrivez votre propre catégorie.'**
  String get requestCreateContentHint;

  /// Libellé du champ description (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get requestCreateDescriptionLabel;

  /// Texte d'indication du champ description (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Précisions utiles : fragile, contenu exact, instructions de remise…'**
  String get requestCreateDescriptionHint;

  /// Erreur de validation : poids non numérique (step_2_details.dart)
  ///
  /// In fr, this message translates to:
  /// **'Valeur invalide'**
  String get requestCreateWeightInvalid;

  /// Sous-titre de l'étape 3 (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre demande, puis indiquez le budget à montrer aux voyageurs.'**
  String get requestCreateBudgetSubtitle;

  /// Libellé du choix du mode de prix (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Comment fixer le prix ?'**
  String get requestCreatePriceModeLabel;

  /// Titre de la carte "prix négociable" (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'J\'ouvre aux offres'**
  String get requestCreatePriceModeOpenTitle;

  /// Sous-titre de la carte "prix négociable" (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Les voyageurs proposent leur prix, vous choisissez.'**
  String get requestCreatePriceModeOpenSubtitle;

  /// Titre de la carte "prix ferme" (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Je fixe mon prix'**
  String get requestCreatePriceModeFixedTitle;

  /// Sous-titre de la carte "prix ferme" (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Un montant ferme, sans négociation.'**
  String get requestCreatePriceModeFixedSubtitle;

  /// Libellé du sélecteur de devise (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get requestCreateCurrencyLabel;

  /// Libellé du champ budget en mode négociable (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Budget indicatif'**
  String get requestCreateBudgetLabelNegotiable;

  /// Libellé du champ budget en mode prix ferme (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Votre prix'**
  String get requestCreateBudgetLabelFixed;

  /// Texte d'aide sous le champ budget en mode négociable (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Donnez un ordre d\'idée pour attirer plus d\'offres, sans vous engager.'**
  String get requestCreateBudgetHintNegotiable;

  /// Texte d'aide sous le champ budget en mode prix ferme (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Les voyageurs verront ce montant et pourront l\'accepter tel quel.'**
  String get requestCreateBudgetHintFixed;

  /// Libellé du champ code promo (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Code promo (optionnel)'**
  String get requestCreatePromoLabel;

  /// Texte d'indication du champ code promo (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ex: WELCOME10'**
  String get requestCreatePromoHint;

  /// Message de repli quand le serveur confirme un code promo sans libellé (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Code appliqué'**
  String get requestCreatePromoAppliedFallback;

  /// Libellé de la section des moyens de paiement acceptés (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement accepté'**
  String get requestCreatePaymentAcceptedLabel;

  /// Texte d'aide sous le libellé des moyens de paiement (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Choisissez comment vous paierez le voyageur.'**
  String get requestCreatePaymentHint;

  /// Message quand l'expéditeur tente de décocher le dernier mode de paiement (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Gardez au moins un mode de paiement.'**
  String get requestCreateKeepOnePaymentMethod;

  /// Bandeau informatif en fin d'étape 3 (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Une fois publiée, les voyageurs sur ce trajet sont prévenus. Vous recevrez une notification à la première offre.'**
  String get requestCreatePublishInfoBanner;

  /// Texte d'indication du champ budget total (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ex. 40,00'**
  String get requestCreateBudgetInputHint;

  /// Erreur de validation : champ budget vide (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un budget'**
  String get requestCreateBudgetEmpty;

  /// Erreur de validation : budget hors bornes (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Entre {min} et {max}'**
  String requestCreateBudgetRange(String min, String max);

  /// Libellé de la ligne commission de la décomposition du budget (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Commission Yadony ({rate} %)'**
  String requestCreateCommissionLabel(String rate);

  /// Libellé de la ligne de bonus promo dans la décomposition du budget (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Grâce au code promo, le voyageur touche'**
  String get requestCreatePromoBoostLabel;

  /// Libellé de la ligne du net voyageur dans la décomposition du budget (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur touchera'**
  String get requestCreateTravelerReceivesLabel;

  /// Libellé d'accessibilité du sélecteur de devise (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Devise de la demande : {name}, {code}. Bouton, modifier la devise.'**
  String requestCreateCurrencySemanticLabel(String name, String code);

  /// Lien de modification de la devise, dans la ligne du sélecteur (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get requestCreateChangeCurrency;

  /// Erreur affichée quand la photo choisie est refusée (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Image non supportée ou trop volumineuse'**
  String get requestCreatePhotoUnsupported;

  /// Option caméra de la feuille de choix de source photo (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get requestCreateTakePhoto;

  /// Option galerie de la feuille de choix de source photo (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get requestCreatePickFromGallery;

  /// Titre de la section photos de l'étape 2 (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Photos du colis'**
  String get requestCreatePhotosLabel;

  /// Texte d'aide sous le titre de la section photos (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Visibles par les voyageurs. Ajoutées à l\'offre quand un trajet est lié.'**
  String get requestCreatePhotosHint;

  /// Libellé d'accessibilité du bouton d'ajout de photo (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo du colis'**
  String get requestCreateAddPhotoSemantic;

  /// Message d'échec d'upload sans raison connue (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'upload de la photo'**
  String get requestCreatePhotoUploadFailed;

  /// Message d'échec d'upload avec raison connue (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Échec : {reason}'**
  String requestCreatePhotoUploadFailedWithReason(String reason);

  /// Libellé d'accessibilité du bouton de réessai d'une photo en échec (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Réessayer l\'envoi de la photo'**
  String get requestCreateRetryPhotoUpload;

  /// Titre du CTA plein largeur d'ajout de photo, aucune photo encore ajoutée (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get requestCreateAddPhotoTitle;

  /// Sous-texte du CTA plein largeur d'ajout de photo (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Fortement recommandé, rassure le voyageur'**
  String get requestCreateAddPhotoSubtitle;

  /// Libellé d'accessibilité du bouton de suppression d'une photo (package_request_photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette photo'**
  String get requestCreateRemovePhoto;

  /// Titre de l'app bar de l'écran de complétion avant paiement (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vérifie & complète'**
  String get requestCreateCompleteDetailsTitle;

  /// Message de succès après soumission des détails destinataire/paiement (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Détails enregistrés'**
  String get requestCreateDetailsSaved;

  /// Titre de la section destinataire (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Destinataire'**
  String get requestCreateRecipientSection;

  /// Libellé du champ nom du destinataire (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get requestCreateRecipientNameLabel;

  /// Erreur de validation générique : champ obligatoire vide (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Requis'**
  String get requestCreateRequiredField;

  /// Libellé du champ téléphone du destinataire (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get requestCreateRecipientPhoneLabel;

  /// Erreur de validation : téléphone du destinataire hors format E.164 (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Format E.164 (+221…)'**
  String get requestCreateRecipientPhoneFormat;

  /// Libellé du champ ville du destinataire (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ville / commune'**
  String get requestCreateRecipientCityLabel;

  /// Texte d'indication du champ ville du destinataire (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ex. Dakar (optionnel)'**
  String get requestCreateRecipientCityHint;

  /// Titre de la section moyen de paiement (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement'**
  String get requestCreatePaymentMethodSection;

  /// Libellé du CTA pendant la soumission (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get requestCreateSendingLabel;

  /// Libellé du CTA de soumission (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Continuer vers le paiement'**
  String get requestCreateContinueToPayment;

  /// Titre de la carte récapitulative (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get requestCreateRecapTitle;

  /// Libellé de la ligne trajet de la carte récapitulative (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet'**
  String get requestCreateRecapTrip;

  /// Libellé de la ligne date de voyage de la carte récapitulative (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date du voyage'**
  String get requestCreateRecapTravelDate;

  /// Libellé de la ligne poids de la carte récapitulative (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Poids'**
  String get requestCreateRecapWeight;

  /// Libellé de la ligne taille de la carte récapitulative (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get requestCreateRecapSize;

  /// Libellé de la ligne prix de la carte récapitulative (complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix à payer'**
  String get requestCreateRecapPrice;

  /// Titre de l'écran et de la sheet « Ma demande » (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ma demande'**
  String get requestDetailTitle;

  /// Snackbar d'échec générique d'une action du détail de demande (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessaie dans un instant.'**
  String get requestDetailNoticeActionFailed;

  /// Snackbar de succès après invitation d'un voyageur (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Invitation envoyée. Le voyageur est prévenu.'**
  String get requestDetailNoticeInvitationSent;

  /// Snackbar d'échec : invitation refusée par le serveur (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ce voyageur ne peut pas être invité.'**
  String get requestDetailNoticeInvitationRefused;

  /// Snackbar d'échec : demande qui n'accepte plus d'invitations (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette demande n\'accepte plus d\'invitations.'**
  String get requestDetailNoticeInvitationNotInvitable;

  /// Snackbar d'échec : limite d'invitations atteinte (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Limite d\'invitations atteinte pour cette demande.'**
  String get requestDetailNoticeInvitationLimitReached;

  /// Corps du message de partage d'une demande, avant le lien (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'J\'envoie un colis de {weight} kg {departure} → {arrival} autour du {date}. Tu voyages sur cet axe ? Réponds à ma demande sur Yadony.'**
  String requestDetailShareMessage(
    String weight,
    String departure,
    String arrival,
    String date,
  );

  /// Tooltip du bouton menu « … » du détail de demande (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'actions'**
  String get requestDetailMoreActionsTooltip;

  /// Titre du dialogue de confirmation d'annulation (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette demande ?'**
  String get requestDetailCancelDialogTitle;

  /// Message du dialogue de confirmation d'annulation (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Les voyageurs ne pourront plus y répondre.'**
  String get requestDetailCancelDialogMessage;

  /// Titre d'erreur 404 (demande annulée/supprimée) (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette demande n\'existe plus'**
  String get requestDetailErrorNotFoundTitle;

  /// Message d'erreur 404 (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Elle a peut-être été annulée ou supprimée.'**
  String get requestDetailErrorNotFoundMessage;

  /// Titre d'erreur générique de chargement (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger ta demande'**
  String get requestDetailErrorLoadTitle;

  /// Message d'erreur générique de chargement (package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vérifie ta connexion, puis réessaie. Ta demande n\'a pas été modifiée.'**
  String get requestDetailErrorLoadMessage;

  /// Nom de repli du voyageur, en milieu de phrase (package_request_detail_screen.dart, request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'le voyageur'**
  String get requestTravelerFallbackNameLower;

  /// Titre de l'écran « Mes demandes » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mes demandes'**
  String get requestListTitle;

  /// Message d'erreur de repli, sans détail serveur (my_package_requests_screen.dart, package_request_search_screen.dart, complete_details_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get requestListErrorFallback;

  /// Titre de l'état vide global de « Mes demandes » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'as encore rien envoyé'**
  String get requestListEmptyTitle;

  /// Description de l'état vide global de « Mes demandes » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publie ta première demande et reçois des offres de voyageurs en quelques heures.'**
  String get requestListEmptyDescription;

  /// CTA de l'état vide global de « Mes demandes » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'+ Publier ma première demande'**
  String get requestListEmptyCta;

  /// Indication du champ de recherche de « Mes demandes » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ville, catégorie…'**
  String get requestListSearchHint;

  /// Libellé du chip de filtre « Toutes », suivi du compte entre parenthèses (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get requestListFilterAllLabel;

  /// Libellé du chip de filtre « Ouvertes » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ouvertes'**
  String get requestListFilterOpenLabel;

  /// Libellé du chip de filtre « Non abouties » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Non abouties'**
  String get requestListFilterClosedLabel;

  /// Libellé du chip de filtre « Brouillons » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Brouillons'**
  String get requestListFilterDraftLabel;

  /// État vide du filtre : recherche sans correspondance (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour cette recherche'**
  String get requestListEmptySearchResult;

  /// État vide du filtre « Ouvertes » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande ouverte'**
  String get requestListEmptyOpen;

  /// État vide du filtre « Non abouties » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande non aboutie'**
  String get requestListEmptyClosed;

  /// État vide du filtre « Brouillons » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun brouillon'**
  String get requestListEmptyDraft;

  /// État vide du filtre « Toutes » (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande'**
  String get requestListEmptyAll;

  /// Libellé du bouton flottant de création (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle demande'**
  String get requestListNewFab;

  /// CTA d'édition dans le pied d'une carte de la liste (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modifier →'**
  String get requestListEditCta;

  /// Badge de statut, tout en majuscules (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'BROUILLON'**
  String get requestListStatusDraft;

  /// Badge de statut, tout en majuscules (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'OUVERTE'**
  String get requestListStatusOpen;

  /// Badge de statut, tout en majuscules (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'NÉGOCIATION'**
  String get requestListStatusNegotiating;

  /// Badge de statut, tout en majuscules (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'ACCEPTÉE'**
  String get requestListStatusAccepted;

  /// Badge de statut, tout en majuscules (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'LIVRÉE'**
  String get requestListStatusCompleted;

  /// Badge de statut, tout en majuscules (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'EXPIRÉE'**
  String get requestListStatusExpired;

  /// Badge de statut, tout en majuscules (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'ANNULÉE'**
  String get requestListStatusCancelled;

  /// Horodatage relatif d'une carte de la liste (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'à l\'instant'**
  String get requestListTimeJustNow;

  /// Horodatage relatif d'une carte de la liste (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'il y a {minutes} min'**
  String requestListTimeMinutesAgo(int minutes);

  /// Horodatage relatif d'une carte de la liste (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'il y a {hours}h'**
  String requestListTimeHoursAgo(int hours);

  /// Horodatage relatif d'une carte de la liste (my_package_requests_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'il y a {days}j'**
  String requestListTimeDaysAgo(int days);

  /// Titre du hub « Envoyer » (envoyer_hub_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get requestEnvoyerHubTitle;

  /// Pill d'action « + Nouveau » du hub « Envoyer » (envoyer_hub_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'+ Nouveau'**
  String get requestEnvoyerHubNewButton;

  /// Compteur de vues affiché dans le méta du billet (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} vue} other{{count} vues}}'**
  String requestDetailViews(int count);

  /// Pli replié « N voyageurs la verront » sur un brouillon (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur la verra} other{{count} voyageurs la verront}}'**
  String requestDetailTravelersWillSee(int count);

  /// Pli replié « N voyageurs sur ton axe » (offres reçues / prix ferme) (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur sur ton axe} other{{count} voyageurs sur ton axe}}'**
  String requestDetailTravelersOnRouteCount(int count);

  /// Titre du bandeau brouillon (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Pas encore visible'**
  String get requestDetailNotVisibleTitle;

  /// Message du bandeau brouillon (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publie ta demande pour que les voyageurs puissent te proposer un prix.'**
  String get requestDetailNotVisibleMessage;

  /// Titre du bandeau accord en espèces, commission en attente (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'{name} règle sa commission Yadony'**
  String requestDetailCashCommissionTitle(String name);

  /// Message du bandeau accord en espèces, commission en attente (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accord en espèces trouvé. Tant que ce n\'est pas fait, tu peux encore choisir quelqu\'un d\'autre.'**
  String get requestDetailCashCommissionMessage;

  /// Titre du bandeau à finaliser (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Finalise pour réserver sa place'**
  String get requestDetailFinalizeTitle;

  /// Message du bandeau à finaliser (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ton argent reste bloqué chez Yadony jusqu\'à la remise du colis.'**
  String get requestDetailFinalizeMessage;

  /// Titre du bandeau expirée (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date dépassée sans accord'**
  String get requestDetailExpiredTitle;

  /// Message du bandeau expirée (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyageur n\'a été retenu à temps. Tes infos sont gardées, il suffit de choisir de nouvelles dates.'**
  String get requestDetailExpiredMessage;

  /// Titre du bandeau annulée (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu as annulé cette demande'**
  String get requestDetailCancelledTitle;

  /// Message du bandeau annulée (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Les voyageurs ne peuvent plus y répondre.'**
  String get requestDetailCancelledMessage;

  /// Titre du bandeau : recherche de voyageurs compatibles en échec (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les voyageurs pour le moment'**
  String get requestDetailNoSearchTitle;

  /// Message du bandeau : recherche de voyageurs compatibles en échec (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Réessaie plus tard, ou partage directement ta demande en attendant.'**
  String get requestDetailNoSearchMessage;

  /// Titre de section : offres reçues (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Offres reçues'**
  String get requestDetailOffersReceivedTitle;

  /// Titre du bandeau prix ferme, un seul candidat retenu (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Un seul choix'**
  String get requestDetailSingleChoiceTitle;

  /// Message du bandeau prix ferme, un seul candidat retenu (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Les autres candidats seront déclinés automatiquement.'**
  String get requestDetailSingleChoiceMessage;

  /// Titre de section : candidats sur un prix ferme (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voyageurs intéressés'**
  String get requestDetailInterestedTravelersTitle;

  /// Titre de section : offres, cas commission en attente (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Offres'**
  String get requestDetailOffersTitle;

  /// Titre de section : offre à finaliser (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Offre retenue'**
  String get requestDetailSelectedOfferTitle;

  /// Titre du bandeau : bid accepté mais hors des rails (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet n\'a pas abouti'**
  String get requestDetailTripNotCompletedTitle;

  /// Message du bandeau : bid accepté mais hors des rails (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur n\'a pas pu assurer la livraison. Publie une demande similaire pour retrouver quelqu\'un.'**
  String get requestDetailTripNotCompletedMessage;

  /// Nom de repli du voyageur dans la frise de progression (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'ton voyageur'**
  String get requestDetailYourTravelerFallback;

  /// Statut du talon voyageur : espèces déjà réglées (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'réglé en main propre'**
  String get requestDetailStubCashPaid;

  /// Statut du talon voyageur : espèces à régler (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'à régler en main propre à la remise'**
  String get requestDetailStubCashPending;

  /// Statut du talon voyageur : paiement carte déjà versé (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'versé au voyageur'**
  String get requestDetailStubPaidToTraveler;

  /// Statut du talon voyageur : paiement carte en séquestre (request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'payé, bloqué chez Yadony'**
  String get requestDetailStubHeldByYadony;

  /// Nom de repli du voyageur, en début de phrase (request_offer_card.dart, request_detail_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur'**
  String get requestTravelerFallbackName;

  /// Étiquette d'offre en attente de trajet, partagée avec le bouton principal (request_offer_card.dart, request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'{name} ajoute son trajet'**
  String requestTravelerAddingTrip(String name);

  /// Étiquette d'offre : accord trouvé, en attente de paiement (request_offer_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accord trouvé'**
  String get requestOfferDealFound;

  /// Étiquette d'offre : accord espèces, commission voyageur en attente (request_offer_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accord en espèces, commission en attente'**
  String get requestOfferCashDealCommissionPending;

  /// Étiquette d'offre sur un prix ferme (request_offer_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Disponible pour ton colis'**
  String get requestOfferAvailableForParcel;

  /// CTA de l'étiquette d'offre sur un prix ferme (request_offer_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Choisir'**
  String get requestOfferChooseCta;

  /// Étiquette d'offre : c'est à l'expéditeur de répondre (request_offer_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'À toi de répondre'**
  String get requestOfferYourTurn;

  /// CTA de l'étiquette d'offre quand c'est à l'expéditeur de répondre (request_offer_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get requestOfferRespondCta;

  /// Étiquette d'offre de repli : en attente du voyageur (request_offer_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente de {name}'**
  String requestOfferWaitingFor(String name);

  /// Légende sous le prix brut d'une carte d'offre (request_offer_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'tu paies'**
  String get requestOfferYouPayCaption;

  /// Poids encore disponible chez un voyageur (request_offer_card.dart, compatible_traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{weight} kg libres'**
  String requestAvailableKg(String weight);

  /// Entrée du menu « … » de « Ma demande » (request_owner_menu_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Dépublier'**
  String get requestDetailMenuUnpublishLabel;

  /// Conséquence de « Dépublier » dans le menu « … » (request_owner_menu_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Redevient un brouillon, invisible des voyageurs'**
  String get requestDetailMenuUnpublishConsequence;

  /// Entrée du menu « … » de « Ma demande » (request_owner_menu_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Dupliquer la demande'**
  String get requestDetailMenuDuplicateLabel;

  /// Conséquence de « Dupliquer la demande » dans le menu « … » (request_owner_menu_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Même colis, nouvelles dates ou nouveau trajet'**
  String get requestDetailMenuDuplicateConsequence;

  /// Entrée du menu « … » de « Ma demande », réutilisée comme confirmLabel du dialogue (request_owner_menu_sheet.dart, package_request_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get requestDetailMenuCancelLabel;

  /// Conséquence de « Annuler la demande » dans le menu « … » (request_owner_menu_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Irréversible'**
  String get requestDetailMenuCancelConsequence;

  /// Titre de la liste des voyageurs compatibles (request_travelers_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voyageurs sur ton axe'**
  String get requestTravelersOnRouteTitle;

  /// Titre de l'état vide : aucun voyageur compatible (request_travelers_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyageur sur {corridor} pour l\'instant'**
  String requestNoTravelersTitle(String corridor);

  /// Message de l'état vide : aucun voyageur compatible (request_travelers_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Les trajets arrivent souvent la semaine du départ. On te prévient dès qu\'un voyageur publie.'**
  String get requestNoTravelersMessage;

  /// Action de l'état vide : créer une alerte (request_travelers_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Être alerté des nouveaux trajets'**
  String get requestNoTravelersAlertCta;

  /// Action de l'état vide : élargir la fenêtre de dates (request_travelers_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Élargir mes dates'**
  String get requestNoTravelersWidenDatesCta;

  /// Pastille de statut : nombre d'offres reçues (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} offre} other{{count} offres}}'**
  String requestStatusOffers(int count);

  /// Pastille de statut : nombre de candidats sur un prix ferme (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} candidat} other{{count} candidats}}'**
  String requestStatusCandidates(int count);

  /// Pastille de statut d'une demande (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get requestStatusDraft;

  /// Pastille de statut d'une demande publiée sans offre (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get requestStatusLive;

  /// Pastille de statut : accord espèces, commission en attente (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get requestStatusPendingCommission;

  /// Pastille de statut : offre à finaliser (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'À finaliser'**
  String get requestStatusToFinalize;

  /// Pastille de statut : demande acceptée (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmée'**
  String get requestStatusConfirmed;

  /// Pastille de statut : demande livrée (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livrée'**
  String get requestStatusDelivered;

  /// Pastille de statut : demande expirée (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'Expirée'**
  String get requestStatusExpired;

  /// Pastille de statut : demande annulée (request_status_pill.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get requestStatusCancelled;

  /// Bouton principal : publier la demande brouillon (request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get requestDetailPublishCta;

  /// Bouton principal : ouvrir un fil de négociation (request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la discussion'**
  String get requestDetailOpenThreadCta;

  /// Bouton principal : payer, sans montant connu (request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer'**
  String get requestDetailPayCta;

  /// Bouton principal : payer un montant donné (request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer {amount}'**
  String requestDetailPayCtaWithAmount(String amount);

  /// Bouton principal : suivre le colis accepté (request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Suivre mon colis'**
  String get requestDetailTrackParcelCta;

  /// Bouton principal : noter le voyageur après livraison (request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Noter {name}'**
  String requestDetailRateCta(String name);

  /// Bouton principal : republier une demande expirée (request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Republier avec de nouvelles dates'**
  String get requestDetailRepublishCta;

  /// Bouton principal : publier une demande similaire après annulation (request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publier une demande similaire'**
  String get requestDetailPublishSimilarCta;

  /// Bouton secondaire : ouvrir le message (request_detail_bottom_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get requestDetailMessageCta;

  /// Libellé d'accessibilité du billet (route + date) (request_ticket_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{departure} vers {arrival}, {date}'**
  String requestTicketRouteSemantic(
    String departure,
    String arrival,
    String date,
  );

  /// Prix du billet quand aucun montant n'est encore fixé (request_ticket_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix à définir'**
  String get requestTicketPriceUndefined;

  /// Légende sous le prix du billet, prix ouvert aux offres (request_ticket_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'négociable'**
  String get requestTicketNegotiable;

  /// Légende sous le prix du billet, prix ferme (request_ticket_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'prix ferme'**
  String get requestTicketFixedPrice;

  /// Libellé d'accessibilité de la vignette photo du billet (request_ticket_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir les photos du colis'**
  String get requestTicketViewPhotosSemantic;

  /// Étape 1 de la frise de progression (request_progress_timeline.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accord et paiement'**
  String get requestProgressDealAndPayment;

  /// Étape 2 de la frise de progression (request_progress_timeline.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remise du colis à {name}'**
  String requestProgressHandoverTo(String name);

  /// Étape 3 de la frise de progression (request_progress_timeline.dart)
  ///
  /// In fr, this message translates to:
  /// **'En voyage'**
  String get requestProgressInTransit;

  /// Étape 4 de la frise de progression (request_progress_timeline.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livraison à {city}'**
  String requestProgressDeliveryTo(String city);

  /// Jauge de poids : poids de la demande de l'expéditeur (compatible_traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'ton colis : {weight} kg'**
  String requestYourParcelWeight(String weight);

  /// État du bouton d'invitation d'un voyageur compatible, déjà invité (compatible_traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Invité'**
  String get requestTravelerInvited;

  /// Bouton d'invitation d'un voyageur compatible (compatible_traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get requestTravelerInviteCta;

  /// Libellé d'accessibilité du squelette de chargement (request_detail_skeleton.dart)
  ///
  /// In fr, this message translates to:
  /// **'Chargement de ta demande'**
  String get requestDetailLoadingSemantic;

  /// Tolérance compacte en jours, format ±Nj, réutilisée par package_request_public_detail_screen.dart, package_request_list_card.dart, package_request_search_screen.dart et package_request_carousel_card.dart
  ///
  /// In fr, this message translates to:
  /// **'±{days}j'**
  String requestToleranceDays(int days);

  /// Nombre d'avis reçus affiché près de la note (package_request_list_card.dart, sender_public_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} avis} other{{count} avis}}'**
  String requestReviewCount(int count);

  /// Identité « demande d'envoi » — titre d'écran et micro-label des cartes (package_request_public_detail_screen.dart, package_request_list_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande d\'envoi'**
  String get requestPublicTitle;

  /// Libellé générique « Description » (package_request_public_detail_screen.dart, package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get requestDescriptionLabel;

  /// Tooltip du bouton de signalement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get requestPublicReportTooltip;

  /// Titre de la feuille de signalement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signaler la demande'**
  String get requestPublicReportSheetTitle;

  /// Motif de signalement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Contenu interdit'**
  String get requestPublicReportReasonProhibited;

  /// Motif de signalement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Arnaque / fraude'**
  String get requestPublicReportReasonScam;

  /// Motif de signalement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Contenu inapproprié'**
  String get requestPublicReportReasonInappropriate;

  /// Motif de signalement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Autre raison'**
  String get requestPublicReportReasonOther;

  /// Snackbar de succès du signalement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande signalée. Merci.'**
  String get requestPublicReportSuccess;

  /// Snackbar d'échec du signalement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de signaler pour le moment'**
  String get requestPublicReportError;

  /// Micro-label majuscule du corridor (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'DEMANDE D\'ENVOI'**
  String get requestPublicBadge;

  /// Badge majuscule affiché quand la demande n'est pas négociable (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'PRIX FERME'**
  String get requestPublicFirmPriceBadge;

  /// Date souhaitée + tolérance compacte entre parenthèses (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'le {date} ({tolerance})'**
  String requestPublicDesiredDate(String date, String tolerance);

  /// Indice de taille de colis « petit » (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Sac'**
  String get requestPublicParcelHintBag;

  /// Indice de taille de colis « moyen » (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Carton'**
  String get requestPublicParcelHintBox;

  /// Indice de taille de colis « grand » (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Valise'**
  String get requestPublicParcelHintSuitcase;

  /// Titre de la section catégories (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'CATÉGORIES'**
  String get requestPublicCategoriesLabel;

  /// Titre de la carte budget et libellé quand la demande est négociable (package_request_public_detail_screen.dart) ; réutilisé pour le titre de l'étape 3 et la ligne budget de la décomposition (step_3_recap_budget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Budget'**
  String get requestPublicBudget;

  /// Titre de la carte pickup/livraison (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Zones'**
  String get requestPublicZonesLabel;

  /// Libellé de la zone de pickup, déjà en anglais côté français (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Pickup'**
  String get requestPublicPickupLabel;

  /// Libellé de la zone de livraison (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get requestPublicDeliveryLabel;

  /// Titre de la carte moyens de paiement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement souhaité'**
  String get requestPublicPaymentTitle;

  /// Sous-titre de la carte moyens de paiement (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accepté par l\'expéditeur'**
  String get requestPublicPaymentSubtitle;

  /// CTA voyageur sur une demande négociable (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Proposer mon trajet'**
  String get requestPublicProposeTripCta;

  /// CTA quand le voyageur a déjà une offre en cours, négociable (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir ma négociation'**
  String get requestPublicViewNegotiationCta;

  /// CTA quand le voyageur a déjà une offre en cours, prix ferme (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir ma proposition'**
  String get requestPublicViewProposalCta;

  /// CTA prix ferme sans montant connu (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prendre ce colis'**
  String get requestPublicTakePackageCta;

  /// CTA prix ferme avec montant connu (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prendre à {price} · Prix ferme'**
  String requestPublicTakeAt(String price);

  /// Snackbar de succès après prise d'un prix ferme (package_request_public_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Offre confirmée'**
  String get requestPublicOfferConfirmed;

  /// Titre de l'écran de recherche publique des demandes (package_request_search_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demandes ouvertes'**
  String get requestSearchTitle;

  /// État vide de la recherche (package_request_search_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande ne correspond à votre filtre'**
  String get requestSearchEmptyMessage;

  /// Ligne budget d'une carte de recherche (package_request_search_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Budget: {amount}'**
  String requestSearchBudgetLine(String amount);

  /// Score de compatibilité « Pour mes trajets » (package_request_list_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ton trajet du {date}'**
  String requestListYourTripOn(String date);

  /// Budget non renseigné (package_request_list_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Budget libre'**
  String get requestBudgetFreeLabel;

  /// Snackbar d'échec du cœur favori (package_request_list_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Action impossible, réessaie'**
  String get requestFavoriteToggleError;

  /// Nombre d'envois de l'expéditeur (package_request_list_card.dart, MatchingRequestCard)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} envoi} other{{count} envois}}'**
  String requestSenderShipmentCount(int count);

  /// Budget par kg d'une carte de matching (package_request_list_card.dart, MatchingRequestCard)
  ///
  /// In fr, this message translates to:
  /// **'Budget {amount}/kg'**
  String requestMatchingBudgetPerKg(String amount);

  /// Titre de la sheet d'aperçu étape 3 (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aperçu de votre demande'**
  String get requestPreviewTitle;

  /// Bouton de publication immédiate (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publier ma demande'**
  String get requestPreviewPublishCta;

  /// Bouton d'enregistrement en brouillon (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer en brouillon'**
  String get requestPreviewSaveDraftCta;

  /// Nombre de photos affiché dans l'aperçu (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} photo} other{{count} photos}}'**
  String requestPreviewPhotos(int count);

  /// Libellé de la ligne lieu de remise (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remise'**
  String get requestPreviewDropoffLabel;

  /// Libellé de la ligne moyens de paiement (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get requestPreviewPaymentLabel;

  /// Prix indicatif non renseigné, négociable (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ouvert aux offres'**
  String get requestPreviewOpenToOffers;

  /// Prix indicatif renseigné, négociable (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Budget indicatif : {amount}'**
  String requestPreviewBudgetIndicative(String amount);

  /// Prix ferme renseigné (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix ferme : {amount}'**
  String requestPreviewFixedPrice(String amount);

  /// Bouton « voir tout » du carousel near-me (near_me_package_request_carousel.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Voir la demande} other{Voir les {count} demandes}}'**
  String requestCarouselSeeAll(int count);

  /// État vide du carousel near-me (near_me_package_request_carousel.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande à proximité'**
  String get requestCarouselEmptyTitle;

  /// CTA de l'état vide du carousel near-me (near_me_package_request_carousel.dart)
  ///
  /// In fr, this message translates to:
  /// **'Élargir la zone'**
  String get requestCarouselWidenZoneCta;

  /// Chip statut OPEN (package_status_chip.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ouverte'**
  String get requestStatusChipOpen;

  /// Chip statut NEGOTIATING (package_status_chip.dart)
  ///
  /// In fr, this message translates to:
  /// **'En négociation'**
  String get requestStatusChipNegotiating;

  /// Chip statut ACCEPTED (package_status_chip.dart)
  ///
  /// In fr, this message translates to:
  /// **'Acceptée'**
  String get requestStatusChipAccepted;

  /// Titre de la sheet profil expéditeur (sender_public_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Profil expéditeur'**
  String get requestSenderProfileTitle;

  /// Tooltip du bouton … (sender_public_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'options'**
  String get requestSenderMoreOptionsTooltip;

  /// Badge KYC vérifié (sender_public_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Identité vérifiée'**
  String get requestSenderVerifiedIdentity;

  /// Repli quand l'expéditeur n'a aucun avis (sender_public_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Nouveau membre'**
  String get requestSenderNewMember;

  /// Bouton de modification d'un trajet proposé (traveler/trip_tile.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modifier le trajet'**
  String get requestPickerModifyTripCta;

  /// Prix au kg indisponible (traveler/trip_tile.dart)
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get requestPickerPriceUnavailable;

  /// Chip espèces activées (traveler/trip_tile.dart)
  ///
  /// In fr, this message translates to:
  /// **'Liquide activé'**
  String get requestPickerCashEnabled;

  /// Chip espèces désactivées (traveler/trip_tile.dart)
  ///
  /// In fr, this message translates to:
  /// **'Liquide désactivé'**
  String get requestPickerCashDisabled;

  /// Capacité disponible d'un trajet non Kg libre (traveler/trip_tile.dart)
  ///
  /// In fr, this message translates to:
  /// **'{kg} kg dispo'**
  String requestPickerKgAvailable(String kg);

  /// Erreur de chargement des trajets du voyageur (trip_picker_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger tes trajets'**
  String get requestPickerLoadErrorMessage;

  /// Titre quand aucun trajet ne correspond (trip_picker_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun de tes trajets ne correspond'**
  String get requestPickerNoMatchTitle;

  /// Titre quand au moins un trajet correspond (trip_picker_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tes trajets compatibles'**
  String get requestPickerMatchingTitle;

  /// Message de l'état vide invitant à créer un trajet (trip_picker_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Crée un trajet correspondant à cette demande'**
  String get requestPickerEmptyCreateHint;

  /// Bouton de création d'un nouveau trajet dédié (trip_picker_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Créer un nouveau trajet'**
  String get requestPickerCreateTripCta;

  /// Prix non renseigné sur la carte carousel (package_request_carousel_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Libre'**
  String get requestCarouselCardPriceFree;

  /// Libellé de la ligne nombre de photos dans l'aperçu (package_request_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get requestPreviewPhotosLabel;

  /// Libellé de la ligne transport de la carte récapitulative de l'étape 3 (wizard_summary_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Transport'**
  String get requestCreateRecapTransport;

  /// Libellé de la ligne colis (poids) de la carte récapitulative de l'étape 3 (wizard_summary_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis'**
  String get requestCreateRecapPackage;

  /// Titre de la confirmation de suppression d'un trajet (announcement_detail_screen.dart, announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce trajet ?'**
  String get listingDeleteTripConfirmTitle;

  /// Message de confirmation de suppression d'un trajet annulé (announcement_detail_screen.dart, announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.'**
  String get listingDeleteTripCancelledMessage;

  /// Message de confirmation de suppression d'un trajet actif (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Le trajet ne sera plus visible pour les expéditeurs.'**
  String get listingDeleteTripActiveMessage;

  /// Titre de l'écran/feuille détail du trajet (announcement_detail_screen.dart, traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Détail du trajet'**
  String get listingTripDetailTitle;

  /// Confirmation après suppression d'un trajet (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet supprimé'**
  String get listingTripDeletedMessage;

  /// Message affiché quand l'annonce a disparu (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette annonce n\'existe plus'**
  String get listingAnnouncementGoneMessage;

  /// Petit libellé au-dessus du corridor dans la carte héro (announcement_detail_screen.dart), et libellé de ligne « Trajet » de l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet'**
  String get listingHeroTripLabel;

  /// Titre de la section adresses de remise/récupération (announcement_detail_screen.dart, announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lieux de remise'**
  String get listingPickupLocationsTitle;

  /// Titre de la section date limite de dépôt (announcement_detail_screen.dart, announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Dépôt des colis'**
  String get listingHandoverDeadlineTitle;

  /// Libellé de la carte statistique capacité disponible (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Capacité dispo.'**
  String get listingCapacityAvailableLabel;

  /// Libellé de la carte statistique en mode grille (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tarification'**
  String get listingPricingModeLabel;

  /// Libellé de la carte statistique prix au kg (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix par kg'**
  String get listingPricePerKgLabel;

  /// Valeur compacte affichée en mode grille tarifaire (announcement_detail_screen.dart, announcement_detail_body.dart, marker_bitmap_factory.dart via announcement_map_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Grille'**
  String get listingPriceGridShort;

  /// Valeur compacte quand le prix au kg est indisponible (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get listingPriceUnavailableShort;

  /// Bouton d'accès aux demandes reçues, avec leur nombre (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir les demandes ({count})'**
  String listingSeeRequestsButton(int count);

  /// Bouton de modification d'un trajet (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Modifier ce trajet'**
  String get listingEditTripButton;

  /// Bouton d'annulation d'un trajet (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annuler ce trajet'**
  String get listingCancelTripButton;

  /// Bouton de suppression d'un trajet (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce trajet'**
  String get listingDeleteTripButton;

  /// Message quand un trajet passé n'est plus modifiable (announcement_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet ne peut plus être modifié.'**
  String get listingTripLockedMessage;

  /// Badge de statut ACTIVE d'un trajet (announcement_detail_screen.dart, trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get listingStatusActive;

  /// Badge de statut FULL d'un trajet (announcement_detail_screen.dart, trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Complet'**
  String get listingStatusFull;

  /// Badge de statut COMPLETED d'un trajet (announcement_detail_screen.dart, trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get listingStatusCompleted;

  /// Badge de statut CANCELLED d'un trajet (announcement_detail_screen.dart, trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get listingStatusCancelled;

  /// Date limite de dépôt affichée en toutes lettres (announcement_detail_screen.dart, announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au {date}'**
  String listingHandoverUntil(String date);

  /// Placeholder du champ de recherche de « Mes trajets » (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une destination…'**
  String get listingSearchDestinationHint;

  /// Chip de filtre statut « Tous » (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get listingFilterAllChip;

  /// Chip de filtre statut « Brouillons » (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Brouillons'**
  String get listingFilterDraftsChip;

  /// Chip de filtre statut « Actifs » (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
  String get listingFilterActiveChip;

  /// Chip de filtre statut « Terminés » (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Terminés'**
  String get listingFilterCompletedChip;

  /// Chip de filtre statut « Annulés » (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annulés'**
  String get listingFilterCancelledChip;

  /// Titre de l'en-tête de l'écran « Mes trajets » (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mes trajets'**
  String get listingHeaderTitle;

  /// Pill de création d'un nouveau trajet (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'+ Nouveau'**
  String get listingNewTripPill;

  /// Titre de l'état d'erreur de chargement (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos trajets'**
  String get listingLoadErrorTitle;

  /// Titre de l'état vide sans aucun trajet (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun trajet à venir'**
  String get listingEmptyNoTripsTitle;

  /// Titre de l'état vide filtré sur les brouillons (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun brouillon'**
  String get listingEmptyDraftTitle;

  /// Titre de l'état vide filtré sur les trajets actifs (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun trajet actif'**
  String get listingEmptyActiveTitle;

  /// Titre de l'état vide filtré sur les trajets terminés (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun historique'**
  String get listingEmptyCompletedTitle;

  /// Titre de l'état vide filtré sur les trajets annulés (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune annulation'**
  String get listingEmptyCancelledTitle;

  /// Titre de l'état vide sans résultat de recherche (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun trajet trouvé'**
  String get listingEmptyAllTitle;

  /// Description de l'état vide sans aucun trajet (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publiez votre premier trajet et commencez à transporter des colis.'**
  String get listingEmptyNoTripsDesc;

  /// Description de l'état vide filtré sur les brouillons (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vos trajets enregistrés sans publication apparaîtront ici.'**
  String get listingEmptyDraftDesc;

  /// Description de l'état vide filtré sur les trajets actifs (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vos trajets en cours et à venir apparaîtront ici.'**
  String get listingEmptyActiveDesc;

  /// Description de l'état vide filtré sur les trajets terminés (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vos trajets passés et terminés apparaîtront ici.'**
  String get listingEmptyCompletedDesc;

  /// Description de l'état vide filtré sur les trajets annulés (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vos trajets annulés apparaîtront ici.'**
  String get listingEmptyCancelledDesc;

  /// Description de l'état vide sans résultat de recherche (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun trajet ne correspond à votre recherche.'**
  String get listingEmptyAllDesc;

  /// Petit libellé capitalisé au-dessus du corridor (announcement_detail_body.dart, traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'TRAJET'**
  String get listingHeroTripLabelCaps;

  /// Libellé secondaire de la pastille capacité disponible (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'disponibles'**
  String get listingCapacityAvailableSuffix;

  /// Libellé secondaire de la pastille prix en mode grille (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'tarifaire'**
  String get listingPricingSuffixTarifaire;

  /// Libellé secondaire de la pastille prix au kilo (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'prix'**
  String get listingPricingSuffixPrix;

  /// Nombre de colis acceptés sur le trajet (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{colis accepté} other{colis acceptés}}'**
  String listingAcceptedParcels(int count);

  /// Libellé secondaire du compteur de demandes en attente (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'en attente'**
  String get listingPendingParcelsLabel;

  /// Titre de la section moyens de paiement acceptés (announcement_detail_body.dart, traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiements acceptés'**
  String get listingPaymentsAcceptedTitle;

  /// Message incitant le voyageur à activer la carte quand seul le cash est accepté (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet en espèces uniquement. Beaucoup d\'expéditeurs préfèrent payer par carte, activez cette option pour augmenter vos chances de recevoir des colis.'**
  String get listingCashOnlyNudgeMessage;

  /// Bouton d'activation des paiements par carte (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Activer les paiements par carte'**
  String get listingActivateCardPaymentsButton;

  /// Titre de la section contenus acceptés (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ce que j\'accepte'**
  String get listingAcceptedContentTitle;

  /// Titre de la section contenus refusés (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ce que je refuse'**
  String get listingRefusedContentTitle;

  /// Titre de la note libre du voyageur à destination des expéditeurs (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Note aux expéditeurs'**
  String get listingSenderNoteTitle;

  /// Badge de statut compact ACTIVE (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'● ACTIF'**
  String get listingBadgeActive;

  /// Badge de statut compact DRAFT (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'✎ BROUILLON'**
  String get listingBadgeDraft;

  /// Badge de statut compact FULL (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'● COMPLET'**
  String get listingBadgeFull;

  /// Badge de statut compact IN_PROGRESS (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'● EN COURS'**
  String get listingBadgeInProgress;

  /// Badge de statut compact COMPLETED (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'✓ TERMINÉ'**
  String get listingBadgeCompleted;

  /// Badge de statut compact CANCELLED (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'✕ ANNULÉ'**
  String get listingBadgeCancelled;

  /// Répartition kg réservés d'un trajet dédié au surplus (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'{kg} kg réservés'**
  String listingReservedKgLabel(String kg);

  /// Répartition kg ouverts au public d'un trajet dédié au surplus (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'{kg} kg ouverts'**
  String listingOpenKgLabel(String kg);

  /// Libellé court de la ligne remise du colis (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remise colis'**
  String get listingPickupParcelTitleShort;

  /// Libellé de la ligne récupération du colis (announcement_detail_body.dart, traveler_announcement_bottom_sheet.dart, announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Récupération'**
  String get listingDeliveryPickupTitle;

  /// Message quand l'expéditeur a déjà un colis actif sur ce trajet (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà un colis sur ce trajet'**
  String get listingAlreadyHasParcelMessage;

  /// Bouton vers le colis déjà en cours sur ce trajet (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir mon colis'**
  String get listingSeeMyParcelButton;

  /// Bouton principal de demande de transport (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Faire une demande'**
  String get listingMakeRequestButton;

  /// Préfixe avant le lien de négociation de prix (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet négociable · '**
  String get listingNegotiableTripPrefix;

  /// Lien d'entrée en négociation de prix (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Proposer un prix'**
  String get listingProposePriceLink;

  /// Libellé secondaire de la carte prix au kilo (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'par kilo'**
  String get listingPricePerKiloLabel;

  /// Équivalent converti « environ » du prix au kilo (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'environ {price}/kg'**
  String listingApproxPricePerKg(String price);

  /// Équivalent converti « environ » d'un article de la grille (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'environ {price}'**
  String listingApproxPrice(String price);

  /// Libellé secondaire de la carte date limite de dépôt (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'date limite de dépôt'**
  String get listingDepositDeadlineLabel;

  /// Titre de la carte grille tarifaire (traveler_announcement_bottom_sheet.dart, trip_card.dart, traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Grille tarifaire'**
  String get listingPriceGridLabel;

  /// Nombre d'articles de la grille tarifaire (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} article} other{{count} articles}}'**
  String listingItemCount(int count);

  /// Titre de la liste des tarifs à l'article (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tarif par article'**
  String get listingPricePerItemTitle;

  /// Bouton de dépliage de la liste des tarifs (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir tous les tarifs ({count})'**
  String listingSeeAllPricesButton(int count);

  /// Titre de la ligne remise du colis (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remise du colis'**
  String get listingPickupParcelTitle;

  /// Lien de signalement du trajet (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signaler ce trajet'**
  String get listingReportTripLink;

  /// Lien de blocage du voyageur (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Bloquer ce voyageur'**
  String get listingBlockTravelerLink;

  /// Confirmation d'ajout aux favoris (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet ajouté aux favoris'**
  String get listingFavoriteAddedMessage;

  /// Confirmation de retrait des favoris (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet retiré des favoris'**
  String get listingFavoriteRemovedMessage;

  /// Erreur lors du basculement d'un favori (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier les favoris'**
  String get listingFavoriteToggleErrorMessage;

  /// Capacité disponible compacte (traveler_announcement_bottom_sheet.dart, traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{kg} kg dispo'**
  String listingKgAvailableLabel(String kg);

  /// Badge compact identité vérifiée du voyageur (traveler_announcement_bottom_sheet.dart, traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get listingIdentityBadge;

  /// Titre de la section types de colis acceptés (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Types de colis acceptés'**
  String get listingCategoriesAcceptedTitle;

  /// Titre du message libre du voyageur (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Message du voyageur'**
  String get listingTravelerMessageTitle;

  /// Badge d'ouverture de l'app de cartes sur une adresse (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Itinéraire'**
  String get listingRouteLabel;

  /// Amorce en gras de l'avertissement paiement cash uniquement (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet en espèces uniquement. '**
  String get listingCashOnlyWarningBold;

  /// Corps de l'avertissement paiement cash uniquement (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le paiement se fait en main propre au voyageur, Yadony ne séquestre pas votre argent et ne peut pas le rembourser automatiquement en cas de litige.'**
  String get listingCashOnlyWarningBody;

  /// Repli affiché quand le voyageur n'a pas encore de note (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get listingNewRatingLabel;

  /// Nombre de trajets déjà effectués par le voyageur (traveler_announcement_bottom_sheet.dart, traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{· {count} trajet} other{· {count} trajets}}'**
  String listingTravelerTrips(int count);

  /// Titre de la feuille d'aperçu avant publication (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aperçu de votre annonce'**
  String get listingPreviewTitle;

  /// Bouton de publication de l'annonce (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publier l\'annonce'**
  String get listingPublishButton;

  /// Bouton d'enregistrement en brouillon (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer comme brouillon'**
  String get listingSaveDraftButton;

  /// Libellé de la ligne heure de départ de l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get listingPreviewDepartureLabel;

  /// Libellé de la ligne adresse de remise de l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remise'**
  String get listingRowLabelPickup;

  /// Libellé de la ligne capacité de l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Capacité'**
  String get listingRowLabelCapacity;

  /// Libellé de la ligne mode de paiement de l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get listingRowLabelPayment;

  /// Valeur de la ligne paiement quand carte et espèces sont acceptées (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Carte + Espèces'**
  String get listingPaymentCardCash;

  /// Valeur de la ligne paiement quand seule la carte est acceptée (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Carte uniquement'**
  String get listingPaymentCardOnly;

  /// Libellé de la ligne contenus acceptés de l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accepte'**
  String get listingRowLabelAccept;

  /// Libellé de la ligne contenus refusés de l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Refuse'**
  String get listingRowLabelRefuse;

  /// Libellé de la ligne note libre de l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get listingRowLabelNote;

  /// Avertissement prix jugé bas dans l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix bas. Vous pourrez le modifier après publication.'**
  String get listingPriceTooLowWarning;

  /// Avertissement prix jugé élevé dans l'aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix élevé. Vous pourrez le modifier après publication.'**
  String get listingPriceTooHighWarning;

  /// Badge de statut IN_PROGRESS d'une carte de trajet (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get listingStatusInProgress;

  /// Date de départ relative — aujourd'hui (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui · {date}'**
  String listingDateTodayLabel(String date);

  /// Date de départ relative — demain (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demain · {date}'**
  String listingDateTomorrowLabel(String date);

  /// Date de départ relative — dans N jours (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Départ dans {days} jours · {date}'**
  String listingDateInDaysLabel(int days, String date);

  /// Erreur du bouton favori sur une carte de trajet (trip_card.dart, traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Action impossible, réessaie'**
  String get listingRetryActionMessage;

  /// Compteur de demandes acceptées sur une carte de trajet (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} acceptée} other{{count} acceptées}}'**
  String listingAcceptedBidsCount(int count);

  /// Compteur de demandes en attente sur une carte de trajet (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count} en attente'**
  String listingPendingBidsCount(int count);

  /// Progression kg vendus / total sur une carte de trajet (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{sold} vendus sur {total}'**
  String listingSoldOfTotalLabel(String sold, String total);

  /// Capacité disponible du footer d'une carte de trajet active (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{kg} disponibles'**
  String listingAvailableKgLabel(String kg);

  /// Kg vendus condensé d'une carte de trajet passée (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{kg} vendus'**
  String listingSoldLabel(String kg);

  /// Montant gagné condensé d'une carte de trajet terminée (trip_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{price} gagnés'**
  String listingEarnedLabel(String price);

  /// Chip de statut d'une demande acceptée sur une carte voyageur (traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée'**
  String get listingBidStatusAccepted;

  /// Chip de statut d'un colis déjà en cours sur ce trajet (traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis sur ce trajet'**
  String get listingBidStatusOnTrip;

  /// Chip de statut voyageur arrivé à destination (traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Arrivé'**
  String get listingBidStatusArrived;

  /// Chip de statut d'une demande en attente sur une carte voyageur (traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande en attente'**
  String get listingBidStatusPending;

  /// Pill signalant que l'annonce appartient au voyageur courant (traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Votre trajet'**
  String get listingYourTripPill;

  /// Badge compte PRO sur une carte voyageur (traveler_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'PRO'**
  String get listingProBadge;

  /// Titre de l'état vide du carousel « près de moi » (near_me_carousel.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyageur à proximité'**
  String get listingNoTravelersNearbyTitle;

  /// Description de l'état vide du carousel « près de moi » (near_me_carousel.dart)
  ///
  /// In fr, this message translates to:
  /// **'Essaie d\'augmenter le rayon ou de changer de date.'**
  String get listingNoTravelersNearbyDesc;

  /// Bouton « voir tout » quand une seule annonce est disponible (near_me_carousel.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'annonce'**
  String get listingSeeAnnouncementButton;

  /// Bouton « voir tout » avec le nombre d'annonces (near_me_carousel.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir les {count} annonces'**
  String listingSeeAnnouncementsCountButton(int count);

  /// Titre de la feuille filtrée sur une ville de départ (route_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Départs depuis {city}'**
  String listingRouteDeparturesFrom(String city);

  /// Titre de la feuille filtrée sur une ville d'arrivée (route_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Arrivées à {city}'**
  String listingRouteArrivalsTo(String city);

  /// Nombre de trajets sur la route filtrée (route_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} trajet} other{{count} trajets}}'**
  String listingRouteTrips(int count);

  /// État vide de la feuille route filtrée (route_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun trajet disponible sur cette route'**
  String get listingNoTripsOnRoute;

  /// Nombre de voyageurs disponibles à la même adresse (same_address_announcements_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} voyageur disponible à cette adresse} other{{count} voyageurs disponibles à cette adresse}}'**
  String listingSameAddressTravelers(int count);

  /// Repli affiché quand l'adresse d'un cluster n'a pas de libellé (announcement_map_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get listingAddressFallback;

  /// Infobulle du bouton « Près de moi » actif (announcement_map_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Désactiver « Près de moi »'**
  String get listingNearMeDeactivateTooltip;

  /// Infobulle du bouton « Près de moi » inactif (announcement_map_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir les voyageurs près de moi'**
  String get listingNearMeActivateTooltip;

  /// Titre de la feuille de filtres de recherche de trajets (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les trajets'**
  String get listingFilterTripsTitle;

  /// Bouton de réinitialisation des filtres (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get listingResetFiltersButton;

  /// Bouton de recherche de la feuille de filtres, avec le nombre de filtres actifs (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Rechercher} =1{Rechercher · {count} filtre} other{Rechercher · {count} filtres}}'**
  String listingSearchButton(int count);

  /// Titre de section des chips de filtres rapides (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'FILTRES RAPIDES'**
  String get listingQuickFiltersTitle;

  /// Chip de filtre voyageur Kilo Pro (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Kilo Pro'**
  String get listingKiloProChip;

  /// Chip de filtre note minimale (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Note ≥ 4.5'**
  String get listingRatingChip;

  /// Chip de filtre départ le week-end (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Week-end'**
  String get listingWeekendChip;

  /// Titre de section du filtre type de contenu (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'MON COLIS CONTIENT'**
  String get listingContentContainsTitle;

  /// Titre de section du filtre urgence du départ (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'URGENCE DU DÉPART'**
  String get listingDepartureUrgencyTitle;

  /// Description du filtre urgence du départ (search_form_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les trajets selon leur proximité de départ'**
  String get listingDepartureUrgencyDesc;

  /// Message de confirmation de suppression, sans la phrase d irréversibilité (announcement_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.'**
  String get listingDeleteTripAssociatedRequestsMessage;

  /// Libellé de la ligne date limite de dépôt (announcement_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date limite'**
  String get listingDeadlineLabel;

  /// Titre de l encart instructions de retrait laissees par le voyageur (traveler_announcement_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Instructions du voyageur'**
  String get listingInstructionsCardTitle;

  /// Libellé de la ligne date de départ de l aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get listingRowLabelDate;

  /// Libellé de la ligne prix de l aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get listingRowLabelPrice;

  /// Suffixe estimation du revenu net affiché après le prix au kg de l aperçu (announcement_preview_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **' · estimation {amount} net'**
  String listingPriceEstimateSuffix(String amount);

  /// Bouton d'envoi de la première proposition en mode négociation (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoyer ma proposition'**
  String get bidCreateSendProposalButton;

  /// Bouton de confirmation du paiement en espèces (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer {amount} en espèces'**
  String bidCreateConfirmCashButton(String amount);

  /// Bouton de confirmation du paiement mobile money (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer {amount} par mobile money'**
  String bidCreateConfirmMobileMoneyButton(String amount);

  /// Bouton de confirmation du paiement par carte (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Bloquer {amount} & payer'**
  String bidCreateLockAndPayButton(String amount);

  /// Erreur de validation, description du colis manquante (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Description obligatoire'**
  String get bidCreateDescriptionRequiredError;

  /// Erreur de validation, nom du destinataire manquant (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Nom du destinataire obligatoire'**
  String get bidCreateRecipientNameRequiredError;

  /// Erreur de validation, téléphone du destinataire manquant (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Téléphone du destinataire obligatoire'**
  String get bidCreateRecipientPhoneRequiredError;

  /// Erreur de validation, prix proposé manquant en mode négociation (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Indiquez le prix que vous proposez'**
  String get bidCreatePriceRequiredError;

  /// Confirmation après envoi d'une première proposition (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Proposition envoyée, le voyageur va vous répondre.'**
  String get bidCreateProposalSentMessage;

  /// Titre de l'écran de succès après une offre en espèces ou mobile money (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Offre envoyée !'**
  String get bidCreateOfferSentTitle;

  /// Sous-titre de l'écran de succès pour une offre en espèces (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement en espèces : si le voyageur accepte, tu remets le montant en main propre à la remise du colis. En cas d\'annulation après la remise, Yadony ne peut pas te rembourser immédiatement mais s\'assurera que le voyageur te restitue ton argent.'**
  String get bidCreateCashSuccessSubtitle;

  /// Sous-titre de l'écran de succès pour une offre en mobile money (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement mobile money : si le voyageur accepte, tu recevras une notification et auras 30 minutes pour valider le paiement sur ton téléphone. Le montant est gardé en sécurité par Yadony jusqu\'à la livraison.'**
  String get bidCreateMobileMoneySuccessSubtitle;

  /// Sous-titre de repli de l'écran de succès après une offre (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur va examiner ta demande.'**
  String get bidCreateReviewPendingSubtitle;

  /// CTA de l'écran de succès vers le détail de l'envoi (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir mon envoi'**
  String get bidCreateSeeMyShipmentButton;

  /// Titre de la section articles de la grille tarifaire (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'ARTICLES'**
  String get bidCreateArticlesSectionLabel;

  /// Nombre d'articles sélectionnés dans la carte grille (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} article sélectionné} other{{count} articles sélectionnés}}'**
  String bidCreateSelectedItems(int count);

  /// Sous-total des articles sélectionnés (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Sous-total : {amount}'**
  String bidCreateSubtotalLabel(String amount);

  /// Libellé du bouton d'ouverture de la sélection d'articles (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Choisir mes articles'**
  String get bidCreateChooseItemsLabel;

  /// Rappel qu'au moins un article doit être sélectionné (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Requis : au moins 1 article'**
  String get bidCreateItemsRequiredHint;

  /// Titre de la section photos du formulaire d'offre (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'PHOTOS DU COLIS (OPTIONNEL)'**
  String get bidCreatePhotosSectionLabel;

  /// Titre de la section description du formulaire d'offre (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'DESCRIPTION (AU VOYAGEUR)'**
  String get bidCreateDescriptionSectionLabel;

  /// Exemple affiché dans le champ description (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Médicaments pour diabète + 2 tee-shirts enfants'**
  String get bidCreateDescriptionHint;

  /// Titre de la section destinataire du formulaire d'offre (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'DESTINATAIRE'**
  String get bidCreateRecipientSectionLabel;

  /// Libellé du champ nom du destinataire (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prénom et nom du destinataire'**
  String get bidCreateRecipientNameLabel;

  /// Exemple affiché dans le champ nom du destinataire (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'ex: Amadou Diallo'**
  String get bidCreateRecipientNameHint;

  /// Libellé du champ téléphone du destinataire (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Téléphone du destinataire'**
  String get bidCreateRecipientPhoneLabel;

  /// Exemple affiché dans le champ téléphone du destinataire (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'ex: +221 77 000 00 00'**
  String get bidCreateRecipientPhoneHint;

  /// Titre de la section code promo du formulaire d'offre (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'CODE PROMO (OPTIONNEL)'**
  String get bidCreatePromoSectionLabel;

  /// Exemple affiché dans le champ code promo (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ex: WELCOME10'**
  String get bidCreatePromoCodeHint;

  /// Confirmation de repli quand le devis n'a pas de libellé de promo (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Code appliqué'**
  String get bidCreatePromoAppliedDefaultLabel;

  /// Titre de la section prix proposé en mode négociation (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'VOTRE PROPOSITION'**
  String get bidCreateYourProposalSectionLabel;

  /// Libellé du champ de prix proposé en mode négociation (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix proposé ({symbol})'**
  String bidCreateProposedPriceLabel(String symbol);

  /// Rappel du prix suggéré sous le champ de proposition (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Suggéré : {amount}'**
  String bidCreateSuggestedPriceLabel(String amount);

  /// Titre de la section mode de paiement en mode négociation (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'MODE DE PAIEMENT'**
  String get bidCreatePaymentMethodSectionLabel;

  /// Explication du choix figé du mode de paiement en négociation (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Si le voyageur accepte votre prix, vous réglerez de cette façon.'**
  String get bidCreatePaymentMethodHint;

  /// Titre de la section contenu du colis (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'CONTENU DU COLIS'**
  String get bidCreateContentSectionLabel;

  /// Note explicative sous le sélecteur de contenu (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ces suggestions sont les contenus acceptés par le voyageur. Si le contenu de votre colis n\'y figure pas, ajoutez-le : ce sera au voyageur de décider s\'il accepte votre colis ou non.'**
  String get bidCreateContentHintText;

  /// Titre de la section des contenus refusés par le voyageur (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'REFUSÉ PAR LE VOYAGEUR'**
  String get bidCreateRefusedByTravelerSectionLabel;

  /// Titre de l'étape de choix du mode de paiement (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Comment veux-tu payer ?'**
  String get bidCreateHowToPayTitle;

  /// Sous-titre de l'étape de choix du mode de paiement (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Choisis le mode de paiement pour cette demande.'**
  String get bidCreateChoosePaymentSubtitle;

  /// Erreur affichée si l'authentification avant paiement échoue (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement non confirmé, réessayez'**
  String get bidCreatePaymentNotConfirmedError;

  /// Libellé de contexte de la feuille de paiement Stripe (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoi vers {city}'**
  String bidCreateShipmentToLabel(String city);

  /// Titre de l'écran de succès après un paiement carte (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Offre payée !'**
  String get bidCreateOfferPaidTitle;

  /// Sous-titre de l'écran de succès après un paiement carte (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ton paiement est bloqué et sécurisé jusqu\'à la livraison confirmée. Le voyageur est notifié de ta demande.'**
  String get bidCreateOfferPaidSubtitle;

  /// Libellé de la section poids, trajet kilo pur (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Poids du colis'**
  String get bidCreateWeightLabel;

  /// Libellé de la section poids, trajet mixte grille + kilo (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Poids du colis (optionnel)'**
  String get bidCreateWeightLabelOptional;

  /// Sous-titre du sélecteur de poids en kilo libre (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Kilo libre : choisissez votre poids'**
  String get bidCreateFreeKgHint;

  /// Message quand le trajet n'a plus de capacité kilo (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune capacité disponible'**
  String get bidCreateNoCapacityAvailable;

  /// Titre de l'encart disclaimer douanier (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Disclaimer douane.'**
  String get bidCreateDisclaimerTitle;

  /// Texte de l'encart disclaimer douanier (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Pas d\'armes, drogues, liquides inflammables ou espèces. Le voyageur peut refuser au contrôle douanier.'**
  String get bidCreateDisclaimerBody;

  /// Libellé de la case à cocher du disclaimer (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Je signe & j\'accepte'**
  String get bidCreateDisclaimerAcceptLabel;

  /// Sous-titre du choix de paiement par carte (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Bloqué jusqu\'à la livraison'**
  String get bidCreateCardModeSubtitle;

  /// Sous-titre du choix de paiement mobile money, noms de marque (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Orange Money, Wave, MTN'**
  String get bidCreateMobileMoneySubtitle;

  /// Sous-titre du choix de paiement en espèces (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'En main propre, à la remise'**
  String get bidCreateCashModeSubtitle;

  /// Tag du montant bloqué chez Yadony (carte, mobile money) (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Séquestre'**
  String get bidCreateEscrowTag;

  /// Tag du montant remis directement au voyageur (espèces) (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'En main propre'**
  String get bidCreateHandToHandTag;

  /// Explication du mode carte dans la carte de paiement ouverte (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Bloqué par Yadony dès maintenant, versé au voyageur quand le destinataire confirme la livraison.'**
  String get bidCreateCardModeBody;

  /// Explication du mode mobile money dans la carte de paiement ouverte (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Après l\'accord du voyageur, tu reçois une demande de paiement sur ton téléphone. Le montant est bloqué par Yadony jusqu\'à la livraison.'**
  String get bidCreateMobileMoneyModeBody;

  /// Explication du mode espèces dans la carte de paiement ouverte (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu remets la somme au voyageur le jour où tu lui confies le colis.'**
  String get bidCreateCashModeBody;

  /// Rappel de garantie sous le mode carte et mobile money (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remboursé si le colis n\'arrive pas'**
  String get bidCreateRefundAssurance;

  /// Avertissement affiché sous le mode espèces (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement en espèces : pas de séquestre, vous payez le voyageur directement, sans garantie de remboursement par Yadony.'**
  String get bidCreateCashEscrowWarning;

  /// Libellé de la ligne articles du récapitulatif de prix (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Articles'**
  String get bidCreateArticlesLineLabel;

  /// Libellé de la ligne de réduction dans le récapitulatif de prix (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Réduction code promo'**
  String get bidCreatePromoDiscountLabel;

  /// Libellé de la ligne totale du récapitulatif de prix (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get bidCreateTotalLabel;

  /// Badge affiché à côté du total quand un code promo réduit le prix (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Promo'**
  String get bidCreatePromoBadge;

  /// Mention sous le total du récapitulatif de prix (create_bid_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Commission Yadony incluse'**
  String get bidCreateServiceFeeIncludedLabel;

  /// Explication de l'utilité des photos du colis (create_bid/photo_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Visibles par le voyageur, elles rassurent sur le contenu.'**
  String get bidCreatePhotosVisibleHint;

  /// Libellé du champ numéro payeur mobile money (create_bid/payer_phone_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Numéro qui paiera (facultatif)'**
  String get bidCreatePayerPhoneLabel;

  /// Texte d'aide quand le compte a un numéro de téléphone (create_bid/payer_phone_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Par défaut, ton numéro Yadony. Tu recevras la demande de paiement sur ce numéro.'**
  String get bidCreatePayerPhoneHintWithProfile;

  /// Texte d'aide quand le compte n'a pas de numéro de téléphone (create_bid/payer_phone_field.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ton compte n\'a pas de numéro : indique celui qui paiera. Tu recevras la demande de paiement dessus.'**
  String get bidCreatePayerPhoneHintNoProfile;

  /// Titre de la section articles hors grille en négociation (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Articles hors grille'**
  String get bidCreateCustomItemsSectionTitle;

  /// Explication de la section articles hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez ce que le voyageur n\'a pas tarifé, et proposez votre prix pour chaque article.'**
  String get bidCreateCustomItemsSectionHint;

  /// État vide de la liste d'articles hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun article pour le moment.'**
  String get bidCreateCustomItemsEmpty;

  /// Libellé du total des articles hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Total des articles hors grille'**
  String get bidCreateCustomItemsTotalLabel;

  /// Bouton et titre d'ajout d'un article hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un article'**
  String get bidCreateAddItemButton;

  /// Tooltip du bouton de suppression d'un article hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Retirer cet article'**
  String get bidCreateRemoveItemTooltip;

  /// Sous-titre de la feuille d'ajout d'un article hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Décrivez l\'article et indiquez le prix que vous proposez pour son transport.'**
  String get bidCreateAddItemSheetSubtitle;

  /// Bouton de validation de la feuille d'ajout d'un article hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get bidCreateAddItemConfirmButton;

  /// Libellé du champ nom de l'article hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Article'**
  String get bidCreateCustomItemLabelField;

  /// Exemple affiché dans le champ nom de l'article hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Sac de riz, boubou, médicaments'**
  String get bidCreateCustomItemLabelHint;

  /// Libellé du champ quantité de l'article hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get bidCreateCustomItemQuantityField;

  /// Libellé du champ prix de l'article hors grille (custom_items_section.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix ({symbol})'**
  String bidCreateCustomItemPriceField(String symbol);

  /// Titre de la feuille de sélection des articles de la grille (grid_item_selection_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Articles disponibles'**
  String get bidCreateGridSheetTitle;

  /// Bouton de confirmation de la feuille de sélection des articles (grid_item_selection_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la sélection'**
  String get bidCreateGridSheetConfirmButton;

  /// Libellé d'accessibilité d'un article de grille sélectionné (grid_item_selection_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{label}, {price} l\'unité, {quantity} sélectionné'**
  String bidCreateGridItemSemanticSelected(
    String label,
    String price,
    int quantity,
  );

  /// Libellé d'accessibilité d'un article de grille non sélectionné (grid_item_selection_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{label}, {price} l\'unité'**
  String bidCreateGridItemSemanticUnit(String label, String price);

  /// Libellé d'accessibilité du bouton moins d'un article de grille (grid_item_selection_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Retirer un {label}'**
  String bidCreateGridItemRemoveSemantic(String label);

  /// Libellé d'accessibilité du bouton plus d'un article de grille (grid_item_selection_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un {label}'**
  String bidCreateGridItemAddSemantic(String label);

  /// Avertissement prix trop bas (price_hint_widget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix bas : risque de méfiance de l\'expéditeur'**
  String get bidCreatePriceTooLowHint;

  /// Avertissement prix trop élevé (price_hint_widget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix élevé : peu de demandes attendues'**
  String get bidCreatePriceTooHighHint;

  /// Préfixe du prix médian de marché avec corridor (price_hint_widget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Marché {corridor} : '**
  String bidCreateMarketPriceCorridor(String corridor);

  /// Préfixe du prix médian de marché sans corridor (price_hint_widget.dart)
  ///
  /// In fr, this message translates to:
  /// **'Marché '**
  String get bidCreateMarketPriceLabel;

  /// Suffixe affiché après le prix médian de marché (price_hint_widget.dart)
  ///
  /// In fr, this message translates to:
  /// **' · Votre prix est compétitif.'**
  String get bidCreateCompetitivePriceSuffix;

  /// Statut du disclaimer avec sa date de signature (details_accordion, tâche D2)
  ///
  /// In fr, this message translates to:
  /// **'Disclaimer signé le {dateTime}'**
  String bidCreateDisclaimerSigned(String dateTime);

  /// Premier segment de l'avertissement commission espèces à la publication (cash_commission_notice.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pourrez accepter un colis en espèces que si la commission Yadony peut être prélevée '**
  String get tripPublishCashCommissionIntro;

  /// Segment en gras de l'avertissement commission espèces (cash_commission_notice.dart)
  ///
  /// In fr, this message translates to:
  /// **'sur votre portefeuille en priorité'**
  String get tripPublishCashCommissionHighlight;

  /// Dernier segment de l'avertissement commission espèces (cash_commission_notice.dart)
  ///
  /// In fr, this message translates to:
  /// **'. À défaut, il faudra le recharger ou enregistrer une carte valide au moment d’accepter.'**
  String get tripPublishCashCommissionOutro;

  /// Libellé de stage : accord carte, c'est à moi de payer (bid_labels.dart, ex-BidNegotiationSummary.stageLabel)
  ///
  /// In fr, this message translates to:
  /// **'à payer'**
  String get negotiationStageToPay;

  /// Libellé de stage : accord carte, en attente du paiement de l'autre partie (bid_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'attente paiement'**
  String get negotiationStageAwaitingPayment;

  /// Libellé de stage : accord en espèces, pas encore réglé (bid_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'accord conclu'**
  String get negotiationStageDealAgreed;

  /// Libellé de stage : fil clos, quel que soit le motif (bid_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'terminé'**
  String get negotiationStageClosed;

  /// Libellé de stage par défaut : négociation en cours (bid_labels.dart)
  ///
  /// In fr, this message translates to:
  /// **'proposition'**
  String get negotiationStageProposal;

  /// Nom de repli affiché pour l'expéditeur sans nom (bid_labels.dart, ex-BidModel.resolvedSenderName). Réutilisé comme intitulé de section « Expéditeur » sur expediteur_card.dart : même texte, même clé.
  ///
  /// In fr, this message translates to:
  /// **'Expéditeur'**
  String get bidSenderFallbackName;

  /// Nombre de trajets du voyageur, composable dans une ligne compacte « · N trajets » (bid_labels.dart, voyageur_card.dart, et partie D pour voyageur_contact_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} trajet} other{{count} trajets}}'**
  String bidTravelerTrips(int count);

  /// Nombre d'envois de l'expéditeur, composable dans une ligne compacte (bid_labels.dart, expediteur_card.dart, et partie D pour expediteur_contact_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} envoi} other{{count} envois}}'**
  String bidSenderShipments(int count);

  /// Date de soumission d'une offre, date déjà formatée par DateFormat.yMd(locale) (expediteur_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Soumis le {date}'**
  String bidSubmittedOn(String date);

  /// Titre de l'écran du fil de négociation (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Discussion de prix'**
  String get negotiationThreadTitle;

  /// Titre de l'état d'erreur du fil de négociation (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Discussion indisponible'**
  String get negotiationThreadErrorTitle;

  /// Amorce du montant en tête, vue voyageur (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous recevriez'**
  String get negotiationThreadYouWouldReceive;

  /// Amorce du montant en tête, vue expéditeur (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous paieriez'**
  String get negotiationThreadYouWouldPay;

  /// Compteur de tours de négociation (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tour {round} sur {maxRounds}'**
  String negotiationThreadRoundLabel(int round, int maxRounds);

  /// Titre de la section récapitulatif du colis (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le colis'**
  String get negotiationThreadParcelSectionTitle;

  /// Titre de la section des messages du fil (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Échanges'**
  String get negotiationThreadExchangesTitle;

  /// Libellé d'un message de type proposition initiale (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Proposition'**
  String get negotiationThreadKindProposal;

  /// Libellé d'un message de type contre-offre (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Contre-offre'**
  String get negotiationThreadKindCounter;

  /// Libellé d'un message d'acceptation (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Acceptée'**
  String get negotiationThreadKindAccepted;

  /// Libellé d'un message de refus (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Refusée'**
  String get negotiationThreadKindRejected;

  /// Consigne de paiement, accord carte côté expéditeur (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix accepté. Réglez maintenant pour réserver votre place, le montant reste bloqué jusqu\'à la livraison.'**
  String get negotiationThreadPayHint;

  /// Bouton de paiement d'un accord carte (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer'**
  String get negotiationThreadPayButton;

  /// Accord carte, vue voyageur en attente du paiement (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix accepté. En attente du paiement de l\'expéditeur.'**
  String get negotiationThreadAwaitingSenderPaymentHint;

  /// Accord en espèces, vue voyageur (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix accepté. Paiement en espèces, il vous reste à régler la commission Yadony.'**
  String get negotiationThreadCashTravelerHint;

  /// Accord en espèces, vue expéditeur (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix accepté. Paiement en espèces, en attente du voyageur, vous n\'avez rien à régler ici.'**
  String get negotiationThreadCashSenderHint;

  /// Fil clos, statut ACCEPTED (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix accepté. Rendez-vous sur votre colis pour la suite.'**
  String get negotiationThreadClosedAccepted;

  /// Fil clos par un refus explicite, message REJECT présent (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Proposition refusée.'**
  String get negotiationThreadClosedRejected;

  /// Fil clos par péremption, aucun message REJECT (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Proposition expirée.'**
  String get negotiationThreadClosedExpired;

  /// Fil clos, statut générique (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Négociation terminée.'**
  String get negotiationThreadClosedDefault;

  /// Attente du tour de l'interlocuteur, nom ou repli traduit (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente de la réponse de {name}.'**
  String negotiationThreadWaitingForReply(String name);

  /// Repli quand l'interlocuteur n'a pas de nom (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'votre interlocuteur'**
  String get negotiationThreadCounterpartyFallback;

  /// Bouton d'acceptation d'une proposition (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get negotiationThreadAcceptButton;

  /// Bouton et titre de la feuille de contre-proposition (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Contre-proposer'**
  String get negotiationThreadCounterButton;

  /// Bouton de refus d'une proposition (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get negotiationThreadRejectButton;

  /// Sous-titre de la feuille de contre-proposition (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Indiquez le montant total que vous proposez. Votre interlocuteur pourra l\'accepter ou répondre à son tour.'**
  String get negotiationThreadCounterSubtitle;

  /// Bouton d'envoi de la feuille de contre-proposition (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoyer ma contre-offre'**
  String get negotiationThreadCounterSubmitButton;

  /// Label du champ montant de la contre-proposition (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Montant proposé ({symbol})'**
  String negotiationThreadCounterAmountLabel(String symbol);

  /// Label du champ message de la contre-proposition (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Message (facultatif)'**
  String get negotiationThreadCounterMessageLabel;

  /// Indice du champ message de la contre-proposition (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Expliquez votre proposition'**
  String get negotiationThreadCounterMessageHint;

  /// Message d'échec d'authentification avant paiement (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement non confirmé, réessayez'**
  String get negotiationThreadPaymentNotConfirmed;

  /// Libellé de contexte affiché dans la feuille de paiement (bid_negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix négocié de votre colis'**
  String get negotiationThreadPaymentContextLabel;

  /// Titre de l'état d'erreur du chargeur de détail (traveler_profile_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get travelerProfileLoadErrorTitle;

  /// Description de repli d'un état de chargement inattendu (traveler_profile_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le détail'**
  String get travelerProfileLoadErrorDescription;

  /// Tooltip du bouton menu ⋯ des fiches profil (traveler_profile_sheet.dart, sender_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'options'**
  String get profileSheetMoreOptionsTooltip;

  /// Titre de la section avis des fiches profil (traveler_profile_sheet.dart, sender_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Évaluations'**
  String get profileSheetReviewsTitle;

  /// État vide de la section avis (traveler_profile_sheet.dart, sender_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune évaluation pour l\'instant.'**
  String get profileSheetNoReviewsYet;

  /// Bouton de pagination des avis (traveler_profile_sheet.dart, sender_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get profileSheetSeeMoreReviews;

  /// Badge compte PRO des fiches profil (traveler_profile_sheet.dart, sender_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Compte PRO'**
  String get profileSheetProBadge;

  /// Badge identité vérifiée des fiches profil (traveler_profile_sheet.dart, sender_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Identité vérifiée'**
  String get profileSheetVerifiedBadge;

  /// Libellé de la stat card « Trajets » (traveler_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajets'**
  String get travelerProfileTripsLabel;

  /// Libellé de la stat card « Livraison » (traveler_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get travelerProfileDeliveryLabel;

  /// Numéro masqué avant acceptation (traveler_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Numéro révélé après acceptation'**
  String get travelerProfilePhoneHiddenLabel;

  /// Libellé de la barre d'abonnement (traveler_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'S\'abonner à ce voyageur'**
  String get travelerProfileSubscribeLabel;

  /// Numéro masqué avant acceptation, expéditeur non joignable (sender_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'📞 Numéro révélé après acceptation'**
  String get senderProfilePhoneHiddenLabel;

  /// Numéro en cours de révélation (sender_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Numéro en cours de récupération…'**
  String get senderProfilePhoneLoadingLabel;

  /// Libellé de la stat « Envois » (sender_profile_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envois'**
  String get senderProfileShipmentsLabel;

  /// Entrée du menu ⋯ de blocage (block_user_action.dart)
  ///
  /// In fr, this message translates to:
  /// **'Bloquer {name}'**
  String blockMenuEntryLabel(String name);

  /// Snackbar de confirmation de blocage (block_user_action.dart)
  ///
  /// In fr, this message translates to:
  /// **'{name} a été bloqué(e)'**
  String blockSuccessMessage(String name);

  /// Titre du dialog de confirmation de blocage (block_user_action.dart)
  ///
  /// In fr, this message translates to:
  /// **'Bloquer {name} ?'**
  String blockConfirmTitle(String name);

  /// Corps du dialog de confirmation de blocage (block_user_action.dart)
  ///
  /// In fr, this message translates to:
  /// **'Il·elle ne pourra plus voir tes annonces ni t\'envoyer d\'offre. Tu ne verras plus les siennes non plus. Tu pourras le·la débloquer à tout moment dans Confidentialité.'**
  String get blockConfirmBody;

  /// Bouton de confirmation du blocage (block_user_action.dart)
  ///
  /// In fr, this message translates to:
  /// **'Bloquer'**
  String get blockConfirmButton;

  /// Étiquette de rôle en tête de la carte voyageur (voyageur_card.dart, et partie D pour voyageur_contact_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'VOYAGEUR'**
  String get bidTravelerRoleTag;

  /// Libellé d'accessibilité du bouton d'appel (voyageur_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get voyageurCardCallSemanticLabel;

  /// Libellé d'accessibilité du bouton de messagerie (voyageur_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la discussion'**
  String get voyageurCardOpenChatSemanticLabel;

  /// Pastille de statut OPEN (thread_hero_card.dart, réutilisée par _StatusPill de my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'EN COURS'**
  String get negotiationStatusBadgeOpen;

  /// Pastille de statut AWAITING_TRIP (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'ATT. TRAJET'**
  String get negotiationStatusBadgeAwaitingTrip;

  /// Pastille de statut AWAITING_PAYMENT (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'PAIEMENT'**
  String get negotiationStatusBadgeAwaitingPayment;

  /// Pastille de statut AWAITING_COMMISSION (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'COMMISSION'**
  String get negotiationStatusBadgeAwaitingCommission;

  /// Pastille de statut AWAITING_DEPOSIT (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'DÉPÔT'**
  String get negotiationStatusBadgeAwaitingDeposit;

  /// Pastille de statut ACCEPTED (thread_hero_card.dart) — aussi le libellé du message système « acceptée » dans thread_message_bubble.dart, texte identique
  ///
  /// In fr, this message translates to:
  /// **'ACCEPTÉE'**
  String get negotiationStatusBadgeAccepted;

  /// Pastille de statut terminal (rejected/autoRejected/expired/cancelled) (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'TERMINÉ'**
  String get negotiationStatusBadgeTerminal;

  /// Libellé au-dessus du prix pour OPEN (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'PRIX ACTUEL'**
  String get negotiationStatusPriceLabelOpen;

  /// Libellé au-dessus du prix pour AWAITING_TRIP (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'ACCORD TROUVÉ'**
  String get negotiationStatusPriceLabelAwaitingTrip;

  /// Libellé au-dessus du prix pour AWAITING_PAYMENT (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'À RÉGLER'**
  String get negotiationStatusPriceLabelAwaitingPayment;

  /// Libellé au-dessus du prix pour AWAITING_COMMISSION (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'COMMISSION DUE'**
  String get negotiationStatusPriceLabelAwaitingCommission;

  /// Libellé au-dessus du prix pour AWAITING_DEPOSIT (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'DÉPÔT EN COURS'**
  String get negotiationStatusPriceLabelAwaitingDeposit;

  /// Libellé au-dessus du prix pour ACCEPTED (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'DEMANDE ACCEPTÉE'**
  String get negotiationStatusPriceLabelAccepted;

  /// Libellé au-dessus du prix pour un statut terminal (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'PRIX FINAL'**
  String get negotiationStatusPriceLabelTerminal;

  /// Alerte dernier round sans contre-offre possible (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⚠ Dernier round : Accepter ou Refuser uniquement'**
  String get negotiationLastRoundWarning;

  /// Compteur de round du hero card, identique en fr/en (« Round » est déjà utilisé tel quel en français dans ce contexte) (thread_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Round {round}/{max}'**
  String negotiationRoundCounter(int round, int max);

  /// Badge « nouveau message » (thread_message_bubble.dart, réutilisé par la carte de liste my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'NOUVEAU'**
  String get negotiationMessageNewBadge;

  /// Libellé capitales du type de message « proposition » (thread_message_bubble.dart)
  ///
  /// In fr, this message translates to:
  /// **'PROPOSITION'**
  String get negotiationMessageKindProposalBadge;

  /// Libellé capitales du type de message « contre-offre » (thread_message_bubble.dart)
  ///
  /// In fr, this message translates to:
  /// **'CONTRE-OFFRE'**
  String get negotiationMessageKindCounterBadge;

  /// Libellé capitales du type de message « rejetée » (thread_message_bubble.dart)
  ///
  /// In fr, this message translates to:
  /// **'REJETÉE'**
  String get negotiationMessageKindRejectedBadge;

  /// Snackbar de succès après relance (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Relance envoyée'**
  String get negotiationNudgeSentMessage;

  /// Snackbar d'erreur de relance, code nudge/rate-limited (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Déjà relancé récemment'**
  String get negotiationNudgeRateLimitedMessage;

  /// Snackbar d'erreur de relance générique (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de relancer pour le moment, réessaie plus tard'**
  String get negotiationNudgeGenericErrorMessage;

  /// Bandeau OPEN quand le dernier message est du viewer (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente de la réponse'**
  String get negotiationOpenAwaitingReplyTitle;

  /// Sous-titre du bandeau « en attente de la réponse » (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu seras notifié dès que la partie adverse répondra.'**
  String get negotiationOpenAwaitingReplySubtitle;

  /// Bandeau AWAITING_TRIP côté expéditeur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur prépare son trajet'**
  String get negotiationAwaitingTripSenderTitle;

  /// Sous-titre du bandeau AWAITING_TRIP côté expéditeur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu seras notifié dès qu\'il l\'aura confirmé.'**
  String get negotiationAwaitingTripSenderSubtitle;

  /// Bouton AWAITING_TRIP côté voyageur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lier un trajet à cette offre'**
  String get negotiationLinkTripButton;

  /// Bouton AWAITING_TRIP côté voyageur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Créer un trajet dédié'**
  String get negotiationCreateDedicatedTripButton;

  /// Bouton AWAITING_PAYMENT côté expéditeur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Compléter & payer {amount}'**
  String negotiationCompleteAndPayButton(String amount);

  /// Bandeau AWAITING_PAYMENT côté voyageur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente du paiement de l\'expéditeur'**
  String get negotiationAwaitingPaymentTravelerTitle;

  /// Sous-titre du bandeau AWAITING_PAYMENT côté voyageur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu seras notifié dès qu\'il aura réglé.'**
  String get negotiationAwaitingPaymentTravelerSubtitle;

  /// Bandeau AWAITING_DEPOSIT côté voyageur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur règle par mobile money'**
  String get negotiationAwaitingDepositTravelerTitle;

  /// Sous-titre du bandeau AWAITING_DEPOSIT côté voyageur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu seras notifié dès que le paiement sera confirmé.'**
  String get negotiationAwaitingDepositTravelerSubtitle;

  /// Bandeau AWAITING_DEPOSIT côté expéditeur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Dépôt mobile money en cours'**
  String get negotiationDepositInProgressTitle;

  /// Sous-titre du dépôt en cours, échéance inconnue (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Valide le paiement sur ton téléphone.'**
  String get negotiationDepositSubtitleDefault;

  /// Sous-titre du dépôt en cours, échéance dépassée (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le délai est écoulé, le fil va revenir à « à payer ».'**
  String get negotiationDepositSubtitleExpired;

  /// Sous-titre du dépôt en cours, échéance future (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Valide le paiement sur ton téléphone. Expire dans {minutes} min.'**
  String negotiationDepositSubtitleExpiring(int minutes);

  /// Bouton AWAITING_DEPOSIT côté expéditeur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le paiement'**
  String get negotiationResumePaymentButton;

  /// Bouton AWAITING_DEPOSIT côté expéditeur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Changer de moyen de paiement'**
  String get negotiationChangePaymentMethodButton;

  /// Bandeau AWAITING_COMMISSION côté expéditeur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente de la confirmation du voyageur'**
  String get negotiationAwaitingCommissionSenderTitle;

  /// Sous-titre du bandeau AWAITING_COMMISSION côté expéditeur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ta demande reste ouverte : tu peux continuer à recevoir et accepter d\'autres offres tant qu\'il n\'a pas réglé.'**
  String get negotiationAwaitingCommissionSenderSubtitle;

  /// Bandeau AWAITING_COMMISSION côté voyageur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirme ta prise en charge'**
  String get negotiationCommissionTravelerBannerTitle;

  /// Sous-titre du bandeau AWAITING_COMMISSION côté voyageur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur a retenu ton offre. Règle la commission Yadony ({amount}) avant l\'échéance pour emporter ce colis, sinon un autre voyageur peut te doubler.'**
  String negotiationCommissionTravelerBannerSubtitle(String amount);

  /// Bouton de règlement de la commission (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Régler la commission'**
  String get negotiationPayCommissionButton;

  /// Titre du dialog de renoncement à la commission (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Renoncer à ce colis ?'**
  String get negotiationDeclineParcelDialogTitle;

  /// Message du dialog de renoncement à la commission (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'La demande sera aussitôt disponible pour un autre voyageur. Cette action est définitive.'**
  String get negotiationDeclineParcelDialogMessage;

  /// Bouton de confirmation du dialog de renoncement (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Renoncer'**
  String get negotiationDeclineParcelConfirmButton;

  /// Lien discret d'ouverture du dialog de renoncement (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Renoncer à ce colis'**
  String get negotiationDeclineParcelButton;

  /// Bandeau ACCEPTED, paiement en ligne (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée et payée'**
  String get negotiationAcceptedPaidTitle;

  /// Bandeau ACCEPTED, paiement hors ligne (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée'**
  String get negotiationAcceptedTitle;

  /// Sous-titre du bandeau ACCEPTED payé en ligne (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu peux passer aux étapes suivantes du suivi.'**
  String get negotiationAcceptedPaidSubtitle;

  /// Sous-titre du bandeau ACCEPTED, paiement cash (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le paiement se fait en espèces à la remise du colis.'**
  String get negotiationAcceptedCashSubtitle;

  /// Sous-titre du bandeau ACCEPTED, autre moyen hors ligne (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le paiement se fait à la remise du colis.'**
  String get negotiationAcceptedOtherSubtitle;

  /// Bouton vers le détail de l'envoi matérialisé (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir mon envoi'**
  String get negotiationViewShipmentButton;

  /// Message centré pour les statuts terminaux (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette négociation est terminée'**
  String get negotiationEndedMessage;

  /// Bouton secondaire de relance (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Relancer'**
  String get negotiationNudgeButton;

  /// Bouton d'acceptation côté expéditeur, montant brut (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accepter : Tu paies {amount}'**
  String negotiationSenderAcceptButton(String amount);

  /// Bouton de refus, expéditeur et voyageur (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Rejeter'**
  String get negotiationDeclineButton;

  /// Bouton d'acceptation côté voyageur, montant net (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accepter : Tu reçois {amount}'**
  String negotiationTravelerAcceptButton(String amount);

  /// Compte à rebours de la commission, échéance dépassée (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Délai écoulé'**
  String get negotiationCommissionCountdownExpired;

  /// Compte à rebours de la commission, au moins une heure restante ; `minutes` déjà mis en forme sur deux chiffres (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Il te reste {hours}h {minutes}min'**
  String negotiationCommissionCountdownHours(int hours, String minutes);

  /// Compte à rebours de la commission, moins d'une heure restante ; `minutes`/`seconds` déjà mis en forme sur deux chiffres (thread_state_cta_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Il te reste {minutes}:{seconds}'**
  String negotiationCommissionCountdownMinutes(String minutes, String seconds);

  /// Bouton et titre de confirmation du refus d'un trajet lié (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Refuser ce trajet'**
  String get negotiationRefuseTripAction;

  /// Bouton de confirmation du refus (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le refus'**
  String get negotiationConfirmRefusalButton;

  /// Bandeau d'avertissement de la confirmation de refus (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur devra proposer un autre trajet. Cette action est irréversible.'**
  String get negotiationRefuseTripWarning;

  /// Label du champ de raison du refus (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Raison du refus (optionnel)'**
  String get negotiationRefusalReasonLabel;

  /// Placeholder du champ de raison du refus (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ex : date incorrecte, trajet annulé…'**
  String get negotiationRefusalReasonHint;

  /// Titre de la feuille de détail du trajet lié (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet lié'**
  String get negotiationLinkedTripSheetTitle;

  /// Libellé de la ligne itinéraire (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Itinéraire'**
  String get negotiationTripRouteLabel;

  /// Libellé de la ligne date de départ (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date de départ'**
  String get negotiationTripDepartureDateLabel;

  /// Libellé de la ligne heure de départ (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Heure de départ'**
  String get negotiationTripDepartureTimeLabel;

  /// Libellé de la ligne poids disponible (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Poids disponible'**
  String get negotiationTripAvailableWeightLabel;

  /// Libellé de la ligne adresse de remise (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Adresse de remise'**
  String get negotiationTripPickupAddressLabel;

  /// Libellé de la ligne adresse de livraison (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Adresse de livraison'**
  String get negotiationTripDeliveryAddressLabel;

  /// Libellé de la note du voyageur (trip_detail_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Note du voyageur'**
  String get negotiationTripTravelerNoteLabel;

  /// Snackbar de fin de négociation via le menu (negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Négociation terminée'**
  String get negotiationEndedSnackbar;

  /// Snackbar de rejet via reject_bottom_sheet (negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Négociation rejetée'**
  String get negotiationRejectedSnackbar;

  /// Snackbar de succès du règlement de la commission (negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Commission réglée : ce colis est à toi !'**
  String get negotiationCommissionSettledSnackbar;

  /// Snackbar de confirmation du renoncement (negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tu as renoncé à ce colis, il reste disponible pour un autre voyageur.'**
  String get negotiationGaveUpParcelSnackbar;

  /// Titre de l'AppBar tant que le fil n'est pas chargé (negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Négociation'**
  String get negotiationFallbackTitle;

  /// Entrée du menu ⋯ pour mettre fin à la négociation (negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mettre fin à la négociation'**
  String get negotiationEndMenuItem;

  /// Titre du dialog de confirmation de fin de négociation (negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mettre fin à cette négociation ?'**
  String get negotiationEndDialogTitle;

  /// Message du dialog de confirmation de fin de négociation (negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette action est définitive.'**
  String get negotiationEndDialogMessage;

  /// Bouton de confirmation du dialog de fin de négociation (negotiation_thread_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mettre fin'**
  String get negotiationEndDialogConfirmButton;

  /// Titre de l'écran « Discussions de prix » (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Discussions de prix'**
  String get negotiationListTitle;

  /// Titre de l'état vide global et du filtre « Toutes » sans résultat (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune négociation'**
  String get negotiationEmptyTitle;

  /// Description de l'état vide global (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tes négociations actives apparaîtront ici dès qu\'un voyageur fait une offre.'**
  String get negotiationEmptyDescription;

  /// Placeholder du champ de recherche (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voyageur, ville…'**
  String get negotiationSearchHint;

  /// Chip de filtre « Toutes » avec le total (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Toutes ({count})'**
  String negotiationFilterAllCountLabel(int count);

  /// Chip de filtre « En cours » avec le total (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'En cours ({count})'**
  String negotiationFilterActiveCountLabel(int count);

  /// Chip de filtre « Terminées » avec le total (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Terminées ({count})'**
  String negotiationFilterTerminalCountLabel(int count);

  /// État vide du filtre « En cours » (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune négociation en cours'**
  String get negotiationEmptyActiveFilter;

  /// État vide du filtre « Terminées » (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucune négociation terminée'**
  String get negotiationEmptyTerminalFilter;

  /// Pastille de source « Demande » sur une carte de négociation colis (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande'**
  String get negotiationSourcePillRequest;

  /// Nom de repli du voyageur avec les 4 premiers caractères de son id (my_negotiations_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voyageur {id}'**
  String negotiationTravelerFallbackWithId(String id);

  /// Libellé compact sous le prix, statut AWAITING_TRIP (my_negotiations_screen.dart, _NegoCard)
  ///
  /// In fr, this message translates to:
  /// **'accord'**
  String get negotiationStageDealPending;

  /// Libellé compact sous le prix, statut AWAITING_DEPOSIT (my_negotiations_screen.dart, _NegoCard)
  ///
  /// In fr, this message translates to:
  /// **'dépôt en cours'**
  String get negotiationStageDepositInProgress;

  /// Libellé compact sous le prix, statut AWAITING_COMMISSION (my_negotiations_screen.dart, _NegoCard)
  ///
  /// In fr, this message translates to:
  /// **'commission due'**
  String get negotiationStageCommissionDue;

  /// Libellé compact sous le prix, statut ACCEPTED (my_negotiations_screen.dart, _NegoCard)
  ///
  /// In fr, this message translates to:
  /// **'payé'**
  String get negotiationStagePaid;

  /// Nom de repli de l'interlocuteur sur une carte de négociation de trajet (my_negotiations_screen.dart, _TripNegoCard)
  ///
  /// In fr, this message translates to:
  /// **'Interlocuteur'**
  String get negotiationTripCardCounterpartyFallback;

  /// Ligne round + horodatage relatif d'une carte de négociation de trajet ; `timeAgo` déjà traduit (my_negotiations_screen.dart, _TripNegoCard)
  ///
  /// In fr, this message translates to:
  /// **'Tour {round} · {timeAgo}'**
  String negotiationTripCardRoundLabel(int round, String timeAgo);

  /// Titre de l'AppBar de l'écran de liaison de trajet (link_trip_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lier un trajet'**
  String get negotiationLinkTripScreenTitle;

  /// Label par défaut de la barre de sélection (link_trip_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un trajet'**
  String get negotiationSelectTripLabel;

  /// Label confirmé de la barre de sélection (link_trip_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer ce trajet'**
  String get negotiationConfirmTripLabel;

  /// Décompte affiché quand un trajet est sélectionné, toujours exactement un (link_trip_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'1 trajet'**
  String get negotiationSelectedTripCount;

  /// Date de voyage affichée sur le récapitulatif de l'écran de liaison (link_trip_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date de voyage : {date}'**
  String negotiationLinkTripDate(String date);

  /// Kg disponibles du trajet sélectionné, utilisé aussi par my_negotiations_screen.dart (link_trip_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'{kg} kg dispo'**
  String negotiationLinkTripKgAvailable(String kg);

  /// Bandeau de récapitulatif du prix accepté (link_trip_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée à {amount}'**
  String negotiationAcceptedAtPriceBanner(String amount);

  /// Titre de l'aperçu des moyens de paiement acceptés (link_trip_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur choisira parmi'**
  String get negotiationSenderChoosesAmong;

  /// Titre : la confirmation du règlement de commission d'une négociation a échoué (negotiation_bloc.dart, code commission/confirm-failed)
  ///
  /// In fr, this message translates to:
  /// **'Règlement non confirmé'**
  String get errorCommissionConfirmFailedTitle;

  /// Message de repli du constructeur (le detail serveur, ex. "PaymentIntent status: ...", reste affiché quand il existe — code dans _serverDetailCodes)
  ///
  /// In fr, this message translates to:
  /// **'Confirmation du règlement échouée'**
  String get errorCommissionConfirmFailedMessage;

  /// Titre : la 3DS du règlement de commission a été interrompue (negotiation_bloc.dart, code commission/3ds-interrupted)
  ///
  /// In fr, this message translates to:
  /// **'Authentification interrompue'**
  String get errorCommission3dsInterruptedTitle;

  /// Message affiché quand StripeException interrompt la 3DS du règlement de commission (negotiation_bloc.dart)
  ///
  /// In fr, this message translates to:
  /// **'Authentification bancaire interrompue'**
  String get errorCommission3dsInterruptedMessage;

  /// Titre : le règlement de la commission d'une négociation a été refusé (negotiation_bloc.dart, code commission/failed)
  ///
  /// In fr, this message translates to:
  /// **'Règlement refusé'**
  String get errorCommissionFailedTitle;

  /// Repli quand le detail machine (r.error) n'est reconnu ni comme un des trois codes connus ni comme card-status-* — Ruling R35 : jamais le code brut
  ///
  /// In fr, this message translates to:
  /// **'Règlement de la commission refusé'**
  String get errorCommissionFailedMessage;

  /// Traduction du code machine backend no-commission-card (settleNegotiationCommission) — Ruling R35
  ///
  /// In fr, this message translates to:
  /// **'Aucune carte enregistrée pour régler la commission.'**
  String get errorCommissionFailedNoCardMessage;

  /// Traduction du code machine backend card-declined (settleNegotiationCommission) — Ruling R35
  ///
  /// In fr, this message translates to:
  /// **'Ta carte a été refusée.'**
  String get errorCommissionFailedCardDeclinedMessage;

  /// Traduction du code machine backend stripe-error (settleNegotiationCommission) — Ruling R35
  ///
  /// In fr, this message translates to:
  /// **'Erreur du service de paiement, réessaie.'**
  String get errorCommissionFailedStripeErrorMessage;

  /// Repli générique pour tout code machine backend card-status-<statut Stripe> (settleNegotiationCommission) — Ruling R35, jamais le statut Stripe brut
  ///
  /// In fr, this message translates to:
  /// **'Le règlement par carte n\'a pas abouti.'**
  String get errorCommissionFailedCardStatusMessage;

  /// BidFailed, reason confirmFailed : repli quand la confirmation post-3DS échoue sans message serveur (bid_acceptance_bloc.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmation échouée'**
  String get bidAcceptConfirmFailed;

  /// BidFailed, reason bankAuthInterrupted : la 3DS de l'acceptation d'un bid est interrompue (StripeException, bid_acceptance_bloc.dart)
  ///
  /// In fr, this message translates to:
  /// **'Authentification bancaire interrompue'**
  String get bidAcceptBankAuthInterrupted;

  /// BidFailed, reason refused : repli quand l'acceptation échoue sans message serveur (bid_acceptance_bloc.dart)
  ///
  /// In fr, this message translates to:
  /// **'Acceptation refusée'**
  String get bidAcceptRefused;

  /// Titre de la feuille quand le prix n'est pas ferme (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Faire une offre'**
  String get negotiationMakeOfferTitle;

  /// Bouton de la feuille, prix ferme avec montant connu (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prendre à {amount}'**
  String negotiationMakeOfferTakeAtLabel(String amount);

  /// Bouton de la feuille, offre négociable (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoyer l\'offre'**
  String get negotiationMakeOfferSendButtonLabel;

  /// Snackbar d'avertissement si la date de voyage n'est pas choisie (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre date de voyage'**
  String get negotiationMakeOfferSelectTravelDate;

  /// Snackbar d'avertissement si aucun trajet n'est sélectionné (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez ou créez un trajet'**
  String get negotiationMakeOfferSelectTrip;

  /// Label majuscule du champ prix, offre négociable (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'VOTRE PRIX'**
  String get negotiationMakeOfferYourPriceLabel;

  /// Label majuscule du champ capacité (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'CAPACITÉ'**
  String get negotiationMakeOfferCapacityLabel;

  /// Label majuscule du champ date (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'DATE DE VOYAGE'**
  String get negotiationMakeOfferTravelDateLabel;

  /// Texte du champ date tant qu'aucune date n'est choisie (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner…'**
  String get negotiationMakeOfferSelectDatePlaceholder;

  /// Label majuscule du champ message, identique dans les deux langues (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'MESSAGE'**
  String get negotiationMakeOfferMessageLabel;

  /// Sous-label du champ message (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'optionnel'**
  String get negotiationMakeOfferMessageOptional;

  /// Texte d'indication du champ message (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Je voyage exactement ce jour-là…'**
  String get negotiationMakeOfferMessageHint;

  /// Erreur de validation du champ prix (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Invalide'**
  String get negotiationMakeOfferInvalidPrice;

  /// Snackbar de succès à l'envoi de l'offre (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Offre envoyée'**
  String get negotiationMakeOfferOfferSentSnackbar;

  /// Label de la bannière d'estimation de prix (make_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Prix du marché'**
  String get negotiationMakeOfferMarketPriceLabel;

  /// Titre de la feuille en étape de paiement final (accept_offer_bottom_sheet.dart, aussi payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer en toute sécurité'**
  String get negotiationPaySecurelyTitle;

  /// Titre de la feuille hors étape de paiement final (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accepter l\'offre'**
  String get negotiationAcceptOfferTitle;

  /// Libellé du bouton pendant le traitement (accept_offer_bottom_sheet.dart, aussi payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Traitement…'**
  String get negotiationProcessingLabel;

  /// Bouton de paiement final (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer ({amount})'**
  String negotiationAcceptOfferPayButtonLabel(String amount);

  /// Bouton d'acceptation du prix, hors paiement final (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer ({amount})'**
  String negotiationAcceptOfferConfirmButtonLabel(String amount);

  /// contextLabel de la feuille Stripe, vu par le voyageur (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement de l\'offre acceptée'**
  String get negotiationAcceptOfferPaymentContextTraveler;

  /// contextLabel de la feuille Stripe, vu par l'expéditeur (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement de votre offre'**
  String get negotiationAcceptOfferPaymentContextSender;

  /// Titre de l'écran de succès après paiement carte (accept_offer_bottom_sheet.dart, payment_recap_bottom_sheet.dart, negotiation_paid_success_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Offre acceptée et payée !'**
  String get negotiationOfferAcceptedPaidTitle;

  /// Sous-titre de l'écran de succès après paiement carte (accept_offer_bottom_sheet.dart, payment_recap_bottom_sheet.dart, negotiation_paid_success_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ton argent est bloqué et sécurisé, le voyageur ne le reçoit qu\'après confirmation de la livraison. Suis ton colis depuis le fil.'**
  String get negotiationOfferAcceptedPaidSubtitle;

  /// CTA des écrans de succès de négociation (accept_offer_bottom_sheet.dart, payment_recap_bottom_sheet.dart, negotiation_paid_success_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir le suivi'**
  String get negotiationTrackShipmentCta;

  /// Sous-titre de l'écran de succès (accord de prix, vu par l'expéditeur) (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes d\'accord sur le prix. Le voyageur va confirmer son trajet, puis tu finaliseras les détails de l\'envoi et le règlement depuis le fil.'**
  String get negotiationAcceptOfferAgreedSubtitleSender;

  /// Sous-titre de l'écran de succès (accord de prix, voyageur avec trajet déjà lié) (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes d\'accord sur le prix. L\'expéditeur va finaliser les détails de l\'envoi et le règlement, tu seras notifié à chaque étape.'**
  String get negotiationAcceptOfferAgreedSubtitleTravelerLinked;

  /// Sous-titre de l'écran de succès (accord de prix, voyageur sans trajet lié) (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes d\'accord sur le prix. Prochaine étape : lie ou crée un trajet pour cette offre afin que l\'expéditeur puisse finaliser le règlement.'**
  String get negotiationAcceptOfferAgreedSubtitleTravelerUnlinked;

  /// Titre de l'écran de succès après accord de prix ou accord cash (accept_offer_bottom_sheet.dart, payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Accord confirmé !'**
  String get negotiationAgreementConfirmedTitle;

  /// Snackbar d'erreur générique du flux de paiement (accept_offer_bottom_sheet.dart, payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get negotiationGenericErrorSnackbar;

  /// Ligne de décomposition de prix, vue voyageur (accept_offer_bottom_sheet.dart, _NegotiationPriceBreakdown)
  ///
  /// In fr, this message translates to:
  /// **'Prix payé par l\'expéditeur'**
  String get negotiationPriceBreakdownPaidBySender;

  /// Ligne de décomposition de prix, vue expéditeur (accept_offer_bottom_sheet.dart, _NegotiationPriceBreakdown)
  ///
  /// In fr, this message translates to:
  /// **'Net voyageur'**
  String get negotiationPriceBreakdownNetTraveler;

  /// Label du total, vue voyageur (accept_offer_bottom_sheet.dart, _NegotiationPriceBreakdown)
  ///
  /// In fr, this message translates to:
  /// **'Tu reçois'**
  String get negotiationPriceBreakdownYouReceive;

  /// Label du total, vue expéditeur (accept_offer_bottom_sheet.dart, _NegotiationPriceBreakdown)
  ///
  /// In fr, this message translates to:
  /// **'Total à régler'**
  String get negotiationPriceBreakdownTotalToSettle;

  /// Badge affiché quand une remise promo réelle s'applique, identique dans les deux langues (accept_offer_bottom_sheet.dart, _NegotiationPriceBreakdown)
  ///
  /// In fr, this message translates to:
  /// **'Promo'**
  String get negotiationPriceBreakdownPromoBadge;

  /// Texte d'explication sous la décomposition de prix, vu voyageur (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'En acceptant, l\'expéditeur effectuera le paiement. Tu recevras {price} à la livraison validée, quel que soit un éventuel code promo utilisé par l\'expéditeur.'**
  String negotiationAcceptOfferInfoTraveler(String price);

  /// Texte d'explication sous la décomposition de prix, vu expéditeur (accept_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'En confirmant, le paiement est bloqué et sécurisé. Le voyageur reçoit le montant à la livraison validée.'**
  String get negotiationAcceptOfferInfoSender;

  /// Titre de la feuille de contre-offre (counter_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Faire une contre-offre'**
  String get negotiationCounterOfferTitle;

  /// Sous-titre : prix actuel (déjà traduit) + round courant (counter_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'{priceLabel} · Round {round}/5'**
  String negotiationCounterOfferSubtitle(String priceLabel, int round);

  /// Label du champ prix (counter_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ton prix proposé'**
  String get negotiationCounterOfferYourPriceLabel;

  /// Label du champ message (counter_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Message (optionnel)'**
  String get negotiationCounterOfferMessageLabel;

  /// Texte d'indication du champ message (counter_offer_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Explique ta proposition…'**
  String get negotiationCounterOfferMessageHint;

  /// Titre de la feuille de rejet (reject_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Rejeter la négociation'**
  String get negotiationRejectTitle;

  /// Bouton de confirmation du rejet (reject_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le rejet'**
  String get negotiationRejectConfirmLabel;

  /// Label du champ raison (reject_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Raison (optionnel)'**
  String get negotiationRejectReasonLabel;

  /// Titre et bouton de la feuille en mode cash (payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer l\'accord'**
  String get negotiationPaymentRecapConfirmAgreementTitle;

  /// Titre de la feuille en mode mobile money (payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer par mobile money'**
  String get negotiationPaymentRecapMobileMoneyTitle;

  /// Bouton de paiement en mode carte (payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer {amount}'**
  String negotiationPaymentRecapPayButtonLabel(String amount);

  /// Bouton de paiement en mode mobile money (payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer {amount} par mobile money'**
  String negotiationPaymentRecapPayMobileMoneyButton(String amount);

  /// contextLabel de la feuille Stripe quand le mode est cash (payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmation de l\'accord'**
  String get negotiationPaymentRecapContextConfirm;

  /// contextLabel de la feuille Stripe quand le mode est carte (payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé'**
  String get negotiationPaymentRecapContextSecure;

  /// Sous-titre de l'écran de succès en mode cash (payment_recap_bottom_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement en espèces : tu remets le montant au voyageur en main propre, à la remise du colis. En cas d\'annulation après la remise, Yadony ne peut pas te rembourser immédiatement mais s\'assurera que le voyageur te restitue ton argent.'**
  String get negotiationPaymentRecapCashSuccessSubtitle;

  /// Ligne du récapitulatif de frais, mode cash (payment_recap_bottom_sheet.dart, PaymentRecapContent)
  ///
  /// In fr, this message translates to:
  /// **'À remettre au voyageur (en espèces)'**
  String get negotiationPaymentRecapCashHandoverLabel;

  /// Sous-ligne du récapitulatif de frais, mode cash (payment_recap_bottom_sheet.dart, PaymentRecapContent)
  ///
  /// In fr, this message translates to:
  /// **'dont frais Yadony (réglés par le voyageur)'**
  String get negotiationPaymentRecapCashFeeNote;

  /// Ligne totale du récapitulatif de frais, mode cash (payment_recap_bottom_sheet.dart, PaymentRecapContent)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur garde net'**
  String get negotiationPaymentRecapCashNetLabel;

  /// Ligne du récapitulatif de frais, mode carte/mobile money (payment_recap_bottom_sheet.dart, PaymentRecapContent)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur touche'**
  String get negotiationPaymentRecapTravelerReceivesLabel;

  /// Ligne du récapitulatif de frais, mode carte/mobile money (payment_recap_bottom_sheet.dart, PaymentRecapContent)
  ///
  /// In fr, this message translates to:
  /// **'Frais de service Yadony'**
  String get negotiationPaymentRecapServiceFeeLabel;

  /// Ligne totale du récapitulatif de frais, mode carte/mobile money (payment_recap_bottom_sheet.dart, PaymentRecapContent)
  ///
  /// In fr, this message translates to:
  /// **'Total à payer'**
  String get negotiationPaymentRecapTotalToPayLabel;

  /// Note explicative sous le récapitulatif de frais, mode cash (payment_recap_bottom_sheet.dart, PaymentRecapContent)
  ///
  /// In fr, this message translates to:
  /// **'Remettez le montant total en espèces au voyageur lors de la remise du colis. Le voyageur déduira ses frais Yadony de ce montant.'**
  String get negotiationPaymentRecapCashNote;

  /// Note explicative sous le récapitulatif de frais, mode mobile money (payment_recap_bottom_sheet.dart, PaymentRecapContent)
  ///
  /// In fr, this message translates to:
  /// **'Une demande de paiement arrive sur le numéro indiqué ci-dessous. Le voyageur reçoit le montant uniquement après confirmation de la livraison.'**
  String get negotiationPaymentRecapMobileMoneyNote;

  /// Note explicative sous le récapitulatif de frais, mode carte (payment_recap_bottom_sheet.dart, PaymentRecapContent)
  ///
  /// In fr, this message translates to:
  /// **'Le montant est bloqué et sécurisé. Le voyageur le reçoit uniquement après confirmation de la livraison.'**
  String get negotiationPaymentRecapSecureNote;

  /// Bannière de confiance, mode cash (payment_recap_bottom_sheet.dart, _TrustBanner)
  ///
  /// In fr, this message translates to:
  /// **'Paiement en main propre à la remise'**
  String get negotiationPaymentRecapCashBannerMessage;

  /// Bannière de confiance, mode mobile money (payment_recap_bottom_sheet.dart, _TrustBanner)
  ///
  /// In fr, this message translates to:
  /// **'Tu valides le paiement sur ton téléphone. Yadony garde l\'argent et ne le verse au voyageur qu\'après confirmation de la livraison.'**
  String get negotiationPaymentRecapMobileMoneyBannerMessage;

  /// Bannière de confiance, mode carte (payment_recap_bottom_sheet.dart, _TrustBanner)
  ///
  /// In fr, this message translates to:
  /// **'Sécurisé · bloqué jusqu\'à la livraison'**
  String get negotiationPaymentRecapSecureBannerMessage;

  /// Titre de la feuille de règlement de commission en solde insuffisant (commission_settlement_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Solde insuffisant'**
  String get negotiationCommissionSettlementTitle;

  /// Texte d'aide de la feuille de règlement de commission (commission_settlement_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Recharge ton portefeuille ou paie la commission directement par carte.'**
  String get negotiationCommissionSettlementHint;

  /// Bouton de recharge du portefeuille (commission_settlement_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Recharger mon portefeuille'**
  String get negotiationCommissionSettlementTopupButton;

  /// Bouton de règlement direct par carte (commission_settlement_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer par carte'**
  String get negotiationCommissionSettlementPayCardButton;

  /// Bouton d'ajout de carte quand le voyageur n'en a pas encore (commission_settlement_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une carte'**
  String get negotiationCommissionSettlementAddCardButton;

  /// Titre de la feuille quand Stripe Connect est disponible dans le pays (payment_capability_block_sheets.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement carte requis'**
  String get negotiationCardCapabilityRequiredTitle;

  /// Titre de la feuille quand Stripe Connect n'est pas disponible dans le pays (payment_capability_block_sheets.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis indisponible'**
  String get negotiationCardCapabilityUnavailableTitle;

  /// Corps de la feuille quand Stripe Connect est disponible dans le pays (payment_capability_block_sheets.dart)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur n\'accepte que le paiement par carte pour ce colis. Active les paiements par carte pour pouvoir lier ce trajet.'**
  String get negotiationCardCapabilityRequiredBody;

  /// Corps de la feuille quand Stripe Connect n'est pas disponible dans le pays (payment_capability_block_sheets.dart)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur n\'accepte que le paiement par carte pour ce colis, et Stripe ne permet pas encore d\'ouvrir un compte de paiement depuis ton pays. Tu peux lier les colis payés en espèces.'**
  String get negotiationCardCapabilityUnavailableBody;

  /// Bouton vers l'onboarding Stripe Connect (payment_capability_block_sheets.dart)
  ///
  /// In fr, this message translates to:
  /// **'Activer le paiement carte'**
  String get negotiationCardCapabilityActivateButton;

  /// Bouton de fermeture quand aucune action n'est possible (payment_capability_block_sheets.dart)
  ///
  /// In fr, this message translates to:
  /// **'J\'ai compris'**
  String get negotiationCardCapabilityUnderstoodButton;

  /// Ligne round abrégé + horodatage relatif d'une carte de négociation colis ; `timeAgo` déjà traduit (my_negotiations_screen.dart, _NegoCard)
  ///
  /// In fr, this message translates to:
  /// **'R.{round}/5 · {timeAgo}'**
  String negotiationCardRoundShortLabel(int round, String timeAgo);

  /// Badge de confiance de l'estimation de prix, valeur HIGH (make_offer_bottom_sheet.dart, _EstimationBanner) — correction relecture C5, remplace l'ancien affichage brut de wireName
  ///
  /// In fr, this message translates to:
  /// **'élevée'**
  String get negotiationMakeOfferConfidenceHigh;

  /// Badge de confiance de l'estimation de prix, valeur MEDIUM (make_offer_bottom_sheet.dart, _EstimationBanner) — correction relecture C5
  ///
  /// In fr, this message translates to:
  /// **'moyenne'**
  String get negotiationMakeOfferConfidenceMedium;

  /// Badge de confiance de l'estimation de prix, valeur LOW/repli (make_offer_bottom_sheet.dart, _EstimationBanner) — correction relecture C5
  ///
  /// In fr, this message translates to:
  /// **'faible'**
  String get negotiationMakeOfferConfidenceLow;

  /// Libellé de la note moyenne (★) dans les fiches de profil (sender_profile_sheet.dart, traveler_profile_sheet.dart) — correction relecture finale C, remplace listingRowLabelNote qui désignait une note écrite
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get profileSheetRatingLabel;

  /// Date limite formatée, ex. deadline de remise (sender_hero_card.dart, traveler_hero_card.dart, _formatDeadline)
  ///
  /// In fr, this message translates to:
  /// **'jusqu\'au {date}'**
  String bidDetailUntil(String date);

  /// Repli quand la ville d'arrivée n'est pas connue (sender_hero_card.dart, traveler_hero_card.dart) — identique en anglais
  ///
  /// In fr, this message translates to:
  /// **'destination'**
  String get bidDetailFallbackDestination;

  /// Bouton de confirmation dans la feuille de signalement d'absence (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signaler l\'absence'**
  String get bidDetailReportNoShowConfirmButton;

  /// Bouton de contestation d'une absence signalée par l'autre partie (sender_hero_card.dart, _ContestationHero)
  ///
  /// In fr, this message translates to:
  /// **'Je conteste'**
  String get bidDetailContestButton;

  /// Titre commun aux bannieres d'absence en attente : auteur du signalement (cancellationNoShowStatus ou deliveryNoShowStatus) (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⏳ Absence signalée'**
  String get bidDetailNoShowReportedTitle;

  /// Titre commun aux memes bannieres une fois la contestation recue (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⚖ Absence contestée'**
  String get bidDetailNoShowContestedTitle;

  /// _DeliveryNoShowHero, sous-titre cote auteur du signalement quand conteste (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'L\'autre partie conteste votre signalement. Notre équipe examine la demande et vous tiendra informé.'**
  String get bidDetailDeliveryNoShowReporterContestedSubtitle;

  /// _DeliveryNoShowHero, sous-titre cote auteur du signalement en attente (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoyé. L\'autre partie a 24 h pour contester. Notre équipe tranche ensuite.'**
  String get bidDetailDeliveryNoShowReporterPendingSubtitle;

  /// _DeliveryNoShowHero, titre cote adversaire une fois sa contestation envoyee (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⚖ Contestation envoyée'**
  String get bidDetailDeliveryNoShowContestSentTitle;

  /// _DeliveryNoShowHero, titre cote adversaire quand le signalement est encore ouvert (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⚠ Une absence est signalée'**
  String get bidDetailDeliveryNoShowAlertTitle;

  /// _DeliveryNoShowHero, sous-titre cote adversaire une fois conteste (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Votre contestation a été transmise. Notre équipe examine la demande et vous tiendra informé.'**
  String get bidDetailDeliveryNoShowContestSentSubtitle;

  /// _DeliveryNoShowHero, sous-titre cote adversaire quand le signalement est encore ouvert (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Une absence à la livraison a été signalée sur cet envoi. Vous pouvez contester si ce signalement est erroné.'**
  String get bidDetailDeliveryNoShowAlertSubtitle;

  /// _DeliveryNoShowHero, bouton de contestation cote adversaire (sender_hero_card.dart, traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Contester ce signalement'**
  String get bidDetailDeliveryNoShowContestButton;

  /// PENDING, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⏳ En attente du voyageur'**
  String get bidDetailSenderPendingTitle;

  /// PENDING, sous-titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous serez notifié dès sa réponse.'**
  String get bidDetailSenderPendingSubtitle;

  /// AWAITING_PAYMENT, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payez pour confirmer l\'envoi'**
  String get bidDetailSenderAwaitingPaymentTitle;

  /// AWAITING_PAYMENT, sous-titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Votre paiement de {amount} sera séquestré jusqu\'à la livraison.'**
  String bidDetailSenderAwaitingPaymentSubtitle(String amount);

  /// PAYMENT_ESCROWED, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'🔒 Paiement sécurisé'**
  String get bidDetailSenderEscrowedTitle;

  /// PAYMENT_ESCROWED, sous-titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{amount} séquestrés. En attente de remise.'**
  String bidDetailSenderEscrowedSubtitle(String amount);

  /// ACCEPTED, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⚡ Remise du colis'**
  String get bidDetailSenderAcceptedTitle;

  /// ACCEPTED, instruction commune avec ou sans fenetre/lieu (sender_hero_card.dart, _buildAcceptedSubtitle)
  ///
  /// In fr, this message translates to:
  /// **'Présentez le QR, ou collez-le sur le colis.'**
  String get bidDetailSenderAcceptedInstructions;

  /// Repli quand bid.travelerName est vide (sender_hero_card.dart, HANDED_OVER)
  ///
  /// In fr, this message translates to:
  /// **'le voyageur'**
  String get bidDetailSenderTravelerFallback;

  /// HANDED_OVER, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'✓ Colis remis à {name}'**
  String bidDetailSenderHandedOverTitle(String name);

  /// HANDED_OVER, sous-titre avec date de depart connue (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Embarquement prévu le {date}.'**
  String bidDetailSenderHandedOverSubtitleWithDate(String date);

  /// HANDED_OVER, sous-titre sans date de depart (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis remis.'**
  String get bidDetailSenderHandedOverSubtitleDefault;

  /// IN_TRANSIT, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'✈ Colis en vol'**
  String get bidDetailSenderInTransitTitle;

  /// IN_TRANSIT, sous-titre avec heure d'arrivee connue (sender_hero_card.dart, _buildInTransitSubtitle)
  ///
  /// In fr, this message translates to:
  /// **'Arrivée prévue {time} à {city}.'**
  String bidDetailSenderInTransitEta(String time, String city);

  /// IN_TRANSIT, sous-titre sans heure d'arrivee (sender_hero_card.dart, _buildInTransitSubtitle)
  ///
  /// In fr, this message translates to:
  /// **'En route vers {city}.'**
  String bidDetailSenderInTransitEnRoute(String city);

  /// IN_TRANSIT, complement quand confirmationCode existe (sender_hero_card.dart, _buildInTransitSubtitle)
  ///
  /// In fr, this message translates to:
  /// **'Le code de retrait figure sur votre billet.'**
  String get bidDetailSenderInTransitTicketNote;

  /// ARRIVED, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'📍 Colis arrivé à destination'**
  String get bidDetailSenderArrivedTitle;

  /// ARRIVED, sous-titre sans instructions saisies par le voyageur (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur est arrivé, les instructions de retrait arrivent bientôt.'**
  String get bidDetailSenderArrivedSubtitleDefault;

  /// Repli quand bid.recipientName est vide (sender_hero_card.dart, COMPLETED/DELIVERED)
  ///
  /// In fr, this message translates to:
  /// **'votre destinataire'**
  String get bidDetailSenderRecipientFallback;

  /// COMPLETED/DELIVERED, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'✓ Livré à {recipient}'**
  String bidDetailSenderDeliveredTitle(String recipient);

  /// COMPLETED/DELIVERED, sous-titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement libéré au voyageur.'**
  String get bidDetailSenderDeliveredSubtitle;

  /// _WindowExpiredHero, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⚠ Fenêtre de remise dépassée'**
  String get bidDetailSenderWindowExpiredTitle;

  /// _WindowExpiredHero, sous-titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le dépôt était possible {window}. Le voyageur ne s\'est pas présenté ?'**
  String bidDetailSenderWindowExpiredSubtitle(String window);

  /// _WindowExpiredHero, bouton d'ouverture de la feuille de signalement (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signaler l\'absence du voyageur'**
  String get bidDetailSenderReportNoShowButton;

  /// Titre de la feuille de signalement d'absence du voyageur (sender_hero_card.dart, _showNoShowSheet)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur ne s\'est pas présenté ?'**
  String get bidDetailSenderNoShowSheetTitle;

  /// Corps de la feuille de signalement d'absence du voyageur (sender_hero_card.dart, _showNoShowSheet)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur ne s\'est pas présenté au point de remise.'**
  String get bidDetailSenderNoShowSheetBody;

  /// Note explicative de la feuille de signalement d'absence du voyageur (sender_hero_card.dart, _showNoShowSheet)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur aura 48 h pour contester. Sans réponse de sa part, l\'envoi sera annulé.'**
  String get bidDetailSenderNoShowSheetHint;

  /// _ContestationHero, decompte expire (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Délai expiré'**
  String get bidDetailSenderContestationExpired;

  /// _ContestationHero, decompte affiche sous le sous-titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⏱ Temps pour contester : {timeLeft}'**
  String bidDetailSenderContestCountdown(String timeLeft);

  /// _ContestationHero, titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⚠ Absence signalée par le voyageur'**
  String get bidDetailSenderNoShowByTravelerTitle;

  /// _ContestationHero, sous-titre (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Il indique que vous n\'étiez pas présent au point de remise.'**
  String get bidDetailSenderNoShowByTravelerSubtitle;

  /// _ContestationHero, bouton d'ouverture de la feuille de confirmation d'absence (sender_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Je confirme'**
  String get bidDetailSenderConfirmNoShowButton;

  /// Titre de la feuille de contestation (sender_hero_card.dart, _showContestSheet)
  ///
  /// In fr, this message translates to:
  /// **'Contester l\'absence'**
  String get bidDetailSenderContestSheetTitle;

  /// Bouton sticky de la feuille de contestation (sender_hero_card.dart, _showContestSheet)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la contestation'**
  String get bidDetailSenderContestConfirmButton;

  /// Corps de la feuille de contestation (sender_hero_card.dart, _showContestSheet)
  ///
  /// In fr, this message translates to:
  /// **'Vous contestez l\'absence signalée par le voyageur.'**
  String get bidDetailSenderContestSheetBody;

  /// Note explicative de la feuille de contestation (sender_hero_card.dart, _showContestSheet)
  ///
  /// In fr, this message translates to:
  /// **'Notre équipe examinera votre demande et vous contactera sous 24 h.'**
  String get bidDetailSenderContestSheetHint;

  /// Titre de la feuille de confirmation d'absence (sender_hero_card.dart, _showConfirmSheet)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer votre absence'**
  String get bidDetailSenderConfirmSheetTitle;

  /// Bouton sticky de la feuille de confirmation d'absence (sender_hero_card.dart, _showConfirmSheet)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer mon absence'**
  String get bidDetailSenderConfirmSheetButton;

  /// Corps de la feuille de confirmation d'absence (sender_hero_card.dart, _showConfirmSheet)
  ///
  /// In fr, this message translates to:
  /// **'En confirmant votre absence, l\'envoi sera annulé et vous ne serez pas débité.'**
  String get bidDetailSenderConfirmSheetBody;

  /// PENDING, titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'📨 Nouvelle demande d\'envoi'**
  String get bidDetailTravelerPendingTitle;

  /// PENDING, sous-titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Gain potentiel : {amount}. Acceptez ou refusez la demande.'**
  String bidDetailTravelerPendingSubtitle(String amount);

  /// ACCEPTED deja scanne par le voyageur (voyageurConfirmed), titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'📷 Lisez le QR du colis'**
  String get bidDetailTravelerScanQrTitle;

  /// ACCEPTED deja scanne par le voyageur (voyageurConfirmed), sous-titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lisez le QR code de l\'expéditeur pour confirmer la prise en charge.'**
  String get bidDetailTravelerScanQrSubtitle;

  /// ACCEPTED, titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⚡ Récupérez le colis'**
  String get bidDetailTravelerAcceptedTitle;

  /// ACCEPTED, instruction avec fenetre/lieu connus (traveler_hero_card.dart, _buildAcceptedSubtitle)
  ///
  /// In fr, this message translates to:
  /// **'Présentez-vous au point de remise.'**
  String get bidDetailTravelerAcceptedInstructions;

  /// ACCEPTED, instruction sans fenetre ni lieu connus (traveler_hero_card.dart, _buildAcceptedSubtitle)
  ///
  /// In fr, this message translates to:
  /// **'Présentez-vous au point de remise convenu avec l\'expéditeur.'**
  String get bidDetailTravelerAcceptedInstructionsDefault;

  /// HANDED_OVER, titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'✓ Colis récupéré'**
  String get bidDetailTravelerCollectedTitle;

  /// HANDED_OVER, sous-titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le colis est en votre possession. Bon voyage !'**
  String get bidDetailTravelerCollectedSubtitle;

  /// IN_TRANSIT, titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'✈ Colis en route'**
  String get bidDetailTravelerInTransitTitle;

  /// IN_TRANSIT, sous-titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'En transit vers {city}. Bonne livraison !'**
  String bidDetailTravelerInTransitSubtitle(String city);

  /// ARRIVED, titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'📍 Arrivé à destination'**
  String get bidDetailTravelerArrivedTitle;

  /// ARRIVED, sous-titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Attendez que le destinataire récupère le colis, puis validez la remise.'**
  String get bidDetailTravelerArrivedSubtitle;

  /// COMPLETED/DELIVERED, titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'✓ Livraison confirmée'**
  String get bidDetailTravelerDeliveredTitle;

  /// COMPLETED/DELIVERED, sous-titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le paiement va être libéré sur votre compte.'**
  String get bidDetailTravelerDeliveredSubtitle;

  /// _WindowExpiredHero, titre (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'⚠ Date limite de dépôt dépassée'**
  String get bidDetailTravelerWindowExpiredTitle;

  /// _WindowExpiredHero, sous-titre avec fenetre connue (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le dépôt était possible {window}. L\'expéditeur ne s\'est pas présenté ?'**
  String bidDetailTravelerWindowExpiredSubtitleWithWindow(String window);

  /// _WindowExpiredHero, sous-titre sans fenetre connue (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur ne s\'est pas présenté au point de dépôt ?'**
  String get bidDetailTravelerWindowExpiredSubtitleDefault;

  /// _WindowExpiredHero, bouton d'ouverture de la feuille de signalement (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signaler l\'absence de l\'expéditeur'**
  String get bidDetailTravelerReportNoShowButton;

  /// Titre de la feuille de signalement d'absence de l'expediteur (traveler_hero_card.dart, _showNoShowSheet)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur ne s\'est pas présenté ?'**
  String get bidDetailTravelerNoShowSheetTitle;

  /// Corps de la feuille de signalement d'absence de l'expediteur (traveler_hero_card.dart, _showNoShowSheet)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur ne s\'est pas présenté au point de remise.'**
  String get bidDetailTravelerNoShowSheetBody;

  /// Note explicative de la feuille de signalement d'absence de l'expediteur (traveler_hero_card.dart, _showNoShowSheet)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur aura 48 h pour contester. Sans réponse de sa part, l\'envoi sera annulé.'**
  String get bidDetailTravelerNoShowSheetHint;

  /// _NoShowReportedHero, sous-titre conteste (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur conteste votre signalement. Notre équipe examine la demande et vous tiendra informé.'**
  String get bidDetailTravelerNoShowContestedSubtitle;

  /// _NoShowReportedHero, sous-titre en attente (traveler_hero_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoyé. L\'expéditeur a 48 h pour confirmer ou contester. Sans réponse, l\'envoi sera annulé automatiquement.'**
  String get bidDetailTravelerNoShowPendingSubtitle;

  /// Libelle du haut, paiement en especes (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'VOUS ENCAISSEZ'**
  String get bidDetailGainCashTopLabel;

  /// Montant affiche, paiement en especes (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{amount} en espèces'**
  String bidDetailGainCashAmount(String amount);

  /// Note, paiement en especes (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Commission Yadony prélevée séparément.'**
  String get bidDetailGainCashNote;

  /// Pastille, paiement en especes (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'ESPÈCES'**
  String get bidDetailGainCashPill;

  /// Libelle du haut, paiement terminal (mobile money verse ou carte recue) (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'VOUS AVEZ REÇU'**
  String get bidDetailGainReceivedTopLabel;

  /// Note, mobile money verse (statut terminal) (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Versé sur ton compte mobile money.'**
  String get bidDetailGainMobileMoneyPaidNote;

  /// Pastille, mobile money verse (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'● Versé'**
  String get bidDetailGainPaidPill;

  /// Libelle du haut, paiement encore en attente (mobile money ou carte sequestree) (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'VOUS RECEVEZ'**
  String get bidDetailGainReceivingTopLabel;

  /// Note, mobile money en attente de livraison (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Versé sur ton compte mobile money à la livraison.'**
  String get bidDetailGainMobileMoneyPendingNote;

  /// Pastille, mobile money en attente (traveler_gain_card.dart) - identique en anglais
  ///
  /// In fr, this message translates to:
  /// **'📱 mobile money'**
  String get bidDetailGainMobileMoneyPill;

  /// Pastille, paiement carte recu (statut terminal) (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'● Reçu'**
  String get bidDetailGainReceivedPill;

  /// Libelle du haut, envoi annule (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'PAIEMENT'**
  String get bidDetailGainCancelledTopLabel;

  /// Note, envoi annule (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement annulé.'**
  String get bidDetailGainCancelledNote;

  /// Note, paiement carte sequestre (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Libéré à la livraison.'**
  String get bidDetailGainEscrowedNote;

  /// Pastille, paiement carte sequestre (traveler_gain_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'🔒 séquestré'**
  String get bidDetailGainEscrowedPill;

  /// Titre du sheet affiché quand la carte de commission est refusée (bid_detail_screen.dart, tâche D2)
  ///
  /// In fr, this message translates to:
  /// **'Paiement refusé'**
  String get bidDetailCardDeclinedTitle;

  /// Indication sous le message d'erreur du sheet carte refusée (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Changez votre carte de commission pour accepter cette demande.'**
  String get bidDetailCardDeclinedHint;

  /// Bouton du sheet carte refusée (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Changer ma carte de commission'**
  String get bidDetailChangeCommissionCard;

  /// Titre du sheet solde insuffisant (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Solde insuffisant'**
  String get bidDetailInsufficientBalanceTitle;

  /// Indication du sheet solde insuffisant (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Recharge ton portefeuille ou paie la commission directement par carte.'**
  String get bidDetailInsufficientBalanceHint;

  /// Bouton du sheet solde insuffisant (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Recharger mon portefeuille'**
  String get bidDetailTopupWallet;

  /// Bouton du sheet solde insuffisant, quand une carte existe déjà (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer par carte'**
  String get bidDetailPayByCard;

  /// Bouton du sheet solde insuffisant, quand aucune carte n'existe (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une carte'**
  String get bidDetailAddCard;

  /// Snackbar après acceptation via BidAcceptanceBloc (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée ! Définissez maintenant la fenêtre de remise.'**
  String get bidDetailAcceptedSetHandoverWindow;

  /// Snackbar NoShowReported (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Absence signalée. L\'expéditeur a 48 h pour contester.'**
  String get bidDetailNoShowReportedSnackbar;

  /// Snackbar DeliveryNoShowReported (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Absence signalée. L\'autre partie a 24 h pour contester.'**
  String get bidDetailDeliveryNoShowReportedSnackbar;

  /// Snackbar DeliveryNoShowContested et NoShowContested, même texte (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Contestation envoyée. Notre équipe va examiner votre demande.'**
  String get bidDetailContestSentSnackbar;

  /// Snackbar NoShowConfirmed (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Absence confirmée. L\'envoi a été annulé, vous ne serez pas débité.'**
  String get bidDetailNoShowConfirmedSnackbar;

  /// Snackbar CancelledAfterHandover (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trajet annulé. Restituez le colis sous 3 jours avec le code de retour.'**
  String get bidDetailCancelledAfterHandoverSnackbar;

  /// Snackbar ReturnConfirmed (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Retour confirmé. Le colis a bien été restitué.'**
  String get bidDetailReturnConfirmedSnackbar;

  /// Snackbar BidAccepted du BidBloc (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée !'**
  String get bidDetailAcceptedSnackbar;

  /// Snackbar BidRejected (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée.'**
  String get bidDetailRejectedSnackbar;

  /// Snackbar BidPresenceConfirmed (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Présence confirmée !'**
  String get bidDetailPresenceConfirmedSnackbar;

  /// Snackbar BidCancelled (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande annulée. L\'expéditeur sera remboursé.'**
  String get bidDetailCancelledSnackbar;

  /// Snackbar BidDeleted (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Demande supprimée.'**
  String get bidDetailDeletedSnackbar;

  /// Snackbar BidNotFound (bid_detail_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ce colis n\'existe plus'**
  String get bidDetailNotFoundSnackbar;

  /// Tooltip et libellé de tuile pour partager le lien de suivi (bid_detail_screen.dart, bid_detail_action_bars.dart, quick_actions_row.dart)
  ///
  /// In fr, this message translates to:
  /// **'Partager le suivi'**
  String get bidDetailShareTracking;

  /// Tooltip du bouton ⋮ et titre des sheets d'options (bid_detail_screen.dart, bid_detail_action_bars.dart, traveler_options_sheet.dart) - identique en anglais
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get bidDetailOptionsTitle;

  /// Titre du sheet de refus (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Refuser la demande'**
  String get bidDetailDeclineRequestTitle;

  /// Sous-titre du sheet de refus (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous indiquer une raison à l\'expéditeur ?'**
  String get bidDetailDeclineRequestSubtitle;

  /// Bouton de confirmation du sheet de refus (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le refus'**
  String get bidDetailConfirmDecline;

  /// Hint du champ de raison de refus (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Raison (optionnelle)'**
  String get bidDetailReasonHint;

  /// Bouton ConfirmPresenceBar (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer ma présence'**
  String get bidDetailConfirmPresence;

  /// Bouton de paiement expéditeur (bid_detail_action_bars.dart, sender_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer mon envoi'**
  String get bidDetailPayMyShipment;

  /// Libellé/titre partagé pour supprimer une demande (bid_detail_action_bars.dart, traveler_options_sheet.dart, traveler_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette demande'**
  String get bidDetailDeleteRequest;

  /// Corps du dialog de suppression, vue voyageur d'une demande refusée (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette demande refusée sera retirée définitivement de votre liste.'**
  String get bidDetailDeleteRejectedBody;

  /// EscrowBadge, paiement libéré (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voyageur payé · {amount}'**
  String bidDetailEscrowReleasedLabel(String amount);

  /// EscrowBadge, paiement remboursé (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remboursé · {amount}'**
  String bidDetailEscrowRefundedLabel(String amount);

  /// EscrowBadge, paiement échoué (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement échoué'**
  String get bidDetailEscrowFailedLabel;

  /// EscrowBadge, statut PENDING (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé · En attente du voyageur'**
  String get bidDetailEscrowSecuredPendingLabel;

  /// EscrowBadge, statut ACCEPTED ou défaut (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé · {amount}'**
  String bidDetailEscrowSecuredLabel(String amount);

  /// _CashBadge (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement en espèces à la remise'**
  String get bidDetailCashAtDropoffLabel;

  /// _MobileMoneyBadge (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement mobile money'**
  String get bidDetailMobileMoneyPaymentLabel;

  /// Tuile d'options expéditeur : signaler le trajet (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signaler ce trajet'**
  String get bidDetailReportTripLabel;

  /// Sous-titre commun des tuiles de signalement (bid_detail_action_bars.dart, traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signaler un problème au support Yadony'**
  String get bidDetailReportSubtitle;

  /// Tuile d'options expéditeur : contacter le voyageur (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Contacter le voyageur'**
  String get bidDetailContactTravelerLabel;

  /// Sous-titre de la tuile contacter le voyageur (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un message au voyageur'**
  String get bidDetailContactTravelerSubtitle;

  /// Sous-titre de la tuile partager le suivi (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien de suivi au destinataire'**
  String get bidDetailShareTrackingSubtitle;

  /// Sous-titre annulation avant remise (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Votre paiement sera remboursé automatiquement'**
  String get bidDetailCancelRefundAutoSubtitle;

  /// Sous-titre annulation après remise, tuile d'options (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remboursement intégral · vous récupérez votre colis'**
  String get bidDetailCancelAfterHandoverOptionSubtitle;

  /// Sous-titre commun des tuiles de suppression (bid_detail_action_bars.dart, traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Retirer définitivement de votre historique'**
  String get bidDetailRemoveFromHistorySubtitle;

  /// Corps du dialog d'annulation avant remise (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment annuler votre demande d\'envoi ? Cette action est définitive.'**
  String get bidDetailCancelConfirmBody;

  /// Bouton de dismiss des dialogs d'annulation (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get bidDetailNo;

  /// Bouton de confirmation des dialogs d'annulation (bid_detail_action_bars.dart, sender_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Oui, annuler'**
  String get bidDetailConfirmCancelButton;

  /// Titre du dialog d'annulation après remise (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annuler après remise ?'**
  String get bidDetailCancelAfterHandoverTitle;

  /// Corps du dialog d'annulation après remise (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le colis est déjà chez le voyageur. Vous serez intégralement remboursé et récupérerez votre colis : le voyageur confirmera la restitution en saisissant votre code de retour.'**
  String get bidDetailCancelAfterHandoverBody;

  /// Corps du dialog de suppression, vue expéditeur (bid_detail_action_bars.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette demande sera définitivement supprimée de votre historique.'**
  String get bidDetailDeleteConfirmBody;

  /// En-tête de l'accordéon (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Plus de détails'**
  String get bidDetailMoreDetails;

  /// Titre de section 1 de l'accordéon (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'DÉPÔT DU COLIS'**
  String get bidDetailSectionDropoff;

  /// InfoRow lieu de remise (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get bidDetailLocationLabel;

  /// Libellé InfoRow quand le colis a déjà été remis (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remise'**
  String get bidDetailHandoverStatusLabel;

  /// Libellé InfoRow avant remise (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Présence confirmée'**
  String get bidDetailPresenceConfirmedLabel;

  /// Valeur InfoRow quand le colis a déjà été remis (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis remis ✓'**
  String get bidDetailParcelHandedOverValue;

  /// Valeur InfoRow, présence confirmée (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Oui ✓'**
  String get bidDetailYesValue;

  /// Valeur InfoRow, présence non confirmée (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Non encore'**
  String get bidDetailNotYetValue;

  /// InfoRow tarif brut par kg (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tarif par kg'**
  String get bidDetailPricePerKgLabel;

  /// Titre de section 3 de l'accordéon (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'LIEN DE SUIVI'**
  String get bidDetailSectionTrackingLink;

  /// Titre de section 4 de l'accordéon (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'RESPONSABILITÉ LÉGALE'**
  String get bidDetailSectionLegal;

  /// Disclaimer sans date de signature (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Disclaimer signé'**
  String get bidDetailDisclaimerSignedNoDate;

  /// Repli du disclaimer sans locale, sans « à » entre date et heure (details_accordion.dart)
  ///
  /// In fr, this message translates to:
  /// **'Disclaimer signé le {date} {time}'**
  String bidDetailDisclaimerSignedCompact(String date, String time);

  /// Tuile d'options voyageur : contacter l'expéditeur (traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Contacter l\'expéditeur'**
  String get bidDetailContactSenderLabel;

  /// Sous-titre de la tuile contacter l'expéditeur (traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un message à l\'expéditeur'**
  String get bidDetailContactSenderSubtitle;

  /// Tuile d'options voyageur et titre du sous-sheet colis (traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Détails du colis'**
  String get bidDetailParcelDetailsLabel;

  /// Sous-titre de la tuile détails du colis (traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir les informations du colis et du destinataire'**
  String get bidDetailParcelDetailsSubtitle;

  /// Tuile d'options voyageur : signaler l'expéditeur (traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Signaler l\'expéditeur'**
  String get bidDetailReportSenderLabel;

  /// Tuile d'options voyageur : annuler ce transport (traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annuler ce transport'**
  String get bidDetailCancelTransportLabel;

  /// Sous-titre annuler ce transport, statut HANDED_OVER (traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Vous devrez restituer le colis sous 3 jours'**
  String get bidDetailCancelTransportHandedOverSubtitle;

  /// Sous-titre annuler ce transport, autre statut (traveler_options_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur sera remboursé automatiquement'**
  String get bidDetailCancelTransportAcceptedSubtitle;

  /// Bouton AWAITING_PAYMENT mobile money (sender_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payer par mobile money'**
  String get bidDetailPayByMobileMoney;

  /// Bouton statut ACCEPTED (sender_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Afficher le QR de remise'**
  String get bidDetailShowPickupQr;

  /// Bouton/tuile/corridor de repli de suivi (sender_sticky_bar.dart, quick_actions_row.dart)
  ///
  /// In fr, this message translates to:
  /// **'Suivi du colis'**
  String get bidDetailTrackParcel;

  /// Bouton statut COMPLETED/DELIVERED, pas encore noté (sender_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Noter le voyageur'**
  String get bidDetailRateTraveler;

  /// Titre du dialog d'annulation AWAITING_PAYMENT (sender_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande de transport ?'**
  String get bidDetailCancelTransportRequestTitle;

  /// Corps du dialog d'annulation AWAITING_PAYMENT (sender_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement n\'a été effectué. La demande sera retirée.'**
  String get bidDetailCancelTransportRequestBody;

  /// Titre par défaut du dialog de suppression (sender_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette demande ?'**
  String get bidDetailDeleteRequestQuestionTitle;

  /// Corps par défaut du dialog de suppression (sender_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Elle sera retirée définitivement de votre historique.'**
  String get bidDetailDeleteRequestDefaultBody;

  /// Ligne d'information AWAITING_PAYMENT mobile money, vue voyageur (traveler_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente du paiement de l\'expéditeur (mobile money).'**
  String get bidDetailAwaitingSenderMobileMoneyPayment;

  /// Bouton étape Départ (traveler_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lire le QR du colis'**
  String get bidDetailScanParcelQr;

  /// Bouton étape Transit (traveler_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lire le QR de transit'**
  String get bidDetailScanTransitQr;

  /// Bouton étape Arrivée, valider la remise au destinataire (traveler_sticky_bar.dart)
  ///
  /// In fr, this message translates to:
  /// **'Valider la remise'**
  String get bidDetailConfirmHandover;

  /// Titre du sheet QR (qr_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'QR du colis'**
  String get bidDetailQrSheetTitle;

  /// Snackbar d'échec d'enregistrement du QR (qr_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer l\'image'**
  String get bidDetailQrSaveErrorSnackbar;

  /// Snackbar de succès d'enregistrement du QR (qr_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'QR code enregistré dans votre galerie'**
  String get bidDetailQrSavedSnackbar;

  /// Sujet du partage natif du QR (qr_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'QR du colis Yadony'**
  String get bidDetailQrShareSubject;

  /// Texte du partage natif du QR (qr_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'QR à présenter ou à coller sur le colis.'**
  String get bidDetailQrShareText;

  /// Snackbar d'échec de partage du QR (qr_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Impossible de partager le QR code'**
  String get bidDetailQrShareErrorSnackbar;

  /// Instruction affichée sous le QR (qr_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lu par le voyageur à la remise, puis à chaque étape jusqu\'au retrait. Vous pouvez aussi l\'imprimer et le coller sur le colis.'**
  String get bidDetailQrInstructions;

  /// Titre du sheet code de retour, vue expéditeur (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Code de retour'**
  String get bidDetailReturnCodeTitle;

  /// Sous-titre du sheet code de retour (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'À communiquer au voyageur en récupérant votre colis'**
  String get bidDetailReturnCodeSubtitle;

  /// Snackbar après copie du code de retour (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Code copié'**
  String get bidDetailReturnCodeCopiedSnackbar;

  /// Bouton copier le code de retour (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Copier le code'**
  String get bidDetailReturnCopyCode;

  /// Indication avec date limite de restitution (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur doit vous restituer le colis avant le {date}. Donnez-lui ce code uniquement en récupérant votre colis.'**
  String bidDetailReturnDeadlineHint(String date);

  /// Indication sans date limite (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Donnez ce code au voyageur uniquement en récupérant votre colis.'**
  String get bidDetailReturnNoDeadlineHint;

  /// Titre de la confirmation de restitution (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis restitué'**
  String get bidDetailReturnedTitle;

  /// Sous-titre de la confirmation de restitution (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur a confirmé vous avoir restitué le colis.'**
  String get bidDetailReturnedSubtitle;

  /// Titre du sheet de saisie du code de retour, vue voyageur (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le retour'**
  String get bidDetailReturnEntryTitle;

  /// Sous-titre du sheet de saisie du code de retour (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code de retour fourni par l\'expéditeur'**
  String get bidDetailReturnEntrySubtitle;

  /// Bouton de confirmation de restitution (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la restitution'**
  String get bidDetailReturnConfirmButton;

  /// Indication sous le clavier PIN de saisie du code (return_code_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'En confirmant, vous déclarez avoir restitué le colis à l\'expéditeur.'**
  String get bidDetailReturnConfirmHint;

  /// Titre du sheet de code de retrait (retrait_code_sheet.dart, tâche D2, réutilisé par D3)
  ///
  /// In fr, this message translates to:
  /// **'Code de retrait'**
  String get ticketPickupCode;

  /// Titre de la carte paiement, vue expéditeur (paiement_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get bidDetailPaymentCardTitle;

  /// Corps de la carte paiement, méthode mobile money (paiement_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement mobile money, gardé en sécurité par Yadony jusqu\'à la livraison : {amount}'**
  String bidDetailMobileMoneySecuredLabel(String amount);

  /// Badge de la carte paiement, méthode mobile money (paiement_card.dart) - identique en anglais
  ///
  /// In fr, this message translates to:
  /// **'MOBILE MONEY'**
  String get bidDetailMobileMoneyBadge;

  /// Corps de la carte paiement, méthode cash/Wave/Orange Money (paiement_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'À régler en espèces à la remise : {amount}'**
  String bidDetailCashAtDropoffAmountLabel(String amount);

  /// Badge de la carte paiement, méthode cash (paiement_card.dart) - identique en anglais
  ///
  /// In fr, this message translates to:
  /// **'CASH'**
  String get bidDetailCashBadge;

  /// Corps de la carte paiement, stripe statut terminal (paiement_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement libéré ✓'**
  String get bidDetailPaymentReleasedLabel;

  /// Corps de la carte paiement, stripe statut annulé (paiement_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{amount} remboursé'**
  String bidDetailAmountRefundedLabel(String amount);

  /// Corps de la carte paiement, stripe par défaut/en séquestre (paiement_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{amount} séquestré : libéré à la livraison'**
  String bidDetailEscrowedUntilDeliveryLabel(String amount);

  /// Texte du partage natif du lien de suivi (quick_actions_row.dart)
  ///
  /// In fr, this message translates to:
  /// **'Suivez votre colis Yadony en temps réel :\n{url}'**
  String bidDetailShareTrackingMessage(String url);

  /// Sujet du partage natif du lien de suivi (quick_actions_row.dart)
  ///
  /// In fr, this message translates to:
  /// **'Suivi de colis Yadony · {number}'**
  String bidDetailTrackingShareSubject(String number);

  /// Étiquette de rôle en tête de la carte expéditeur (expediteur_contact_card.dart, tâche D2)
  ///
  /// In fr, this message translates to:
  /// **'EXPÉDITEUR'**
  String get bidSenderRoleTag;

  /// Pill affichée quand l'évaluation du voyageur a déjà été soumise (sender_detail_body.dart)
  ///
  /// In fr, this message translates to:
  /// **'Évaluation envoyée'**
  String get bidDetailRatingSentBadge;

  /// Titre de la carte fusionnée colis + destinataire (colis_destinataire_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis & destinataire'**
  String get bidDetailParcelRecipientTitle;

  /// Clé dédiée (Ruling R40, correction relecture D2) — remplace la réutilisation de requestDetailMenuCancelLabel (feature package_request) dans bid_detail_action_bars.dart et sender_sticky_bar.dart
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get bidDetailCancelRequestLabel;

  /// Clé dédiée (Ruling R40) — remplace requestCreateRecapPackage dans colis_destinataire_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Colis'**
  String get bidDetailParcelLabel;

  /// Clé dédiée (Ruling R40) — remplace requestCreateRecipientSection dans colis_destinataire_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Destinataire'**
  String get bidDetailRecipientLabel;

  /// Clé dédiée (Ruling R40) — remplace requestCreateRecipientPhoneLabel dans colis_destinataire_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get bidDetailPhoneLabel;

  /// Clé dédiée (Ruling R40) — remplace requestDescriptionLabel dans colis_destinataire_card.dart - identique en anglais
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get bidDetailDescriptionLabel;

  /// Clé dédiée (Ruling R40) — remplace voyageurCardCallSemanticLabel réutilisée sur la carte expéditeur (expediteur_contact_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get bidDetailSenderCallSemanticLabel;

  /// Clé dédiée (Ruling R40) — remplace voyageurCardOpenChatSemanticLabel réutilisée sur la carte expéditeur (expediteur_contact_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la discussion'**
  String get bidDetailSenderOpenChatSemanticLabel;

  /// Clé dédiée (Ruling R40) — remplace tripPosterCopyLinkButton dans details_accordion.dart (lien de suivi)
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get bidDetailCopyTrackingLinkButton;

  /// Clé dédiée (Ruling R40) — remplace tripPosterLinkCopiedMessage dans details_accordion.dart (lien de suivi)
  ///
  /// In fr, this message translates to:
  /// **'Lien copié'**
  String get bidDetailTrackingLinkCopiedMessage;

  /// Clé dédiée (Ruling R40) — remplace negotiationThreadAcceptButton dans TravelerPendingBar (bid_detail_action_bars.dart), accepter une demande de transport
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get bidDetailAcceptRequestButton;

  /// Clé dédiée (Ruling R40) — remplace negotiationThreadRejectButton dans TravelerPendingBar (bid_detail_action_bars.dart), refuser une demande de transport
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get bidDetailDeclineRequestButton;

  /// Bouton talon annulation avec restitution en attente, vue expéditeur (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'Code de retour'**
  String get ticketReturnCodeButton;

  /// Bouton talon annulation avec restitution en attente, vue voyageur (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le retour'**
  String get ticketConfirmReturnButton;

  /// Bloc restitution confirmée du talon (billet_talon.dart, clé dédiée : duplique bidDetailReturnedTitle d'un autre préfixe, R40)
  ///
  /// In fr, this message translates to:
  /// **'Colis restitué'**
  String get ticketParcelReturnedLabel;

  /// CTA rematch du talon (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir les trajets alternatifs'**
  String get ticketViewAlternativeTripsButton;

  /// Bouton QR du talon, variante compacte (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'QR du colis'**
  String get ticketQrButtonCompact;

  /// Bouton QR du talon, variante pleine largeur (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'QR du colis (à présenter ou coller sur le colis)'**
  String get ticketQrButtonFull;

  /// Bouton voyageur vers les étapes de scan du talon (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lire les QR des étapes'**
  String get ticketScanStepsButton;

  /// Placeholder sender / PENDING du talon (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente de confirmation du voyageur'**
  String get ticketAwaitingTravelerConfirmation;

  /// Bloc expéditeur en attente de paiement mobile money du talon (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'Le voyageur a accepté : paie par mobile money depuis le bouton en bas pour sécuriser ton envoi.'**
  String get ticketSenderAwaitingMobileMoneyHint;

  /// Bloc voyageur en attente de paiement du talon (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente du paiement de l\'expéditeur'**
  String get ticketTravelerAwaitingPayment;

  /// Bloc terminal COMPLETED/DELIVERED du talon (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis livré'**
  String get ticketParcelDeliveredLabel;

  /// Message terminal REJECTED/CANCELLED du talon (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette demande est terminée.'**
  String get ticketRequestClosedMessage;

  /// Libellé de la mini-stat poids du talon voyageur, casse conservée telle quelle dans le code source (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'POIDS'**
  String get ticketMiniStatWeightLabel;

  /// Libellé de la mini-stat catégorie du talon voyageur, mot identique dans les deux langues, casse conservée telle quelle (billet_talon.dart)
  ///
  /// In fr, this message translates to:
  /// **'TYPE'**
  String get ticketMiniStatCategoryLabel;

  /// Étiquette de section au-dessus des chiffres du code, casse conservée telle quelle (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'CODE DE RETRAIT'**
  String get ticketPickupCodeSectionLabel;

  /// Bouton copier le code de retrait (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Copier le code'**
  String get ticketCopyCodeButton;

  /// Snackbar après copie du code de retrait (talon_retrait_code_view.dart, clé dédiée : duplique bidDetailReturnCodeCopiedSnackbar d'un autre préfixe, R40)
  ///
  /// In fr, this message translates to:
  /// **'Code copié'**
  String get ticketCodeCopiedSnackbar;

  /// État de chargement du bouton visibilité publique du code (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour…'**
  String get ticketUpdatingLabel;

  /// Bouton visibilité publique active du code (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Retirer le code de la page de suivi'**
  String get ticketHideCodeFromTrackingPageButton;

  /// Bouton visibilité publique inactive du code (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mettre le code sur la page de suivi'**
  String get ticketShowCodeOnTrackingPageButton;

  /// Confirmation sous le bouton visibilité publique (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Code visible sur la page de suivi'**
  String get ticketCodeVisibleOnTrackingPageLabel;

  /// État de chargement du bouton régénérer (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Régénération…'**
  String get ticketRegeneratingLabel;

  /// Bouton régénérer bloqué par le rate-limit, {remaining} déjà formaté en heures/minutes/secondes (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Disponible dans {remaining}'**
  String ticketRegenerateAvailableInLabel(String remaining);

  /// Bouton régénérer disponible (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Régénérer le code'**
  String get ticketRegenerateCodeButton;

  /// Message d'alerte rate-limit atteint, {remaining} déjà formaté (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Limite de 5 régénérations atteinte. Le bouton se réactivera automatiquement dans {remaining}.'**
  String ticketRegenerateLimitReachedMessage(String remaining);

  /// Message d'information hors rate-limit (talon_retrait_code_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Transmettez ce code au voyageur par vos propres moyens (SMS, WhatsApp…). Il devra le saisir à la livraison.'**
  String get ticketShareCodeManuallyHint;

  /// Tampon de statut AWAITING_PAYMENT, vue expéditeur (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'À payer'**
  String get ticketStatusAwaitingPaymentSenderLabel;

  /// Tampon de statut AWAITING_PAYMENT, vue voyageur (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'Paiement en attente'**
  String get ticketStatusAwaitingPaymentTravelerLabel;

  /// Tampon de statut PENDING/PAYMENT_ESCROWED (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get ticketStatusPendingLabel;

  /// Tampon de statut ACCEPTED (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmé'**
  String get ticketStatusAcceptedLabel;

  /// Tampon de statut HANDED_OVER (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'En route'**
  String get ticketStatusHandedOverLabel;

  /// Tampon de statut IN_TRANSIT (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'En transit'**
  String get ticketStatusInTransitLabel;

  /// Tampon de statut ARRIVED (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'Arrivé'**
  String get ticketStatusArrivedLabel;

  /// Tampon de statut COMPLETED/DELIVERED (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livré'**
  String get ticketStatusDeliveredLabel;

  /// Tampon de statut REJECTED (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get ticketStatusRejectedLabel;

  /// Tampon de statut CANCELLED, orthographe américaine (R38) (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get ticketStatusCancelledLabel;

  /// Tampon de statut NO_SHOW (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'Absent'**
  String get ticketStatusNoShowLabel;

  /// Tampon de statut PARCEL_REFUSED (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis refusé'**
  String get ticketStatusParcelRefusedLabel;

  /// Tampon de statut EXPIRED (billet_status_stamp.dart)
  ///
  /// In fr, this message translates to:
  /// **'Expiré'**
  String get ticketStatusExpiredLabel;

  /// Bouton talon voyageur, action scan (talon_traveler_action_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Lire le QR du colis'**
  String get ticketScanQrActionLabel;

  /// Indication au-dessus du bouton scan (talon_traveler_action_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'À la remise, lisez le QR de l\'expéditeur.'**
  String get ticketScanQrActionHint;

  /// Bouton talon voyageur, action confirmation de livraison (talon_traveler_action_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la livraison'**
  String get ticketConfirmDeliveryActionLabel;

  /// Indication au-dessus du bouton confirmation de livraison (talon_traveler_action_view.dart)
  ///
  /// In fr, this message translates to:
  /// **'À l\'arrivée, saisissez le code de retrait de l\'expéditeur.'**
  String get ticketConfirmDeliveryActionHint;

  /// Texte de partage sans lien de suivi (talon_tracking_strip.dart)
  ///
  /// In fr, this message translates to:
  /// **'Suivez mon colis Yadony #{trackingNumber}'**
  String ticketShareTrackingMessage(String trackingNumber);

  /// Texte de partage avec lien de suivi (talon_tracking_strip.dart)
  ///
  /// In fr, this message translates to:
  /// **'Suivez mon colis Yadony #{trackingNumber} en temps réel :\n{link}'**
  String ticketShareTrackingMessageWithLink(String trackingNumber, String link);

  /// Étiquette de section au-dessus du numéro de suivi, casse conservée telle quelle (talon_tracking_strip.dart)
  ///
  /// In fr, this message translates to:
  /// **'N° DE SUIVI'**
  String get ticketTrackingNumberSectionLabel;

  /// Snackbar après copie du numéro de suivi (talon_tracking_strip.dart)
  ///
  /// In fr, this message translates to:
  /// **'Numéro copié'**
  String get ticketTrackingNumberCopiedSnackbar;

  /// Bandeau d'en-tête du billet, la marque Yadony reste inchangée (colis_billet.dart)
  ///
  /// In fr, this message translates to:
  /// **'YADONY · TRANSPORT DE COLIS'**
  String get ticketHeaderTagline;

  /// Libellé de la colonne départ de la zone dates du billet (colis_billet.dart, clé dédiée : hors préfixes de domaine partagés, R40)
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get ticketDepartureLabel;

  /// Libellé de la colonne arrivée de la zone dates du billet (colis_billet.dart, clé dédiée : hors préfixes de domaine partagés, R40)
  ///
  /// In fr, this message translates to:
  /// **'Arrivée'**
  String get ticketArrivalLabel;

  /// Badge pill de statut IN_TRANSIT, casse conservée telle quelle (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'EN TRANSIT'**
  String get shipmentBadgeInTransit;

  /// Badge pill de statut ARRIVED (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'ARRIVÉ'**
  String get shipmentBadgeArrived;

  /// Badge pill de statut HANDED_OVER (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'REMIS'**
  String get shipmentBadgeHandedOver;

  /// Badge pill de statut ACCEPTED (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'À REMETTRE'**
  String get shipmentBadgeToHandOver;

  /// Badge pill de statut PENDING/AWAITING_PAYMENT/PAYMENT_ESCROWED (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'EN ATTENTE'**
  String get shipmentBadgeWaiting;

  /// Badge pill de statut COMPLETED (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'LIVRÉ'**
  String get shipmentBadgeDelivered;

  /// Badge pill de statut CANCELLED, orthographe américaine (R38) (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'ANNULÉ'**
  String get shipmentBadgeCancelled;

  /// Badge pill de statut REJECTED (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'REFUSÉ'**
  String get shipmentBadgeRejected;

  /// Badge pill de statut NO_SHOW (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'ABSENT'**
  String get shipmentBadgeNoShow;

  /// Badge pill de statut EXPIRED (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'EXPIRÉ'**
  String get shipmentBadgeExpired;

  /// Badge pill de statut PARCEL_REFUSED (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'COLIS REFUSÉ'**
  String get shipmentBadgeParcelRefused;

  /// Libellé d'étape ACCEPTED sous le stepper (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remise au voyageur à venir'**
  String get shipmentStepAcceptedLabel;

  /// Libellé d'étape HANDED_OVER sous le stepper (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis remis au voyageur'**
  String get shipmentStepHandedOverLabel;

  /// Libellé d'étape IN_TRANSIT sous le stepper (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'En vol vers {city}'**
  String shipmentStepInTransitLabel(String city);

  /// Repli de {city} quand la ville d'arrivée est inconnue, mot identique dans les deux langues (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'destination'**
  String get shipmentDestinationFallback;

  /// Libellé d'étape ARRIVED sous le stepper (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Arrivé, prêt à être récupéré'**
  String get shipmentStepArrivedLabel;

  /// Libellé d'étape COMPLETED sous le stepper (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livré à destination'**
  String get shipmentStepDeliveredLabel;

  /// CTA pied de carte, statuts en transit (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Suivre le colis →'**
  String get shipmentCtaTrackParcel;

  /// CTA pied de carte, statut ACCEPTED (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir le QR →'**
  String get shipmentCtaViewQr;

  /// CTA pied de carte, autres statuts (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Détails →'**
  String get shipmentCtaDetails;

  /// Ligne meta poids sans destinataire, {weight} déjà formaté avec son unité (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis {weight}'**
  String shipmentParcelWeightLabel(String weight);

  /// Ligne meta poids avec destinataire, {weight} déjà formaté avec son unité (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis {weight} · pour {recipient}'**
  String shipmentParcelWeightForRecipientLabel(String weight, String recipient);

  /// Libellé de pastille 1/5 du stepper (shipment_card.dart, clé dédiée : casse différente du badge REMIS, R40)
  ///
  /// In fr, this message translates to:
  /// **'Remis'**
  String get shipmentStepperHandedOverLabel;

  /// Libellé de pastille 2/5 du stepper (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Embarqué'**
  String get shipmentStepperEmbarkedLabel;

  /// Libellé de pastille 3/5 du stepper (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'En vol'**
  String get shipmentStepperInFlightLabel;

  /// Libellé de pastille 4/5 du stepper (shipment_card.dart, clé dédiée : casse différente du badge ARRIVÉ, R40)
  ///
  /// In fr, this message translates to:
  /// **'Arrivé'**
  String get shipmentStepperArrivedLabel;

  /// Libellé de pastille 5/5 du stepper (shipment_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get shipmentStepperDeliveryLabel;

  /// Titre du sheet de filtre par statut (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Filtrer par statut'**
  String get shipmentStatusFilterTitle;

  /// Bouton appliquer du sheet de filtre par statut, avec le nombre de statuts choisis (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Appliquer ({count})'**
  String shipmentStatusFilterApplyWithCount(int count);

  /// Groupe de statuts « en cours », réutilisé comme chip rapide de la liste d'envois (shipment_status_filter_sheet.dart, shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get shipmentGroupInProgress;

  /// Groupe de statuts « en attente », réutilisé comme chip rapide et comme libellé du statut PENDING (shipment_status_filter_sheet.dart, shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get shipmentGroupWaiting;

  /// Groupe de statuts « livrés », réutilisé comme chip rapide de la liste d'envois (shipment_status_filter_sheet.dart, shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livrés'**
  String get shipmentGroupDelivered;

  /// Groupe de statuts « non aboutis », réutilisé comme chip rapide de la liste d'envois (shipment_status_filter_sheet.dart, shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Non aboutis'**
  String get shipmentGroupNotCompleted;

  /// Option de statut ACCEPTED du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'À remettre'**
  String get shipmentStatusToHandOverOption;

  /// Option de statut HANDED_OVER du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Remis'**
  String get shipmentStatusHandedOverOption;

  /// Option de statut IN_TRANSIT du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'En transit'**
  String get shipmentStatusInTransitOption;

  /// Option de statut ARRIVED du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Arrivé'**
  String get shipmentStatusArrivedOption;

  /// Option de statut AWAITING_PAYMENT du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'À payer'**
  String get shipmentStatusAwaitingPaymentOption;

  /// Option de statut PAYMENT_ESCROWED du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Payé'**
  String get shipmentStatusPaidOption;

  /// Option de statut COMPLETED du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Livré'**
  String get shipmentStatusDeliveredOption;

  /// Option de statut CANCELLED du sheet de filtre, orthographe américaine (R38) (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get shipmentStatusCancelledOption;

  /// Option de statut REJECTED du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get shipmentStatusRejectedOption;

  /// Option de statut PARCEL_REFUSED du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Colis refusé'**
  String get shipmentStatusParcelRefusedOption;

  /// Option de statut NO_SHOW du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Absent'**
  String get shipmentStatusNoShowOption;

  /// Option de statut EXPIRED du sheet de filtre (shipment_status_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Expiré'**
  String get shipmentStatusExpiredOption;

  /// Titre du sheet de filtre par période, réutilisé comme tooltip du bouton dans la liste d'envois (shipment_period_filter_sheet.dart, shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Filtrer par période'**
  String get shipmentPeriodFilterTitle;

  /// Onglet base de période « date de départ » (shipment_period_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date de départ'**
  String get shipmentPeriodBasisDepartureLabel;

  /// Onglet base de période « date de création » (shipment_period_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Date de création'**
  String get shipmentPeriodBasisCreationLabel;

  /// Chip de préréglage de période (shipment_period_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'3 derniers mois'**
  String get shipmentPeriodLast3MonthsLabel;

  /// Chip de préréglage de période (shipment_period_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Cette année'**
  String get shipmentPeriodThisYearLabel;

  /// Chip de préréglage de période « tout » (shipment_period_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get shipmentPeriodAllLabel;

  /// Chip de préréglage de période personnalisée, non sélectionnée (shipment_period_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get shipmentPeriodCustomLabel;

  /// Chip de préréglage de période personnalisée, sélectionnée (shipment_period_filter_sheet.dart)
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé ✓'**
  String get shipmentPeriodCustomSelectedLabel;

  /// Bandeau d'information remboursement, {cap} déjà formaté (reimbursement_info_banner.dart)
  ///
  /// In fr, this message translates to:
  /// **'En cas de perte confirmée après recherche, Yadony rembourse jusqu\'à {cap} € sous conditions.'**
  String shipmentReimbursementInfoMessage(String cap);

  /// Bouton vers la FAQ remboursement (reimbursement_info_banner.dart)
  ///
  /// In fr, this message translates to:
  /// **'Voir conditions'**
  String get shipmentReimbursementSeeConditionsButton;

  /// Placeholder du champ de recherche de la liste d'envois (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Ville, destinataire, voyageur…'**
  String get shipmentSearchFieldHint;

  /// Compteur de résultats filtrés de la liste d'envois, remplace shipment_list_screen.dart:297 (shipment_list_screen.dart). Ruling R41 : one{} au lieu de =1{}, la catégorie CLDR fr couvre 0 et 1 (0 résultat, singulier).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} résultat} other{{count} résultats}}'**
  String shipmentResultCount(int count);

  /// Lien d'effacement de tous les filtres actifs (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get shipmentClearAllFiltersLabel;

  /// Snackbar après suppression d'un envoi (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Envoi supprimé'**
  String get shipmentDeletedSnackbar;

  /// Titre du dialogue de confirmation de suppression (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cet envoi ?'**
  String get shipmentDeleteConfirmTitle;

  /// Message du dialogue de confirmation de suppression (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Il sera retiré de votre historique. Cette action est irréversible.'**
  String get shipmentDeleteConfirmMessage;

  /// Titre de l'état vide liste brute (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun envoi pour l\'instant'**
  String get shipmentEmptyTitle;

  /// Description de l'état vide liste brute (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Trouvez un voyageur et envoyez votre colis vers l\'Afrique.'**
  String get shipmentEmptyDescription;

  /// CTA de l'état vide liste brute (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un trajet'**
  String get shipmentEmptySearchTripAction;

  /// Message de l'état vide filtré (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Aucun envoi ne correspond à tes filtres'**
  String get shipmentFilteredEmptyMessage;

  /// Titre de l'état d'erreur de chargement (shipment_list_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get shipmentLoadErrorTitle;

  /// Titre du header de l'écran Mes colis (mes_colis_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Mes colis'**
  String get shipmentMesColisHeaderTitle;

  /// Onglet segmenté « En route » de Mes colis (mes_colis_screen.dart, clé dédiée : hors préfixes de domaine partagés, R40)
  ///
  /// In fr, this message translates to:
  /// **'En route'**
  String get shipmentTabEnRouteLabel;

  /// Onglet segmenté « Publiés » de Mes colis (mes_colis_screen.dart)
  ///
  /// In fr, this message translates to:
  /// **'Publiés'**
  String get shipmentTabPubliesLabel;

  /// Filtre « à traiter » de l'écran Demandes reçues (TravelerBidFilterL10n.label, traveler_bids_labels.dart, appelée depuis demandes_screen.dart) ; réutilisée telle quelle pour le bouton/pill de bid_list_screen.dart et le titre de pending_bids_screen.dart (même préfixe bidList, texte identique).
  ///
  /// In fr, this message translates to:
  /// **'À traiter'**
  String get bidListFilterToReview;

  /// Filtre « acceptées » (TravelerBidFilterL10n.label, traveler_bids_labels.dart).
  ///
  /// In fr, this message translates to:
  /// **'Acceptées'**
  String get bidListFilterAccepted;

  /// Filtre « terminées » (TravelerBidFilterL10n.label, traveler_bids_labels.dart).
  ///
  /// In fr, this message translates to:
  /// **'Terminées'**
  String get bidListFilterCompleted;

  /// Semantics label du bouton pill « À traiter » de l'app bar (bid_list_screen.dart, remplace bid_list_screen.dart:283). Ruling R41 : one{} au lieu de =1{} en français, la catégorie CLDR fr couvre 0 et 1.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} demande à traiter} other{{count} demandes à traiter}}'**
  String bidListRequestsToReview(int count);

  /// Titre de l'état vide de la liste « Acceptées » (bid_list_screen.dart _AcceptedList) ; réutilisé dans demandes_screen.dart pour le filtre « Acceptées » (même préfixe, texte identique).
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande acceptée'**
  String get bidListEmptyAcceptedTitle;

  /// Description de l'état vide ci-dessus (bid_list_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez accepté aucune demande pour l\'instant.'**
  String get bidListEmptyAcceptedDescription;

  /// Hint du champ de recherche (bid_list_screen.dart _BidSearchField).
  ///
  /// In fr, this message translates to:
  /// **'Nom ou n° de suivi…'**
  String get bidListSearchHint;

  /// Chip de filtre « Tous » (bid_list_screen.dart _StatusFilterChips).
  ///
  /// In fr, this message translates to:
  /// **'Tous ({count})'**
  String bidListChipAll(int count);

  /// Chip de filtre « Actifs » (bid_list_screen.dart _StatusFilterChips).
  ///
  /// In fr, this message translates to:
  /// **'Actifs ({count})'**
  String bidListChipActive(int count);

  /// Chip de filtre « Clôturés » (bid_list_screen.dart _StatusFilterChips).
  ///
  /// In fr, this message translates to:
  /// **'Clôturés ({count})'**
  String bidListChipClosed(int count);

  /// Titre de l'état vide recherche sans résultat (bid_list_screen.dart _SearchEmptyState) ; réutilisé dans demandes_screen.dart _NoSearchResult (même préfixe, texte identique).
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get bidListNoResultTitle;

  /// Titre de l'état vide sans recherche active (bid_list_screen.dart _SearchEmptyState).
  ///
  /// In fr, this message translates to:
  /// **'Aucun envoi'**
  String get bidListEmptyShipmentsTitle;

  /// Description avec la recherche en cours (bid_list_screen.dart _SearchEmptyState).
  ///
  /// In fr, this message translates to:
  /// **'Aucun envoi ne correspond à « {query} ».'**
  String bidListNoResultDescription(String query);

  /// Description sans recherche active (bid_list_screen.dart _SearchEmptyState).
  ///
  /// In fr, this message translates to:
  /// **'Aucun envoi dans cette catégorie.'**
  String get bidListEmptyShipmentsDescription;

  /// Chip scanner de l'app bar (bid_list_screen.dart _ScannerChipButton).
  ///
  /// In fr, this message translates to:
  /// **'Lire le QR'**
  String get bidListScanChipLabel;

  /// Bandeau d'offres masquées par le filtre prix minimum (bid_list_chrome.dart HiddenBidsBanner, remplace bid_list_chrome.dart:81). Ruling R41 : one{} au lieu de =1{} en français.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} offre masquée (prix minimum actif)} other{{count} offres masquées (prix minimum actif)}}'**
  String bidListHiddenOffers(int count);

  /// Snackbar de succès d'acceptation (pending_bids_screen.dart, demandes_screen.dart — même préfixe, texte identique).
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée !'**
  String get bidListAcceptedSnackbar;

  /// Snackbar de refus (pending_bids_screen.dart, demandes_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée.'**
  String get bidListRejectedSnackbar;

  /// Snackbar de suppression (pending_bids_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Demande supprimée.'**
  String get bidListDeletedSnackbar;

  /// Titre de la sheet « paiement carte refusé » (pending_bids_screen.dart _showCardDeclinedSheet).
  ///
  /// In fr, this message translates to:
  /// **'Paiement refusé'**
  String get bidListCardDeclinedSheetTitle;

  /// Indication sous le message d'erreur de la sheet paiement refusé (pending_bids_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Changez votre carte de commission pour accepter cette demande.'**
  String get bidListCardDeclinedHint;

  /// Bouton de la sheet « paiement carte refusé » (pending_bids_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Changer ma carte de commission'**
  String get bidListChangeCommissionCardButton;

  /// Titre de la sheet solde insuffisant (pending_bids_screen.dart, demandes_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Solde insuffisant'**
  String get bidListWalletInsufficientTitle;

  /// Indication de la sheet solde insuffisant (pending_bids_screen.dart, demandes_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Recharge ton portefeuille ou paie la commission directement par carte.'**
  String get bidListWalletInsufficientHint;

  /// Bouton de recharge de la sheet solde insuffisant (pending_bids_screen.dart, demandes_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Recharger mon portefeuille'**
  String get bidListWalletTopupButton;

  /// Bouton paiement carte de la sheet solde insuffisant (pending_bids_screen.dart, demandes_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Payer par carte'**
  String get bidListPayByCardButton;

  /// Bouton ajout de carte de la sheet solde insuffisant (pending_bids_screen.dart, demandes_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une carte'**
  String get bidListAddCardButton;

  /// Titre du dialogue de refus d'une demande (pending_bids_screen.dart, demandes_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Refuser cette demande ?'**
  String get bidListDeclineDialogTitle;

  /// Message du dialogue de refus d'une demande (pending_bids_screen.dart, demandes_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur sera informé. Cette action est irréversible.'**
  String get bidListDeclineDialogMessage;

  /// Bouton « Refuser » (bid_card.dart _PendingActions) ; réutilisé comme confirmLabel du dialogue de refus (pending_bids_screen.dart, demandes_screen.dart — même préfixe).
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get bidListDeclineButton;

  /// Titre du dialogue de suppression d'une demande refusée (pending_bids_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette demande ?'**
  String get bidListDeleteDialogTitle;

  /// Message du dialogue de suppression (pending_bids_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Cette demande refusée sera retirée définitivement de votre liste.'**
  String get bidListDeleteDialogMessage;

  /// Titre de l'app bar avec compteur (pending_bids_screen.dart) ; le cas count == 0 réutilise bidListFilterToReview.
  ///
  /// In fr, this message translates to:
  /// **'À traiter ({count})'**
  String bidListPendingTitleWithCount(int count);

  /// État vide de l'écran « À traiter » (pending_bids_screen.dart) ; réutilisé dans demandes_screen.dart pour le filtre « À traiter » (même préfixe, texte identique).
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande à traiter'**
  String get bidListEmptyPendingTitle;

  /// Description de l'état vide « À traiter » (pending_bids_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Partagez votre annonce pour recevoir des demandes.'**
  String get bidListEmptyPendingDescription;

  /// Titre de l'app bar (demandes_screen.dart). Clé dédiée (R40) : le texte est identique à shellRequestsTitle mais le préfixe shell n'est pas partagé.
  ///
  /// In fr, this message translates to:
  /// **'Demandes'**
  String get bidListDemandesTitle;

  /// Hint du champ de recherche (demandes_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Expéditeur, n° de suivi…'**
  String get bidListDemandesSearchHint;

  /// Description de l'état « Aucun résultat » (demandes_screen.dart _NoSearchResult).
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande ne correspond à votre recherche.'**
  String get bidListNoSearchResultDescription;

  /// Description du filtre « À traiter » vide (demandes_screen.dart _EmptyForFilter).
  ///
  /// In fr, this message translates to:
  /// **'Publiez un trajet pour recevoir des demandes d\'expéditeurs.'**
  String get bidListEmptyNoRequestsDescription;

  /// Description du filtre « Acceptées » vide (demandes_screen.dart _EmptyForFilter).
  ///
  /// In fr, this message translates to:
  /// **'Les demandes que vous acceptez apparaîtront ici.'**
  String get bidListEmptyAcceptedArchiveDescription;

  /// Titre du filtre « Terminées » vide (demandes_screen.dart _EmptyForFilter).
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande terminée'**
  String get bidListEmptyCompletedTitle;

  /// Description du filtre « Terminées » vide (demandes_screen.dart _EmptyForFilter).
  ///
  /// In fr, this message translates to:
  /// **'Vos demandes clôturées seront archivées ici.'**
  String get bidListEmptyCompletedDescription;

  /// Snackbar de succès à la suppression du trajet (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Trajet supprimé'**
  String get tripOwnerDeletedSnackbar;

  /// Titre de l'écran de succès après publication d'un brouillon (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Trajet publié !'**
  String get tripOwnerPublishedTitle;

  /// Sous-titre de l'écran de succès après publication (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Ton trajet {dep} → {arr} est en ligne.'**
  String tripOwnerPublishedSubtitle(String dep, String arr);

  /// Bouton secondaire de partage de l'écran de succès (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Partager mon trajet'**
  String get tripOwnerShareMyTrip;

  /// Message partagé après publication d'un brouillon (trip_owner_detail_screen.dart). date formatée en DateFormat.MMMMd(locale) ; url = donnée non traduite.
  ///
  /// In fr, this message translates to:
  /// **'✈️ Je voyage {dep} → {arr} le {date} avec de la place dans mes bagages !\nRéserve tes kilos sur Yadony 📦\n{url}'**
  String tripOwnerShareMessage(String dep, String arr, String date, String url);

  /// Titre du bandeau brouillon (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet est un brouillon'**
  String get tripOwnerDraftBannerTitle;

  /// Message du bandeau brouillon (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Il est invisible pour les expéditeurs tant qu\'il n\'est pas publié.'**
  String get tripOwnerDraftBannerMessage;

  /// Bouton CTA d'arrivée (trip_owner_detail_screen.dart) ; réutilisé comme titre de ArrivalInstructionsBottomSheet en mode création (arrival_instructions_bottom_sheet.dart, même préfixe tripOwner, texte identique).
  ///
  /// In fr, this message translates to:
  /// **'Arrivé à destination'**
  String get tripOwnerMarkArrivedButton;

  /// Bouton CTA d'édition des instructions déjà arrivées (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Modifier les instructions de retrait'**
  String get tripOwnerEditInstructionsButton;

  /// Titre du dialogue de suppression bloquée par un colis accepté (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible'**
  String get tripOwnerDeleteBlockedTitle;

  /// Message du dialogue de suppression bloquée (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Un colis est déjà accepté sur ce trajet. Pour le retirer, vous devez d\'abord annuler le voyage : l\'expéditeur sera remboursé automatiquement.'**
  String get tripOwnerDeleteBlockedMessage;

  /// confirmLabel du dialogue de suppression bloquée (trip_owner_detail_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Annuler le voyage'**
  String get tripOwnerCancelTripButton;

  /// Titre du dialogue de limite mensuelle PRO atteinte (trip_owner_detail_screen.dart). Clé dédiée (R40) : distincte de tripPublishMonthlyLimitTitle (préfixe non partagé).
  ///
  /// In fr, this message translates to:
  /// **'Limite mensuelle atteinte'**
  String get tripOwnerProLimitTitle;

  /// Libellé du montant, en majuscules dans le code (bid_card.dart).
  ///
  /// In fr, this message translates to:
  /// **'MONTANT'**
  String get bidListCardAmountLabel;

  /// Pastille de poids en mode grille tarifaire (bid_card.dart).
  ///
  /// In fr, this message translates to:
  /// **'Forfait'**
  String get bidListCardFlatRateLabel;

  /// Numéro de suivi affiché sous le nom de l'expéditeur (bid_card.dart).
  ///
  /// In fr, this message translates to:
  /// **'N° {number}'**
  String bidListCardTrackingNumberLabel(String number);

  /// Bouton « Accepter » (bid_card.dart _PendingActions).
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get bidListAcceptButton;

  /// Bandeau paiement espèces en attente (bid_card.dart _PaymentHint).
  ///
  /// In fr, this message translates to:
  /// **'💵 Paiement en espèces : en attente de votre réponse'**
  String get bidListCashPaymentHint;

  /// Bandeau paiement carte/mobile money déjà reçu, en attente de réponse (bid_card.dart _PaymentHint).
  ///
  /// In fr, this message translates to:
  /// **'💳 Paiement reçu : en attente de votre réponse'**
  String get bidListEscrowPaymentHint;

  /// Statut compact du badge de bid (bid_card.dart _StatusDot). Clé dédiée (R40) : distincte des libellés ticketStatus…/shipmentBadge…, texte parfois identique, doublons acceptés.
  ///
  /// In fr, this message translates to:
  /// **'Accepté'**
  String get bidListStatusAccepted;

  /// Statut compact (bid_card.dart _StatusDot).
  ///
  /// In fr, this message translates to:
  /// **'Paiement en attente'**
  String get bidListStatusAwaitingPayment;

  /// Statut compact (bid_card.dart _StatusDot).
  ///
  /// In fr, this message translates to:
  /// **'En route'**
  String get bidListStatusHandedOver;

  /// Statut compact (bid_card.dart _StatusDot).
  ///
  /// In fr, this message translates to:
  /// **'En transit'**
  String get bidListStatusInTransit;

  /// Statut compact (bid_card.dart _StatusDot).
  ///
  /// In fr, this message translates to:
  /// **'Arrivé'**
  String get bidListStatusArrived;

  /// Statut compact (bid_card.dart _StatusDot).
  ///
  /// In fr, this message translates to:
  /// **'Livré'**
  String get bidListStatusDelivered;

  /// Statut compact (bid_card.dart _StatusDot).
  ///
  /// In fr, this message translates to:
  /// **'Absent'**
  String get bidListStatusNoShow;

  /// Statut compact (bid_card.dart _StatusDot).
  ///
  /// In fr, this message translates to:
  /// **'Colis refusé'**
  String get bidListStatusParcelRefused;

  /// Statut compact (bid_card.dart _StatusDot). Orthographe américaine (R38).
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get bidListStatusCancelled;

  /// Tuile « Publier » (owner_action_grid.dart) ; réutilisée pour le libellé actif du bouton de OpenSurplusBottomSheet (même préfixe tripOwner, texte identique).
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get tripOwnerPublishTile;

  /// Tuile « Affiche » (owner_action_grid.dart).
  ///
  /// In fr, this message translates to:
  /// **'Affiche'**
  String get tripOwnerPosterTile;

  /// Tuile + confirmLabel « Dépublier » (owner_action_grid.dart).
  ///
  /// In fr, this message translates to:
  /// **'Dépublier'**
  String get tripOwnerUnpublishTile;

  /// Titre du dialogue de dépublication (owner_action_grid.dart).
  ///
  /// In fr, this message translates to:
  /// **'Dépublier ce trajet ?'**
  String get tripOwnerUnpublishDialogTitle;

  /// Message du dialogue de dépublication (owner_action_grid.dart).
  ///
  /// In fr, this message translates to:
  /// **'Le trajet ne sera plus visible et restera dans vos brouillons.'**
  String get tripOwnerUnpublishDialogMessage;

  /// Tuile « Demandes » (owner_action_grid.dart). Clé dédiée (R40) : distincte de bidListDemandesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demandes'**
  String get tripOwnerRequestsTile;

  /// Tooltip de la tuile « Demandes » désactivée (owner_action_grid.dart). Clé dédiée (R40) : distincte de bidListEmptyPendingTitle, texte identique, doublon accepté.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande à traiter'**
  String get tripOwnerRequestsDisabledMessage;

  /// Tuile « Colis » (owner_action_grid.dart), aussi valeur poussée comme titre à BidListScreen via extra['title'] (remplace le littéral en dur).
  ///
  /// In fr, this message translates to:
  /// **'Colis'**
  String get tripOwnerParcelsTile;

  /// Tooltip de la tuile « Colis » désactivée (owner_action_grid.dart) ; réutilisé comme titre de l'état vide de la section Colis (trip_parcels_section.dart, même préfixe, texte identique).
  ///
  /// In fr, this message translates to:
  /// **'Aucun colis embarqué'**
  String get tripOwnerNoParcelsMessage;

  /// Tooltip de la tuile « Modifier » désactivée (owner_action_grid.dart).
  ///
  /// In fr, this message translates to:
  /// **'Modifiable tant qu\'aucune demande'**
  String get tripOwnerEditDisabledMessage;

  /// Titre du dialogue de suppression du trajet (owner_action_grid.dart).
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce trajet ?'**
  String get tripOwnerDeleteDialogTitle;

  /// Message de suppression d'un trajet déjà annulé (owner_action_grid.dart).
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.'**
  String get tripOwnerDeleteCancelledMessage;

  /// Message de suppression d'un trajet actif (owner_action_grid.dart).
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Le trajet ne sera plus visible pour les expéditeurs.'**
  String get tripOwnerDeleteActiveMessage;

  /// Tuile « Annuler » quand le trajet actif n'est plus supprimable (owner_action_grid.dart).
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get tripOwnerCancelTile;

  /// Titre de la section colis embarqués (trip_parcels_section.dart).
  ///
  /// In fr, this message translates to:
  /// **'Colis dans le trajet'**
  String get tripOwnerParcelsSectionTitle;

  /// Description de l'état vide de la section (trip_parcels_section.dart).
  ///
  /// In fr, this message translates to:
  /// **'Les colis acceptés apparaîtront ici.'**
  String get tripOwnerParcelsEmptyDescription;

  /// Chip de filtre « Tous » de la section colis embarqués (trip_parcels_section.dart).
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get tripOwnerParcelsFilterAll;

  /// Statut compact de la section colis embarqués (trip_parcels_section.dart _statusMeta). Clé dédiée (R40) : distincte de bidListStatusAccepted, texte identique, doublon accepté.
  ///
  /// In fr, this message translates to:
  /// **'Accepté'**
  String get tripOwnerParcelsStatusAccepted;

  /// Statut compact (trip_parcels_section.dart _statusMeta).
  ///
  /// In fr, this message translates to:
  /// **'Paiement en attente'**
  String get tripOwnerParcelsStatusAwaitingPayment;

  /// Statut compact (trip_parcels_section.dart _statusMeta).
  ///
  /// In fr, this message translates to:
  /// **'Remis'**
  String get tripOwnerParcelsStatusHandedOver;

  /// Statut compact (trip_parcels_section.dart _statusMeta).
  ///
  /// In fr, this message translates to:
  /// **'En transit'**
  String get tripOwnerParcelsStatusInTransit;

  /// Statut compact (trip_parcels_section.dart _statusMeta).
  ///
  /// In fr, this message translates to:
  /// **'Arrivé'**
  String get tripOwnerParcelsStatusArrived;

  /// Statut compact (trip_parcels_section.dart _statusMeta).
  ///
  /// In fr, this message translates to:
  /// **'Livré'**
  String get tripOwnerParcelsStatusDelivered;

  /// Statut compact (trip_parcels_section.dart _statusMeta).
  ///
  /// In fr, this message translates to:
  /// **'Absent'**
  String get tripOwnerParcelsStatusNoShow;

  /// Statut compact (trip_parcels_section.dart _statusMeta).
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get tripOwnerParcelsStatusParcelRefused;

  /// Statut compact (trip_parcels_section.dart _statusMeta). Orthographe américaine (R38).
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get tripOwnerParcelsStatusCancelled;

  /// Repli de contenu quand le bid n'a ni catégorie ni description (trip_parcels_section.dart _ColisRow).
  ///
  /// In fr, this message translates to:
  /// **'Colis'**
  String get tripOwnerParcelsDefaultContent;

  /// Titre de la sheet (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les kg restants'**
  String get tripOwnerSurplusTitle;

  /// Sous-titre de la sheet (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Mettez votre capacité libre à disposition du public'**
  String get tripOwnerSurplusSubtitle;

  /// Libellé du bouton pendant la publication (open_surplus_bottom_sheet.dart) ; l'état actif réutilise tripOwnerPublishTile.
  ///
  /// In fr, this message translates to:
  /// **'Publication…'**
  String get tripOwnerSurplusPublishingButton;

  /// Erreur du validateur kg quand le champ est vide/invalide (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Entrez un nombre de kg'**
  String get tripOwnerSurplusKgValidatorEmpty;

  /// Erreur du validateur kg quand la valeur est < 1 (open_surplus_bottom_sheet.dart) — identique en anglais (chiffre + unité).
  ///
  /// In fr, this message translates to:
  /// **'Minimum 1 kg'**
  String get tripOwnerSurplusKgValidatorMin;

  /// Snackbar de succès à l'ouverture du surplus (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Capacité ouverte au public'**
  String get tripOwnerSurplusOpenedSnackbar;

  /// Libellé du bandeau de capacité réservée (open_surplus_bottom_sheet.dart _ReservedBanner).
  ///
  /// In fr, this message translates to:
  /// **'Réservé à votre expéditeur'**
  String get tripOwnerSurplusReservedLabel;

  /// Valeur du bandeau de capacité réservée, {kg} déjà formaté (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'{kg} kg verrouillés'**
  String tripOwnerSurplusReservedKgValue(String kg);

  /// Libellé de section, en majuscules dans le code (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'KG À OUVRIR'**
  String get tripOwnerSurplusKgSectionLabel;

  /// Libellé de section, en majuscules dans le code (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'PRIX PAR KG'**
  String get tripOwnerSurplusPriceSectionLabel;

  /// Hint du champ kg à ouvrir (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Ex. 8'**
  String get tripOwnerSurplusKgHint;

  /// Chip de prix « Autre » (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get tripOwnerSurplusOtherPriceChip;

  /// Hint du champ de prix libre (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Votre prix'**
  String get tripOwnerSurplusCustomPriceHint;

  /// Erreur du validateur de prix libre (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Prix invalide'**
  String get tripOwnerSurplusCustomPriceInvalid;

  /// Texte d'avertissement en bas de la sheet (open_surplus_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Action définitive : une fois publiée, votre capacité libre devient visible dans la recherche et ne peut plus être refermée.'**
  String get tripOwnerSurplusDisclaimerText;

  /// Libellé de l'aperçu du prix public (open_surplus_bottom_sheet.dart _PublicPricePreview).
  ///
  /// In fr, this message translates to:
  /// **'Prix affiché aux expéditeurs'**
  String get tripOwnerSurplusPublicPriceLabel;

  /// Titre de la sheet en mode édition, et titre statique du corps (arrival_instructions_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Instructions de retrait'**
  String get tripOwnerArrivalEditingTitle;

  /// Sous-titre de la sheet (arrival_instructions_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Indiquez où et comment récupérer le colis'**
  String get tripOwnerArrivalSubtitle;

  /// Bouton de confirmation en mode création (arrival_instructions_bottom_sheet.dart) ; le mode édition réutilise commonSave.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer l\'arrivée'**
  String get tripOwnerArrivalConfirmButton;

  /// Snackbar de succès au marquage d'arrivée (arrival_instructions_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Trajet marqué comme arrivé'**
  String get tripOwnerArrivedSnackbar;

  /// Snackbar de succès à la mise à jour des instructions (arrival_instructions_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Instructions mises à jour'**
  String get tripOwnerArrivalUpdatedSnackbar;

  /// Label du champ en mode édition, obligatoire (arrival_instructions_bottom_sheet.dart) — identique en anglais.
  ///
  /// In fr, this message translates to:
  /// **'Instructions'**
  String get tripOwnerArrivalFieldLabel;

  /// Label du champ en mode création, optionnel (arrival_instructions_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Instructions (optionnel)'**
  String get tripOwnerArrivalFieldLabelOptional;

  /// Hint du champ de texte libre (arrival_instructions_bottom_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Ex : Métro Châtelet, sortie 3'**
  String get tripOwnerArrivalFieldHint;

  /// Titre du dialogue d'annulation d'un bid par le voyageur (cancellation_dialog.dart).
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette demande ?'**
  String get bidCancelDialogTitle;

  /// Sous-titre du cas colis pas encore remis (cancellation_dialog.dart).
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur sera remboursé automatiquement.'**
  String get bidCancelAcceptedSubtitle;

  /// Message d'avertissement du cas colis déjà remis (cancellation_dialog.dart).
  ///
  /// In fr, this message translates to:
  /// **'Le colis a déjà été remis. Vous devrez le restituer à l\'expéditeur sous 3 jours en saisissant le code de retour qu\'il vous communiquera.'**
  String get bidCancelWarningMessage;

  /// Note de remboursement du cas colis déjà remis (cancellation_dialog.dart).
  ///
  /// In fr, this message translates to:
  /// **'L\'expéditeur sera intégralement remboursé. Si le paiement était en espèces, aucun mouvement d\'argent n\'a lieu.'**
  String get bidCancelWarningRefundNote;

  /// Hint du champ motif quand il est obligatoire (cancellation_dialog.dart).
  ///
  /// In fr, this message translates to:
  /// **'Motif de l\'annulation *'**
  String get bidCancelReasonRequiredHint;

  /// Hint du champ motif quand il est optionnel (cancellation_dialog.dart).
  ///
  /// In fr, this message translates to:
  /// **'Motif (optionnel)'**
  String get bidCancelReasonOptionalHint;

  /// Erreur affichée si le motif obligatoire est vide (cancellation_dialog.dart).
  ///
  /// In fr, this message translates to:
  /// **'Motif requis'**
  String get bidCancelReasonRequiredError;

  /// Bouton de fermeture sans annuler (cancellation_dialog.dart).
  ///
  /// In fr, this message translates to:
  /// **'Garder'**
  String get bidCancelKeepButton;

  /// Bouton de confirmation destructive (cancellation_dialog.dart).
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get bidCancelConfirmButton;

  /// Libellé court de la période 7 jours, chips du hub Activités (activity_labels.dart StatsPeriodL10n.label, stats_period_cubit.dart).
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get activityPeriod7Days;

  /// Libellé court de la période 30 jours (activity_labels.dart StatsPeriodL10n.label).
  ///
  /// In fr, this message translates to:
  /// **'30 jours'**
  String get activityPeriod30Days;

  /// Libellé court de la période 12 mois (activity_labels.dart StatsPeriodL10n.label).
  ///
  /// In fr, this message translates to:
  /// **'12 mois'**
  String get activityPeriod12Months;

  /// Sous-titre des feuilles de détail pour la période 7 jours (activity_labels.dart StatsPeriodL10n.detailLabel).
  ///
  /// In fr, this message translates to:
  /// **'7 derniers jours'**
  String get activityPeriodLast7Days;

  /// Sous-titre des feuilles de détail pour la période 30 jours (activity_labels.dart StatsPeriodL10n.detailLabel).
  ///
  /// In fr, this message translates to:
  /// **'30 derniers jours'**
  String get activityPeriodLast30Days;

  /// Sous-titre des feuilles de détail pour la période 12 mois (activity_labels.dart StatsPeriodL10n.detailLabel).
  ///
  /// In fr, this message translates to:
  /// **'12 derniers mois'**
  String get activityPeriodLast12Months;

  /// Libellé du rail de paiement carte, feuille Revenus (activity_labels.dart RevenueRailL10n.label, revenue_details_model.dart).
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get activityRevenueCard;

  /// Libellé du rail de paiement mobile money, identique en anglais (activity_labels.dart RevenueRailL10n.label).
  ///
  /// In fr, this message translates to:
  /// **'Mobile money'**
  String get activityRevenueMobileMoney;

  /// Libellé du rail de paiement espèces (activity_labels.dart RevenueRailL10n.label).
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get activityRevenueCash;

  /// Libellé de repli pour un rail de paiement inconnu du serveur (activity_labels.dart RevenueRailL10n.label).
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get activityRevenueOther;

  /// Groupe nominal de l'outil adresses dans la phrase des manquants (activity_labels.dart ToolKeyL10n.missingPhrase).
  ///
  /// In fr, this message translates to:
  /// **'une adresse'**
  String get activityToolMissingAddress;

  /// Groupe nominal de l'outil destinataires (activity_labels.dart ToolKeyL10n.missingPhrase).
  ///
  /// In fr, this message translates to:
  /// **'un destinataire'**
  String get activityToolMissingRecipient;

  /// Groupe nominal de l'outil alertes (activity_labels.dart ToolKeyL10n.missingPhrase).
  ///
  /// In fr, this message translates to:
  /// **'une alerte'**
  String get activityToolMissingAlert;

  /// Groupe nominal de l'outil modèles de trajet (activity_labels.dart ToolKeyL10n.missingPhrase).
  ///
  /// In fr, this message translates to:
  /// **'un modèle de trajet'**
  String get activityToolMissingTemplate;

  /// Groupe nominal de l'outil grille de prix (activity_labels.dart ToolKeyL10n.missingPhrase).
  ///
  /// In fr, this message translates to:
  /// **'une grille de prix'**
  String get activityToolMissingPriceGrid;

  /// CTA de l'outil adresses (activity_labels.dart ToolKeyL10n.ctaLabel).
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une adresse'**
  String get activityToolCtaAddresses;

  /// CTA de l'outil destinataires (activity_labels.dart ToolKeyL10n.ctaLabel).
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un destinataire'**
  String get activityToolCtaRecipients;

  /// CTA de l'outil alertes (activity_labels.dart ToolKeyL10n.ctaLabel).
  ///
  /// In fr, this message translates to:
  /// **'Créer une alerte'**
  String get activityToolCtaAlerts;

  /// CTA de l'outil modèles de trajet (activity_labels.dart ToolKeyL10n.ctaLabel).
  ///
  /// In fr, this message translates to:
  /// **'Créer un modèle de trajet'**
  String get activityToolCtaTemplates;

  /// CTA de l'outil grille de prix (activity_labels.dart ToolKeyL10n.ctaLabel).
  ///
  /// In fr, this message translates to:
  /// **'Remplir ma grille de prix'**
  String get activityToolCtaPriceGrid;

  /// Texte du badge « prêt » de l'outil adresses (activity_labels.dart ToolKeyL10n.badgeLabel).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} adresse} other{{count} adresses}}'**
  String activityToolBadgeAddresses(num count);

  /// Texte du badge « prêt » de l'outil destinataires (activity_labels.dart ToolKeyL10n.badgeLabel).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} destinataire} other{{count} destinataires}}'**
  String activityToolBadgeRecipients(num count);

  /// Texte du badge « prêt » de l'outil alertes (activity_labels.dart ToolKeyL10n.badgeLabel).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} alerte} other{{count} alertes}}'**
  String activityToolBadgeAlerts(num count);

  /// Texte du badge « prêt » de l'outil modèles de trajet (activity_labels.dart ToolKeyL10n.badgeLabel).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} modèle} other{{count} modèles}}'**
  String activityToolBadgeTemplates(num count);

  /// Texte du badge « prêt » de la grille de prix, invariant : le nombre de lignes ne compte pas (activity_labels.dart ToolKeyL10n.badgeLabel).
  ///
  /// In fr, this message translates to:
  /// **'Configurée'**
  String get activityToolBadgePriceGridReady;

  /// Phrase des outils manquants, {items} déjà joints par joinList (activity_labels.dart missingSentence).
  ///
  /// In fr, this message translates to:
  /// **'Il vous manque {items}.'**
  String activityToolsMissing(Object items);

  /// Titre de la tuile/ligne outil alertes, partagé entre activites_hub_screen.dart et activites_menu_sheet.dart.
  ///
  /// In fr, this message translates to:
  /// **'Mes alertes'**
  String get activityToolTitleAlerts;

  /// Titre de la tuile/ligne outil modèles de trajet, partagé entre activites_hub_screen.dart et activites_menu_sheet.dart.
  ///
  /// In fr, this message translates to:
  /// **'Modèles de trajet'**
  String get activityToolTitleTemplates;

  /// Titre de la tuile/ligne outil grille de prix, partagé entre activites_hub_screen.dart et activites_menu_sheet.dart.
  ///
  /// In fr, this message translates to:
  /// **'Ma grille de prix'**
  String get activityToolTitlePriceGrid;

  /// Titre de la tuile/ligne outil adresses, partagé entre activites_hub_screen.dart et activites_menu_sheet.dart.
  ///
  /// In fr, this message translates to:
  /// **'Mes adresses'**
  String get activityToolTitleAddresses;

  /// Titre de la tuile/ligne outil destinataires, partagé entre activites_hub_screen.dart et activites_menu_sheet.dart.
  ///
  /// In fr, this message translates to:
  /// **'Mes destinataires'**
  String get activityToolTitleRecipients;

  /// Sous-titre de la tuile modèles de trajet du hub (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Republiez vos trajets habituels'**
  String get activityToolSubtitleTemplates;

  /// Sous-titre de la tuile grille de prix du hub (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Tarifs par article pour vos trajets'**
  String get activityToolSubtitlePriceGrid;

  /// Sous-titre de la tuile adresses du hub (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Vos lieux d\'envoi enregistrés'**
  String get activityToolSubtitleAddresses;

  /// Sous-titre de la tuile destinataires du hub (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Les personnes à qui vous envoyez'**
  String get activityToolSubtitleRecipients;

  /// Texte du badge d'un outil non configuré, partagé entre le hub et le menu burger.
  ///
  /// In fr, this message translates to:
  /// **'À configurer'**
  String get activityToolBadgeUnconfigured;

  /// Semantics du badge d'outil prêt dans la grille du hub (activites_hub_screen.dart _toolBadge).
  ///
  /// In fr, this message translates to:
  /// **'{title}, prêt, {label}'**
  String activityToolHubSemanticsReady(Object label, Object title);

  /// Semantics du badge d'outil non configuré dans la grille du hub (activites_hub_screen.dart _toolBadge).
  ///
  /// In fr, this message translates to:
  /// **'{title}, à configurer'**
  String activityToolHubSemanticsUnconfigured(Object title);

  /// Semantics du badge d'outil prêt dans le menu burger (activites_menu_sheet.dart _ToolTile).
  ///
  /// In fr, this message translates to:
  /// **'{label} : {badge}'**
  String activityToolMenuSemanticsReady(Object badge, Object label);

  /// Semantics du badge d'outil non configuré dans le menu burger (activites_menu_sheet.dart _ToolTile).
  ///
  /// In fr, this message translates to:
  /// **'{label} : à configurer'**
  String activityToolMenuSemanticsUnconfigured(Object label);

  /// Titre de la tuile/ligne Historique, partagé entre le hub et le menu burger.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get activityHistoryTitle;

  /// Sous-titre de la tuile Historique du hub (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Tout ce qui est terminé'**
  String get activityHistorySubtitle;

  /// Titre de la tuile Aide & support du hub (activites_hub_screen.dart, avec l'esperluette).
  ///
  /// In fr, this message translates to:
  /// **'Aide & support'**
  String get activityHelpTitleHub;

  /// Sous-titre de la tuile Aide & support du hub (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Une question, un souci ?'**
  String get activityHelpSubtitle;

  /// Sous-titre de la tuile alertes quand aucune alerte n'est configurée (activites_hub_screen.dart _alertsTile).
  ///
  /// In fr, this message translates to:
  /// **'Soyez prévenu avant les autres'**
  String get activityAlertsSubtitleUnconfigured;

  /// Sous-titre de la tuile alertes configurée sans nouveauté (activites_hub_screen.dart _alertsTile).
  ///
  /// In fr, this message translates to:
  /// **'Rien de neuf pour l\'instant'**
  String get activityAlertsSubtitleCaughtUp;

  /// Sous-titre de repli de la tuile alertes (résumé non chargé ou aucun corridor récent) (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux trajets et colis'**
  String get activityAlertsSubtitleDefault;

  /// Grand titre de l'écran, en-tête du hub Activités (activites_hub_screen.dart _Header) - clé dédiée, distincte de shellTabActivity (R40).
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get activityHubTitle;

  /// Tooltip et semanticLabel du bouton burger de l'en-tête, identique en anglais (activites_hub_screen.dart _Header).
  ///
  /// In fr, this message translates to:
  /// **'Menu'**
  String get activityMenuButtonTooltip;

  /// Titre de la section grille d'activité (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'En ce moment'**
  String get activitySectionCurrent;

  /// Titre de la section statistiques (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get activitySectionStats;

  /// Titre de la section outils (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Outils'**
  String get activitySectionTools;

  /// Titre de la carte d'introduction du hub (activites_hub_screen.dart _IntroCard).
  ///
  /// In fr, this message translates to:
  /// **'Envoyez ou transportez, c\'est vous qui choisissez'**
  String get activityIntroTitle;

  /// Corps de la carte d'introduction du hub (activites_hub_screen.dart _IntroCard).
  ///
  /// In fr, this message translates to:
  /// **'Envoyez vos colis avec des voyageurs de confiance, ou transportez des colis pendant vos trajets pour gagner de l\'argent. Tout se suit depuis cet écran.'**
  String get activityIntroBody;

  /// Bouton Publier un colis de la rangée d'actions du hub (activites_hub_screen.dart _ActionRow) ; Publier un trajet réutilise tripPublishTitle (R40, préfixe partagé trip…).
  ///
  /// In fr, this message translates to:
  /// **'Publier un colis'**
  String get activityPublishParcelCta;

  /// Libellé de la tuile Trajets actifs de la grille d'activité (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Trajets actifs'**
  String get activityTileTripsLabel;

  /// Sous-titre de la tuile Trajets actifs.
  ///
  /// In fr, this message translates to:
  /// **'Vos voyages à venir'**
  String get activityTileTripsSubtitle;

  /// Invite affichée quand le compteur de trajets actifs est à zéro.
  ///
  /// In fr, this message translates to:
  /// **'Publiez un trajet'**
  String get activityTileTripsEmptyHint;

  /// Libellé de la tuile Mes colis de la grille d'activité (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Mes colis'**
  String get activityTileShipmentsLabel;

  /// Sous-titre de la tuile Mes colis.
  ///
  /// In fr, this message translates to:
  /// **'Publiés, négociés, en route'**
  String get activityTileShipmentsSubtitle;

  /// Invite affichée quand le compteur de la tuile Mes colis est à zéro.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez un colis'**
  String get activityTileShipmentsEmptyHint;

  /// Libellé de la tuile Demandes reçues de la grille d'activité (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Demandes reçues'**
  String get activityTileRequestsLabel;

  /// Sous-titre de la tuile Demandes reçues.
  ///
  /// In fr, this message translates to:
  /// **'Des colis à transporter pour vous'**
  String get activityTileRequestsSubtitle;

  /// Invite affichée quand le compteur de la tuile Demandes reçues est à zéro.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pour l\'instant'**
  String get activityTileRequestsEmptyHint;

  /// Libellé de la tuile Discussions de prix de la grille d'activité (activites_hub_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Discussions de prix'**
  String get activityTileNegotiationsLabel;

  /// Sous-titre de la tuile Discussions de prix.
  ///
  /// In fr, this message translates to:
  /// **'Proposez ou acceptez un tarif'**
  String get activityTileNegotiationsSubtitle;

  /// Invite affichée quand le compteur de la tuile Discussions de prix est à zéro.
  ///
  /// In fr, this message translates to:
  /// **'Aucune en cours'**
  String get activityTileNegotiationsEmptyHint;

  /// Titre partagé entre la tuile de stats du hub et la feuille de détail (activites_hub_screen.dart, revenue_details_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get activityRevenueTitle;

  /// Titre partagé entre la tuile de stats du hub et la feuille de détail (activites_hub_screen.dart, kg_sold_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Kg vendus'**
  String get activityKgSoldTitle;

  /// Libellé de la tuile de statistiques Trajets (activites_hub_screen.dart _StatsRow).
  ///
  /// In fr, this message translates to:
  /// **'Trajets'**
  String get activityStatTripsLabel;

  /// Valeur de la tuile de statistiques Trajets (activites_hub_screen.dart _StatsRow) ; correction d'accord 0/1 (Ruling R44, fix round 1).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} publié} other{{count} publiés}}'**
  String activityStatTripsPublished(int count);

  /// Libellé de la tuile de statistiques Envois (activites_hub_screen.dart _StatsRow).
  ///
  /// In fr, this message translates to:
  /// **'Envois'**
  String get activityStatParcelsLabel;

  /// Valeur de la tuile de statistiques Envois (activites_hub_screen.dart _StatsRow) ; correction d'accord 0/1 (Ruling R44, fix round 1).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} envoyé} other{{count} envoyés}}'**
  String activityStatParcelsSent(int count);

  /// Action rapide Suivre un colis de la feuille de menu burger (activites_menu_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Suivre un colis'**
  String get activityMenuTrackParcel;

  /// Action rapide Scanner un colis de la feuille de menu burger (activites_menu_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Scanner un colis'**
  String get activityMenuScanParcel;

  /// Action rapide Paramètres de la feuille de menu burger (activites_menu_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get activityMenuSettings;

  /// Titre de la section outils de la feuille de menu burger (activites_menu_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Mes outils'**
  String get activityMenuToolsSection;

  /// Décompte de complétion affiché à droite du titre de section outils (activites_menu_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'{ready}/{total} prêts'**
  String activityMenuToolsReady(Object ready, Object total);

  /// Titre de la section compte de la feuille de menu burger (activites_menu_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Mon compte'**
  String get activityMenuAccountSection;

  /// Ligne Portefeuille de la feuille de menu burger (activites_menu_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Portefeuille'**
  String get activityWalletTitle;

  /// Ligne Aide et support de la feuille de menu burger (activites_menu_sheet.dart, sans esperluette).
  ///
  /// In fr, this message translates to:
  /// **'Aide et support'**
  String get activityHelpTitleMenu;

  /// Titre de l'état d'erreur, partagé entre les feuilles Kg vendus et Revenus.
  ///
  /// In fr, this message translates to:
  /// **'Détail indisponible'**
  String get activityDetailUnavailable;

  /// Description de l'état d'erreur de la feuille Kg vendus (kg_sold_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos kg vendus. Vérifiez votre connexion, puis réessayez.'**
  String get activityKgSoldErrorBody;

  /// Description de l'état d'erreur de la feuille Revenus (revenue_details_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos revenus. Vérifiez votre connexion, puis réessayez.'**
  String get activityRevenueErrorBody;

  /// Titre de l'état vide, partagé entre les feuilles Kg vendus et Revenus.
  ///
  /// In fr, this message translates to:
  /// **'Aucune livraison sur la période'**
  String get activityEmptyPeriodTitle;

  /// Description de l'état vide de la feuille Kg vendus (kg_sold_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Les kg vendus apparaissent ici une fois vos colis livrés.'**
  String get activityKgSoldEmptyBody;

  /// Description de l'état vide de la feuille Revenus (revenue_details_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'Vos revenus apparaissent ici une fois vos colis livrés et payés.'**
  String get activityRevenueEmptyBody;

  /// Compteur de colis de la feuille Kg vendus, colis invariant en français (kg_sold_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} colis} other{{count} colis}}'**
  String activityKgSoldParcels(num count);

  /// Compteur de trajets de la feuille Kg vendus (kg_sold_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} trajet} other{{count} trajets}}'**
  String activityKgSoldTrips(num count);

  /// Sous-titre du total (N colis livrés), branches fr identiques pour reproduire le texte d'origine (kg_sold_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} colis livrés} other{{count} colis livrés}}'**
  String activityKgSoldParcelsDelivered(num count);

  /// Sous-titre d'une ligne de trajet, avant le séparateur et le compteur de colis (kg_sold_sheet.dart _TripRow).
  ///
  /// In fr, this message translates to:
  /// **'Départ le {date}'**
  String activityKgSoldTripDeparture(Object date);

  /// Compteur de livraisons de la feuille Revenus ; 0 livraison corrige l'accord (revenue_details_sheet.dart).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} livraison} other{{count} livraisons}}'**
  String activityDeliveries(num count);

  /// Rappel de conversion en bas de la feuille Revenus quand la tuile affiche un total converti (revenue_details_sheet.dart _ConversionNote).
  ///
  /// In fr, this message translates to:
  /// **'Sur la tuile, « {total} » est un total converti au taux du jour, indicatif. Ici, chaque montant garde sa devise.'**
  String activityRevenueConversionNote(Object total);

  /// Titre du bandeau compact à 5/5 outils prêts (tools_completion_card.dart _CompleteBanner).
  ///
  /// In fr, this message translates to:
  /// **'Vos outils sont prêts'**
  String get activityToolsCompleteTitle;

  /// Corps du bandeau compact à 5/5 outils prêts (tools_completion_card.dart _CompleteBanner).
  ///
  /// In fr, this message translates to:
  /// **'Publiez un colis ou un trajet en 3 taps'**
  String get activityToolsCompleteBody;

  /// Titre de la carte de progression quand aucun outil n'est encore prêt (tools_completion_card.dart _ProgressCard).
  ///
  /// In fr, this message translates to:
  /// **'Préparez vos outils une fois'**
  String get activityToolsStartTitle;

  /// Titre de la carte de progression dès qu'au moins un outil est prêt (tools_completion_card.dart _ProgressCard).
  ///
  /// In fr, this message translates to:
  /// **'Publiez en 3 taps'**
  String get activityToolsProgressTitle;

  /// Corps de la carte de progression au tout départ, aucun outil prêt (tools_completion_card.dart).
  ///
  /// In fr, this message translates to:
  /// **'Adresses, destinataires, modèles, grille de prix, alertes : remplis une fois, réutilisés à chaque publication.'**
  String get activityToolsStartBody;

  /// Corps de la carte de progression une fois au moins un outil prêt ; {missing} est la phrase déjà localisée (activityToolsMissing) (tools_completion_card.dart).
  ///
  /// In fr, this message translates to:
  /// **'{missing} Une fois vos outils prêts, plus rien à ressaisir.'**
  String activityToolsProgressBody(Object missing);

  /// CTA de la carte de progression au tout départ, aucun outil prêt (tools_completion_card.dart).
  ///
  /// In fr, this message translates to:
  /// **'Commencer par mes adresses'**
  String get activityToolsStartCta;

  /// Libellé court affiché par la jauge de progression des outils (tools_completion_card.dart DonyOnboardingGauge.label).
  ///
  /// In fr, this message translates to:
  /// **'prêts'**
  String get activityToolsGaugeLabel;

  /// Semantics de la jauge de progression des outils (tools_completion_card.dart).
  ///
  /// In fr, this message translates to:
  /// **'Préparation de vos outils'**
  String get activityToolsGaugeSemantics;

  /// Texte du badge de nouveauté de la tuile alertes, deux branches identiques en anglais (activites_hub_screen.dart _alertsTile).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} nouveau} other{{count} nouveaux}}'**
  String activityNewCount(num count);

  /// Semantics du badge de nouveauté de la tuile alertes (activites_hub_screen.dart _alertsTile).
  ///
  /// In fr, this message translates to:
  /// **'{title}, {label} depuis votre dernière visite'**
  String activityNewSinceLastVisit(Object label, Object title);

  /// Libellé du poids maximum au-dessus du slider (create_bid_bottom_sheet.dart _buildSlider). {maxKg} déjà formaté (toStringAsFixed(0)).
  ///
  /// In fr, this message translates to:
  /// **'max {maxKg} kg'**
  String bidCreateMaxWeightLabel(String maxKg);

  /// Bouton générique de fin d'action (ex. bouton Terminé de la vue succès de DonyPaymentSheet).
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get commonDone;

  /// Bouton générique de report d'action.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get commonLater;

  /// Titre générique court d'un état d'erreur de chargement.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get commonLoadError;

  /// Message générique court d'erreur, sans point final.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get commonSomethingWentWrong;

  /// Message générique court d'erreur, avec point final.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue.'**
  String get commonSomethingWentWrongDot;

  /// Action générique de capture photo (choix appareil photo vs galerie).
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get commonTakePhoto;

  /// Action générique de sélection depuis la galerie (choix appareil photo vs galerie).
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get commonPickFromGallery;

  /// Message générique d'erreur d'upload d'image.
  ///
  /// In fr, this message translates to:
  /// **'Image non supportée ou trop volumineuse'**
  String get commonImageUnsupported;

  /// Badge générique « par défaut » (ex. adresse ou destinataire par défaut).
  ///
  /// In fr, this message translates to:
  /// **'Par défaut'**
  String get commonDefault;

  /// Famille commonDate… : date relative « hier ».
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get commonDateYesterday;

  /// Nom affichable de la devise EUR (SupportedCurrencyL10n.name), identique fr/en.
  ///
  /// In fr, this message translates to:
  /// **'Euro'**
  String get currencyNameEur;

  /// Nom affichable de la devise USD (SupportedCurrencyL10n.name).
  ///
  /// In fr, this message translates to:
  /// **'Dollar américain'**
  String get currencyNameUsd;

  /// Nom affichable de la devise CAD (SupportedCurrencyL10n.name).
  ///
  /// In fr, this message translates to:
  /// **'Dollar canadien'**
  String get currencyNameCad;

  /// Nom affichable de la devise GBP (SupportedCurrencyL10n.name).
  ///
  /// In fr, this message translates to:
  /// **'Livre sterling'**
  String get currencyNameGbp;

  /// Nom affichable de la devise CHF (SupportedCurrencyL10n.name).
  ///
  /// In fr, this message translates to:
  /// **'Franc suisse'**
  String get currencyNameChf;

  /// Nom affichable de la devise XOF (SupportedCurrencyL10n.name).
  ///
  /// In fr, this message translates to:
  /// **'Franc CFA Ouest'**
  String get currencyNameXof;

  /// Nom affichable de la devise XAF (SupportedCurrencyL10n.name).
  ///
  /// In fr, this message translates to:
  /// **'Franc CFA Centre'**
  String get currencyNameXaf;

  /// Libellé générique de PaymentSheetFailureReason.cardUnavailable (dony_payment_sheet.dart), affiché quand providerMessage est absent.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement par carte est indisponible pour le moment. Réessaie dans un instant.'**
  String get paymentCardUnavailable;

  /// Libellé générique de PaymentSheetFailureReason.generic (dony_payment_sheet.dart), affiché quand providerMessage est absent.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement a échoué. Réessaie dans un instant.'**
  String get paymentFailedGeneric;

  /// Libellé générique de PaymentSheetFailureReason.declined (dony_payment_sheet.dart), affiché quand providerMessage est absent.
  ///
  /// In fr, this message translates to:
  /// **'Paiement refusé'**
  String get paymentDeclined;

  /// Semantics regroupée des moyens de paiement (payment_method_names.dart, mode compact). {wallet} = Apple Pay ou Google Pay, nom de marque non traduit.
  ///
  /// In fr, this message translates to:
  /// **'Carte, {wallet}, PayPal'**
  String paymentMethodsSemantics(String wallet);

  /// Libellé de contexte de la feuille de paiement quand le destinataire est connu (payment_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Envoi de {name}'**
  String paymentContextRecipient(String name);

  /// Libellé de contexte de la feuille de paiement quand aucun destinataire n'est connu (payment_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Envoi de votre colis'**
  String get paymentContextDefault;

  /// Notice de débit de la carte commission, cas devise active = EUR (commission_method_screen.dart) : le plancher de 1 € est un montant serveur en euros, fixe quelle que soit la langue.
  ///
  /// In fr, this message translates to:
  /// **'Cette carte sera débitée de la commission ({percent} %, min. 1 €) à chaque colis en espèces accepté.'**
  String commissionCardDebitNoticeMin(String percent);

  /// Notice de débit de la carte commission, cas devise active différente de l'EUR (commission_method_screen.dart), sans le plancher en euros.
  ///
  /// In fr, this message translates to:
  /// **'Cette carte sera débitée de la commission ({percent} %) à chaque colis en espèces accepté.'**
  String commissionCardDebitNotice(String percent);

  /// Titre de l'AppBar de l'écran Carte commission (commission_method_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Carte commission'**
  String get commissionCardScreenTitle;

  /// Message de l'état d'erreur de chargement de la carte commission (commission_method_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get commissionCardLoadError;

  /// Snackbar affichée quand requirePaymentAuth échoue, partagée entre commission_method_screen.dart et payment_screen.dart (même feature payments).
  ///
  /// In fr, this message translates to:
  /// **'Paiement non confirmé, réessayez'**
  String get paymentNotConfirmedSnackbar;

  /// Bouton de remplacement de la carte commission (commission_method_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Remplacer la carte'**
  String get commissionCardReplaceButton;

  /// Bouton de suppression de la carte commission (commission_method_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la carte'**
  String get commissionCardDeleteButton;

  /// Message de repli quand le SDK Stripe ne fournit pas de localizedMessage (commission_method_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'ajout de la carte.'**
  String get commissionCardAddErrorMessage;

  /// Corps de la bottom sheet de confirmation de suppression de la carte commission (commission_method_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette carte ? Vous ne pourrez plus accepter de colis en espèces tant que vous n\'aurez pas enregistré une nouvelle carte.'**
  String get commissionCardDeleteConfirmMessage;

  /// Titre de l'état vide de la carte commission (commission_card_empty_state.dart).
  ///
  /// In fr, this message translates to:
  /// **'Aucune carte enregistrée'**
  String get commissionCardEmptyTitle;

  /// Corps de l'état vide de la carte commission (commission_card_empty_state.dart).
  ///
  /// In fr, this message translates to:
  /// **'Pour accepter des paiements en espèces, enregistrez une carte sur laquelle nous prélèverons notre commission ({percent} %) à chaque colis accepté.'**
  String commissionCardEmptyBody(String percent);

  /// Bouton d'ajout de la carte commission (commission_card_empty_state.dart).
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une carte'**
  String get commissionCardAddButton;

  /// Bandeau d'expiration de la carte commission, carte déjà expirée (commission_card_expiration_banner.dart).
  ///
  /// In fr, this message translates to:
  /// **'Votre carte a expiré. Remplacez-la pour réactiver le paiement en espèces.'**
  String get commissionCardExpiredMessage;

  /// Bandeau d'expiration de la carte commission, carte bientôt expirée (commission_card_expiration_banner.dart). {date} = formattedExpiry (MM/AA), un format, pas une date localisée.
  ///
  /// In fr, this message translates to:
  /// **'Votre carte expire le {date}. Pensez à la remplacer.'**
  String commissionCardExpiringMessage(String date);

  /// Date d'expiration affichée sur l'aperçu de la carte commission (commission_card_preview.dart). {date} = formattedExpiry (MM/AA), un format, pas une date localisée.
  ///
  /// In fr, this message translates to:
  /// **'Expire le {date}'**
  String commissionCardExpiryLabel(String date);

  /// Titre du dialogue de confirmation d'action importante avant paiement (payment_auth.dart, requirePaymentAuth).
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le paiement'**
  String get paymentAuthConfirmTitle;

  /// Message du dialogue de confirmation d'action importante avant paiement (payment_auth.dart, requirePaymentAuth).
  ///
  /// In fr, this message translates to:
  /// **'Le montant sera bloqué jusqu\'à la livraison, puis versé au voyageur.'**
  String get paymentAuthConfirmMessage;

  /// Titre de l'AppBar de l'écran de paiement (payment_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Payer mon envoi'**
  String get paymentScreenTitle;

  /// Bandeau info de l'écran de paiement (payment_screen.dart).
  ///
  /// In fr, this message translates to:
  /// **'Votre paiement est sécurisé, libéré uniquement après confirmation de livraison par le destinataire.'**
  String get paymentSecureNotice;

  /// Bouton de paiement de l'écran de paiement (payment_screen.dart). {price} déjà formaté dans sa devise (formatPriceIn).
  ///
  /// In fr, this message translates to:
  /// **'Payer {price}'**
  String paymentPayButtonLabel(String price);

  /// Titre de la carte récapitulatif de l'écran de paiement (payment_screen.dart _SummaryCard).
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get paymentSummaryTitle;

  /// Libellé de la ligne poids du récapitulatif de paiement (payment_screen.dart _SummaryCard).
  ///
  /// In fr, this message translates to:
  /// **'Poids'**
  String get paymentSummaryWeightLabel;

  /// Libellé de la ligne prix au kilo du récapitulatif de paiement (payment_screen.dart _SummaryCard).
  ///
  /// In fr, this message translates to:
  /// **'Prix/kg'**
  String get paymentSummaryPricePerKgLabel;

  /// Libellé de la ligne type (mode grille d'articles) du récapitulatif de paiement, identique fr/en (payment_screen.dart _SummaryCard).
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get paymentSummaryTypeLabel;

  /// Valeur de la ligne type en mode grille d'articles du récapitulatif de paiement (payment_screen.dart _SummaryCard).
  ///
  /// In fr, this message translates to:
  /// **'Forfait articles'**
  String get paymentSummaryFlatRateValue;

  /// Libellé du total du récapitulatif de paiement (payment_screen.dart _SummaryCard).
  ///
  /// In fr, this message translates to:
  /// **'Vous payez'**
  String get paymentSummaryTotalLabel;

  /// Titre de la vue de confirmation escrow de l'écran de paiement (payment_screen.dart _EscrowConfirmedView).
  ///
  /// In fr, this message translates to:
  /// **'Envoi réservé !'**
  String get paymentEscrowTitle;

  /// Sous-titre de la vue de confirmation escrow de l'écran de paiement (payment_screen.dart _EscrowConfirmedView). {amount} déjà formaté dans sa devise (formatPriceIn).
  ///
  /// In fr, this message translates to:
  /// **'{amount} sont bloqués et sécurisés, puis libérés après confirmation de livraison par le destinataire.'**
  String paymentEscrowSubtitle(String amount);

  /// CTA de la vue de confirmation escrow de l'écran de paiement (payment_screen.dart _EscrowConfirmedView).
  ///
  /// In fr, this message translates to:
  /// **'Voir mes envois'**
  String get paymentEscrowCta;

  /// Titre de la feuille de paiement custom Yadony (dony_payment_sheet.dart _MainView).
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get paymentSheetTitle;

  /// Titre de la vue succès de la feuille de paiement (dony_payment_sheet.dart _SuccessView).
  ///
  /// In fr, this message translates to:
  /// **'Paiement confirmé'**
  String get paymentSheetConfirmedTitle;

  /// Note d'explication du séquestre dans la vue succès de la feuille de paiement (dony_payment_sheet.dart _SuccessView).
  ///
  /// In fr, this message translates to:
  /// **'Les fonds sont conservés en séquestre, le voyageur sera payé après la remise du colis.'**
  String get paymentSheetEscrowNote;

  /// Pied de la feuille de paiement, hors vue succès (dony_payment_sheet.dart _StickyBottom).
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé par Stripe'**
  String get paymentSheetSecureFooter;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
