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

  /// No description provided for @errorFirebaseInvalidPhoneNumberTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro invalide'**
  String get errorFirebaseInvalidPhoneNumberTitle;

  /// No description provided for @errorFirebaseInvalidPhoneNumberMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie le numéro saisi et réessaie.'**
  String get errorFirebaseInvalidPhoneNumberMessage;

  /// No description provided for @errorFirebaseCodeIncorrectTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect'**
  String get errorFirebaseCodeIncorrectTitle;

  /// No description provided for @errorFirebaseCodeIncorrectMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le code de vérification saisi est incorrect.'**
  String get errorFirebaseCodeIncorrectMessage;

  /// No description provided for @errorFirebaseCodeExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code expiré'**
  String get errorFirebaseCodeExpiredTitle;

  /// No description provided for @errorFirebaseCodeExpiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a expiré. Demande un nouveau code.'**
  String get errorFirebaseCodeExpiredMessage;

  /// No description provided for @errorFirebaseTooManyAttemptsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives'**
  String get errorFirebaseTooManyAttemptsTitle;

  /// No description provided for @errorFirebaseTooManyAttemptsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessaie dans quelques minutes.'**
  String get errorFirebaseTooManyAttemptsMessage;

  /// No description provided for @errorFirebaseSessionExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée'**
  String get errorFirebaseSessionExpiredTitle;

  /// No description provided for @errorFirebaseSessionExpiredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ta session a expiré. Recommence la connexion.'**
  String get errorFirebaseSessionExpiredMessage;

  /// No description provided for @errorFirebaseNetworkRequestFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Erreur réseau'**
  String get errorFirebaseNetworkRequestFailedTitle;

  /// No description provided for @errorFirebaseNetworkRequestFailedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre les serveurs Google. Vérifie ta connexion.'**
  String get errorFirebaseNetworkRequestFailedMessage;

  /// No description provided for @errorFirebaseAppVerificationFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification impossible'**
  String get errorFirebaseAppVerificationFailedTitle;

  /// No description provided for @errorFirebaseAppVerificationFailedMessage.
  ///
  /// In fr, this message translates to:
  /// **'La vérification de l\'application a échoué. Réinstalle l\'app depuis TestFlight ou le Store puis réessaie.'**
  String get errorFirebaseAppVerificationFailedMessage;

  /// No description provided for @errorFirebaseAuthErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion'**
  String get errorFirebaseAuthErrorTitle;

  /// No description provided for @errorFirebaseAuthErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'La connexion a échoué. Réessaie dans un instant.'**
  String get errorFirebaseAuthErrorMessage;

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

  /// No description provided for @errorPhoneAlreadyRegisteredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro déjà utilisé'**
  String get errorPhoneAlreadyRegisteredTitle;

  /// No description provided for @errorPhoneAlreadyRegisteredMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro est déjà associé à un compte'**
  String get errorPhoneAlreadyRegisteredMessage;

  /// No description provided for @errorAuthGenericErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errorAuthGenericErrorTitle;

  /// No description provided for @errorAuthGenericErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get errorAuthGenericErrorMessage;

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

  /// No description provided for @authCountryGaugeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get authCountryGaugeLabel;

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

  /// No description provided for @authPersonalInfoContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get authPersonalInfoContinue;

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

  /// No description provided for @authConsentGaugeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get authConsentGaugeLabel;

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

  /// No description provided for @authLocalCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get authLocalCancel;

  /// No description provided for @authLocalContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get authLocalContinue;

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
