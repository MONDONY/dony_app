// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonOk => 'OK';

  @override
  String get commonClose => 'Close';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguagePhone => 'Phone language';

  @override
  String get errorMobileMoneyDisabledTitle => 'Mobile money unavailable';

  @override
  String get errorMobileMoneyDisabledMessage =>
      'Mobile money payments aren\'t available right now. Choose another payment method.';

  @override
  String get errorMobileMoneyPhoneRequiredTitle => 'Phone number missing';

  @override
  String get errorMobileMoneyPhoneRequiredMessage =>
      'Enter the mobile money number to use to continue.';

  @override
  String get errorMobileMoneyAccountUnsupportedTitle => 'Number not supported';

  @override
  String get errorMobileMoneyAccountUnsupportedMessage =>
      'Your number isn\'t linked to a supported mobile money provider, or its currency doesn\'t match your region.';

  @override
  String get errorMobileMoneyAccountRequiredTitle => 'Payout account required';

  @override
  String get errorMobileMoneyAccountRequiredMessage =>
      'Turn on mobile money payouts before accepting this offer.';

  @override
  String get errorMobileMoneyCurrencyMismatchTitle => 'Different currency';

  @override
  String get errorMobileMoneyCurrencyMismatchMessage =>
      'Your mobile money payout account isn\'t in this trip\'s currency.';

  @override
  String get errorMobileMoneyNotAvailableTitle => 'Mobile money not offered';

  @override
  String get errorMobileMoneyNotAvailableMessage =>
      'This traveler doesn\'t accept mobile money payments.';

  @override
  String get errorMobileMoneyPayerUnsupportedTitle => 'Number not supported';

  @override
  String get errorMobileMoneyPayerUnsupportedMessage =>
      'Check the number that will pay, or try another number.';

  @override
  String get errorMobileMoneyInvalidPhoneTitle => 'Number not recognized';

  @override
  String get errorMobileMoneyInvalidPhoneMessage =>
      'No mobile money provider recognizes this number. Check it and try again.';

  @override
  String get errorMobileMoneyDepositRejectedTitle => 'Payment declined';

  @override
  String get errorMobileMoneyDepositRejectedMessage =>
      'The provider declined the payment request. Try again, or use another number.';

  @override
  String get errorMobileMoneyPaymentExpiredTitle => 'Time\'s up';

  @override
  String get errorMobileMoneyPaymentExpiredMessage =>
      'The 30-minute payment window has passed. Make the traveler a new offer.';

  @override
  String get errorMobileMoneyPaymentNotPendingTitle =>
      'Payment already processed';

  @override
  String get errorMobileMoneyPaymentNotPendingMessage =>
      'This payment is no longer pending.';

  @override
  String get errorMobileMoneyOperationInProgressTitle =>
      'Operation in progress';

  @override
  String get errorMobileMoneyOperationInProgressMessage =>
      'A mobile money operation is already in progress for this parcel. Please wait a moment.';

  @override
  String get errorMobileMoneyProviderUnavailableTitle => 'Service unavailable';

  @override
  String get errorMobileMoneyProviderUnavailableMessage =>
      'The mobile money service isn\'t responding. Try again in a few minutes.';

  @override
  String get errorInvalidPaymentMethodTitle => 'Invalid payment method';

  @override
  String get errorInvalidPaymentMethodMessage =>
      'This payment method isn\'t recognized. Update the app.';

  @override
  String get errorRequestBudgetOutOfBoundsTitle => 'Budget too high';

  @override
  String get errorRequestBudgetOutOfBoundsMessage =>
      'This budget is above the limit for this currency. Lower the amount and try again.';

  @override
  String get errorRequestAlreadyAcceptedTitle => 'This parcel is taken';

  @override
  String get errorRequestAlreadyAcceptedMessage =>
      'Another traveler paid the service fee before you, so this parcel is no longer available to you.';

  @override
  String get errorThreadNotAwaitingCommissionTitle => 'This parcel is taken';

  @override
  String get errorThreadNotAwaitingCommissionMessage =>
      'This offer no longer needs payment. It was settled another way or the time limit has passed.';

  @override
  String get errorUnauthorizedTitle => 'Session expired';

  @override
  String get errorUnauthorizedMessage => 'Sign in again to continue.';

  @override
  String get errorReauthRequiredTitle => 'Sign in again';

  @override
  String get errorReauthRequiredMessage =>
      'For your security, sign in again to do this.';

  @override
  String get errorForbiddenTitle => 'Action not allowed';

  @override
  String get errorForbiddenMessage => 'You don\'t have permission to do this.';

  @override
  String get errorAccessDeniedTitle => 'Access denied';

  @override
  String get errorAccessDeniedMessage => 'You can\'t access this content.';

  @override
  String get errorAccountBannedTitle => 'Account suspended';

  @override
  String get errorAccountBannedMessage =>
      'Your account has been suspended. Contact support for more information.';

  @override
  String get errorFirebaseInvalidPhoneNumberTitle => 'Invalid number';

  @override
  String get errorFirebaseInvalidPhoneNumberMessage =>
      'Check the number you entered and try again.';

  @override
  String get errorFirebaseCodeIncorrectTitle => 'Incorrect code';

  @override
  String get errorFirebaseCodeIncorrectMessage =>
      'The verification code you entered is incorrect.';

  @override
  String get errorFirebaseCodeExpiredTitle => 'Code expired';

  @override
  String get errorFirebaseCodeExpiredMessage =>
      'This code has expired. Request a new one.';

  @override
  String get errorFirebaseTooManyAttemptsTitle => 'Too many attempts';

  @override
  String get errorFirebaseTooManyAttemptsMessage =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get errorFirebaseSessionExpiredTitle => 'Session expired';

  @override
  String get errorFirebaseSessionExpiredMessage =>
      'Your session has expired. Sign in again from the start.';

  @override
  String get errorFirebaseNetworkRequestFailedTitle => 'Network error';

  @override
  String get errorFirebaseNetworkRequestFailedMessage =>
      'Can\'t reach Google\'s servers. Check your connection.';

  @override
  String get errorFirebaseAppVerificationFailedTitle => 'Verification failed';

  @override
  String get errorFirebaseAppVerificationFailedMessage =>
      'App verification failed. Reinstall the app from TestFlight or the store, then try again.';

  @override
  String get errorFirebaseAuthErrorTitle => 'Sign-in error';

  @override
  String get errorFirebaseAuthErrorMessage =>
      'Sign-in failed. Try again in a moment.';

  @override
  String get errorPhoneOtpInvalidTitle => 'Incorrect code';

  @override
  String get errorPhoneOtpInvalidMessage =>
      'The verification code you entered is incorrect.';

  @override
  String get errorPhoneOtpExpiredTitle => 'Code expired';

  @override
  String get errorPhoneOtpExpiredMessage =>
      'This code has expired. Request a new one.';

  @override
  String get errorPhoneOtpAttemptsExceededTitle => 'Too many attempts';

  @override
  String get errorPhoneOtpAttemptsExceededMessage =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get errorPhoneOtpRateLimitTitle => 'Too many requests';

  @override
  String get errorPhoneOtpRateLimitMessage =>
      'Too many codes sent. Try again in a few minutes.';

  @override
  String get errorPhoneAlreadySetTitle => 'Number already set';

  @override
  String get errorPhoneAlreadySetMessage =>
      'A phone number is already linked to this account.';

  @override
  String get errorPhoneAlreadyExistsTitle => 'Number already in use';

  @override
  String get errorPhoneAlreadyExistsMessage =>
      'This number is already linked to another account.';

  @override
  String get errorSmsOtpDisabledTitle => 'Unavailable';

  @override
  String get errorSmsOtpDisabledMessage =>
      'Phone sign-in isn\'t available yet.';

  @override
  String get errorInvalidPhoneNumberTitle => 'Number unreachable';

  @override
  String get errorInvalidPhoneNumberMessage =>
      'This number can\'t receive text messages. Check the country code and the number of digits, then try again.';

  @override
  String get errorAnnouncementNotFoundTitle => 'Trip not found';

  @override
  String get errorAnnouncementNotFoundMessage =>
      'This trip no longer exists or has been removed.';

  @override
  String get errorCurrencyMismatchTitle => 'Different currency';

  @override
  String get errorCurrencyMismatchMessage =>
      'This trip is no longer available in your currency. Change your country in Settings to see it.';

  @override
  String get errorCountryRequiredTitle => 'Country missing';

  @override
  String get errorCountryRequiredMessage =>
      'Set your country in Settings, under Preferences, before creating your payment account. It sets your currency and can\'t be changed afterwards.';

  @override
  String get errorCountryLockedTitle => 'Country locked';

  @override
  String get errorCountryLockedMessage =>
      'You can\'t change your country: a parcel is in progress, your wallet isn\'t empty, or your payment account is already set up.';

  @override
  String get errorCountryUnsupportedTitle => 'Country not served';

  @override
  String get errorCountryUnsupportedMessage =>
      'Yadony doesn\'t serve this country yet. Choose another one.';

  @override
  String get errorDeletionImpossibleTitle => 'Can\'t delete';

  @override
  String get errorDeletionImpossibleMessage =>
      'A parcel has already been accepted on this trip. Cancel the trip instead: the sender will get a refund.';

  @override
  String get errorProLimitReachedTitle => 'Monthly limit reached';

  @override
  String get errorProLimitReachedMessage =>
      'You\'ve reached your listing limit for this month. Upgrade to Pro to publish without limits.';

  @override
  String get errorDraftLimitReachedTitle => 'Draft limit reached';

  @override
  String get errorDraftLimitReachedMessage =>
      'Upgrade to Pro to create more drafts.';

  @override
  String get errorNotADraftTitle => 'Already published';

  @override
  String get errorNotADraftMessage => 'This trip isn\'t a draft.';

  @override
  String get errorPublishingSuspendedTitle => 'Publishing suspended';

  @override
  String get errorPublishingSuspendedMessage =>
      'Publishing is suspended on your account. Contact support.';

  @override
  String get errorKycNotVerifiedTitle => 'Identity not verified';

  @override
  String get errorKycNotVerifiedMessage =>
      'Verify your identity before publishing a trip.';

  @override
  String get errorDepartureDatePassedTitle => 'Departure date has passed';

  @override
  String get errorDepartureDatePassedMessage =>
      'Change the departure date before publishing this trip.';

  @override
  String get errorBidNotFoundTitle => 'Request not found';

  @override
  String get errorBidNotFoundMessage => 'This parcel request no longer exists.';

  @override
  String get errorContactKycRequiredTitle => 'Verified profile required';

  @override
  String get errorContactKycRequiredMessage =>
      'This traveler only accepts verified profiles. Verify your identity to send them a request.';

  @override
  String get errorBidNotAcceptedTitle => 'Request not accepted';

  @override
  String get errorBidNotAcceptedMessage =>
      'The traveler must accept this request before this step.';

  @override
  String get errorBidNotDeliveredTitle => 'Parcel not delivered';

  @override
  String get errorBidNotDeliveredMessage =>
      'The parcel must be delivered before you can do this.';

  @override
  String get errorInvalidBidStatusTitle => 'Invalid parcel status';

  @override
  String get errorInvalidBidStatusMessage =>
      'The parcel\'s current status doesn\'t allow this.';

  @override
  String get errorUseConfirmDeliveryTitle => 'Confirm the delivery';

  @override
  String get errorUseConfirmDeliveryMessage =>
      'To finish, use the recipient\'s delivery confirmation screen.';

  @override
  String get errorQrNotReadyTitle => 'QR code not ready yet';

  @override
  String get errorQrNotReadyMessage =>
      'The QR code will be available once the sender has completed the payment.';

  @override
  String get errorDepartAlreadyScannedTitle => 'Departure already scanned';

  @override
  String get errorDepartAlreadyScannedMessage =>
      'This parcel\'s departure is already recorded. You can move on to the next step.';

  @override
  String get errorCodeNotGeneratedTitle => 'No code yet';

  @override
  String get errorCodeNotGeneratedMessage =>
      'No confirmation code has been generated for this delivery yet.';

  @override
  String get errorCodeExpiredTitle => 'Code expired';

  @override
  String get errorCodeExpiredMessage =>
      'This code has expired. Ask the sender to generate a new one.';

  @override
  String get errorCodeIncorrectTitle => 'Incorrect code';

  @override
  String get errorCodeIncorrectMessage =>
      'The code you entered is incorrect. Check with the sender.';

  @override
  String get errorTooManyAttemptsTitle => 'Too many attempts';

  @override
  String get errorTooManyAttemptsMessage =>
      'You\'ve made too many attempts. Wait a few minutes before trying again.';

  @override
  String get errorTooManyRefreshesTitle => 'Limit reached';

  @override
  String get errorTooManyRefreshesMessage =>
      'You\'ve already refreshed the code several times. Wait before generating a new one.';

  @override
  String get errorInvalidTimestampTitle => 'Invalid timestamp';

  @override
  String get errorInvalidTimestampMessage =>
      'The scan\'s timestamp doesn\'t add up. Try again once you\'re online.';

  @override
  String get errorInvalidWindowTitle => 'Outside the time slot';

  @override
  String get errorInvalidWindowMessage =>
      'This isn\'t allowed outside the scheduled time slot.';

  @override
  String get errorAlreadyCancelledTitle => 'Already canceled';

  @override
  String get errorAlreadyCancelledMessage => 'This has already been canceled.';

  @override
  String get errorActiveTransactionsTitle => 'Can\'t do this';

  @override
  String get errorActiveTransactionsMessage =>
      'Some transactions are in progress. Finish or cancel them before continuing.';

  @override
  String get errorInvalidStatusTitle => 'Invalid status';

  @override
  String get errorInvalidStatusMessage =>
      'The current status doesn\'t allow this.';

  @override
  String get errorNotPendingDeletionTitle => 'No deletion requested';

  @override
  String get errorNotPendingDeletionMessage =>
      'There\'s no pending account deletion request.';

  @override
  String get errorAlreadyRatedTitle => 'Already rated';

  @override
  String get errorAlreadyRatedMessage =>
      'You\'ve already left a rating for this delivery.';

  @override
  String get errorRatingWindowExpiredTitle => 'Time\'s up';

  @override
  String get errorRatingWindowExpiredMessage =>
      'The time to rate this delivery has passed.';

  @override
  String get errorNegotiationCommissionChargeFailedTitle =>
      'Deal not confirmed';

  @override
  String get errorNegotiationCommissionChargeFailedMessage =>
      'We couldn\'t charge the service fee to the traveler, so the deal isn\'t confirmed. They\'ve just been asked to top up their wallet. Try again afterwards.';

  @override
  String get errorNegotiationNotAwaitingDepositTitle => 'No payment pending';

  @override
  String get errorNegotiationNotAwaitingDepositMessage =>
      'This conversation isn\'t waiting for a mobile money payment.';

  @override
  String get errorNegotiationDepositInFlightTitle => 'Payment being confirmed';

  @override
  String get errorNegotiationDepositInFlightMessage =>
      'Your provider is still processing the payment. Please wait a moment.';

  @override
  String get errorNegotiationTravelerCannotReceiveMobileMoneyTitle =>
      'Mobile money unavailable';

  @override
  String get errorNegotiationTravelerCannotReceiveMobileMoneyMessage =>
      'The traveler can\'t receive mobile money payouts in this currency. Choose another payment method.';

  @override
  String get errorBidNotNegotiatedTitle => 'Nothing to pay here';

  @override
  String get errorBidNotNegotiatedMessage =>
      'This parcel didn\'t come from a price negotiation, so there\'s no payment to start from this screen.';

  @override
  String get errorBidNotAwaitingPaymentTitle => 'Deal can\'t be paid';

  @override
  String get errorBidNotAwaitingPaymentMessage =>
      'This negotiation isn\'t waiting for a card payment. Open it again to see where it stands.';

  @override
  String get errorBidAlreadyPaidTitle => 'Already paid';

  @override
  String get errorBidAlreadyPaidMessage =>
      'This parcel is already paid. Refresh to see its latest status.';

  @override
  String get errorPaymentAlreadyCompletedTitle => 'Already paid';

  @override
  String get errorPaymentAlreadyCompletedMessage =>
      'This parcel is already paid. Find it in My parcels to follow what happens next.';

  @override
  String get errorTravelerStripeInvalidTitle => 'Traveler not set up';

  @override
  String get errorTravelerStripeInvalidMessage =>
      'The traveler hasn\'t finished setting up their payments. Card payment isn\'t possible for now. Contact them from the conversation.';

  @override
  String get errorPaymentMethodTravelerInsufficientFundsCashTitle =>
      'Insufficient balance';

  @override
  String get errorPaymentMethodTravelerInsufficientFundsCashMessage =>
      'Your wallet doesn\'t have enough funds to pay the Yadony service fee for a cash payment. Top it up or add a card.';

  @override
  String get errorPaymentMethodNoCommissionCardTitle => 'Card required';

  @override
  String get errorPaymentMethodNoCommissionCardMessage =>
      'Add a card for the service fee first, so you can pay in cash when your balance is too low.';

  @override
  String get errorPaymentMethodNotInAvailableSetTitle =>
      'Payment method not offered';

  @override
  String get errorPaymentMethodNotInAvailableSetMessage =>
      'This payment method isn\'t available for this offer. Choose another one.';

  @override
  String get errorPaymentMethodMobileMoneyCapabilityRequiredTitle =>
      'Mobile money unavailable';

  @override
  String get errorPaymentMethodMobileMoneyCapabilityRequiredMessage =>
      'The traveler doesn\'t have a mobile money payout account in this currency.';

  @override
  String get errorWalletTopupStripeErrorTitle => 'Top-up unavailable';

  @override
  String get errorWalletTopupStripeErrorMessage =>
      'We couldn\'t set up the top-up. Try again in a moment.';

  @override
  String get errorTopupAmountOutOfRangeTitle => 'Amount out of range';

  @override
  String get errorTopupAmountOutOfRangeMessage =>
      'This amount is outside the allowed top-up limits. Adjust the amount and try again.';

  @override
  String get errorTopupAlreadyPendingTitle => 'Top-up already in progress';

  @override
  String get errorTopupAlreadyPendingMessage =>
      'A top-up is already in progress. Approve it on your phone, or wait for it to expire before starting a new one.';

  @override
  String get errorTopupPhoneRequiredTitle => 'Phone number missing';

  @override
  String get errorTopupPhoneRequiredMessage =>
      'Enter the number that will pay for the top-up.';

  @override
  String get errorTopupPhoneUnsupportedTitle => 'Number not supported';

  @override
  String get errorTopupPhoneUnsupportedMessage =>
      'This number can\'t be used for a mobile money top-up. Check it or try another number.';

  @override
  String get errorTopupNotFoundTitle => 'Top-up not found';

  @override
  String get errorTopupNotFoundMessage =>
      'This top-up no longer exists or its link has expired.';

  @override
  String get errorPaymentMethodUnavailableForCurrencyTitle =>
      'Payment method unavailable';

  @override
  String get errorPaymentMethodUnavailableForCurrencyMessage =>
      'This payment method isn\'t offered in this trip\'s currency.';

  @override
  String get errorUnsupportedCurrencyTitle => 'Currency not supported';

  @override
  String get errorUnsupportedCurrencyMessage =>
      'This currency isn\'t available yet. Check your account currency in Settings.';

  @override
  String get errorStripeAccountRequiredTitle => 'Stripe account needed';

  @override
  String get errorStripeAccountRequiredMessage =>
      'Your payment account hasn\'t been created yet. Tap the button again to start setting it up.';

  @override
  String get errorStripeAccountInvalidTitle => 'Invalid payment account';

  @override
  String get errorStripeAccountInvalidMessage =>
      'Your payment account is no longer valid. Tap the button again to create a new one.';

  @override
  String get errorStripeErrorTitle => 'Payment declined';

  @override
  String get errorStripeErrorMessage =>
      'The payment couldn\'t be processed. Check your card or try again in a moment.';

  @override
  String get errorGoogleTimeoutTitle => 'Service unavailable';

  @override
  String get errorGoogleTimeoutMessage =>
      'The location service is slow to respond. Try again in a few seconds.';

  @override
  String get errorOtpInvalidTitle => 'Invalid code';

  @override
  String get errorOtpInvalidMessage =>
      'The code you entered is incorrect or has already been used. Check the code you received by email.';

  @override
  String get errorOtpExpiredTitle => 'Code expired';

  @override
  String get errorOtpExpiredMessage =>
      'This code has expired. Go back and request a new one.';

  @override
  String get errorOtpAttemptsExceededTitle => 'Too many attempts';

  @override
  String get errorOtpAttemptsExceededMessage =>
      'Too many incorrect attempts. Wait a few minutes. Requesting a new code won\'t unlock it.';

  @override
  String get errorEmailAlreadyExistsTitle => 'Email already in use';

  @override
  String get errorEmailAlreadyExistsMessage =>
      'This email address is already linked to another account.';

  @override
  String get errorEmailAlreadySetTitle => 'Email already set';

  @override
  String get errorEmailAlreadySetMessage =>
      'An email address is already linked to this account and can\'t be replaced.';

  @override
  String get errorRateLimitTitle => 'Too many codes requested';

  @override
  String get errorRateLimitMessage =>
      'You\'ve requested several codes in a row. Wait a few minutes before asking for another one.';

  @override
  String get errorEmailServiceErrorTitle => 'Couldn\'t send';

  @override
  String get errorEmailServiceErrorMessage =>
      'The email couldn\'t be sent. Check the address you entered and try again.';

  @override
  String get errorFirebaseErrorTitle => 'Can\'t sign in';

  @override
  String get errorFirebaseErrorMessage =>
      'Sign-in couldn\'t be completed. Try again in a moment.';

  @override
  String get errorPromoNotFoundTitle => 'Promo code not found';

  @override
  String get errorPromoNotFoundMessage =>
      'This promo code doesn\'t exist. Check what you entered and try again.';

  @override
  String get errorPromoExpiredTitle => 'Promo code expired';

  @override
  String get errorPromoExpiredMessage =>
      'This promo code isn\'t valid (expired or not active yet).';

  @override
  String get errorPromoLimitReachedTitle => 'Promo code used up';

  @override
  String get errorPromoLimitReachedMessage =>
      'This promo code has reached its usage limit (overall or per user).';

  @override
  String get errorPromoNotEligibleTitle => 'Promo code doesn\'t apply';

  @override
  String get errorPromoNotEligibleMessage =>
      'This promo code isn\'t available for your profile.';

  @override
  String get errorReferralCodeNotFoundTitle => 'Code not found';

  @override
  String get errorReferralCodeNotFoundMessage =>
      'This referral code doesn\'t exist. Check what you entered and try again.';

  @override
  String get errorSelfReferralTitle => 'Self-referral not allowed';

  @override
  String get errorSelfReferralMessage =>
      'You can\'t use your own referral code.';

  @override
  String get errorAlreadyReferredTitle => 'Code already used';

  @override
  String get errorAlreadyReferredMessage =>
      'You\'ve already used a referral code.';

  @override
  String get errorUserNotFoundTitle => 'User not found';

  @override
  String get errorUserNotFoundMessage => 'This user account no longer exists.';

  @override
  String get errorOfflineTitle => 'No connection';

  @override
  String get errorOfflineMessage =>
      'Check your internet connection and try again. Your offline scans will sync when you\'re back online.';

  @override
  String get errorTimeoutTitle => 'The server is taking a while';

  @override
  String get errorTimeoutMessage =>
      'The request took too long. Try again in a few seconds.';

  @override
  String get errorRateLimitedTitle => 'Too many requests';

  @override
  String get errorRateLimitedMessage =>
      'You\'ve made too many requests in a short time. Wait a moment before trying again.';

  @override
  String get errorServerErrorTitle => 'Server error';

  @override
  String get errorServerErrorMessage =>
      'Something went wrong on our side. We\'re looking into it. Try again in a moment.';

  @override
  String get errorCancelledTitle => 'Action canceled';

  @override
  String get errorCancelledMessage => 'The action was canceled.';

  @override
  String get errorNotFoundTitle => 'Not found';

  @override
  String get errorNotFoundMessage =>
      'This item can\'t be found or has been deleted.';

  @override
  String get errorValidationTitle => 'Invalid information';

  @override
  String get errorValidationMessage =>
      'Check the information you entered and try again.';

  @override
  String get errorConflictTitle => 'Can\'t do this';

  @override
  String get errorConflictMessage => 'The current status doesn\'t allow this.';

  @override
  String get errorStorageTitle => 'Storage unavailable';

  @override
  String get errorStorageMessage =>
      'Can\'t access local storage. Restart the app.';

  @override
  String get errorNetworkTitle => 'Network error';

  @override
  String get errorNetworkMessage =>
      'Something went wrong. Check your connection and try again.';

  @override
  String get errorGenericTitle => 'Something went wrong';

  @override
  String get errorGenericMessage =>
      'Try again in a moment. If the problem continues, contact support.';

  @override
  String get networkFallbackSessionExpired => 'Session expired';

  @override
  String get networkFallbackAccessDenied => 'Access denied';

  @override
  String get networkFallbackNotFound => 'Resource not found';

  @override
  String get networkFallbackConflict => 'Conflict';

  @override
  String get networkFallbackInvalidData => 'Invalid information';

  @override
  String get networkFallbackTooManyAttempts => 'Too many attempts';

  @override
  String get networkFallbackServerError => 'Server error';

  @override
  String get networkFallbackNetworkError => 'Network error';

  @override
  String get countryNameDe => 'Germany';

  @override
  String get countryNameAt => 'Austria';

  @override
  String get countryNameBe => 'Belgium';

  @override
  String get countryNameCy => 'Cyprus';

  @override
  String get countryNameHr => 'Croatia';

  @override
  String get countryNameEs => 'Spain';

  @override
  String get countryNameEe => 'Estonia';

  @override
  String get countryNameFi => 'Finland';

  @override
  String get countryNameFr => 'France';

  @override
  String get countryNameGr => 'Greece';

  @override
  String get countryNameIe => 'Ireland';

  @override
  String get countryNameIt => 'Italy';

  @override
  String get countryNameLv => 'Latvia';

  @override
  String get countryNameLt => 'Lithuania';

  @override
  String get countryNameLu => 'Luxembourg';

  @override
  String get countryNameMt => 'Malta';

  @override
  String get countryNameNl => 'Netherlands';

  @override
  String get countryNamePt => 'Portugal';

  @override
  String get countryNameGb => 'United Kingdom';

  @override
  String get countryNameSk => 'Slovakia';

  @override
  String get countryNameSi => 'Slovenia';

  @override
  String get countryNameCh => 'Switzerland';

  @override
  String get countryNameCa => 'Canada';

  @override
  String get countryNameUs => 'United States';

  @override
  String get countryNameBj => 'Benin';

  @override
  String get countryNameBf => 'Burkina Faso';

  @override
  String get countryNameCi => 'Côte d\'Ivoire';

  @override
  String get countryNameGw => 'Guinea-Bissau';

  @override
  String get countryNameMl => 'Mali';

  @override
  String get countryNameNe => 'Niger';

  @override
  String get countryNameSn => 'Senegal';

  @override
  String get countryNameTg => 'Togo';

  @override
  String get countryNameCm => 'Cameroon';

  @override
  String get countryNameCf => 'Central African Republic';

  @override
  String get countryNameCg => 'Congo';

  @override
  String get countryNameGa => 'Gabon';

  @override
  String get countryNameGq => 'Equatorial Guinea';

  @override
  String get countryNameTd => 'Chad';

  @override
  String get countryZoneEurope => 'Europe';

  @override
  String get countryZoneNorthAmerica => 'North America';

  @override
  String get countryZoneWestAfrica => 'West Africa';

  @override
  String get countryZoneCentralAfrica => 'Central Africa';

  @override
  String get errorGuestSessionFailedTitle => 'Browsing unavailable';

  @override
  String get errorGuestSessionFailedMessage =>
      'Couldn\'t start browsing without an account. Check your connection.';

  @override
  String get errorPhoneAlreadyRegisteredTitle => 'Number already in use';

  @override
  String get errorPhoneAlreadyRegisteredMessage =>
      'This number is already linked to an account';

  @override
  String get errorAuthGenericErrorTitle => 'Something went wrong';

  @override
  String get errorAuthGenericErrorMessage => 'Something went wrong. Try again.';

  @override
  String get authCountrySaveError => 'Couldn\'t save your country. Try again.';

  @override
  String get authCountryChoiceSaveError =>
      'Couldn\'t save your choice. Try again.';

  @override
  String get authPersonalInfoSaveError =>
      'Couldn\'t save your details. Try again.';

  @override
  String get authUserFallbackName => 'User';

  @override
  String get authBiometricUnlockReason =>
      'Unlock Yadony to access your account';

  @override
  String get authStepConsent => 'Privacy';

  @override
  String get authStepCountry => 'Country';

  @override
  String get authStepIdentity => 'Identity';

  @override
  String get authStepPersonalInfo => 'Your details';

  @override
  String get authStepPayouts => 'Payments';

  @override
  String get authMethodIllustrationLabel =>
      'Yadony traveler holding a secured parcel';

  @override
  String get authMethodSecureBadge => 'Secure';

  @override
  String get authMethodTitle => 'Sign in with confidence';

  @override
  String get authMethodSubtitle =>
      'Your messages, your payment and your parcel tracking are protected at every step.';

  @override
  String get authMethodContinueWithApple => 'Continue with Apple';

  @override
  String get authMethodContinueWithEmail => 'Continue with email';

  @override
  String get authMethodContinueWithPhone => 'Continue with phone';

  @override
  String get authMethodContinueWithGoogle => 'Continue with Google';

  @override
  String get authMethodOr => 'OR';

  @override
  String get authMethodGuestSemantics =>
      'Browse without an account. Access limited to search. Sign-in required to post, contact, book or pay.';

  @override
  String get authMethodBrowseWithoutAccount => 'Browse without an account';

  @override
  String get authMethodGuestNotice =>
      'Limited access: search only. Sign-in required to post, contact, book or pay.';

  @override
  String get authLegalPrefix => 'By continuing, you accept our ';

  @override
  String get authLegalTermsLink => 'Terms of Use';

  @override
  String get authLegalMiddle => ' and our ';

  @override
  String get authLegalPrivacyLink => 'Privacy Policy';

  @override
  String get authEmailStepLabel => 'Email';

  @override
  String get authEmailTitle => 'Your email address';

  @override
  String get authEmailBody => 'Enter your email address to get a sign-in code.';

  @override
  String get authEmailFootnote =>
      'We protect your access without sharing your email with travelers.';

  @override
  String get authEmailHint => 'example@email.com';

  @override
  String get authEmailSpamHint =>
      'Check your spam folder if you don\'t get the code.';

  @override
  String get authEmailSendCode => 'Send code';

  @override
  String get authEmailPreferSms => 'Prefer SMS?';

  @override
  String get authPhoneDialCodeTitle => 'Country code';

  @override
  String get authPhoneStepLabel => 'Phone';

  @override
  String get authPhoneTitle => 'Your number';

  @override
  String get authPhoneBody =>
      'We\'ll text you a 6-digit code to check that it\'s really you.';

  @override
  String get authPhoneFootnote =>
      'Your number is only used to secure your account and your Yadony messages.';

  @override
  String get authPhoneNumberLabel => 'PHONE NUMBER';

  @override
  String get authPhoneEnterNumber => 'Enter your number';

  @override
  String get authPhoneNumberTooShort => 'Number too short';

  @override
  String get authPhoneGetSmsCode => 'Get SMS code';

  @override
  String get authPhoneContinueWithEmail => 'Continue with an email address';

  @override
  String get authOtpEnterSixDigits => 'Enter the 6-digit code';

  @override
  String get authOtpSessionExpired => 'Session expired, please start again';

  @override
  String get authOtpEmailVerified => 'Email verified!';

  @override
  String get authOtpPhoneAdded => 'Number added!';

  @override
  String get authOtpStepEmail => 'Email code';

  @override
  String get authOtpStepSms => 'SMS code';

  @override
  String get authOtpEmailTitle => 'Got the code?';

  @override
  String get authOtpPhoneTitle => 'Enter the code';

  @override
  String authOtpCodeSentTo(String contact) {
    return 'Code sent to $contact';
  }

  @override
  String authOtpCodeSentToPhone(String contact) {
    return 'Code sent to $contact';
  }

  @override
  String get authOtpFootnote =>
      'The code expires quickly to keep your Yadony account protected.';

  @override
  String authOtpResendIn(int seconds) {
    return 'Resend code ($seconds s)';
  }

  @override
  String get authOtpResend => 'Resend code';

  @override
  String get authOtpVerify => 'Verify';

  @override
  String get authDialCodeSearchHint => 'Search for a country or code';

  @override
  String get authDialCodeNoMatch => 'No matching country';

  @override
  String get authFlowIllustrationLabel => 'Secure Yadony sign-in';

  @override
  String get authFlowProtectedBadge => 'Protected sign-in';

  @override
  String get authFlowSkipForNow => 'Skip for now';

  @override
  String get authRequiredTitle => 'Sign-in required';

  @override
  String get authRequiredSignIn => 'Sign in';

  @override
  String get authRequiredKeepExploring => 'Keep exploring';

  @override
  String get authRequiredFreeSearchTitle => 'Free search';

  @override
  String get authRequiredFreeSearchBody =>
      'You can browse parcel requests and compare trips.';

  @override
  String get authRequiredProtectedTitle => 'Protected actions';

  @override
  String get authRequiredOfferSubtitle => 'Sign in to offer your trip safely.';

  @override
  String get authRequiredOfferBody =>
      'Signing in protects messages, offers and parcel tracking.';

  @override
  String get authRequiredReportSubtitle => 'Sign in to report a listing.';

  @override
  String get authRequiredReportBody =>
      'Reports are tied to an account to prevent abuse and better protect the community.';

  @override
  String get authRequiredExploreSubtitle => 'Sign in to use this action.';

  @override
  String get authRequiredExploreBody =>
      'Posting, contacting, booking or paying requires a Yadony account.';

  @override
  String get authOnboardingHandoffEyebrow => 'Step 1';

  @override
  String get authOnboardingHandoffTitle => 'Get your parcel ready.';

  @override
  String get authOnboardingHandoffSubtitle =>
      'Enter the destination and parcel size, then find an available traveler.';

  @override
  String get authOnboardingHandoffStep1Title => 'Create the listing';

  @override
  String get authOnboardingHandoffStep1Subtitle =>
      'Departure, arrival, parcel size.';

  @override
  String get authOnboardingHandoffStep2Title => 'Choose a traveler';

  @override
  String get authOnboardingHandoffStep2Subtitle =>
      'Profile, trip and availability.';

  @override
  String get authOnboardingHandoffStep3Title => 'Drop off the parcel';

  @override
  String get authOnboardingHandoffStep3Subtitle =>
      'The journey starts with the scan.';

  @override
  String get authOnboardingSecurityEyebrow => 'Security';

  @override
  String get authOnboardingSecurityTitle => 'Every drop-off is safeguarded.';

  @override
  String get authOnboardingSecuritySubtitle =>
      'Yadony protects profiles, payments and every key step of the parcel\'s journey.';

  @override
  String get authOnboardingChipVerifiedIdentity => 'Verified identity';

  @override
  String get authOnboardingChipPaymentOnHold => 'Payment on hold';

  @override
  String get authOnboardingChipTrackingQr => 'Tracking QR code';

  @override
  String get authOnboardingChipProofOfDropOff => 'Proof of drop-off';

  @override
  String get authOnboardingTrackingEyebrow => 'Real time';

  @override
  String get authOnboardingTrackingTitle => 'Keep track of your parcel.';

  @override
  String get authOnboardingTrackingSubtitle =>
      'Tracking moves forward with every scan, from departure to confirmed arrival.';

  @override
  String get authOnboardingTrackingStep1Title => 'Dropped off';

  @override
  String get authOnboardingTrackingStep1Subtitle =>
      'The parcel is handed to the traveler.';

  @override
  String get authOnboardingTrackingStep2Title => 'Departure, transit, arrival';

  @override
  String get authOnboardingTrackingStep2Subtitle =>
      'Every scan updates the tracking.';

  @override
  String get authOnboardingTrackingStep3Title => 'Delivery';

  @override
  String get authOnboardingTrackingStep3Subtitle =>
      'Receipt confirms the end of the trip.';

  @override
  String get authOnboardingDestinationsEyebrow => 'Destinations';

  @override
  String get authOnboardingDestinationsTitle => 'Your parcels go further.';

  @override
  String get authOnboardingDestinationsSubtitle =>
      'Yadony connects available countries with travelers already making the trip.';

  @override
  String get authOnboardingDestinationsStep6Title => 'Hand over on arrival';

  @override
  String get authOnboardingDestinationsStep6Subtitle =>
      'The recipient confirms receipt.';

  @override
  String get authOnboardingDestinationsStep7Title => 'Release the payment';

  @override
  String get authOnboardingDestinationsStep7Subtitle =>
      'The traveler gets paid once delivery succeeds.';

  @override
  String get authOnboardingChipAfrica => 'Africa';

  @override
  String get authOnboardingChipAvailableCountries => 'Available countries';

  @override
  String get authOnboardingImageLabel => 'Yadony onboarding scene';

  @override
  String get authOnboardingSkip => 'Skip';

  @override
  String get authOnboardingRouteDropOff => 'Drop-off';

  @override
  String get authOnboardingRouteDeparture => 'Departure';

  @override
  String get authOnboardingRouteTransit => 'In transit';

  @override
  String get authOnboardingRouteArrival => 'Arrival';

  @override
  String get authOnboardingRouteDelivery => 'Delivery';

  @override
  String get authOnboardingGetStarted => 'Get started';

  @override
  String get authOnboardingNext => 'Next';

  @override
  String get authOnboardingLegalPrefix => 'By continuing, you agree to our ';

  @override
  String get authOnboardingLegalTermsLink => 'Terms of Use';

  @override
  String get authOnboardingLegalMiddle => ' and our ';

  @override
  String get authOnboardingLegalPrivacyLink => 'Privacy Policy';

  @override
  String get authCountryGaugeLabel => 'Country';

  @override
  String get authCountryTitle => 'Which country do you live in?';

  @override
  String get authCountrySubtitle =>
      'We\'ll adapt the currency, trips and availability to your country.';

  @override
  String get authCountryFieldLabel => 'Country';

  @override
  String get authCountryFieldHint => 'E.g. Senegal, France, Canada';

  @override
  String get authCountryFieldHelper =>
      'Type your country, then pick a suggestion.';

  @override
  String get authCountrySaving => 'Saving country...';

  @override
  String get authCountryDeleteDialogTitle => 'Permanently delete the account?';

  @override
  String get authCountryDeleteDialogMessage =>
      'Your Yadony account and all related data will be deleted. This action cannot be undone.';

  @override
  String get authCountryDeleteDialogConfirm => 'Confirm deletion';

  @override
  String get authCountryUnavailableTitle =>
      'Yadony isn\'t available in this country yet';

  @override
  String get authCountryUnavailableBody =>
      'You can continue to send parcels. Trips and carrying parcels won\'t be available from this account.';

  @override
  String get authCountryContinueAsSender => 'Continue and send parcels';

  @override
  String get authCountryDeleteAccount => 'Delete my account';

  @override
  String authCountryOptionSavingLabel(String country, String currency) {
    return 'Selected country: $country, currency $currency. Saving.';
  }

  @override
  String authCountryOptionSelectLabel(String country, String currency) {
    return 'Select $country, currency $currency';
  }

  @override
  String get authPersonalInfoCountryNotSet => 'Not provided';

  @override
  String get authPersonalInfoGaugeLabel => 'Details';

  @override
  String get authPersonalInfoTitle => 'Your details';

  @override
  String get authPersonalInfoBody =>
      'Your legal name, exactly as it appears on your ID. Stripe will ask for the rest, only once.';

  @override
  String get authPersonalInfoFootnote =>
      'Never shared with other members, never shown publicly.';

  @override
  String get authPersonalInfoContinue => 'Continue';

  @override
  String get authPersonalInfoIdentitySection => 'Identity';

  @override
  String get authPersonalInfoFirstName => 'First name';

  @override
  String get authPersonalInfoLastName => 'Last name';

  @override
  String get authPersonalInfoCountrySection => 'Country';

  @override
  String get authPersonalInfoCountryField => 'Country';

  @override
  String authPersonalInfoCountrySemantics(String country) {
    return 'Country of residence: $country. Set at sign-up, can\'t be changed here.';
  }

  @override
  String get authPersonalInfoCountryMissingSemantics =>
      'Country of residence not provided. Set at sign-up, can\'t be changed here.';

  @override
  String get authReferralGaugeLabel => 'Referral';

  @override
  String get authReferralTitle => 'Did a friend invite you?';

  @override
  String get authReferralBody =>
      'Enter their code so they get a reward after your first delivery.';

  @override
  String get authReferralFootnote =>
      'This step is optional. You can use Yadony without a code.';

  @override
  String get authReferralCodeLabel => 'Referral code';

  @override
  String get authReferralCodeHint => 'E.g. JEAN0234';

  @override
  String get authReferralApply => 'Apply code';

  @override
  String get authReferralSuccessTitle => 'Code applied!';

  @override
  String get authReferralSuccessBody =>
      'Your friend gets a reward as soon as you complete your first delivery.';

  @override
  String get authReferralSuccessFootnote =>
      'Your Yadony account is ready. You can start searching for, sending and tracking parcels.';

  @override
  String get authReferralContinueHome => 'Continue to home';

  @override
  String get authConsentGaugeLabel => 'Privacy';

  @override
  String get authConsentTitle => 'One last thing';

  @override
  String get authConsentBody =>
      'To improve Yadony, we\'d like to measure how the app is used. It\'s anonymous and optional.';

  @override
  String get authConsentFootnote =>
      'Never your payments, identity or phone number. You can change your mind in Settings.';

  @override
  String get authConsentPointScreens => 'Screens visited and features used';

  @override
  String get authConsentPointGestures =>
      'Taps and swipes, to spot what gets in the way';

  @override
  String get authConsentPointNeverPersonal =>
      'Never your payments, identity or phone number';

  @override
  String get authConsentPointChangeAnytime =>
      'Can be changed anytime in Settings';

  @override
  String get authConsentAccept => 'Accept';

  @override
  String get authConsentDecline => 'No thanks';

  @override
  String get authLocalSwitchAccountTitle => 'Switch account?';

  @override
  String get authLocalSwitchAccountMessage =>
      'You\'ll be signed out of this account. You\'ll need to sign in again and set up a new PIN.';

  @override
  String get authLocalCancel => 'Cancel';

  @override
  String get authLocalContinue => 'Continue';

  @override
  String get authLocalOtherAccount => 'Other account';

  @override
  String get authLocalEnterPin => 'Enter your PIN';

  @override
  String get authLocalLastAttempt => 'Last attempt before lockout';

  @override
  String authLocalAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts left',
      one: '$count attempt left',
    );
    return '$_temp0';
  }

  @override
  String authLocalRetryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Try again in $seconds seconds',
      one: 'Try again in $seconds second',
    );
    return '$_temp0';
  }
}
