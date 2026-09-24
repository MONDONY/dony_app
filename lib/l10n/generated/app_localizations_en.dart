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
  String get errorAuthTokenUnavailableTitle => 'Authentication failed';

  @override
  String get errorAuthTokenUnavailableMessage =>
      'We couldn\'t verify your identity. Try again in a moment.';

  @override
  String get errorAuthGenericErrorTitle => 'Sign-in failed';

  @override
  String get errorAuthGenericErrorMessage =>
      'Something went wrong while signing in. Try again.';

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
      'You\'ve reached your listing limit for this month. Upgrade to Pro to post without limits.';

  @override
  String get errorDraftLimitReachedTitle => 'Draft limit reached';

  @override
  String get errorDraftLimitReachedMessage =>
      'Upgrade to Pro to create more drafts.';

  @override
  String get errorNotADraftTitle => 'Already posted';

  @override
  String get errorNotADraftMessage => 'This trip isn\'t a draft.';

  @override
  String get errorPublishingSuspendedTitle => 'Posting suspended';

  @override
  String get errorPublishingSuspendedMessage =>
      'Posting is suspended on your account. Contact support.';

  @override
  String get errorKycNotVerifiedTitle => 'Identity not verified';

  @override
  String get errorKycNotVerifiedMessage =>
      'Verify your identity before posting a trip.';

  @override
  String get errorDepartureDatePassedTitle => 'Departure date has passed';

  @override
  String get errorDepartureDatePassedMessage =>
      'Change the departure date before posting this trip.';

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
  String get networkFallbackInvalidRequest => 'Invalid request';

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
  String get authLegalPrefix => 'By continuing, you agree to our ';

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
  String get authRequiredFreeSearchTitle => 'Browse freely';

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
      'The recipient\'s confirmation ends the trip.';

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

  @override
  String get countryNameCd => 'DR Congo';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClearFilters => 'Clear filters';

  @override
  String get parcelSizeSmall => 'Small';

  @override
  String get parcelSizeMedium => 'Medium';

  @override
  String get parcelSizeLarge => 'Large';

  @override
  String get cityClearCity => 'Clear city';

  @override
  String get cityChooseCity => 'Choose a city';

  @override
  String get cityRecentSection => 'RECENT';

  @override
  String get cityDepartureLabel => 'Departure';

  @override
  String get cityArrivalLabel => 'Arrival';

  @override
  String get citySwapLabel => 'Swap departure and arrival';

  @override
  String get shellTabActivity => 'Activity';

  @override
  String get shellTabSearch => 'Search';

  @override
  String get shellTabMessages => 'Messages';

  @override
  String get shellTabProfile => 'Profile';

  @override
  String get shellOrbTracking => 'Tracking';

  @override
  String get shellOrbQrScanner => 'QR scanner';

  @override
  String get shellPlaceholderConfirmPayment => 'Confirm payment';

  @override
  String get shellPlaceholderAdmin => 'Admin';

  @override
  String get shellRequestsTitle => 'Requests';

  @override
  String get shellPrivacyPolicyTitle => 'Privacy Policy';

  @override
  String homeCorridorFrom(String dep) {
    return 'From $dep';
  }

  @override
  String homeCorridorTo(String arr) {
    return 'To $arr';
  }

  @override
  String get homeCorridorAll => 'All routes';

  @override
  String get homePullToList => 'Pull up to see the list';

  @override
  String homePullToTravelers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pull up to see the $count travelers',
      one: 'Pull up to see the traveler',
    );
    return '$_temp0';
  }

  @override
  String homePullToParcels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pull up to see the $count parcels',
      one: 'Pull up to see the parcel',
    );
    return '$_temp0';
  }

  @override
  String get homePullToMap => 'Pull down to see the map';

  @override
  String homeCrossParcels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcels are looking for a traveler',
      one: '$count parcel is looking for a traveler',
    );
    return '$_temp0';
  }

  @override
  String homeCrossParcelsRoute(int count, String dep, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcels are looking for a traveler on $dep → $arr',
      one: '$count parcel is looking for a traveler on $dep → $arr',
    );
    return '$_temp0';
  }

  @override
  String homeCrossParcelsFrom(int count, String dep) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcels are looking for a traveler from $dep',
      one: '$count parcel is looking for a traveler from $dep',
    );
    return '$_temp0';
  }

  @override
  String homeCrossParcelsTo(int count, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcels are looking for a traveler to $arr',
      one: '$count parcel is looking for a traveler to $arr',
    );
    return '$_temp0';
  }

  @override
  String homeCrossTravelers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers are traveling',
      one: '$count traveler is traveling',
    );
    return '$_temp0';
  }

  @override
  String homeCrossTravelersRoute(int count, String dep, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers are traveling on $dep → $arr',
      one: '$count traveler is traveling on $dep → $arr',
    );
    return '$_temp0';
  }

  @override
  String homeCrossTravelersFrom(int count, String dep) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers are traveling from $dep',
      one: '$count traveler is traveling from $dep',
    );
    return '$_temp0';
  }

  @override
  String homeCrossTravelersTo(int count, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers are traveling to $arr',
      one: '$count traveler is traveling to $arr',
    );
    return '$_temp0';
  }

  @override
  String homeAlertTrip(String dep, String arr) {
    return 'Alert me when a trip appears on $dep → $arr';
  }

  @override
  String homeAlertParcel(String dep, String arr) {
    return 'Alert me when a parcel appears on $dep → $arr';
  }

  @override
  String get homeLocateError => 'Couldn\'t find your location. Try again.';

  @override
  String get homeMaxWeightTitle => 'Max parcel weight';

  @override
  String get homeParcelSizeTitle => 'Parcel size';

  @override
  String homeListTravelersNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers nearby',
      one: '$count traveler nearby',
    );
    return '$_temp0';
  }

  @override
  String homeListTravelersRoute(int count, String dep, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers for $dep → $arr',
      one: '$count traveler for $dep → $arr',
    );
    return '$_temp0';
  }

  @override
  String homeListTravelersCorridor(int count, String corridor) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers · $corridor',
      one: '$count traveler · $corridor',
    );
    return '$_temp0';
  }

  @override
  String homeListParcelsMatching(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matching parcels',
      one: '$count matching parcel',
    );
    return '$_temp0';
  }

  @override
  String homeListParcelsRoute(int count, String dep, String arr) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcels to carry for $dep → $arr',
      one: '$count parcel to carry for $dep → $arr',
    );
    return '$_temp0';
  }

  @override
  String homeListParcelsCorridor(int count, String corridor) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcels to carry · $corridor',
      one: '$count parcel to carry · $corridor',
    );
    return '$_temp0';
  }

  @override
  String get homeListSubtitleNoTraveler => 'No one is offering this trip yet';

  @override
  String get homeListSubtitleTravelersCanCarry => 'They can carry your parcel';

  @override
  String get homeListSubtitleActiveTripsUnknown => 'With your active trips';

  @override
  String homeListSubtitleActiveTrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'With your $count active trips',
      one: 'With your active trip',
    );
    return '$_temp0';
  }

  @override
  String get homeListSubtitleNoRequest => 'No parcel requests yet';

  @override
  String get homeListSubtitleYouCanCarry => 'You can carry them on your trip';

  @override
  String get homeSort => 'Sort';

  @override
  String get homeConnectionErrorTitle => 'Can\'t connect';

  @override
  String get homeRequestsLoadError =>
      'Couldn\'t load parcel requests. Check your connection and try again.';

  @override
  String get homeEmptyParcelsFiltered => 'No parcels match these filters';

  @override
  String get homeEmptyParcelsSoon => 'Parcel requests coming soon';

  @override
  String get homeEmptyParcelsFilteredHint =>
      'Change or remove your filters to see more parcel requests.';

  @override
  String get homeEmptyParcelsSoonHint =>
      'Soon you\'ll be able to browse parcel requests posted by senders.';

  @override
  String get homeTripsLoadError =>
      'Couldn\'t load trips. Check your connection and try again.';

  @override
  String get homeEmptyTravelersNearby => 'No travelers nearby';

  @override
  String get homeEmptyTravelersFiltered => 'No travelers match these filters';

  @override
  String get homeEmptyTravelersRoute => 'No travelers on this route';

  @override
  String get homeEmptyNearbyHint => 'Widen your area or turn off “Near me”';

  @override
  String get homeEmptyTravelersFilteredHint =>
      'Change your filters to see more travelers.';

  @override
  String get homeEmptyTravelersRouteHint =>
      'New trips are posted every day. Check back soon.';

  @override
  String get homeMapButton => 'Map';

  @override
  String homeRadiusKm(int km) {
    return 'Radius · $km km';
  }

  @override
  String get homeDepartureDateTitle => 'Departure date';

  @override
  String get commonDateToday => 'Today';

  @override
  String get commonDateThisWeek => 'This week';

  @override
  String get commonDateThisMonthLong => 'This month';

  @override
  String get homeChooseDate => 'Choose a date';

  @override
  String get homeMinRatingTitle => 'Minimum rating';

  @override
  String get homeRatingOnlyFive => '★ 5.0 only';

  @override
  String homeRatingAndUp(String rating) {
    return '★ $rating and up';
  }

  @override
  String get homeWeightCapacityTitle => 'Weight capacity';

  @override
  String get homeMaxPriceTitle => 'Maximum price';

  @override
  String get homeAnyPrice => 'Any price';

  @override
  String get homeComposerTitleTrips => 'Filter trips';

  @override
  String get homeComposerTitleParcels => 'Filter parcels';

  @override
  String get homeComposerClearAll => 'Clear all';

  @override
  String get homeComposerSectionPhrase => 'IN ONE SENTENCE';

  @override
  String get homeComposerSectionWhere => 'WHERE';

  @override
  String get homeComposerSectionWhen => 'WHEN';

  @override
  String get homeComposerSectionAroundMe => 'AROUND ME';

  @override
  String get homeComposerSearch => 'Search';

  @override
  String homeComposerSearchWithCount(int count) {
    return 'Search ($count)';
  }

  @override
  String get homeComposerSectionWeightPrice => 'WEIGHT AND PRICE';

  @override
  String get homeComposerSectionContents => 'MY PARCEL CONTAINS';

  @override
  String get homeComposerContentHint => 'Search for a content type…';

  @override
  String get homeComposerSectionQuickFilters => 'QUICK FILTERS';

  @override
  String get homeComposerMinRating => 'Rating ≥ 4.5';

  @override
  String get homeComposerWeekend => 'Weekend';

  @override
  String get homeComposerVerifiedIdentity => 'Verified identity';

  @override
  String get homeComposerSectionUrgency => 'DEPARTURE URGENCY';

  @override
  String get homeComposerUrgencyHint => 'Filter trips by how soon they leave';

  @override
  String get homeComposerSectionMaxWeight => 'MAXIMUM WEIGHT';

  @override
  String get homeComposerSectionParcelSize => 'PARCEL SIZE';

  @override
  String get homeComposerForMyTrips => 'For my trips';

  @override
  String get homeComposerAlertTip =>
      'Tip: you can get alerts for new matching parcels in Settings, Notifications.';

  @override
  String get homeComposerAroundMe => 'Around me';

  @override
  String get homeComposerLocating => 'Finding your location…';

  @override
  String get homeRecapTitle => 'SET FROM YOUR SENTENCE';

  @override
  String get homeRecapArrival => 'Arrival';

  @override
  String get homeRecapDeparture => 'Departure';

  @override
  String get homeRecapWhen => 'When';

  @override
  String get homeRecapMinWeight => 'Minimum weight';

  @override
  String homeRecapFieldLine(String label, String value) {
    return '$label: $value';
  }

  @override
  String homeUnresolvedPriceQuestion(String phrase) {
    return '“$phrase”: how much?';
  }

  @override
  String get homeUnresolvedCityUnknown => 'To which city?';

  @override
  String get homeUnresolvedCityAmbiguous => 'Which city exactly?';

  @override
  String get homeUnresolvedDateQuestion => 'When do you want to leave?';

  @override
  String homeUnresolvedUpTo(String price) {
    return 'Up to $price/kg';
  }

  @override
  String get homeUnresolvedAnyPrice => 'Any price';

  @override
  String get commonDateThisMonth => 'This month';

  @override
  String get homeUnresolvedAnyTime => 'Any time';

  @override
  String get homePhraseHint => '20 kg to Bamako in March';

  @override
  String get homeSectionOptional => 'Optional';

  @override
  String get homeModeSelectorSending => 'I\'m sending a parcel';

  @override
  String get homeModeSelectorTraveling => 'I\'m traveling';

  @override
  String homeModeSelectorTravelersAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers available',
      one: '$count traveler available',
    );
    return '$_temp0';
  }

  @override
  String get homeModeSelectorTravelersSubtitle => 'Travelers available';

  @override
  String homeModeSelectorParcelsToCarry(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcels to carry',
      one: '$count parcel to carry',
    );
    return '$_temp0';
  }

  @override
  String get homeModeSelectorParcelsSubtitle => 'Parcels to carry';

  @override
  String get homeFilterChipsDate => 'Date';

  @override
  String get homeFilterChipsAnyDate => 'Any date';

  @override
  String get homeFilterChipsRating => 'Rating';

  @override
  String get homeFilterChipsWeight => 'Weight';

  @override
  String get homeFilterChipsPrice => 'Price';

  @override
  String get homeFilterChipsSize => 'Size';

  @override
  String get homeFilterChipsUrgent => '🔥 Urgent';

  @override
  String get homeFilterFieldsExactDate => 'EXACT DATE';

  @override
  String get homeFilterFieldsMaxPrice => 'MAX PRICE';

  @override
  String get homeFilterFieldsAll => 'Any';

  @override
  String get homeFilterFieldsChoose => 'Choose';

  @override
  String get homeFilterFieldsMinWeight => 'MIN WEIGHT';

  @override
  String get homeFilterFieldsMinWeightTitle => 'Minimum trip weight';

  @override
  String get homeFilterFieldsTransportMode => 'Transport mode';

  @override
  String get homeMapOpenPrice => 'Open price';

  @override
  String get homeMapRequests => 'Parcel requests';

  @override
  String get homeMapNoRequestsNearby => 'No parcel requests within this radius';

  @override
  String get homeMapNoRequestsYet => 'No parcel requests yet';

  @override
  String get homeMapEmptyNearbyHint => 'Widen your area or turn off “Near me”';

  @override
  String get homeMapEmptyHint =>
      'Check back soon, new parcel requests are posted every day';

  @override
  String get homeGuidancePublishTrip => 'Post my trip';

  @override
  String get homeGuidancePublishParcel => 'Post a parcel';

  @override
  String get homeGuidanceCreateAlert => 'Create an alert';

  @override
  String get homeGuidanceVerifyIdentity => 'Verify my identity';

  @override
  String get homeGuidanceHowItWorks => 'How does it work?';

  @override
  String get homeGuidanceDontShowAgain => 'Don\'t show again';

  @override
  String get homeNoActiveTripTitle => 'No active trip';

  @override
  String get homeNoActiveTripBody =>
      'This filter only shows parcels that fit your upcoming trips. Post a trip to use it.';

  @override
  String get homeNoActiveTripPublish => 'Post a trip';

  @override
  String get homeFilterFieldsTransport => 'TRANSPORT';

  @override
  String get homeFilterFieldsDate => 'DATE';

  @override
  String get homeNearMeTitle => 'Near me';

  @override
  String get homeNearMeConfirm => 'Turn on the filter';

  @override
  String get homeNearMeExplanation =>
      'We only keep listings whose drop-off point is within this radius of you.';

  @override
  String get homeLocationPermissionOpenSettings => 'Open settings';

  @override
  String get homeLocationPermissionServiceOffTitle => 'Location is off';

  @override
  String get homeLocationPermissionDeniedTitle => 'Location access denied';

  @override
  String get homeLocationPermissionServiceOffBody =>
      'Turn on your phone\'s location to see what\'s near you.';

  @override
  String get homeLocationPermissionDeniedBody =>
      'Allow location access in your settings to use “Near me” and see where you are on the map.';

  @override
  String get shellTermsTitle => 'Terms of Use';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSend => 'Send';

  @override
  String get commonShare => 'Share';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonSeeAll => 'See all';

  @override
  String commonDateAtTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String commonListPair(String first, String second) {
    return '$first and $second';
  }

  @override
  String commonListLast(String head, String last) {
    return '$head, and $last';
  }

  @override
  String get tripKgFree => 'Flexible kg';

  @override
  String get tripFixedPrice => 'Fixed price';

  @override
  String get tripTravelerFallbackName => 'Traveler';

  @override
  String get tripTransportPlane => 'Plane';

  @override
  String get tripTransportCar => 'Car';

  @override
  String get tripTransportTrain => 'Train';

  @override
  String get tripTransportBus => 'Bus';

  @override
  String get tripTransportBoat => 'Boat';

  @override
  String get tripTransportOther => 'Other';

  @override
  String get tripUrgencyVeryUrgent => '< 3d';

  @override
  String get tripUrgencyUrgent => '3–7d';

  @override
  String get tripUrgencySoon => '7–14d';

  @override
  String get tripUrgencyLater => '14d+';

  @override
  String get tripCapacitySuitcase23 => '1 suitcase (23 kg)';

  @override
  String get tripCapacitySuitcase32 => '1 suitcase (32 kg)';

  @override
  String get tripCapacityCustom => 'Custom';

  @override
  String get tripPublishTitle => 'Post a trip';

  @override
  String get tripPublishEditTitle => 'Edit trip';

  @override
  String get tripPublishDedicatedTitle => 'Create the trip for this request';

  @override
  String get tripPublishSubmitDedicated => 'Confirm the trip';

  @override
  String get tripPublishPreviewButton => 'Preview';

  @override
  String get tripPublishFieldDepartureCityRequired => 'Departure city required';

  @override
  String get tripPublishFieldArrivalCityRequired => 'Arrival city required';

  @override
  String get tripPublishFieldDepartureDateRequired => 'Departure date required';

  @override
  String get tripPublishFieldDepartureTimeRequired => 'Departure time required';

  @override
  String get tripPublishFieldTransportModeRequired => 'Transport mode required';

  @override
  String get tripPublishFieldHandoverDeadlineRequired =>
      'Drop-off deadline required';

  @override
  String get tripPublishFieldPickupAddressRequired =>
      'Parcel drop-off location required';

  @override
  String get tripPublishFieldDeliveryAddressRequired =>
      'Pickup location required';

  @override
  String get tripPublishHandoverDeadlineInvalid =>
      'The deadline must be before departure.';

  @override
  String get tripPublishHandoverDeadlineBeforeDeparture =>
      'The drop-off deadline must be before departure';

  @override
  String get tripPublishOfferSentWithTrip => 'Offer sent with the linked trip.';

  @override
  String get tripPublishTripLinked => 'Trip linked. The sender can now pay.';

  @override
  String get tripPublishSuccessTitleEdit => 'Trip updated!';

  @override
  String get tripPublishSuccessTitleCreate => 'Trip posted!';

  @override
  String tripPublishSuccessSubtitle(String departureCity, String arrivalCity) {
    return 'Your trip $departureCity → $arrivalCity is live.';
  }

  @override
  String get tripPublishSuccessCta => 'View my trip';

  @override
  String get tripPublishSuccessShareCta => 'Share my poster';

  @override
  String get tripPublishMonthlyLimitTitle => 'Monthly limit reached';

  @override
  String get tripPublishDraftLimitTitle => 'Draft limit reached';

  @override
  String get tripPublishTemplatesLabel => 'My templates';

  @override
  String get tripPublishTemplatesHint =>
      'Apply a template to pre-fill the trip';

  @override
  String tripPublishTemplateAppliedMessage(String label) {
    return 'Template “$label” applied';
  }

  @override
  String tripPublishTemplateChipGrid(String label) {
    return '$label · price grid';
  }

  @override
  String get tripPublishDropoffSectionLabel => 'PARCEL DROP-OFF';

  @override
  String get tripPublishHandoverDeadlineLabel => 'Drop-off deadline';

  @override
  String get tripPublishHandoverDeadlineSubtitle =>
      'Latest date senders can hand you their parcels';

  @override
  String get tripPublishHandoverDeadlineChoose => 'Choose';

  @override
  String get tripPublishLockedBannerTitle => 'Trip dedicated to the request';

  @override
  String get tripPublishLockedBannerSubtitle =>
      'Corridor, capacity and price are locked. The date must stay within the sender\'s tolerance window.';

  @override
  String get requestPublishIntroTitle => 'Post a parcel';

  @override
  String get tripPublishIntroVerifiedTextTrip =>
      'Identity verified. You can post your trip safely.';

  @override
  String get requestPublishIntroVerifiedText =>
      'Identity verified. You can post your shipping request safely.';

  @override
  String get tripPublishIntroEngagementsTitleTrip =>
      'Your commitments as a traveler';

  @override
  String get tripPublishIntroEngagementsIntroTrip =>
      'By posting, you commit to:';

  @override
  String get tripPublishIntroRuleTripCarry =>
      'Carrying the parcel **yourself**, never handing it off to a third party.';

  @override
  String get tripPublishIntroRuleTripSchedule =>
      'Sticking to the announced **date** and **route**.';

  @override
  String get tripPublishIntroRuleTripScan =>
      '**Scanning the QR code** at drop-off and delivery.';

  @override
  String get tripPublishIntroRuleTripContent =>
      'Only accepting **allowed contents**, never an illegal item.';

  @override
  String get tripPublishIntroRuleTripHandover =>
      'Handing the parcel to **the right recipient**, in person.';

  @override
  String get tripPublishIntroWhyTitleTrip => 'Why post a trip';

  @override
  String get tripPublishIntroWhyBulletTripVisibility =>
      'Seen by thousands of senders in the diaspora.';

  @override
  String get tripPublishIntroWhyBulletTripEarnings =>
      'Turn your spare kilos into earnings on every trip.';

  @override
  String get tripPublishIntroWhyBulletTripReputation =>
      'Build a reputation through the reviews you receive.';

  @override
  String get requestPublishIntroEngagementsTitle =>
      'Your commitments as a sender';

  @override
  String get requestPublishIntroEngagementsIntro =>
      'By sending a parcel, you certify:';

  @override
  String get requestPublishIntroRuleLicit =>
      'Only sending **lawful** and allowed contents.';

  @override
  String get requestPublishIntroRuleForbidden =>
      'No **forbidden item** (cash, weapons, dangerous goods…).';

  @override
  String get requestPublishIntroRuleHonest =>
      'Describing the contents **honestly**, and their value if the traveler asks.';

  @override
  String get requestPublishIntroRulePackaging =>
      '**Packing it carefully** and describing the contents precisely.';

  @override
  String get requestPublishIntroRuleHandover =>
      'Being present at the **drop-off** and stating the right recipient.';

  @override
  String get requestPublishIntroWhyTitle => 'How it works';

  @override
  String get requestPublishIntroWhyBulletCarried =>
      'A traveler carries your parcel in their luggage.';

  @override
  String get requestPublishIntroWhyBulletPayment =>
      'Secure payment, released once delivery is confirmed.';

  @override
  String get requestPublishIntroWhyBulletTracking =>
      'QR tracking from drop-off to receipt.';

  @override
  String tripPublishIntroVerifyCallout(String identity, String path) {
    return 'Before you post, your **$identity**. Go to $path to verify it (2 min).';
  }

  @override
  String get tripPublishIntroVerifyIdentity => 'identity must be verified';

  @override
  String get tripPublishIntroVerifyPath => 'Profile › Verifications';

  @override
  String get tripPublishIntroVerifyButton => 'Verify my identity';

  @override
  String tripPublishIntroVerifyHint(String continueLabel) {
    return 'The button becomes “$continueLabel” once your identity is verified.';
  }

  @override
  String get tripPublishIntroStripeTitle => 'Activate card payments';

  @override
  String get tripPublishIntroStripeSubtitle =>
      'Set up your Stripe account so your senders can pay by card, and get more parcels.';

  @override
  String get tripPublishPricingModeKg => 'By the kilo';

  @override
  String get tripPublishPricingModeMixed => 'Price grid + kilo';

  @override
  String get tripPublishPricePerKgSectionLabel => 'Price per kg';

  @override
  String get tripPublishKgPriceToggleTitle => 'Price per kilo';

  @override
  String get tripPublishKgPriceToggleSubtitle => 'Optional in grid mode';

  @override
  String get tripPublishCustomPriceChipLabel => 'Other price';

  @override
  String get tripPublishCustomPriceFieldHint => 'e.g. 12';

  @override
  String get tripPublishPriceSelectPrompt =>
      'Select a price to see the estimate';

  @override
  String get tripPublishUnlimitedCapacityEstimateNote =>
      'Unlimited capacity: estimate based on demand';

  @override
  String tripPublishPriceEstimateLine(String travelerNet, String senderTotal) {
    return 'You get $travelerNet · the sender pays $senderTotal';
  }

  @override
  String tripPublishGridCommissionNotice(String percent) {
    return 'Yadony adds $percent% to every item and to the price per kilo';
  }

  @override
  String get tripPublishNegotiableToggleTitle => 'I accept price proposals';

  @override
  String get tripPublishNegotiableToggleSubtitle =>
      'Senders will be able to propose an amount, and you\'re always free to decline';

  @override
  String get tripPublishPaymentMethodsSectionLabel =>
      'Accepted payment methods';

  @override
  String get tripPublishCardPaymentTitle => 'Card payment (Stripe)';

  @override
  String get tripPublishCardPaymentSubtitle => 'Secure payment by default';

  @override
  String get tripPublishCashLabel => 'Cash';

  @override
  String get tripPublishCashSubtitle =>
      'Service fee charged to the traveler at drop-off';

  @override
  String get tripPublishAcceptedContentSectionLabel => 'What I accept';

  @override
  String get tripPublishRefusedContentSectionLabel => 'What I refuse';

  @override
  String get tripPublishRefusedContentHint => 'E.g. Liquids, Perishable goods…';

  @override
  String get tripPublishNoteToSendersSectionLabel => 'Note to senders';

  @override
  String get tripPublishNoteToSendersHint =>
      'E.g. I prefer well-packed parcels. Contact me before departure.';

  @override
  String get tripPublishCashOnlyBannerWithConnect =>
      'Post in cash right now. Connect Stripe to also accept card payments.';

  @override
  String get tripPublishCashOnlyBannerNoConnect =>
      'Card payment isn\'t available in your country yet. Your trips are posted in cash.';

  @override
  String get tripPublishActivateCardPaymentsCta => 'Activate card payments';

  @override
  String get tripPublishCardNotConfiguredSubtitle =>
      'Not set up, turn it on to offer secure payment';

  @override
  String get tripPublishActivatePayoutCta => 'Turn on payout';

  @override
  String get tripPublishMobileMoneyIneligibleSubtitle =>
      'Available for trips in XOF or XAF';

  @override
  String get tripPublishMobileMoneyInactiveSubtitle =>
      'First turn on your mobile money payout';

  @override
  String get tripPublishLockedPriceNoteTitle => 'Price set by the negotiation';

  @override
  String get tripPublishLockedPriceNoteSubtitle =>
      'This parcel\'s amount was agreed with the sender and can\'t be changed here.';

  @override
  String get tripPublishAgreedPriceLabel => 'Total price agreed';

  @override
  String get tripPublishGridPreviewLabel => 'Your grid';

  @override
  String tripPublishGridPreviewSeeAll(int count) {
    return 'See all $count items';
  }

  @override
  String get tripPublishGridPreviewNote =>
      'These prices come from your profile. Editing them changes them on all your trips.';

  @override
  String get tripPublishGridSheetTitle => 'Your price grid';

  @override
  String get tripPublishGridSheetSubtitle => 'Valid on all your trips';

  @override
  String get tripPublishGridSheetEditCta => 'Edit my grid';

  @override
  String tripPublishGridSheetCommissionNote(String percent) {
    return 'Prices paid by the sender, Yadony service fee of $percent% included.';
  }

  @override
  String get tripPublishGridEmptyTitle => 'Your grid is empty';

  @override
  String get tripPublishGridEmptySubtitle =>
      'Add at least one item so senders can book item by item.';

  @override
  String get tripPublishGridComposeCta => 'Build my grid';

  @override
  String get tripPublishCorridorConfirmedBadge => 'Confirmed';

  @override
  String get tripPublishRouteSectionLabel => 'Trip';

  @override
  String get tripPublishDepartureCityLabel => 'Departure city';

  @override
  String get tripPublishArrivalCityLabel => 'Arrival city';

  @override
  String get tripPublishDepartureTimeLabel => 'Departure time';

  @override
  String get tripPublishArrivalTimeOptionalLabel => 'Arrival time (optional)';

  @override
  String get tripPublishClearArrivalTimeTooltip => 'Clear arrival time';

  @override
  String get tripPublishDepartureDateLabel => 'Departure date';

  @override
  String get tripPublishUrgentDepartureWarning =>
      '🔥 Departure soon · this trip will be flagged urgent';

  @override
  String get tripPublishCapacityAvailableLabel => 'Available capacity';

  @override
  String tripPublishSuitcaseCount(int count, int kg) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suitcases of $kg kg',
      one: '$count suitcase of $kg kg',
    );
    return '$_temp0';
  }

  @override
  String tripPublishYouOfferKg(int kg) {
    return 'You offer $kg kg';
  }

  @override
  String get tripPublishDecreaseQuantityTooltip => 'Decrease quantity';

  @override
  String get tripPublishIncreaseQuantityTooltip => 'Increase quantity';

  @override
  String get tripPublishUnlimitedCapacityTitle => 'Unlimited capacity';

  @override
  String get tripPublishUnlimitedCapacitySubtitle =>
      'Sold by the kilo · the sender chooses the weight';

  @override
  String get tripPublishCapacityKgFieldLabel => 'Capacity (kg)';

  @override
  String get tripPublishCapacityKgFieldHint =>
      'Enter the total capacity you\'re offering';

  @override
  String tripPublishCurrencySemanticsLabel(
    String currencyName,
    String currencyCode,
  ) {
    return 'Publishing currency: $currencyName, $currencyCode. Users in another currency see a converted price. Payment stays in this currency. Button, change currency.';
  }

  @override
  String tripPublishCurrencyBannerTitle(
    String currencyName,
    String currencyCode,
  ) {
    return 'Posted in $currencyName ($currencyCode)';
  }

  @override
  String get tripPublishCurrencyBannerSubtitle =>
      'Users in another currency see a converted price. Payment stays in this currency.';

  @override
  String get tripPublishCurrencyChangeCta => 'Change';

  @override
  String get tripPublishPlacesCapacityStepLabel => 'Locations & capacity';

  @override
  String get tripPublishPriceConditionsStepLabel => 'Price & conditions';

  @override
  String get tripPublishHandoverLocationsLabel => 'Drop-off locations';

  @override
  String get tripPublishHandoverLocationsSubtitle =>
      'Specify the exact drop-off and pickup location';

  @override
  String get tripPublishLockedCapacityNote => 'Capacity set by the request';

  @override
  String addressGpsPosition(String lat, String lng) {
    return 'GPS location ($lat, $lng)';
  }

  @override
  String get addressGpsDisabledTitle => 'GPS disabled';

  @override
  String get addressLocationDeniedTitle => 'Location access denied';

  @override
  String get addressLocationDeniedForeverTitle =>
      'Location access permanently denied';

  @override
  String get addressGpsDisabledMessage =>
      'Turn on location services in your system settings.';

  @override
  String get addressLocationDeniedMessage =>
      'Turn on location access in your settings to use this feature.';

  @override
  String get addressOpenSettingsButton => 'Open settings';

  @override
  String get addressPositionUnavailableTitle => 'Position unavailable';

  @override
  String get addressPositionUnavailableMessage =>
      'Couldn\'t get your position right now. Try again.';

  @override
  String get addressReverseGeocodeFailedTitle => 'Address not found';

  @override
  String get addressReverseGeocodeFailedMessage =>
      'Couldn\'t convert your position into an address. Try again.';

  @override
  String get addressSelectFailedMessage =>
      'Couldn\'t select this address. Try again.';

  @override
  String get addressSearchHint => 'Search for an address…';

  @override
  String get addressConfirmButton => 'Confirm this address';

  @override
  String get addressOfflineTitle => 'Connection required';

  @override
  String get addressOfflineSubtitle =>
      'Check your connection to search for an address.';

  @override
  String get addressSearchErrorTitle => 'Error';

  @override
  String get addressSearchErrorSubtitle =>
      'Couldn\'t search for an address. Try again.';

  @override
  String get addressNoResultsTitle => 'No results';

  @override
  String get addressNoResultsSubtitle => 'Try “Use my current location”.';

  @override
  String get addressUseCurrentLocation => 'Use my current location';

  @override
  String get addressRecentSearchesHeader => 'RECENT SEARCHES';

  @override
  String get addressSavedAddressesHeader => 'MY SAVED ADDRESSES';

  @override
  String get addressAddNewTitle => 'Add an address';

  @override
  String get addressAddNewSubtitle => 'Save it for next time';

  @override
  String get addressDefaultBadge => 'Default';

  @override
  String get addressPickupSheetTitle => '📦  Drop-off address';

  @override
  String get addressDeliverySheetTitle => '🗺️  Delivery address';

  @override
  String get addressFieldRequiredError => 'Address required';

  @override
  String get addressFieldSearchHint => 'Type to search for an address…';

  @override
  String get addressFieldNoResultsHint =>
      'No results, try \"My current location\"';

  @override
  String get addressOfflineInlineMessage =>
      'Connection required to search for an address';

  @override
  String get addressSelectorDropoffLabel => 'Choose a drop-off address';

  @override
  String get addressSelectorDropoffSubtitle =>
      'Where you collect parcels from senders';

  @override
  String get addressSelectorDeliveryLabel => 'Choose a delivery address';

  @override
  String get addressSelectorDeliverySubtitle =>
      'Where you drop off parcels at destination';

  @override
  String get tripPosterTimePattern => 'h:mm a';

  @override
  String get tripPosterDepartureLabel => 'Departure';

  @override
  String get tripPosterDeadlineLabel => 'Last drop-off';

  @override
  String get tripPosterCapacityLabel => 'Available space';

  @override
  String get tripPosterHandoverLabel => 'Drop-off';

  @override
  String get tripPosterPickupLabel => 'Pickup';

  @override
  String tripPosterFromPrice(String price) {
    return 'from $price';
  }

  @override
  String get tripPosterUnitPerItem => 'per item';

  @override
  String get tripPosterUnitPerKg => 'per kg';

  @override
  String get tripPosterPriceUnavailable => 'Price unavailable';

  @override
  String tripPosterPricePerKg(String price) {
    return '$price per kg';
  }

  @override
  String tripPosterPriceFromItem(String price) {
    return 'from $price per item';
  }

  @override
  String get tripPosterTagline =>
      'Secure payment, parcel tracking, verified travelers';

  @override
  String get tripPosterTitle => 'My poster';

  @override
  String get tripPosterNotFoundTitle => 'Trip not found';

  @override
  String get tripPosterNotFoundDescription =>
      'Couldn\'t load this trip right now.';

  @override
  String tripPosterCaptionCorridor(String departure, String arrival) {
    return '$departure to $arrival';
  }

  @override
  String tripPosterCaptionDeparture(String day) {
    return 'Departure on $day';
  }

  @override
  String tripPosterCaptionDeadline(String deadline) {
    return 'Last drop-off on $deadline';
  }

  @override
  String tripPosterCaptionHandover(String address) {
    return 'Drop-off: $address';
  }

  @override
  String tripPosterCaptionPickup(String address) {
    return 'Pickup: $address';
  }

  @override
  String get tripPosterCaptionCta => 'Book your kilos here:';

  @override
  String get tripPosterCaptionFooter =>
      'Secure payment, parcel tracking, verified traveler.';

  @override
  String tripPosterShareSubject(String departure, String arrival) {
    return 'Trip $departure to $arrival';
  }

  @override
  String get tripPosterShareError => 'Couldn\'t share the poster';

  @override
  String get tripPosterSaveError => 'Couldn\'t save the poster';

  @override
  String get tripPosterSaveSuccess => 'Poster saved to your gallery';

  @override
  String get tripPosterCaptionCopied => 'Caption copied';

  @override
  String get tripPosterLinkCopiedMessage => 'Link copied';

  @override
  String get tripPosterInstructions =>
      'Post this poster as usual, then paste the caption into your post\'s text. The link becomes clickable there, unlike an address written on the image.';

  @override
  String get tripPosterShareButton => 'Share the poster';

  @override
  String get tripPosterCopyCaptionButton => 'Copy the caption';

  @override
  String get tripPosterCopyLinkButton => 'Copy the link';

  @override
  String get tripPosterSaveButton => 'Save to gallery';

  @override
  String get errorAnnouncementUpdateBlockedTitle => 'Can\'t edit this trip';

  @override
  String get errorAnnouncementUpdateBlockedMessage =>
      'Parcels have already been accepted for this trip';

  @override
  String get tripTemplateListTitle => 'My trip templates';

  @override
  String get tripTemplateNewLabel => 'New template';

  @override
  String get tripTemplateLoadErrorTitle => 'Loading error';

  @override
  String get tripTemplateLoadErrorFallback => 'Something went wrong.';

  @override
  String get tripTemplateEmptyTitle => 'No templates';

  @override
  String get tripTemplateEmptyDescription =>
      'Create reusable trip templates to post your listings in seconds.';

  @override
  String get tripTemplateCreateAction => 'Create a template';

  @override
  String get tripTemplateGridPriceLabel => 'grid pricing';

  @override
  String get tripTemplateDeleteDialogTitle => 'Delete template';

  @override
  String tripTemplateDeleteDialogMessage(String label) {
    return 'Are you sure you want to delete \"$label\"? This action can\'t be undone.';
  }

  @override
  String get tripTemplateScheduleRecurrenceAction =>
      'Schedule the recurring trip';

  @override
  String get tripTemplateNameSectionLabel => 'TEMPLATE NAME';

  @override
  String get tripTemplateNameFieldLabel => 'Name';

  @override
  String get tripTemplateNameFieldHint => 'E.g. My Paris → Dakar';

  @override
  String get tripTemplateTripSectionLabel => 'TRIP';

  @override
  String get tripTemplateTransportSectionLabel => 'TRANSPORT MODE';

  @override
  String get tripTemplateScheduleSectionLabel => 'SCHEDULE';

  @override
  String get tripTemplateDepartureTimeFieldLabel => 'Departure time';

  @override
  String get tripTemplateDepartureShortLabel => 'Departure';

  @override
  String get tripTemplateArrivalTimeFieldLabel => 'Arrival time';

  @override
  String get tripTemplateArrivalShortLabel => 'Arrival';

  @override
  String get tripTemplateHandoverDeadlineSectionLabel => 'DROP-OFF DEADLINE';

  @override
  String get tripTemplateHandoverDeadlineHint =>
      'At the latest, how many days before departure should the parcel be dropped off?';

  @override
  String get tripTemplateHandoverNone => 'None';

  @override
  String get tripTemplateHandoverSameDay => 'Same day';

  @override
  String tripTemplateHandoverDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days before',
      one: '$count day before',
    );
    return '$_temp0';
  }

  @override
  String tripTemplateOptionalSuffix(String label) {
    return '$label (optional)';
  }

  @override
  String tripTemplateClearFieldSemantic(String label) {
    return 'Clear $label';
  }

  @override
  String get tripTemplateEditTitle => 'Edit template';

  @override
  String get tripTemplateSaveButton => 'Save template';

  @override
  String get tripTemplateUpdatedMessage => 'Template updated';

  @override
  String get tripTemplateSavedMessage => 'Template saved';

  @override
  String get tripTemplateRecurrenceActivatedMessage =>
      'Recurring trip activated. Your trips will be posted automatically.';

  @override
  String get tripTemplateRecurrenceTitle => 'Recurring trip';

  @override
  String get tripTemplateActivateRecurrenceButton => 'Make it a recurring trip';

  @override
  String get tripTemplateNoPricePerKgWarning =>
      'This template has no price per kg';

  @override
  String get tripTemplateRepeatDaysSectionLabel => 'REPEAT DAYS';

  @override
  String get tripTemplateRecurrenceDepartureTimeSectionLabel =>
      'DEPARTURE TIME';

  @override
  String get tripTemplateOptionalTimeHint => 'Optional: pick a time';

  @override
  String get tripTemplateClearTimeSemantic => 'Clear the departure time';

  @override
  String get tripTemplateLocationsSectionLabel => 'LOCATIONS';

  @override
  String get tripTemplatePickupFieldLabel => 'Parcel drop-off location *';

  @override
  String get tripTemplateDeliveryFieldLabel => 'Pickup location *';

  @override
  String get tripTemplateActiveLabel => 'Recurring trip on';

  @override
  String get tripTemplateActiveDescription =>
      'Automatically posts upcoming trips';

  @override
  String get contentCategoryDocuments => 'Documents & paperwork';

  @override
  String get contentCategoryDryFood => 'Dry food';

  @override
  String get contentCategoryFreshFood => 'Fresh / perishable food';

  @override
  String get contentCategoryCosmetics => 'Cosmetics & perfume';

  @override
  String get contentCategoryClothing => 'Clothing & fabrics';

  @override
  String get contentCategoryShoes => 'Shoes';

  @override
  String get contentCategoryTraditionalMedicine => 'Traditional medicine';

  @override
  String get contentCategoryElectronics => 'Phones & electronics';

  @override
  String get contentCategoryBooks => 'Books';

  @override
  String get contentCategoryGifts => 'Gifts & toys';

  @override
  String get contentCategoryOther => 'Other';

  @override
  String contentCategoryAdd(String label) {
    return 'Add \"$label\"';
  }

  @override
  String get contentCategoryRemove => 'Remove this category';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodMobileMoney => 'Mobile money';

  @override
  String requestThreadYouReceive(String amount) {
    return 'You receive $amount';
  }

  @override
  String requestThreadYouPay(String amount) {
    return 'You pay $amount';
  }

  @override
  String requestWeightRange(String min, String max) {
    return 'Between $min and $max kg';
  }

  @override
  String get requestSenderFallbackName => 'Yadony user';

  @override
  String get requestBudgetRequired => 'Enter a budget to continue';

  @override
  String requestTimeJustNow(String verb) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'created just now',
      'other': 'posted just now',
    });
    return '$_temp0';
  }

  @override
  String requestTimeMinutesAgo(String verb, int minutes) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'created $minutes min ago',
      'other': 'posted $minutes min ago',
    });
    return '$_temp0';
  }

  @override
  String requestTimeHoursAgo(String verb, int hours) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'created $hours h ago',
      'other': 'posted $hours h ago',
    });
    return '$_temp0';
  }

  @override
  String requestTimeYesterday(String verb, String time) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'created yesterday, $time',
      'other': 'posted yesterday, $time',
    });
    return '$_temp0';
  }

  @override
  String requestTimeOn(String verb, String date) {
    String _temp0 = intl.Intl.selectLogic(verb, {
      'created': 'created on $date',
      'other': 'posted on $date',
    });
    return '$_temp0';
  }

  @override
  String get contentCategoryHintDefault => 'Add a content type…';

  @override
  String get requestCreateEditWarningTitle => 'Edit your request?';

  @override
  String get requestCreateEditWarningMessage =>
      'Travelers are currently negotiating this request. Editing it will cancel all pending offers. They will need to propose a new trip.';

  @override
  String get requestCreateEditWarningConfirm => 'Edit anyway';

  @override
  String get requestCreateStepTitleEdit => 'Edit the request';

  @override
  String get requestCreateStepTitleTrip => 'The trip';

  @override
  String get requestCreateStepTitlePackage => 'The parcel';

  @override
  String get requestCreateStepTitleBudget => 'The budget';

  @override
  String get requestCreateDraftSavedTitle => 'Draft saved!';

  @override
  String get requestCreateEditedTitle => 'Request updated!';

  @override
  String get requestCreatePublishedTitle => 'Request posted!';

  @override
  String get requestCreateDraftSavedSubtitle =>
      'You can post it whenever you\'re ready.';

  @override
  String get requestCreateEditedSubtitle => 'Your changes are live.';

  @override
  String get requestCreatePublishedSubtitle =>
      'Travelers are notified. You\'ll receive offers soon.';

  @override
  String get requestCreateViewDraftCta => 'View my draft';

  @override
  String get requestCreateViewRequestCta => 'View my request';

  @override
  String get requestCreateGenericError => 'Couldn\'t create the request';

  @override
  String get requestCreateDraftLimitTitle => 'Draft limit reached';

  @override
  String get requestCreateCguPrefix => 'By posting, you accept the ';

  @override
  String get requestCreateCguLink => 'Terms of Use';

  @override
  String get requestCreatePublishingLabel => 'Posting…';

  @override
  String get requestCreatePreviewButton => 'Preview';

  @override
  String get requestCreateDepartureRequired => 'Departure city required';

  @override
  String get requestCreateArrivalRequired => 'Arrival city required';

  @override
  String get requestCreateArrivalSameAsDeparture =>
      'Choose a different city from the departure';

  @override
  String get requestCreateDateRequired => 'Departure date required';

  @override
  String get requestCreateToleranceExactHint =>
      'Only travelers leaving on that exact day will be able to respond.';

  @override
  String requestCreateToleranceGenericHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '± $count days around your date. More flexibility, more travelers.',
      one: '± $count day around your date. More flexibility, more travelers.',
    );
    return '$_temp0';
  }

  @override
  String requestCreateToleranceRangeHint(String from, String to) {
    return 'Travelers leaving between $from and $to will be able to respond.';
  }

  @override
  String get requestCreateAirplaneOnlyMode => 'only mode available';

  @override
  String get requestCreateTrajetSectionLabel => 'TRIP';

  @override
  String get requestCreateTrajetQuestion => 'Where from, where to?';

  @override
  String get requestCreateDateFieldLabel => 'Date';

  @override
  String get requestCreateToleranceFieldLabel => 'Flexibility';

  @override
  String get requestCreateUrgentDateHint =>
      '🔥 Date is close, this request will be marked urgent';

  @override
  String requestCreateToleranceShort(int count) {
    return '± $count d';
  }

  @override
  String get requestCreateDateExact => 'Exact date';

  @override
  String requestCreateDateFlex(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '± $count days',
      one: '± $count day',
    );
    return '$_temp0';
  }

  @override
  String requestCreateMaxCategories(int max) {
    return 'Maximum $max categories';
  }

  @override
  String get requestCreateCategoryRequired => 'Choose at least one category';

  @override
  String get requestCreateAutrePrecisionTitle =>
      'Specify the content (optional)';

  @override
  String get requestCreateAutrePrecisionSubtitle =>
      'This helps the traveler know what they\'re carrying.';

  @override
  String get requestCreateAutrePrecisionValidate => 'Confirm';

  @override
  String get requestCreateAutrePrecisionHint => 'E.g. Musical instruments';

  @override
  String get requestCreateStep2Title => 'Describe your parcel';

  @override
  String get requestCreateStep2Subtitle =>
      'This information helps travelers know if they can carry your shipment.';

  @override
  String get requestCreateWeightLabel => 'Approximate weight';

  @override
  String get requestCreateContentLabel => 'Content';

  @override
  String get requestCreateContentHint =>
      'Type to search, or write your own category.';

  @override
  String get requestCreateDescriptionLabel => 'Description (optional)';

  @override
  String get requestCreateDescriptionHint =>
      'Useful details: fragile, exact content, drop-off instructions…';

  @override
  String get requestCreateWeightInvalid => 'Invalid value';

  @override
  String get requestCreateBudgetSubtitle =>
      'Check your request, then enter the budget to show travelers.';

  @override
  String get requestCreatePriceModeLabel => 'How do you want to set the price?';

  @override
  String get requestCreatePriceModeOpenTitle => 'I\'m open to offers';

  @override
  String get requestCreatePriceModeOpenSubtitle =>
      'Travelers propose their price, you choose.';

  @override
  String get requestCreatePriceModeFixedTitle => 'I set my price';

  @override
  String get requestCreatePriceModeFixedSubtitle =>
      'A fixed amount, no negotiation.';

  @override
  String get requestCreateCurrencyLabel => 'Currency';

  @override
  String get requestCreateBudgetLabelNegotiable => 'Estimated budget';

  @override
  String get requestCreateBudgetLabelFixed => 'Your price';

  @override
  String get requestCreateBudgetHintNegotiable =>
      'Give a rough idea to attract more offers, without committing.';

  @override
  String get requestCreateBudgetHintFixed =>
      'Travelers will see this amount and can accept it as is.';

  @override
  String get requestCreatePromoLabel => 'Promo code (optional)';

  @override
  String get requestCreatePromoHint => 'E.g. WELCOME10';

  @override
  String get requestCreatePromoAppliedFallback => 'Code applied';

  @override
  String get requestCreatePaymentAcceptedLabel => 'Accepted payment';

  @override
  String get requestCreatePaymentHint => 'Choose how you\'ll pay the traveler.';

  @override
  String get requestCreateKeepOnePaymentMethod =>
      'Keep at least one payment method.';

  @override
  String get requestCreatePublishInfoBanner =>
      'Once posted, travelers on this trip are notified. You\'ll get a notification at the first offer.';

  @override
  String get requestCreateBudgetInputHint => 'E.g. 40.00';

  @override
  String get requestCreateBudgetEmpty => 'Enter a budget';

  @override
  String requestCreateBudgetRange(String min, String max) {
    return 'Between $min and $max';
  }

  @override
  String requestCreateCommissionLabel(String rate) {
    return 'Yadony service fee ($rate%)';
  }

  @override
  String get requestCreatePromoBoostLabel =>
      'Thanks to the promo code, the traveler gets';

  @override
  String get requestCreateTravelerReceivesLabel => 'The traveler will receive';

  @override
  String requestCreateCurrencySemanticLabel(String name, String code) {
    return 'Request currency: $name, $code. Button, change the currency.';
  }

  @override
  String get requestCreateChangeCurrency => 'Change';

  @override
  String get requestCreatePhotoUnsupported => 'Unsupported or too large image';

  @override
  String get requestCreateTakePhoto => 'Take a photo';

  @override
  String get requestCreatePickFromGallery => 'Choose from the gallery';

  @override
  String get requestCreatePhotosLabel => 'Parcel photos';

  @override
  String get requestCreatePhotosHint =>
      'Visible to travelers. Added to the offer once a trip is linked.';

  @override
  String get requestCreateAddPhotoSemantic => 'Add a photo of the parcel';

  @override
  String get requestCreatePhotoUploadFailed => 'Photo upload failed';

  @override
  String requestCreatePhotoUploadFailedWithReason(String reason) {
    return 'Failed: $reason';
  }

  @override
  String get requestCreateRetryPhotoUpload => 'Retry sending the photo';

  @override
  String get requestCreateAddPhotoTitle => 'Add a photo';

  @override
  String get requestCreateAddPhotoSubtitle =>
      'Strongly recommended, reassures the traveler';

  @override
  String get requestCreateRemovePhoto => 'Remove this photo';

  @override
  String get requestCreateCompleteDetailsTitle => 'Check & complete';

  @override
  String get requestCreateDetailsSaved => 'Details saved';

  @override
  String get requestCreateRecipientSection => 'Recipient';

  @override
  String get requestCreateRecipientNameLabel => 'Full name';

  @override
  String get requestCreateRequiredField => 'Required';

  @override
  String get requestCreateRecipientPhoneLabel => 'Phone';

  @override
  String get requestCreateRecipientPhoneFormat => 'E.164 format (+221…)';

  @override
  String get requestCreateRecipientCityLabel => 'City / town';

  @override
  String get requestCreateRecipientCityHint => 'E.g. Dakar (optional)';

  @override
  String get requestCreatePaymentMethodSection => 'Payment method';

  @override
  String get requestCreateSendingLabel => 'Sending…';

  @override
  String get requestCreateContinueToPayment => 'Continue to payment';

  @override
  String get requestCreateRecapTitle => 'Summary';

  @override
  String get requestCreateRecapTrip => 'Trip';

  @override
  String get requestCreateRecapTravelDate => 'Travel date';

  @override
  String get requestCreateRecapWeight => 'Weight';

  @override
  String get requestCreateRecapSize => 'Size';

  @override
  String get requestCreateRecapPrice => 'Price to pay';

  @override
  String get requestDetailTitle => 'My request';

  @override
  String get requestDetailNoticeActionFailed =>
      'Something went wrong. Try again in a moment.';

  @override
  String get requestDetailNoticeInvitationSent =>
      'Invitation sent. The traveler has been notified.';

  @override
  String get requestDetailNoticeInvitationRefused =>
      'This traveler can\'t be invited.';

  @override
  String get requestDetailNoticeInvitationNotInvitable =>
      'This request no longer accepts invitations.';

  @override
  String get requestDetailNoticeInvitationLimitReached =>
      'Invitation limit reached for this request.';

  @override
  String requestDetailShareMessage(
    String weight,
    String departure,
    String arrival,
    String date,
  ) {
    return 'I\'m sending a $weight kg parcel $departure → $arrival around $date. Are you traveling this route? Reply to my request on Yadony.';
  }

  @override
  String get requestDetailMoreActionsTooltip => 'More actions';

  @override
  String get requestDetailCancelDialogTitle => 'Cancel this request?';

  @override
  String get requestDetailCancelDialogMessage =>
      'This action can\'t be undone. Travelers won\'t be able to respond to it anymore.';

  @override
  String get requestDetailErrorNotFoundTitle => 'This request no longer exists';

  @override
  String get requestDetailErrorNotFoundMessage =>
      'It may have been canceled or deleted.';

  @override
  String get requestDetailErrorLoadTitle => 'We couldn\'t load your request';

  @override
  String get requestDetailErrorLoadMessage =>
      'Check your connection, then try again. Your request hasn\'t changed.';

  @override
  String get requestTravelerFallbackNameLower => 'the traveler';

  @override
  String get requestListTitle => 'My requests';

  @override
  String get requestListErrorFallback => 'Error';

  @override
  String get requestListEmptyTitle => 'You haven\'t sent anything yet';

  @override
  String get requestListEmptyDescription =>
      'Post your first request and get offers from travelers within hours.';

  @override
  String get requestListEmptyCta => '+ Post my first request';

  @override
  String get requestListSearchHint => 'City, category…';

  @override
  String get requestListFilterAllLabel => 'All';

  @override
  String get requestListFilterOpenLabel => 'Open';

  @override
  String get requestListFilterClosedLabel => 'Unsuccessful';

  @override
  String get requestListFilterDraftLabel => 'Drafts';

  @override
  String get requestListEmptySearchResult => 'No results for this search';

  @override
  String get requestListEmptyOpen => 'No open requests';

  @override
  String get requestListEmptyClosed => 'No unsuccessful requests';

  @override
  String get requestListEmptyDraft => 'No drafts';

  @override
  String get requestListEmptyAll => 'No requests';

  @override
  String get requestListNewFab => 'New request';

  @override
  String get requestListEditCta => 'Edit →';

  @override
  String get requestListStatusDraft => 'DRAFT';

  @override
  String get requestListStatusOpen => 'OPEN';

  @override
  String get requestListStatusNegotiating => 'NEGOTIATING';

  @override
  String get requestListStatusAccepted => 'ACCEPTED';

  @override
  String get requestListStatusCompleted => 'DELIVERED';

  @override
  String get requestListStatusExpired => 'EXPIRED';

  @override
  String get requestListStatusCancelled => 'CANCELED';

  @override
  String get requestListTimeJustNow => 'just now';

  @override
  String requestListTimeMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String requestListTimeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String requestListTimeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get requestEnvoyerHubTitle => 'Send';

  @override
  String get requestEnvoyerHubNewButton => '+ New';

  @override
  String requestDetailViews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count views',
      one: '$count view',
    );
    return '$_temp0';
  }

  @override
  String requestDetailTravelersWillSee(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers will see it',
      one: '$count traveler will see it',
    );
    return '$_temp0';
  }

  @override
  String requestDetailTravelersOnRouteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers on your route',
      one: '$count traveler on your route',
    );
    return '$_temp0';
  }

  @override
  String get requestDetailNotVisibleTitle => 'Not visible yet';

  @override
  String get requestDetailNotVisibleMessage =>
      'Post your request so travelers can propose a price.';

  @override
  String requestDetailCashCommissionTitle(String name) {
    return '$name is paying their Yadony service fee';
  }

  @override
  String get requestDetailCashCommissionMessage =>
      'Cash deal found. Until it\'s done, you can still choose someone else.';

  @override
  String get requestDetailFinalizeTitle => 'Finalize to secure their spot';

  @override
  String get requestDetailFinalizeMessage =>
      'Your money stays held by Yadony until the parcel is dropped off.';

  @override
  String get requestDetailExpiredTitle => 'Date passed without a deal';

  @override
  String get requestDetailExpiredMessage =>
      'No traveler was selected in time. Your info is kept, just choose new dates.';

  @override
  String get requestDetailCancelledTitle => 'You canceled this request';

  @override
  String get requestDetailCancelledMessage =>
      'Travelers can no longer respond to it.';

  @override
  String get requestDetailNoSearchTitle =>
      'We couldn\'t load travelers right now';

  @override
  String get requestDetailNoSearchMessage =>
      'Try again later, or share your request directly in the meantime.';

  @override
  String get requestDetailOffersReceivedTitle => 'Offers received';

  @override
  String get requestDetailSingleChoiceTitle => 'Only one choice';

  @override
  String get requestDetailSingleChoiceMessage =>
      'The other candidates will be automatically declined.';

  @override
  String get requestDetailInterestedTravelersTitle => 'Interested travelers';

  @override
  String get requestDetailOffersTitle => 'Offers';

  @override
  String get requestDetailSelectedOfferTitle => 'Selected offer';

  @override
  String get requestDetailTripNotCompletedTitle =>
      'This trip didn\'t go through';

  @override
  String get requestDetailTripNotCompletedMessage =>
      'The traveler couldn\'t complete the delivery. Post a similar request to find someone else.';

  @override
  String get requestDetailYourTravelerFallback => 'your traveler';

  @override
  String get requestDetailStubCashPaid => 'paid in person';

  @override
  String get requestDetailStubCashPending => 'to pay in person at drop-off';

  @override
  String get requestDetailStubPaidToTraveler => 'paid to the traveler';

  @override
  String get requestDetailStubHeldByYadony => 'paid, held by Yadony';

  @override
  String get requestTravelerFallbackName => 'The traveler';

  @override
  String requestTravelerAddingTrip(String name) {
    return '$name is adding their trip';
  }

  @override
  String get requestOfferDealFound => 'Deal found';

  @override
  String get requestOfferCashDealCommissionPending =>
      'Cash deal, service fee pending';

  @override
  String get requestOfferAvailableForParcel => 'Available for your parcel';

  @override
  String get requestOfferChooseCta => 'Choose';

  @override
  String get requestOfferYourTurn => 'Your turn to respond';

  @override
  String get requestOfferRespondCta => 'Respond';

  @override
  String requestOfferWaitingFor(String name) {
    return 'Waiting for $name';
  }

  @override
  String get requestOfferYouPayCaption => 'you pay';

  @override
  String requestAvailableKg(String weight) {
    return '$weight kg available';
  }

  @override
  String get requestDetailMenuUnpublishLabel => 'Unpublish';

  @override
  String get requestDetailMenuUnpublishConsequence =>
      'Becomes a draft again, hidden from travelers';

  @override
  String get requestDetailMenuDuplicateLabel => 'Duplicate the request';

  @override
  String get requestDetailMenuDuplicateConsequence =>
      'Same parcel, new dates or a new trip';

  @override
  String get requestDetailMenuCancelLabel => 'Cancel the request';

  @override
  String get requestDetailMenuCancelConsequence => 'Irreversible';

  @override
  String get requestTravelersOnRouteTitle => 'Travelers on your route';

  @override
  String requestNoTravelersTitle(String corridor) {
    return 'No traveler on $corridor yet';
  }

  @override
  String get requestNoTravelersMessage =>
      'Trips often show up the week of departure. We\'ll let you know as soon as a traveler posts one.';

  @override
  String get requestNoTravelersAlertCta => 'Get alerted about new trips';

  @override
  String get requestNoTravelersWidenDatesCta => 'Widen my dates';

  @override
  String requestStatusOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers',
      one: '$count offer',
    );
    return '$_temp0';
  }

  @override
  String requestStatusCandidates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count interested travelers',
      one: '$count interested traveler',
    );
    return '$_temp0';
  }

  @override
  String get requestStatusDraft => 'Draft';

  @override
  String get requestStatusLive => 'Live';

  @override
  String get requestStatusPendingCommission => 'Pending';

  @override
  String get requestStatusToFinalize => 'To finalize';

  @override
  String get requestStatusConfirmed => 'Confirmed';

  @override
  String get requestStatusDelivered => 'Delivered';

  @override
  String get requestStatusExpired => 'Expired';

  @override
  String get requestStatusCancelled => 'Canceled';

  @override
  String get requestDetailPublishCta => 'Post';

  @override
  String get requestDetailOpenThreadCta => 'Open the conversation';

  @override
  String get requestDetailPayCta => 'Pay';

  @override
  String requestDetailPayCtaWithAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get requestDetailTrackParcelCta => 'Track my parcel';

  @override
  String requestDetailRateCta(String name) {
    return 'Rate $name';
  }

  @override
  String get requestDetailRepublishCta => 'Republish with new dates';

  @override
  String get requestDetailPublishSimilarCta => 'Post a similar request';

  @override
  String get requestDetailMessageCta => 'Message';

  @override
  String requestTicketRouteSemantic(
    String departure,
    String arrival,
    String date,
  ) {
    return '$departure to $arrival, $date';
  }

  @override
  String get requestTicketPriceUndefined => 'Price to be set';

  @override
  String get requestTicketNegotiable => 'negotiable';

  @override
  String get requestTicketFixedPrice => 'fixed price';

  @override
  String get requestTicketViewPhotosSemantic => 'View parcel photos';

  @override
  String get requestProgressDealAndPayment => 'Deal and payment';

  @override
  String requestProgressHandoverTo(String name) {
    return 'Parcel drop-off to $name';
  }

  @override
  String get requestProgressInTransit => 'Traveling';

  @override
  String requestProgressDeliveryTo(String city) {
    return 'Delivery to $city';
  }

  @override
  String requestYourParcelWeight(String weight) {
    return 'your parcel: $weight kg';
  }

  @override
  String get requestTravelerInvited => 'Invited';

  @override
  String get requestTravelerInviteCta => 'Invite';

  @override
  String get requestDetailLoadingSemantic => 'Loading your request';

  @override
  String requestToleranceDays(int days) {
    return '±${days}d';
  }

  @override
  String requestReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '$count review',
    );
    return '$_temp0';
  }

  @override
  String get requestPublicTitle => 'Shipping request';

  @override
  String get requestDescriptionLabel => 'Description';

  @override
  String get requestPublicReportTooltip => 'Report';

  @override
  String get requestPublicReportSheetTitle => 'Report this request';

  @override
  String get requestPublicReportReasonProhibited => 'Prohibited content';

  @override
  String get requestPublicReportReasonScam => 'Scam / fraud';

  @override
  String get requestPublicReportReasonInappropriate => 'Inappropriate content';

  @override
  String get requestPublicReportReasonOther => 'Other reason';

  @override
  String get requestPublicReportSuccess => 'Request reported. Thanks.';

  @override
  String get requestPublicReportError => 'Can\'t report right now';

  @override
  String get requestPublicBadge => 'SHIPPING REQUEST';

  @override
  String get requestPublicFirmPriceBadge => 'FIXED PRICE';

  @override
  String requestPublicDesiredDate(String date, String tolerance) {
    return 'on $date ($tolerance)';
  }

  @override
  String get requestPublicParcelHintBag => 'Bag';

  @override
  String get requestPublicParcelHintBox => 'Box';

  @override
  String get requestPublicParcelHintSuitcase => 'Suitcase';

  @override
  String get requestPublicCategoriesLabel => 'CATEGORIES';

  @override
  String get requestPublicBudget => 'Budget';

  @override
  String get requestPublicZonesLabel => 'Zones';

  @override
  String get requestPublicPickupLabel => 'Drop-off';

  @override
  String get requestPublicDeliveryLabel => 'Delivery';

  @override
  String get requestPublicPaymentTitle => 'Preferred payment method';

  @override
  String get requestPublicPaymentSubtitle => 'Accepted by the sender';

  @override
  String get requestPublicProposeTripCta => 'Propose my trip';

  @override
  String get requestPublicViewNegotiationCta => 'View my negotiation';

  @override
  String get requestPublicViewProposalCta => 'View my proposal';

  @override
  String get requestPublicTakePackageCta => 'Take this parcel';

  @override
  String requestPublicTakeAt(String price) {
    return 'Take it for $price · Fixed price';
  }

  @override
  String get requestPublicOfferConfirmed => 'Offer confirmed';

  @override
  String get requestSearchTitle => 'Open requests';

  @override
  String get requestSearchEmptyMessage => 'No request matches your filter';

  @override
  String requestSearchBudgetLine(String amount) {
    return 'Budget: $amount';
  }

  @override
  String requestListYourTripOn(String date) {
    return 'Your trip on $date';
  }

  @override
  String get requestBudgetFreeLabel => 'Open budget';

  @override
  String get requestFavoriteToggleError => 'Action failed, try again';

  @override
  String requestSenderShipmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shipments',
      one: '$count shipment',
    );
    return '$_temp0';
  }

  @override
  String requestMatchingBudgetPerKg(String amount) {
    return 'Budget $amount/kg';
  }

  @override
  String get requestPreviewTitle => 'Preview your request';

  @override
  String get requestPreviewPublishCta => 'Post my request';

  @override
  String get requestPreviewSaveDraftCta => 'Save as draft';

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
  String get requestPreviewDropoffLabel => 'Drop-off';

  @override
  String get requestPreviewPaymentLabel => 'Payment';

  @override
  String get requestPreviewOpenToOffers => 'Open to offers';

  @override
  String requestPreviewBudgetIndicative(String amount) {
    return 'Estimated budget: $amount';
  }

  @override
  String requestPreviewFixedPrice(String amount) {
    return 'Fixed price: $amount';
  }

  @override
  String requestCarouselSeeAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'See $count requests',
      one: 'See the request',
    );
    return '$_temp0';
  }

  @override
  String get requestCarouselEmptyTitle => 'No requests nearby';

  @override
  String get requestCarouselWidenZoneCta => 'Widen the area';

  @override
  String get requestStatusChipOpen => 'Open';

  @override
  String get requestStatusChipNegotiating => 'Negotiating';

  @override
  String get requestStatusChipAccepted => 'Accepted';

  @override
  String get requestSenderProfileTitle => 'Sender profile';

  @override
  String get requestSenderMoreOptionsTooltip => 'More options';

  @override
  String get requestSenderVerifiedIdentity => 'Verified identity';

  @override
  String get requestSenderNewMember => 'New member';

  @override
  String get requestPickerModifyTripCta => 'Edit trip';

  @override
  String get requestPickerPriceUnavailable => 'Unavailable';

  @override
  String get requestPickerCashEnabled => 'Cash accepted';

  @override
  String get requestPickerCashDisabled => 'Cash not accepted';

  @override
  String requestPickerKgAvailable(String kg) {
    return '$kg kg available';
  }

  @override
  String get requestPickerLoadErrorMessage => 'Can\'t load your trips';

  @override
  String get requestPickerNoMatchTitle => 'None of your trips match';

  @override
  String get requestPickerMatchingTitle => 'Your matching trips';

  @override
  String get requestPickerEmptyCreateHint =>
      'Create a trip that matches this request';

  @override
  String get requestPickerCreateTripCta => 'Create a new trip';

  @override
  String get requestCarouselCardPriceFree => 'Open price';

  @override
  String get requestPreviewPhotosLabel => 'Photos';

  @override
  String get requestCreateRecapTransport => 'Transport';

  @override
  String get requestCreateRecapPackage => 'Parcel';

  @override
  String get listingDeleteTripConfirmTitle => 'Delete this trip?';

  @override
  String get listingDeleteTripCancelledMessage =>
      'This action is irreversible. The canceled trip and all related requests will be permanently removed from the platform.';

  @override
  String get listingDeleteTripActiveMessage =>
      'This action is irreversible. The trip will no longer be visible to senders.';

  @override
  String get listingTripDetailTitle => 'Trip details';

  @override
  String get listingTripDeletedMessage => 'Trip deleted';

  @override
  String get listingAnnouncementGoneMessage => 'This listing no longer exists';

  @override
  String get listingHeroTripLabel => 'Trip';

  @override
  String get listingPickupLocationsTitle => 'Drop-off locations';

  @override
  String get listingHandoverDeadlineTitle => 'Parcel drop-off deadline';

  @override
  String get listingCapacityAvailableLabel => 'Available capacity';

  @override
  String get listingPricingModeLabel => 'Pricing';

  @override
  String get listingPricePerKgLabel => 'Price per kg';

  @override
  String get listingPriceGridShort => 'Grid';

  @override
  String get listingPriceUnavailableShort => 'Unavailable';

  @override
  String listingSeeRequestsButton(int count) {
    return 'See requests ($count)';
  }

  @override
  String get listingEditTripButton => 'Edit this trip';

  @override
  String get listingCancelTripButton => 'Cancel this trip';

  @override
  String get listingDeleteTripButton => 'Delete this trip';

  @override
  String get listingTripLockedMessage => 'This trip can no longer be edited.';

  @override
  String get listingStatusActive => 'Active';

  @override
  String get listingStatusFull => 'Full';

  @override
  String get listingStatusCompleted => 'Completed';

  @override
  String get listingStatusCancelled => 'Canceled';

  @override
  String listingHandoverUntil(String date) {
    return 'Until $date';
  }

  @override
  String get listingSearchDestinationHint => 'Search a destination…';

  @override
  String get listingFilterAllChip => 'All';

  @override
  String get listingFilterDraftsChip => 'Drafts';

  @override
  String get listingFilterActiveChip => 'Active';

  @override
  String get listingFilterCompletedChip => 'Completed';

  @override
  String get listingFilterCancelledChip => 'Canceled';

  @override
  String get listingHeaderTitle => 'My trips';

  @override
  String get listingNewTripPill => '+ New';

  @override
  String get listingLoadErrorTitle => 'We couldn\'t load your trips';

  @override
  String get listingEmptyNoTripsTitle => 'No upcoming trips';

  @override
  String get listingEmptyDraftTitle => 'No drafts';

  @override
  String get listingEmptyActiveTitle => 'No active trips';

  @override
  String get listingEmptyCompletedTitle => 'No history';

  @override
  String get listingEmptyCancelledTitle => 'No cancellations';

  @override
  String get listingEmptyAllTitle => 'No trips found';

  @override
  String get listingEmptyNoTripsDesc =>
      'Post your first trip and start carrying parcels.';

  @override
  String get listingEmptyDraftDesc =>
      'Your trips saved without publishing will appear here.';

  @override
  String get listingEmptyActiveDesc =>
      'Your ongoing and upcoming trips will appear here.';

  @override
  String get listingEmptyCompletedDesc =>
      'Your past and completed trips will appear here.';

  @override
  String get listingEmptyCancelledDesc =>
      'Your canceled trips will appear here.';

  @override
  String get listingEmptyAllDesc => 'No trips match your search.';

  @override
  String get listingHeroTripLabelCaps => 'TRIP';

  @override
  String get listingCapacityAvailableSuffix => 'available';

  @override
  String get listingPricingSuffixTarifaire => 'pricing';

  @override
  String get listingPricingSuffixPrix => 'price';

  @override
  String listingAcceptedParcels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'parcels accepted',
      one: 'parcel accepted',
    );
    return '$_temp0';
  }

  @override
  String get listingPendingParcelsLabel => 'pending';

  @override
  String get listingPaymentsAcceptedTitle => 'Accepted payment methods';

  @override
  String get listingCashOnlyNudgeMessage =>
      'Cash-only trip. Many senders prefer to pay by card, so enabling this option increases your chances of receiving parcels.';

  @override
  String get listingActivateCardPaymentsButton => 'Activate card payments';

  @override
  String get listingAcceptedContentTitle => 'What I accept';

  @override
  String get listingRefusedContentTitle => 'What I refuse';

  @override
  String get listingSenderNoteTitle => 'Note to senders';

  @override
  String get listingBadgeActive => '● ACTIVE';

  @override
  String get listingBadgeDraft => '✎ DRAFT';

  @override
  String get listingBadgeFull => '● FULL';

  @override
  String get listingBadgeInProgress => '● IN PROGRESS';

  @override
  String get listingBadgeCompleted => '✓ COMPLETED';

  @override
  String get listingBadgeCancelled => '✕ CANCELED';

  @override
  String listingReservedKgLabel(String kg) {
    return '$kg kg reserved';
  }

  @override
  String listingOpenKgLabel(String kg) {
    return '$kg kg open';
  }

  @override
  String get listingPickupParcelTitleShort => 'Parcel drop-off';

  @override
  String get listingDeliveryPickupTitle => 'Pickup';

  @override
  String get listingAlreadyHasParcelMessage =>
      'You already have a parcel on this trip';

  @override
  String get listingSeeMyParcelButton => 'See my parcel';

  @override
  String get listingMakeRequestButton => 'Make a request';

  @override
  String get listingNegotiableTripPrefix => 'Negotiable trip · ';

  @override
  String get listingProposePriceLink => 'Propose a price';

  @override
  String get listingPricePerKiloLabel => 'per kilo';

  @override
  String listingApproxPricePerKg(String price) {
    return 'approx. $price/kg';
  }

  @override
  String listingApproxPrice(String price) {
    return 'approx. $price';
  }

  @override
  String get listingDepositDeadlineLabel => 'drop-off deadline';

  @override
  String get listingPriceGridLabel => 'Price grid';

  @override
  String listingItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get listingPricePerItemTitle => 'Price per item';

  @override
  String listingSeeAllPricesButton(int count) {
    return 'See all prices ($count)';
  }

  @override
  String get listingPickupParcelTitle => 'Parcel drop-off';

  @override
  String get listingReportTripLink => 'Report this trip';

  @override
  String get listingBlockTravelerLink => 'Block this traveler';

  @override
  String get listingFavoriteAddedMessage => 'Trip added to favorites';

  @override
  String get listingFavoriteRemovedMessage => 'Trip removed from favorites';

  @override
  String get listingFavoriteToggleErrorMessage => 'Couldn\'t update favorites';

  @override
  String listingKgAvailableLabel(String kg) {
    return '$kg kg available';
  }

  @override
  String get listingIdentityBadge => 'Verified';

  @override
  String get listingCategoriesAcceptedTitle => 'Accepted parcel types';

  @override
  String get listingTravelerMessageTitle => 'Traveler\'s message';

  @override
  String get listingRouteLabel => 'Directions';

  @override
  String get listingCashOnlyWarningBold => 'Cash-only trip. ';

  @override
  String get listingCashOnlyWarningBody =>
      'Payment is made directly to the traveler in person. Yadony does not put your money on hold and cannot refund it automatically in case of a dispute.';

  @override
  String get listingNewRatingLabel => 'New';

  @override
  String listingTravelerTrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '· $count trips',
      one: '· $count trip',
    );
    return '$_temp0';
  }

  @override
  String get listingPreviewTitle => 'Preview your listing';

  @override
  String get listingPublishButton => 'Post the listing';

  @override
  String get listingSaveDraftButton => 'Save as draft';

  @override
  String get listingPreviewDepartureLabel => 'Departure';

  @override
  String get listingRowLabelPickup => 'Drop-off';

  @override
  String get listingRowLabelCapacity => 'Capacity';

  @override
  String get listingRowLabelPayment => 'Payment';

  @override
  String get listingPaymentCardCash => 'Card + Cash';

  @override
  String get listingPaymentCardOnly => 'Card only';

  @override
  String get listingRowLabelAccept => 'Accepts';

  @override
  String get listingRowLabelRefuse => 'Refuses';

  @override
  String get listingRowLabelNote => 'Note';

  @override
  String get listingPriceTooLowWarning =>
      'Low price. You\'ll be able to change it after posting.';

  @override
  String get listingPriceTooHighWarning =>
      'High price. You\'ll be able to change it after posting.';

  @override
  String get listingStatusInProgress => 'In progress';

  @override
  String listingDateTodayLabel(String date) {
    return 'Today · $date';
  }

  @override
  String listingDateTomorrowLabel(String date) {
    return 'Tomorrow · $date';
  }

  @override
  String listingDateInDaysLabel(int days, String date) {
    return 'Departs in $days days · $date';
  }

  @override
  String get listingRetryActionMessage => 'Action failed, try again';

  @override
  String listingAcceptedBidsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accepted',
      one: '$count accepted',
    );
    return '$_temp0';
  }

  @override
  String listingPendingBidsCount(int count) {
    return '$count pending';
  }

  @override
  String listingSoldOfTotalLabel(String sold, String total) {
    return '$sold sold of $total';
  }

  @override
  String listingAvailableKgLabel(String kg) {
    return '$kg available';
  }

  @override
  String listingSoldLabel(String kg) {
    return '$kg sold';
  }

  @override
  String listingEarnedLabel(String price) {
    return '$price earned';
  }

  @override
  String get listingBidStatusAccepted => 'Request accepted';

  @override
  String get listingBidStatusOnTrip => 'Parcel on this trip';

  @override
  String get listingBidStatusArrived => 'Arrived';

  @override
  String get listingBidStatusPending => 'Request pending';

  @override
  String get listingYourTripPill => 'Your trip';

  @override
  String get listingProBadge => 'PRO';

  @override
  String get listingNoTravelersNearbyTitle => 'No travelers nearby';

  @override
  String get listingNoTravelersNearbyDesc =>
      'Try widening the radius or changing the date.';

  @override
  String get listingSeeAnnouncementButton => 'See the listing';

  @override
  String listingSeeAnnouncementsCountButton(int count) {
    return 'See the $count listings';
  }

  @override
  String listingRouteDeparturesFrom(String city) {
    return 'Departures from $city';
  }

  @override
  String listingRouteArrivalsTo(String city) {
    return 'Arrivals in $city';
  }

  @override
  String listingRouteTrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips',
      one: '$count trip',
    );
    return '$_temp0';
  }

  @override
  String get listingNoTripsOnRoute => 'No trips available on this route';

  @override
  String listingSameAddressTravelers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers available at this address',
      one: '$count traveler available at this address',
    );
    return '$_temp0';
  }

  @override
  String get listingAddressFallback => 'Address';

  @override
  String get listingNearMeDeactivateTooltip => 'Turn off \"Near me\"';

  @override
  String get listingNearMeActivateTooltip => 'See travelers near me';

  @override
  String get listingFilterTripsTitle => 'Filter trips';

  @override
  String get listingResetFiltersButton => 'Reset';

  @override
  String listingSearchButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Search · $count filters',
      one: 'Search · $count filter',
      zero: 'Search',
    );
    return '$_temp0';
  }

  @override
  String get listingQuickFiltersTitle => 'QUICK FILTERS';

  @override
  String get listingKiloProChip => 'Kilo Pro';

  @override
  String get listingRatingChip => 'Rating ≥ 4.5';

  @override
  String get listingWeekendChip => 'Weekend';

  @override
  String get listingContentContainsTitle => 'MY PARCEL CONTAINS';

  @override
  String get listingDepartureUrgencyTitle => 'DEPARTURE URGENCY';

  @override
  String get listingDepartureUrgencyDesc =>
      'Filter trips by how soon they depart';

  @override
  String get listingDeleteTripAssociatedRequestsMessage =>
      'The canceled trip and all related requests will be permanently removed from the platform.';

  @override
  String get listingDeadlineLabel => 'Deadline';

  @override
  String get listingInstructionsCardTitle => 'Traveler\'s instructions';

  @override
  String get listingRowLabelDate => 'Date';

  @override
  String get listingRowLabelPrice => 'Price';

  @override
  String listingPriceEstimateSuffix(String amount) {
    return ' · estimate $amount net';
  }

  @override
  String get bidCreateSendProposalButton => 'Send my proposal';

  @override
  String bidCreateConfirmCashButton(String amount) {
    return 'Confirm $amount in cash';
  }

  @override
  String bidCreateConfirmMobileMoneyButton(String amount) {
    return 'Confirm $amount by mobile money';
  }

  @override
  String bidCreateLockAndPayButton(String amount) {
    return 'Lock $amount & pay';
  }

  @override
  String get bidCreateDescriptionRequiredError => 'Description required';

  @override
  String get bidCreateRecipientNameRequiredError => 'Recipient name required';

  @override
  String get bidCreateRecipientPhoneRequiredError => 'Recipient phone required';

  @override
  String get bidCreatePriceRequiredError => 'Enter the price you\'re proposing';

  @override
  String get bidCreateProposalSentMessage =>
      'Proposal sent, the traveler will get back to you.';

  @override
  String get bidCreateOfferSentTitle => 'Offer sent!';

  @override
  String get bidCreateCashSuccessSubtitle =>
      'Cash payment: if the traveler accepts, you hand over the amount in person at drop-off. If canceled after drop-off, Yadony can\'t refund you right away, but will make sure the traveler gives your money back.';

  @override
  String get bidCreateMobileMoneySuccessSubtitle =>
      'Mobile money payment: if the traveler accepts, you\'ll get a notification and have 30 minutes to confirm the payment on your phone. The amount is kept safe by Yadony until delivery.';

  @override
  String get bidCreateReviewPendingSubtitle =>
      'The traveler will review your request.';

  @override
  String get bidCreateSeeMyShipmentButton => 'View my shipment';

  @override
  String get bidCreateArticlesSectionLabel => 'ITEMS';

  @override
  String bidCreateSelectedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items selected',
      one: '$count item selected',
    );
    return '$_temp0';
  }

  @override
  String bidCreateSubtotalLabel(String amount) {
    return 'Subtotal: $amount';
  }

  @override
  String get bidCreateChooseItemsLabel => 'Choose my items';

  @override
  String get bidCreateItemsRequiredHint => 'Required: at least 1 item';

  @override
  String get bidCreatePhotosSectionLabel => 'PARCEL PHOTOS (OPTIONAL)';

  @override
  String get bidCreateDescriptionSectionLabel =>
      'DESCRIPTION (TO THE TRAVELER)';

  @override
  String get bidCreateDescriptionHint =>
      'Diabetes medication + 2 children\'s t-shirts';

  @override
  String get bidCreateRecipientSectionLabel => 'RECIPIENT';

  @override
  String get bidCreateRecipientNameLabel => 'Recipient\'s first and last name';

  @override
  String get bidCreateRecipientNameHint => 'e.g.: Amadou Diallo';

  @override
  String get bidCreateRecipientPhoneLabel => 'Recipient\'s phone number';

  @override
  String get bidCreateRecipientPhoneHint => 'e.g.: +221 77 000 00 00';

  @override
  String get bidCreatePromoSectionLabel => 'PROMO CODE (OPTIONAL)';

  @override
  String get bidCreatePromoCodeHint => 'E.g. WELCOME10';

  @override
  String get bidCreatePromoAppliedDefaultLabel => 'Code applied';

  @override
  String get bidCreateYourProposalSectionLabel => 'YOUR PROPOSAL';

  @override
  String bidCreateProposedPriceLabel(String symbol) {
    return 'Proposed price ($symbol)';
  }

  @override
  String bidCreateSuggestedPriceLabel(String amount) {
    return 'Suggested: $amount';
  }

  @override
  String get bidCreatePaymentMethodSectionLabel => 'PAYMENT METHOD';

  @override
  String get bidCreatePaymentMethodHint =>
      'If the traveler accepts your price, you\'ll pay this way.';

  @override
  String get bidCreateContentSectionLabel => 'PARCEL CONTENT';

  @override
  String get bidCreateContentHintText =>
      'These suggestions are the contents accepted by the traveler. If your parcel\'s content isn\'t listed, add it: it\'ll be up to the traveler to decide whether to accept your parcel or not.';

  @override
  String get bidCreateRefusedByTravelerSectionLabel =>
      'REFUSED BY THE TRAVELER';

  @override
  String get bidCreateHowToPayTitle => 'How do you want to pay?';

  @override
  String get bidCreateChoosePaymentSubtitle =>
      'Choose the payment method for this request.';

  @override
  String get bidCreatePaymentNotConfirmedError =>
      'Payment not confirmed, try again';

  @override
  String bidCreateShipmentToLabel(String city) {
    return 'Shipment to $city';
  }

  @override
  String get bidCreateOfferPaidTitle => 'Offer paid!';

  @override
  String get bidCreateOfferPaidSubtitle =>
      'Your payment is locked and secured until delivery is confirmed. The traveler has been notified of your request.';

  @override
  String get bidCreateWeightLabel => 'Parcel weight';

  @override
  String get bidCreateWeightLabelOptional => 'Parcel weight (optional)';

  @override
  String get bidCreateFreeKgHint => 'Flexible kg: choose your weight';

  @override
  String get bidCreateNoCapacityAvailable => 'No capacity available';

  @override
  String get bidCreateDisclaimerTitle => 'Customs disclaimer.';

  @override
  String get bidCreateDisclaimerBody =>
      'No weapons, drugs, flammable liquids or cash. The traveler can refuse at customs control.';

  @override
  String get bidCreateDisclaimerAcceptLabel => 'I sign & accept';

  @override
  String get bidCreateCardModeSubtitle => 'Locked until delivery';

  @override
  String get bidCreateMobileMoneySubtitle => 'Orange Money, Wave, MTN';

  @override
  String get bidCreateCashModeSubtitle => 'Hand to hand, at drop-off';

  @override
  String get bidCreateEscrowTag => 'Payment on hold';

  @override
  String get bidCreateHandToHandTag => 'Hand to hand';

  @override
  String get bidCreateCardModeBody =>
      'Locked by Yadony right away, paid to the traveler once the recipient confirms delivery.';

  @override
  String get bidCreateMobileMoneyModeBody =>
      'Once the traveler agrees, you\'ll get a payment request on your phone. The amount is locked by Yadony until delivery.';

  @override
  String get bidCreateCashModeBody =>
      'You hand the amount to the traveler on the day you give them the parcel.';

  @override
  String get bidCreateRefundAssurance =>
      'Refunded if the parcel doesn\'t arrive';

  @override
  String get bidCreateCashEscrowWarning =>
      'Cash payment: no payment on hold, you pay the traveler directly, with no refund guarantee from Yadony.';

  @override
  String get bidCreateArticlesLineLabel => 'Items';

  @override
  String get bidCreatePromoDiscountLabel => 'Promo code discount';

  @override
  String get bidCreateTotalLabel => 'Total';

  @override
  String get bidCreatePromoBadge => 'Promo';

  @override
  String get bidCreateServiceFeeIncludedLabel => 'Yadony service fee included';

  @override
  String get bidCreatePhotosVisibleHint =>
      'Visible to the traveler, they reassure about the content.';

  @override
  String get bidCreatePayerPhoneLabel => 'Payer\'s number (optional)';

  @override
  String get bidCreatePayerPhoneHintWithProfile =>
      'By default, your Yadony number. You\'ll receive the payment request on this number.';

  @override
  String get bidCreatePayerPhoneHintNoProfile =>
      'Your account has no number: enter the one that will pay. You\'ll receive the payment request on it.';

  @override
  String get bidCreateCustomItemsSectionTitle => 'Items outside the grid';

  @override
  String get bidCreateCustomItemsSectionHint =>
      'Add what the traveler hasn\'t priced, and propose your price for each item.';

  @override
  String get bidCreateCustomItemsEmpty => 'No items yet.';

  @override
  String get bidCreateCustomItemsTotalLabel =>
      'Total for items outside the grid';

  @override
  String get bidCreateAddItemButton => 'Add an item';

  @override
  String get bidCreateRemoveItemTooltip => 'Remove this item';

  @override
  String get bidCreateAddItemSheetSubtitle =>
      'Describe the item and state the price you\'re proposing for its transport.';

  @override
  String get bidCreateAddItemConfirmButton => 'Add';

  @override
  String get bidCreateCustomItemLabelField => 'Item';

  @override
  String get bidCreateCustomItemLabelHint => 'Bag of rice, boubou, medication';

  @override
  String get bidCreateCustomItemQuantityField => 'Quantity';

  @override
  String bidCreateCustomItemPriceField(String symbol) {
    return 'Price ($symbol)';
  }

  @override
  String get bidCreateGridSheetTitle => 'Available items';

  @override
  String get bidCreateGridSheetConfirmButton => 'Confirm selection';

  @override
  String bidCreateGridItemSemanticSelected(
    String label,
    String price,
    int quantity,
  ) {
    return '$label, $price per unit, $quantity selected';
  }

  @override
  String bidCreateGridItemSemanticUnit(String label, String price) {
    return '$label, $price per unit';
  }

  @override
  String bidCreateGridItemRemoveSemantic(String label) {
    return 'Remove one $label';
  }

  @override
  String bidCreateGridItemAddSemantic(String label) {
    return 'Add one $label';
  }

  @override
  String get bidCreatePriceTooLowHint =>
      'Low price: risk of distrust from the sender';

  @override
  String get bidCreatePriceTooHighHint => 'High price: few requests expected';

  @override
  String bidCreateMarketPriceCorridor(String corridor) {
    return 'Market $corridor: ';
  }

  @override
  String get bidCreateMarketPriceLabel => 'Market ';

  @override
  String get bidCreateCompetitivePriceSuffix => ' · Your price is competitive.';

  @override
  String bidCreateDisclaimerSigned(String dateTime) {
    return 'Disclaimer signed on $dateTime';
  }

  @override
  String get tripPublishCashCommissionIntro =>
      'You\'ll only be able to accept a cash-paid parcel if the Yadony service fee can be collected ';

  @override
  String get tripPublishCashCommissionHighlight => 'from your wallet first';

  @override
  String get tripPublishCashCommissionOutro =>
      '. Otherwise, you\'ll need to top it up or add a valid card when accepting.';

  @override
  String get negotiationStageToPay => 'to pay';

  @override
  String get negotiationStageAwaitingPayment => 'awaiting payment';

  @override
  String get negotiationStageDealAgreed => 'deal agreed';

  @override
  String get negotiationStageClosed => 'closed';

  @override
  String get negotiationStageProposal => 'proposal';

  @override
  String get bidSenderFallbackName => 'Sender';

  @override
  String bidTravelerTrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips',
      one: '$count trip',
    );
    return '$_temp0';
  }

  @override
  String bidSenderShipments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shipments',
      one: '$count shipment',
    );
    return '$_temp0';
  }

  @override
  String bidSubmittedOn(String date) {
    return 'Submitted on $date';
  }

  @override
  String get negotiationThreadTitle => 'Price discussion';

  @override
  String get negotiationThreadErrorTitle => 'Discussion unavailable';

  @override
  String get negotiationThreadYouWouldReceive => 'You would receive';

  @override
  String get negotiationThreadYouWouldPay => 'You would pay';

  @override
  String negotiationThreadRoundLabel(int round, int maxRounds) {
    return 'Round $round of $maxRounds';
  }

  @override
  String get negotiationThreadParcelSectionTitle => 'The parcel';

  @override
  String get negotiationThreadExchangesTitle => 'Exchanges';

  @override
  String get negotiationThreadKindProposal => 'Proposal';

  @override
  String get negotiationThreadKindCounter => 'Counter-offer';

  @override
  String get negotiationThreadKindAccepted => 'Accepted';

  @override
  String get negotiationThreadKindRejected => 'Declined';

  @override
  String get negotiationThreadPayHint =>
      'Price accepted. Pay now to secure your spot, the amount stays on hold until delivery.';

  @override
  String get negotiationThreadPayButton => 'Pay';

  @override
  String get negotiationThreadAwaitingSenderPaymentHint =>
      'Price accepted. Awaiting the sender\'s payment.';

  @override
  String get negotiationThreadCashTravelerHint =>
      'Price accepted. Cash payment, you still need to pay the Yadony service fee.';

  @override
  String get negotiationThreadCashSenderHint =>
      'Price accepted. Cash payment, awaiting the traveler, you have nothing to pay here.';

  @override
  String get negotiationThreadClosedAccepted =>
      'Price accepted. Head to your parcel for what\'s next.';

  @override
  String get negotiationThreadClosedRejected => 'Proposal declined.';

  @override
  String get negotiationThreadClosedExpired => 'Proposal expired.';

  @override
  String get negotiationThreadClosedDefault => 'Negotiation closed.';

  @override
  String negotiationThreadWaitingForReply(String name) {
    return 'Waiting for $name\'s reply.';
  }

  @override
  String get negotiationThreadCounterpartyFallback => 'the other party';

  @override
  String get negotiationThreadAcceptButton => 'Accept';

  @override
  String get negotiationThreadCounterButton => 'Counter-propose';

  @override
  String get negotiationThreadRejectButton => 'Decline';

  @override
  String get negotiationThreadCounterSubtitle =>
      'Enter the total amount you\'re proposing. The other party can accept it or respond in turn.';

  @override
  String get negotiationThreadCounterSubmitButton => 'Send my counter-offer';

  @override
  String negotiationThreadCounterAmountLabel(String symbol) {
    return 'Proposed amount ($symbol)';
  }

  @override
  String get negotiationThreadCounterMessageLabel => 'Message (optional)';

  @override
  String get negotiationThreadCounterMessageHint => 'Explain your proposal';

  @override
  String get negotiationThreadPaymentNotConfirmed =>
      'Payment not confirmed, try again';

  @override
  String get negotiationThreadPaymentContextLabel =>
      'Negotiated price for your shipment';

  @override
  String get travelerProfileLoadErrorTitle => 'Loading error';

  @override
  String get travelerProfileLoadErrorDescription => 'Unable to load details';

  @override
  String get profileSheetMoreOptionsTooltip => 'More options';

  @override
  String get profileSheetReviewsTitle => 'Reviews';

  @override
  String get profileSheetNoReviewsYet => 'No reviews yet.';

  @override
  String get profileSheetSeeMoreReviews => 'See more';

  @override
  String get profileSheetProBadge => 'PRO account';

  @override
  String get profileSheetVerifiedBadge => 'Verified identity';

  @override
  String get travelerProfileTripsLabel => 'Trips';

  @override
  String get travelerProfileDeliveryLabel => 'Delivery';

  @override
  String get travelerProfilePhoneHiddenLabel =>
      'Number revealed after acceptance';

  @override
  String get travelerProfileSubscribeLabel => 'Follow this traveler';

  @override
  String get senderProfilePhoneHiddenLabel =>
      '📞 Number revealed after acceptance';

  @override
  String get senderProfilePhoneLoadingLabel => 'Retrieving number…';

  @override
  String get senderProfileShipmentsLabel => 'Shipments';

  @override
  String blockMenuEntryLabel(String name) {
    return 'Block $name';
  }

  @override
  String blockSuccessMessage(String name) {
    return '$name has been blocked';
  }

  @override
  String blockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockConfirmBody =>
      'They won\'t be able to see your listings or send you offers anymore. You won\'t see theirs either. You can unblock them anytime in Privacy.';

  @override
  String get blockConfirmButton => 'Block';

  @override
  String get bidTravelerRoleTag => 'TRAVELER';

  @override
  String get voyageurCardCallSemanticLabel => 'Call';

  @override
  String get voyageurCardOpenChatSemanticLabel => 'Open the conversation';

  @override
  String get negotiationStatusBadgeOpen => 'IN PROGRESS';

  @override
  String get negotiationStatusBadgeAwaitingTrip => 'AWAITING TRIP';

  @override
  String get negotiationStatusBadgeAwaitingPayment => 'PAYMENT';

  @override
  String get negotiationStatusBadgeAwaitingCommission => 'FEE';

  @override
  String get negotiationStatusBadgeAwaitingDeposit => 'DEPOSIT';

  @override
  String get negotiationStatusBadgeAccepted => 'ACCEPTED';

  @override
  String get negotiationStatusBadgeTerminal => 'CLOSED';

  @override
  String get negotiationStatusPriceLabelOpen => 'CURRENT PRICE';

  @override
  String get negotiationStatusPriceLabelAwaitingTrip => 'DEAL AGREED';

  @override
  String get negotiationStatusPriceLabelAwaitingPayment => 'DUE';

  @override
  String get negotiationStatusPriceLabelAwaitingCommission => 'SERVICE FEE DUE';

  @override
  String get negotiationStatusPriceLabelAwaitingDeposit =>
      'DEPOSIT IN PROGRESS';

  @override
  String get negotiationStatusPriceLabelAccepted => 'REQUEST ACCEPTED';

  @override
  String get negotiationStatusPriceLabelTerminal => 'FINAL PRICE';

  @override
  String get negotiationLastRoundWarning =>
      '⚠ Last round: Accept or Decline only';

  @override
  String negotiationRoundCounter(int round, int max) {
    return 'Round $round/$max';
  }

  @override
  String get negotiationMessageNewBadge => 'NEW';

  @override
  String get negotiationMessageKindProposalBadge => 'PROPOSAL';

  @override
  String get negotiationMessageKindCounterBadge => 'COUNTER-OFFER';

  @override
  String get negotiationMessageKindRejectedBadge => 'DECLINED';

  @override
  String get negotiationNudgeSentMessage => 'Reminder sent';

  @override
  String get negotiationNudgeRateLimitedMessage =>
      'Already sent a reminder recently';

  @override
  String get negotiationNudgeGenericErrorMessage =>
      'Can\'t send a reminder right now, try again later';

  @override
  String get negotiationOpenAwaitingReplyTitle => 'Waiting for a reply';

  @override
  String get negotiationOpenAwaitingReplySubtitle =>
      'You\'ll be notified as soon as the other party replies.';

  @override
  String get negotiationAwaitingTripSenderTitle =>
      'The traveler is preparing their trip';

  @override
  String get negotiationAwaitingTripSenderSubtitle =>
      'You\'ll be notified as soon as they\'ve confirmed it.';

  @override
  String get negotiationLinkTripButton => 'Link a trip to this offer';

  @override
  String get negotiationCreateDedicatedTripButton => 'Create a dedicated trip';

  @override
  String negotiationCompleteAndPayButton(String amount) {
    return 'Complete & pay $amount';
  }

  @override
  String get negotiationAwaitingPaymentTravelerTitle =>
      'Waiting for the sender\'s payment';

  @override
  String get negotiationAwaitingPaymentTravelerSubtitle =>
      'You\'ll be notified as soon as they\'ve paid.';

  @override
  String get negotiationAwaitingDepositTravelerTitle =>
      'The sender is paying by mobile money';

  @override
  String get negotiationAwaitingDepositTravelerSubtitle =>
      'You\'ll be notified as soon as the payment is confirmed.';

  @override
  String get negotiationDepositInProgressTitle =>
      'Mobile money deposit in progress';

  @override
  String get negotiationDepositSubtitleDefault =>
      'Confirm the payment on your phone.';

  @override
  String get negotiationDepositSubtitleExpired =>
      'Time\'s up, the thread will go back to “awaiting payment”.';

  @override
  String negotiationDepositSubtitleExpiring(int minutes) {
    return 'Confirm the payment on your phone. Expires in $minutes min.';
  }

  @override
  String get negotiationResumePaymentButton => 'Resume payment';

  @override
  String get negotiationChangePaymentMethodButton => 'Change payment method';

  @override
  String get negotiationAwaitingCommissionSenderTitle =>
      'Waiting for the traveler\'s confirmation';

  @override
  String get negotiationAwaitingCommissionSenderSubtitle =>
      'Your request stays open: you can keep receiving and accepting other offers until they\'ve paid.';

  @override
  String get negotiationCommissionTravelerBannerTitle =>
      'Confirm you\'re taking this parcel';

  @override
  String negotiationCommissionTravelerBannerSubtitle(String amount) {
    return 'The sender picked your offer. Pay the Yadony service fee ($amount) before the deadline to get this parcel, or another traveler could beat you to it.';
  }

  @override
  String get negotiationPayCommissionButton => 'Pay the service fee';

  @override
  String get negotiationDeclineParcelDialogTitle => 'Give up this parcel?';

  @override
  String get negotiationDeclineParcelDialogMessage =>
      'The request will immediately become available to another traveler. This action is final.';

  @override
  String get negotiationDeclineParcelConfirmButton => 'Give up';

  @override
  String get negotiationDeclineParcelButton => 'Give up this parcel';

  @override
  String get negotiationAcceptedPaidTitle => 'Request accepted and paid';

  @override
  String get negotiationAcceptedTitle => 'Request accepted';

  @override
  String get negotiationAcceptedPaidSubtitle =>
      'You can move on to the next tracking steps.';

  @override
  String get negotiationAcceptedCashSubtitle =>
      'Payment is made in cash at parcel drop-off.';

  @override
  String get negotiationAcceptedOtherSubtitle =>
      'Payment is made at parcel drop-off.';

  @override
  String get negotiationViewShipmentButton => 'View my shipment';

  @override
  String get negotiationEndedMessage => 'This negotiation has ended';

  @override
  String get negotiationNudgeButton => 'Send a reminder';

  @override
  String negotiationSenderAcceptButton(String amount) {
    return 'Accept: You pay $amount';
  }

  @override
  String get negotiationDeclineButton => 'Decline';

  @override
  String negotiationTravelerAcceptButton(String amount) {
    return 'Accept: You receive $amount';
  }

  @override
  String get negotiationCommissionCountdownExpired => 'Time\'s up';

  @override
  String negotiationCommissionCountdownHours(int hours, String minutes) {
    return '${hours}h ${minutes}min left';
  }

  @override
  String negotiationCommissionCountdownMinutes(String minutes, String seconds) {
    return '$minutes:$seconds left';
  }

  @override
  String get negotiationRefuseTripAction => 'Decline this trip';

  @override
  String get negotiationConfirmRefusalButton => 'Confirm the refusal';

  @override
  String get negotiationRefuseTripWarning =>
      'The traveler will need to suggest another trip. This action cannot be undone.';

  @override
  String get negotiationRefusalReasonLabel => 'Reason for refusal (optional)';

  @override
  String get negotiationRefusalReasonHint => 'E.g.: wrong date, trip canceled…';

  @override
  String get negotiationLinkedTripSheetTitle => 'Linked trip';

  @override
  String get negotiationTripRouteLabel => 'Route';

  @override
  String get negotiationTripDepartureDateLabel => 'Departure date';

  @override
  String get negotiationTripDepartureTimeLabel => 'Departure time';

  @override
  String get negotiationTripAvailableWeightLabel => 'Available weight';

  @override
  String get negotiationTripPickupAddressLabel => 'Drop-off address';

  @override
  String get negotiationTripDeliveryAddressLabel => 'Delivery address';

  @override
  String get negotiationTripTravelerNoteLabel => 'Traveler\'s note';

  @override
  String get negotiationEndedSnackbar => 'Negotiation ended';

  @override
  String get negotiationRejectedSnackbar => 'Negotiation declined';

  @override
  String get negotiationCommissionSettledSnackbar =>
      'Service fee paid: this parcel is yours!';

  @override
  String get negotiationGaveUpParcelSnackbar =>
      'You\'ve given up this parcel, it\'s available to another traveler again.';

  @override
  String get negotiationFallbackTitle => 'Negotiation';

  @override
  String get negotiationEndMenuItem => 'End the negotiation';

  @override
  String get negotiationEndDialogTitle => 'End this negotiation?';

  @override
  String get negotiationEndDialogMessage => 'This action is final.';

  @override
  String get negotiationEndDialogConfirmButton => 'End it';

  @override
  String get negotiationListTitle => 'Price discussions';

  @override
  String get negotiationEmptyTitle => 'No negotiations';

  @override
  String get negotiationEmptyDescription =>
      'Your active negotiations will show up here as soon as a traveler makes an offer.';

  @override
  String get negotiationSearchHint => 'Traveler, city…';

  @override
  String negotiationFilterAllCountLabel(int count) {
    return 'All ($count)';
  }

  @override
  String negotiationFilterActiveCountLabel(int count) {
    return 'In progress ($count)';
  }

  @override
  String negotiationFilterTerminalCountLabel(int count) {
    return 'Completed ($count)';
  }

  @override
  String get negotiationEmptyActiveFilter => 'No negotiations in progress';

  @override
  String get negotiationEmptyTerminalFilter => 'No completed negotiations';

  @override
  String get negotiationSourcePillRequest => 'Request';

  @override
  String negotiationTravelerFallbackWithId(String id) {
    return 'Traveler $id';
  }

  @override
  String get negotiationStageDealPending => 'deal';

  @override
  String get negotiationStageDepositInProgress => 'deposit in progress';

  @override
  String get negotiationStageCommissionDue => 'service fee due';

  @override
  String get negotiationStagePaid => 'paid';

  @override
  String get negotiationTripCardCounterpartyFallback => 'Counterpart';

  @override
  String negotiationTripCardRoundLabel(int round, String timeAgo) {
    return 'Round $round · $timeAgo';
  }

  @override
  String get negotiationLinkTripScreenTitle => 'Link a trip';

  @override
  String get negotiationSelectTripLabel => 'Select a trip';

  @override
  String get negotiationConfirmTripLabel => 'Confirm this trip';

  @override
  String get negotiationSelectedTripCount => '1 trip';

  @override
  String negotiationLinkTripDate(String date) {
    return 'Travel date: $date';
  }

  @override
  String negotiationLinkTripKgAvailable(String kg) {
    return '$kg kg available';
  }

  @override
  String negotiationAcceptedAtPriceBanner(String amount) {
    return 'Request accepted at $amount';
  }

  @override
  String get negotiationSenderChoosesAmong => 'The sender will choose from';

  @override
  String get errorCommissionConfirmFailedTitle => 'Payment not confirmed';

  @override
  String get errorCommissionConfirmFailedMessage =>
      'We couldn\'t confirm the payment';

  @override
  String get errorCommission3dsInterruptedTitle => 'Authentication interrupted';

  @override
  String get errorCommission3dsInterruptedMessage =>
      'Bank authentication was interrupted';

  @override
  String get errorCommissionFailedTitle => 'Payment declined';

  @override
  String get errorCommissionFailedMessage =>
      'The service fee payment was declined';

  @override
  String get errorCommissionFailedNoCardMessage =>
      'No card is registered to pay the service fee.';

  @override
  String get errorCommissionFailedCardDeclinedMessage =>
      'Your card was declined.';

  @override
  String get errorCommissionFailedStripeErrorMessage =>
      'Payment service error, please try again.';

  @override
  String get errorCommissionFailedCardStatusMessage =>
      'The card payment didn\'t go through.';

  @override
  String get bidAcceptConfirmFailed => 'Confirmation failed';

  @override
  String get bidAcceptBankAuthInterrupted =>
      'Bank authentication was interrupted';

  @override
  String get bidAcceptRefused => 'Acceptance declined';

  @override
  String get negotiationMakeOfferTitle => 'Make an offer';

  @override
  String negotiationMakeOfferTakeAtLabel(String amount) {
    return 'Take for $amount';
  }

  @override
  String get negotiationMakeOfferSendButtonLabel => 'Send offer';

  @override
  String get negotiationMakeOfferSelectTravelDate => 'Select your travel date';

  @override
  String get negotiationMakeOfferSelectTrip => 'Select or create a trip';

  @override
  String get negotiationMakeOfferYourPriceLabel => 'YOUR PRICE';

  @override
  String get negotiationMakeOfferCapacityLabel => 'CAPACITY';

  @override
  String get negotiationMakeOfferTravelDateLabel => 'TRAVEL DATE';

  @override
  String get negotiationMakeOfferSelectDatePlaceholder => 'Select…';

  @override
  String get negotiationMakeOfferMessageLabel => 'MESSAGE';

  @override
  String get negotiationMakeOfferMessageOptional => 'optional';

  @override
  String get negotiationMakeOfferMessageHint =>
      'I\'m traveling on that exact day…';

  @override
  String get negotiationMakeOfferInvalidPrice => 'Invalid';

  @override
  String get negotiationMakeOfferOfferSentSnackbar => 'Offer sent';

  @override
  String get negotiationMakeOfferMarketPriceLabel => 'Market price';

  @override
  String get negotiationPaySecurelyTitle => 'Pay securely';

  @override
  String get negotiationAcceptOfferTitle => 'Accept the offer';

  @override
  String get negotiationProcessingLabel => 'Processing…';

  @override
  String negotiationAcceptOfferPayButtonLabel(String amount) {
    return 'Pay ($amount)';
  }

  @override
  String negotiationAcceptOfferConfirmButtonLabel(String amount) {
    return 'Confirm ($amount)';
  }

  @override
  String get negotiationAcceptOfferPaymentContextTraveler =>
      'Payment for the accepted offer';

  @override
  String get negotiationAcceptOfferPaymentContextSender =>
      'Payment for your offer';

  @override
  String get negotiationOfferAcceptedPaidTitle => 'Offer accepted and paid!';

  @override
  String get negotiationOfferAcceptedPaidSubtitle =>
      'Your money is held and secured, the traveler only receives it once delivery is confirmed. Track your parcel from the thread.';

  @override
  String get negotiationTrackShipmentCta => 'Track your shipment';

  @override
  String get negotiationAcceptOfferAgreedSubtitleSender =>
      'You\'ve agreed on the price. The traveler will confirm their trip, then you\'ll finalize the shipment details and payment from the thread.';

  @override
  String get negotiationAcceptOfferAgreedSubtitleTravelerLinked =>
      'You\'ve agreed on the price. The sender will finalize the shipment details and payment, you\'ll be notified at every step.';

  @override
  String get negotiationAcceptOfferAgreedSubtitleTravelerUnlinked =>
      'You\'ve agreed on the price. Next step: link or create a trip for this offer so the sender can finalize the payment.';

  @override
  String get negotiationAgreementConfirmedTitle => 'Agreement confirmed!';

  @override
  String get negotiationGenericErrorSnackbar =>
      'Something went wrong. Please try again.';

  @override
  String get negotiationPriceBreakdownPaidBySender =>
      'Price paid by the sender';

  @override
  String get negotiationPriceBreakdownNetTraveler => 'Traveler net';

  @override
  String get negotiationPriceBreakdownYouReceive => 'You receive';

  @override
  String get negotiationPriceBreakdownTotalToSettle => 'Total to settle';

  @override
  String get negotiationPriceBreakdownPromoBadge => 'Promo';

  @override
  String negotiationAcceptOfferInfoTraveler(String price) {
    return 'By accepting, the sender will make the payment. You\'ll receive $price once delivery is confirmed, regardless of any promo code the sender uses.';
  }

  @override
  String get negotiationAcceptOfferInfoSender =>
      'By confirming, the payment is held and secured. The traveler receives the amount once delivery is confirmed.';

  @override
  String get negotiationCounterOfferTitle => 'Make a counter-offer';

  @override
  String negotiationCounterOfferSubtitle(String priceLabel, int round) {
    return '$priceLabel · Round $round/5';
  }

  @override
  String get negotiationCounterOfferYourPriceLabel => 'Your proposed price';

  @override
  String get negotiationCounterOfferMessageLabel => 'Message (optional)';

  @override
  String get negotiationCounterOfferMessageHint => 'Explain your offer…';

  @override
  String get negotiationRejectTitle => 'Decline the negotiation';

  @override
  String get negotiationRejectConfirmLabel => 'Confirm decline';

  @override
  String get negotiationRejectReasonLabel => 'Reason (optional)';

  @override
  String get negotiationPaymentRecapConfirmAgreementTitle =>
      'Confirm the agreement';

  @override
  String get negotiationPaymentRecapMobileMoneyTitle => 'Pay by mobile money';

  @override
  String negotiationPaymentRecapPayButtonLabel(String amount) {
    return 'Pay $amount';
  }

  @override
  String negotiationPaymentRecapPayMobileMoneyButton(String amount) {
    return 'Pay $amount by mobile money';
  }

  @override
  String get negotiationPaymentRecapContextConfirm =>
      'Confirming the agreement';

  @override
  String get negotiationPaymentRecapContextSecure => 'Secure payment';

  @override
  String get negotiationPaymentRecapCashSuccessSubtitle =>
      'Cash payment: you hand the amount to the traveler in person, at parcel drop-off. If canceled after drop-off, Yadony can\'t refund you immediately but will make sure the traveler gives your money back.';

  @override
  String get negotiationPaymentRecapCashHandoverLabel =>
      'To hand over to the traveler (in cash)';

  @override
  String get negotiationPaymentRecapCashFeeNote =>
      'including Yadony fees (paid by the traveler)';

  @override
  String get negotiationPaymentRecapCashNetLabel => 'The traveler keeps net';

  @override
  String get negotiationPaymentRecapTravelerReceivesLabel =>
      'The traveler receives';

  @override
  String get negotiationPaymentRecapServiceFeeLabel => 'Yadony service fee';

  @override
  String get negotiationPaymentRecapTotalToPayLabel => 'Total to pay';

  @override
  String get negotiationPaymentRecapCashNote =>
      'Hand over the full amount in cash to the traveler at parcel drop-off. The traveler will deduct their Yadony fees from that amount.';

  @override
  String get negotiationPaymentRecapMobileMoneyNote =>
      'A payment request arrives on the number shown below. The traveler receives the amount only after delivery is confirmed.';

  @override
  String get negotiationPaymentRecapSecureNote =>
      'The amount is held and secured. The traveler receives it only after delivery is confirmed.';

  @override
  String get negotiationPaymentRecapCashBannerMessage =>
      'Cash payment in person at drop-off';

  @override
  String get negotiationPaymentRecapMobileMoneyBannerMessage =>
      'You confirm the payment on your phone. Yadony holds the money and only releases it to the traveler once delivery is confirmed.';

  @override
  String get negotiationPaymentRecapSecureBannerMessage =>
      'Secure · held until delivery';

  @override
  String get negotiationCommissionSettlementTitle => 'Insufficient balance';

  @override
  String get negotiationCommissionSettlementHint =>
      'Top up your wallet or pay the service fee directly by card.';

  @override
  String get negotiationCommissionSettlementTopupButton => 'Top up my wallet';

  @override
  String get negotiationCommissionSettlementPayCardButton => 'Pay by card';

  @override
  String get negotiationCommissionSettlementAddCardButton => 'Add a card';

  @override
  String get negotiationCardCapabilityRequiredTitle => 'Card payment required';

  @override
  String get negotiationCardCapabilityUnavailableTitle => 'Parcel unavailable';

  @override
  String get negotiationCardCapabilityRequiredBody =>
      'The sender only accepts card payment for this parcel. Activate card payments to link this trip.';

  @override
  String get negotiationCardCapabilityUnavailableBody =>
      'The sender only accepts card payment for this parcel, and Stripe doesn\'t yet support opening a payment account from your country. You can link parcels paid in cash.';

  @override
  String get negotiationCardCapabilityActivateButton =>
      'Activate card payments';

  @override
  String get negotiationCardCapabilityUnderstoodButton => 'Got it';

  @override
  String negotiationCardRoundShortLabel(int round, String timeAgo) {
    return 'Rd. $round/5 · $timeAgo';
  }

  @override
  String get negotiationMakeOfferConfidenceHigh => 'high';

  @override
  String get negotiationMakeOfferConfidenceMedium => 'medium';

  @override
  String get negotiationMakeOfferConfidenceLow => 'low';

  @override
  String get profileSheetRatingLabel => 'Rating';
}
