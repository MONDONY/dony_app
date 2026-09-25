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

  @override
  String bidDetailUntil(String date) {
    return 'until $date';
  }

  @override
  String get bidDetailFallbackDestination => 'destination';

  @override
  String get bidDetailReportNoShowConfirmButton => 'Report the no-show';

  @override
  String get bidDetailContestButton => 'I contest';

  @override
  String get bidDetailNoShowReportedTitle => '⏳ No-show reported';

  @override
  String get bidDetailNoShowContestedTitle => '⚖ No-show contested';

  @override
  String get bidDetailDeliveryNoShowReporterContestedSubtitle =>
      'The other party is contesting your report. Our team is reviewing the request and will keep you informed.';

  @override
  String get bidDetailDeliveryNoShowReporterPendingSubtitle =>
      'Report sent. The other party has 24 hours to contest. Our team will then decide.';

  @override
  String get bidDetailDeliveryNoShowContestSentTitle => '⚖ Contest sent';

  @override
  String get bidDetailDeliveryNoShowAlertTitle =>
      '⚠ A no-show has been reported';

  @override
  String get bidDetailDeliveryNoShowContestSentSubtitle =>
      'Your contest has been sent. Our team is reviewing the request and will keep you informed.';

  @override
  String get bidDetailDeliveryNoShowAlertSubtitle =>
      'A delivery no-show has been reported on this shipment. You can contest it if this report is wrong.';

  @override
  String get bidDetailDeliveryNoShowContestButton => 'Contest this report';

  @override
  String get bidDetailSenderPendingTitle => '⏳ Waiting for the traveler';

  @override
  String get bidDetailSenderPendingSubtitle =>
      'You\'ll be notified as soon as they reply.';

  @override
  String get bidDetailSenderAwaitingPaymentTitle =>
      'Pay to confirm the shipment';

  @override
  String bidDetailSenderAwaitingPaymentSubtitle(String amount) {
    return 'Your payment of $amount will be held until delivery.';
  }

  @override
  String get bidDetailSenderEscrowedTitle => '🔒 Payment secured';

  @override
  String bidDetailSenderEscrowedSubtitle(String amount) {
    return '$amount on hold. Awaiting drop-off.';
  }

  @override
  String get bidDetailSenderAcceptedTitle => '⚡ Parcel drop-off';

  @override
  String get bidDetailSenderAcceptedInstructions =>
      'Show the QR code, or stick it on the parcel.';

  @override
  String get bidDetailSenderTravelerFallback => 'the traveler';

  @override
  String bidDetailSenderHandedOverTitle(String name) {
    return '✓ Parcel handed to $name';
  }

  @override
  String bidDetailSenderHandedOverSubtitleWithDate(String date) {
    return 'Boarding scheduled for $date.';
  }

  @override
  String get bidDetailSenderHandedOverSubtitleDefault => 'Parcel handed over.';

  @override
  String get bidDetailSenderInTransitTitle => '✈ Parcel in flight';

  @override
  String bidDetailSenderInTransitEta(String time, String city) {
    return 'Arrival expected $time in $city.';
  }

  @override
  String bidDetailSenderInTransitEnRoute(String city) {
    return 'On the way to $city.';
  }

  @override
  String get bidDetailSenderInTransitTicketNote =>
      'The pickup code is on your ticket.';

  @override
  String get bidDetailSenderArrivedTitle => '📍 Parcel arrived at destination';

  @override
  String get bidDetailSenderArrivedSubtitleDefault =>
      'The traveler has arrived, pickup instructions are coming soon.';

  @override
  String get bidDetailSenderRecipientFallback => 'your recipient';

  @override
  String bidDetailSenderDeliveredTitle(String recipient) {
    return '✓ Delivered to $recipient';
  }

  @override
  String get bidDetailSenderDeliveredSubtitle =>
      'Payment released to the traveler.';

  @override
  String get bidDetailSenderWindowExpiredTitle => '⚠ Drop-off window expired';

  @override
  String bidDetailSenderWindowExpiredSubtitle(String window) {
    return 'Drop-off was possible $window. Did the traveler not show up?';
  }

  @override
  String get bidDetailSenderReportNoShowButton =>
      'Report the traveler\'s no-show';

  @override
  String get bidDetailSenderNoShowSheetTitle => 'Did the traveler not show up?';

  @override
  String get bidDetailSenderNoShowSheetBody =>
      'The traveler didn\'t show up at the drop-off point.';

  @override
  String get bidDetailSenderNoShowSheetHint =>
      'The traveler will have 48 hours to contest. If they don\'t respond, the shipment will be canceled.';

  @override
  String get bidDetailSenderContestationExpired => 'Expired';

  @override
  String bidDetailSenderContestCountdown(String timeLeft) {
    return '⏱ Time left to contest: $timeLeft';
  }

  @override
  String get bidDetailSenderNoShowByTravelerTitle =>
      '⚠ No-show reported by the traveler';

  @override
  String get bidDetailSenderNoShowByTravelerSubtitle =>
      'They indicate you weren\'t at the drop-off point.';

  @override
  String get bidDetailSenderConfirmNoShowButton => 'I confirm';

  @override
  String get bidDetailSenderContestSheetTitle => 'Contest the no-show';

  @override
  String get bidDetailSenderContestConfirmButton => 'Confirm the contest';

  @override
  String get bidDetailSenderContestSheetBody =>
      'You\'re contesting the no-show reported by the traveler.';

  @override
  String get bidDetailSenderContestSheetHint =>
      'Our team will review your request and contact you within 24 hours.';

  @override
  String get bidDetailSenderConfirmSheetTitle => 'Confirm your no-show';

  @override
  String get bidDetailSenderConfirmSheetButton => 'Confirm my no-show';

  @override
  String get bidDetailSenderConfirmSheetBody =>
      'By confirming your no-show, the shipment will be canceled and you won\'t be charged.';

  @override
  String get bidDetailTravelerPendingTitle => '📨 New shipment request';

  @override
  String bidDetailTravelerPendingSubtitle(String amount) {
    return 'Potential earnings: $amount. Accept or decline the request.';
  }

  @override
  String get bidDetailTravelerScanQrTitle => '📷 Scan the parcel\'s QR code';

  @override
  String get bidDetailTravelerScanQrSubtitle =>
      'Scan the sender\'s QR code to confirm the drop-off.';

  @override
  String get bidDetailTravelerAcceptedTitle => '⚡ Collect the parcel';

  @override
  String get bidDetailTravelerAcceptedInstructions =>
      'Be at the drop-off point.';

  @override
  String get bidDetailTravelerAcceptedInstructionsDefault =>
      'Be at the drop-off point agreed with the sender.';

  @override
  String get bidDetailTravelerCollectedTitle => '✓ Parcel collected';

  @override
  String get bidDetailTravelerCollectedSubtitle =>
      'You have the parcel. Have a safe trip!';

  @override
  String get bidDetailTravelerInTransitTitle => '✈ Parcel on its way';

  @override
  String bidDetailTravelerInTransitSubtitle(String city) {
    return 'In transit to $city. Have a good delivery!';
  }

  @override
  String get bidDetailTravelerArrivedTitle => '📍 Arrived at destination';

  @override
  String get bidDetailTravelerArrivedSubtitle =>
      'Wait for the recipient to pick up the parcel, then confirm the drop-off.';

  @override
  String get bidDetailTravelerDeliveredTitle => '✓ Delivery confirmed';

  @override
  String get bidDetailTravelerDeliveredSubtitle =>
      'The payment will be released to your account.';

  @override
  String get bidDetailTravelerWindowExpiredTitle =>
      '⚠ Drop-off deadline passed';

  @override
  String bidDetailTravelerWindowExpiredSubtitleWithWindow(String window) {
    return 'Drop-off was possible $window. Did the sender not show up?';
  }

  @override
  String get bidDetailTravelerWindowExpiredSubtitleDefault =>
      'Did the sender not show up at the drop-off point?';

  @override
  String get bidDetailTravelerReportNoShowButton =>
      'Report the sender\'s no-show';

  @override
  String get bidDetailTravelerNoShowSheetTitle => 'Did the sender not show up?';

  @override
  String get bidDetailTravelerNoShowSheetBody =>
      'The sender didn\'t show up at the drop-off point.';

  @override
  String get bidDetailTravelerNoShowSheetHint =>
      'The sender will have 48 hours to contest. If they don\'t respond, the shipment will be canceled.';

  @override
  String get bidDetailTravelerNoShowContestedSubtitle =>
      'The sender is contesting your report. Our team is reviewing the request and will keep you informed.';

  @override
  String get bidDetailTravelerNoShowPendingSubtitle =>
      'Report sent. The sender has 48 hours to confirm or contest. If there\'s no response, the shipment will be canceled automatically.';

  @override
  String get bidDetailGainCashTopLabel => 'YOU COLLECT';

  @override
  String bidDetailGainCashAmount(String amount) {
    return '$amount in cash';
  }

  @override
  String get bidDetailGainCashNote => 'Yadony service fee charged separately.';

  @override
  String get bidDetailGainCashPill => 'CASH';

  @override
  String get bidDetailGainReceivedTopLabel => 'YOU RECEIVED';

  @override
  String get bidDetailGainMobileMoneyPaidNote =>
      'Paid to your mobile money account.';

  @override
  String get bidDetailGainPaidPill => '● Paid';

  @override
  String get bidDetailGainReceivingTopLabel => 'YOU RECEIVE';

  @override
  String get bidDetailGainMobileMoneyPendingNote =>
      'Paid to your mobile money account on delivery.';

  @override
  String get bidDetailGainMobileMoneyPill => '📱 mobile money';

  @override
  String get bidDetailGainReceivedPill => '● Received';

  @override
  String get bidDetailGainCancelledTopLabel => 'PAYMENT';

  @override
  String get bidDetailGainCancelledNote => 'Payment canceled.';

  @override
  String get bidDetailGainEscrowedNote => 'Released on delivery.';

  @override
  String get bidDetailGainEscrowedPill => '🔒 on hold';

  @override
  String get bidDetailCardDeclinedTitle => 'Payment declined';

  @override
  String get bidDetailCardDeclinedHint =>
      'Change the card used for your service fee to accept this request.';

  @override
  String get bidDetailChangeCommissionCard => 'Change my service fee card';

  @override
  String get bidDetailInsufficientBalanceTitle => 'Insufficient balance';

  @override
  String get bidDetailInsufficientBalanceHint =>
      'Top up your wallet or pay the service fee directly by card.';

  @override
  String get bidDetailTopupWallet => 'Top up my wallet';

  @override
  String get bidDetailPayByCard => 'Pay by card';

  @override
  String get bidDetailAddCard => 'Add a card';

  @override
  String get bidDetailAcceptedSetHandoverWindow =>
      'Request accepted! Now set the drop-off window.';

  @override
  String get bidDetailNoShowReportedSnackbar =>
      'No-show reported. The sender has 48 hours to contest.';

  @override
  String get bidDetailDeliveryNoShowReportedSnackbar =>
      'No-show reported. The other party has 24 hours to contest.';

  @override
  String get bidDetailContestSentSnackbar =>
      'Contest sent. Our team will review your request.';

  @override
  String get bidDetailNoShowConfirmedSnackbar =>
      'No-show confirmed. The shipment has been canceled, you will not be charged.';

  @override
  String get bidDetailCancelledAfterHandoverSnackbar =>
      'Trip canceled. Return the parcel within 3 days using the return code.';

  @override
  String get bidDetailReturnConfirmedSnackbar =>
      'Return confirmed. The parcel has been returned.';

  @override
  String get bidDetailAcceptedSnackbar => 'Request accepted!';

  @override
  String get bidDetailRejectedSnackbar => 'Request declined.';

  @override
  String get bidDetailPresenceConfirmedSnackbar => 'Presence confirmed!';

  @override
  String get bidDetailCancelledSnackbar =>
      'Request canceled. The sender will be refunded.';

  @override
  String get bidDetailDeletedSnackbar => 'Request deleted.';

  @override
  String get bidDetailNotFoundSnackbar => 'This parcel no longer exists';

  @override
  String get bidDetailShareTracking => 'Share tracking';

  @override
  String get bidDetailOptionsTitle => 'Options';

  @override
  String get bidDetailDeclineRequestTitle => 'Decline the request';

  @override
  String get bidDetailDeclineRequestSubtitle =>
      'Would you like to give the sender a reason?';

  @override
  String get bidDetailConfirmDecline => 'Confirm the decline';

  @override
  String get bidDetailReasonHint => 'Reason (optional)';

  @override
  String get bidDetailConfirmPresence => 'Confirm my presence';

  @override
  String get bidDetailPayMyShipment => 'Pay for my shipment';

  @override
  String get bidDetailDeleteRequest => 'Delete this request';

  @override
  String get bidDetailDeleteRejectedBody =>
      'This declined request will be permanently removed from your list.';

  @override
  String bidDetailEscrowReleasedLabel(String amount) {
    return 'Traveler paid · $amount';
  }

  @override
  String bidDetailEscrowRefundedLabel(String amount) {
    return 'Refunded · $amount';
  }

  @override
  String get bidDetailEscrowFailedLabel => 'Payment failed';

  @override
  String get bidDetailEscrowSecuredPendingLabel =>
      'Payment secured · Awaiting the traveler';

  @override
  String bidDetailEscrowSecuredLabel(String amount) {
    return 'Payment secured · $amount';
  }

  @override
  String get bidDetailCashAtDropoffLabel => 'Cash payment at drop-off';

  @override
  String get bidDetailMobileMoneyPaymentLabel => 'Mobile money payment';

  @override
  String get bidDetailReportTripLabel => 'Report this trip';

  @override
  String get bidDetailReportSubtitle => 'Report a problem to Yadony support';

  @override
  String get bidDetailContactTravelerLabel => 'Contact the traveler';

  @override
  String get bidDetailContactTravelerSubtitle =>
      'Send a message to the traveler';

  @override
  String get bidDetailShareTrackingSubtitle =>
      'Send the tracking link to the recipient';

  @override
  String get bidDetailCancelRefundAutoSubtitle =>
      'Your payment will be refunded automatically';

  @override
  String get bidDetailCancelAfterHandoverOptionSubtitle =>
      'Full refund · you get your parcel back';

  @override
  String get bidDetailRemoveFromHistorySubtitle =>
      'Permanently remove from your history';

  @override
  String get bidDetailCancelConfirmBody =>
      'Are you sure you want to cancel your shipment request? This action is final.';

  @override
  String get bidDetailNo => 'No';

  @override
  String get bidDetailConfirmCancelButton => 'Yes, cancel';

  @override
  String get bidDetailCancelAfterHandoverTitle => 'Cancel after drop-off?';

  @override
  String get bidDetailCancelAfterHandoverBody =>
      'The parcel is already with the traveler. You will be fully refunded and get your parcel back: the traveler will confirm the return by entering your return code.';

  @override
  String get bidDetailDeleteConfirmBody =>
      'This request will be permanently deleted from your history.';

  @override
  String get bidDetailMoreDetails => 'More details';

  @override
  String get bidDetailSectionDropoff => 'PARCEL DROP-OFF';

  @override
  String get bidDetailLocationLabel => 'Location';

  @override
  String get bidDetailHandoverStatusLabel => 'Drop-off';

  @override
  String get bidDetailPresenceConfirmedLabel => 'Presence confirmed';

  @override
  String get bidDetailParcelHandedOverValue => 'Parcel handed over ✓';

  @override
  String get bidDetailYesValue => 'Yes ✓';

  @override
  String get bidDetailNotYetValue => 'Not yet';

  @override
  String get bidDetailPricePerKgLabel => 'Price per kg';

  @override
  String get bidDetailSectionTrackingLink => 'TRACKING LINK';

  @override
  String get bidDetailSectionLegal => 'LEGAL LIABILITY';

  @override
  String get bidDetailDisclaimerSignedNoDate => 'Disclaimer signed';

  @override
  String bidDetailDisclaimerSignedCompact(String date, String time) {
    return 'Disclaimer signed on $date $time';
  }

  @override
  String get bidDetailContactSenderLabel => 'Contact the sender';

  @override
  String get bidDetailContactSenderSubtitle => 'Send a message to the sender';

  @override
  String get bidDetailParcelDetailsLabel => 'Parcel details';

  @override
  String get bidDetailParcelDetailsSubtitle =>
      'View the parcel and recipient information';

  @override
  String get bidDetailReportSenderLabel => 'Report the sender';

  @override
  String get bidDetailCancelTransportLabel => 'Cancel this transport';

  @override
  String get bidDetailCancelTransportHandedOverSubtitle =>
      'You will need to return the parcel within 3 days';

  @override
  String get bidDetailCancelTransportAcceptedSubtitle =>
      'The sender will be refunded automatically';

  @override
  String get bidDetailPayByMobileMoney => 'Pay by mobile money';

  @override
  String get bidDetailShowPickupQr => 'Show the drop-off QR';

  @override
  String get bidDetailTrackParcel => 'Track my parcel';

  @override
  String get bidDetailRateTraveler => 'Rate the traveler';

  @override
  String get bidDetailCancelTransportRequestTitle =>
      'Cancel the transport request?';

  @override
  String get bidDetailCancelTransportRequestBody =>
      'No payment has been made. The request will be withdrawn.';

  @override
  String get bidDetailDeleteRequestQuestionTitle => 'Delete this request?';

  @override
  String get bidDetailDeleteRequestDefaultBody =>
      'It will be permanently removed from your history.';

  @override
  String get bidDetailAwaitingSenderMobileMoneyPayment =>
      'Awaiting the sender\'s payment (mobile money).';

  @override
  String get bidDetailScanParcelQr => 'Scan the parcel QR';

  @override
  String get bidDetailScanTransitQr => 'Scan the transit QR';

  @override
  String get bidDetailConfirmHandover => 'Confirm the drop-off';

  @override
  String get bidDetailQrSheetTitle => 'Parcel QR';

  @override
  String get bidDetailQrSaveErrorSnackbar => 'Unable to save the image';

  @override
  String get bidDetailQrSavedSnackbar => 'QR code saved to your gallery';

  @override
  String get bidDetailQrShareSubject => 'Yadony parcel QR';

  @override
  String get bidDetailQrShareText => 'QR to show or stick on the parcel.';

  @override
  String get bidDetailQrShareErrorSnackbar => 'Unable to share the QR code';

  @override
  String get bidDetailQrInstructions =>
      'Scanned by the traveler at drop-off, then at every step until pickup. You can also print it and stick it on the parcel.';

  @override
  String get bidDetailReturnCodeTitle => 'Return code';

  @override
  String get bidDetailReturnCodeSubtitle =>
      'To share with the traveler when picking up your parcel';

  @override
  String get bidDetailReturnCodeCopiedSnackbar => 'Code copied';

  @override
  String get bidDetailReturnCopyCode => 'Copy the code';

  @override
  String bidDetailReturnDeadlineHint(String date) {
    return 'The traveler must return the parcel to you before $date. Only give them this code when picking up your parcel.';
  }

  @override
  String get bidDetailReturnNoDeadlineHint =>
      'Only give this code to the traveler when picking up your parcel.';

  @override
  String get bidDetailReturnedTitle => 'Parcel returned';

  @override
  String get bidDetailReturnedSubtitle =>
      'The traveler has confirmed returning the parcel to you.';

  @override
  String get bidDetailReturnEntryTitle => 'Confirm the return';

  @override
  String get bidDetailReturnEntrySubtitle =>
      'Enter the return code provided by the sender';

  @override
  String get bidDetailReturnConfirmButton => 'Confirm the return';

  @override
  String get bidDetailReturnConfirmHint =>
      'By confirming, you declare that you have returned the parcel to the sender.';

  @override
  String get ticketPickupCode => 'Pickup code';

  @override
  String get bidDetailPaymentCardTitle => 'Payment';

  @override
  String bidDetailMobileMoneySecuredLabel(String amount) {
    return 'Mobile money payment, kept safe by Yadony until delivery: $amount';
  }

  @override
  String get bidDetailMobileMoneyBadge => 'MOBILE MONEY';

  @override
  String bidDetailCashAtDropoffAmountLabel(String amount) {
    return 'To pay in cash at drop-off: $amount';
  }

  @override
  String get bidDetailCashBadge => 'CASH';

  @override
  String get bidDetailPaymentReleasedLabel => 'Payment released ✓';

  @override
  String bidDetailAmountRefundedLabel(String amount) {
    return '$amount refunded';
  }

  @override
  String bidDetailEscrowedUntilDeliveryLabel(String amount) {
    return '$amount on hold: released at delivery';
  }

  @override
  String bidDetailShareTrackingMessage(String url) {
    return 'Track your Yadony parcel in real time:\n$url';
  }

  @override
  String bidDetailTrackingShareSubject(String number) {
    return 'Yadony parcel tracking · $number';
  }

  @override
  String get bidSenderRoleTag => 'SENDER';

  @override
  String get bidDetailRatingSentBadge => 'Rating sent';

  @override
  String get bidDetailParcelRecipientTitle => 'Parcel & recipient';

  @override
  String get bidDetailCancelRequestLabel => 'Cancel the request';

  @override
  String get bidDetailParcelLabel => 'Parcel';

  @override
  String get bidDetailRecipientLabel => 'Recipient';

  @override
  String get bidDetailPhoneLabel => 'Phone';

  @override
  String get bidDetailDescriptionLabel => 'Description';

  @override
  String get bidDetailSenderCallSemanticLabel => 'Call';

  @override
  String get bidDetailSenderOpenChatSemanticLabel => 'Open the conversation';

  @override
  String get bidDetailCopyTrackingLinkButton => 'Copy the link';

  @override
  String get bidDetailTrackingLinkCopiedMessage => 'Link copied';

  @override
  String get bidDetailAcceptRequestButton => 'Accept';

  @override
  String get bidDetailDeclineRequestButton => 'Decline';

  @override
  String get ticketReturnCodeButton => 'Return code';

  @override
  String get ticketConfirmReturnButton => 'Confirm the return';

  @override
  String get ticketParcelReturnedLabel => 'Parcel returned';

  @override
  String get ticketViewAlternativeTripsButton => 'View alternative trips';

  @override
  String get ticketQrButtonCompact => 'Parcel QR';

  @override
  String get ticketQrButtonFull => 'Parcel QR (to show or stick on the parcel)';

  @override
  String get ticketScanStepsButton => 'Scan the step QR codes';

  @override
  String get ticketAwaitingTravelerConfirmation =>
      'Waiting for the traveler\'s confirmation';

  @override
  String get ticketSenderAwaitingMobileMoneyHint =>
      'The traveler has accepted: pay by mobile money from the button below to secure your shipment.';

  @override
  String get ticketTravelerAwaitingPayment =>
      'Waiting for the sender\'s payment';

  @override
  String get ticketParcelDeliveredLabel => 'Parcel delivered';

  @override
  String get ticketRequestClosedMessage => 'This request is closed.';

  @override
  String get ticketMiniStatWeightLabel => 'WEIGHT';

  @override
  String get ticketMiniStatCategoryLabel => 'TYPE';

  @override
  String get ticketPickupCodeSectionLabel => 'PICKUP CODE';

  @override
  String get ticketCopyCodeButton => 'Copy the code';

  @override
  String get ticketCodeCopiedSnackbar => 'Code copied';

  @override
  String get ticketUpdatingLabel => 'Updating…';

  @override
  String get ticketHideCodeFromTrackingPageButton =>
      'Remove the code from the tracking page';

  @override
  String get ticketShowCodeOnTrackingPageButton =>
      'Show the code on the tracking page';

  @override
  String get ticketCodeVisibleOnTrackingPageLabel =>
      'Code visible on the tracking page';

  @override
  String get ticketRegeneratingLabel => 'Regenerating…';

  @override
  String ticketRegenerateAvailableInLabel(String remaining) {
    return 'Available in $remaining';
  }

  @override
  String get ticketRegenerateCodeButton => 'Regenerate the code';

  @override
  String ticketRegenerateLimitReachedMessage(String remaining) {
    return 'Limit of 5 regenerations reached. The button will reactivate automatically in $remaining.';
  }

  @override
  String get ticketShareCodeManuallyHint =>
      'Share this code with the traveler by your own means (SMS, WhatsApp…). They will need to enter it at delivery.';

  @override
  String get ticketStatusAwaitingPaymentSenderLabel => 'To pay';

  @override
  String get ticketStatusAwaitingPaymentTravelerLabel => 'Payment pending';

  @override
  String get ticketStatusPendingLabel => 'Pending';

  @override
  String get ticketStatusAcceptedLabel => 'Confirmed';

  @override
  String get ticketStatusHandedOverLabel => 'On the way';

  @override
  String get ticketStatusInTransitLabel => 'In transit';

  @override
  String get ticketStatusArrivedLabel => 'Arrived';

  @override
  String get ticketStatusDeliveredLabel => 'Delivered';

  @override
  String get ticketStatusRejectedLabel => 'Declined';

  @override
  String get ticketStatusCancelledLabel => 'Canceled';

  @override
  String get ticketStatusNoShowLabel => 'No-show';

  @override
  String get ticketStatusParcelRefusedLabel => 'Parcel refused';

  @override
  String get ticketStatusExpiredLabel => 'Expired';

  @override
  String get ticketScanQrActionLabel => 'Scan the parcel QR';

  @override
  String get ticketScanQrActionHint => 'At drop-off, scan the sender\'s QR.';

  @override
  String get ticketConfirmDeliveryActionLabel => 'Confirm the delivery';

  @override
  String get ticketConfirmDeliveryActionHint =>
      'On arrival, enter the sender\'s pickup code.';

  @override
  String ticketShareTrackingMessage(String trackingNumber) {
    return 'Track my Yadony parcel #$trackingNumber';
  }

  @override
  String ticketShareTrackingMessageWithLink(
    String trackingNumber,
    String link,
  ) {
    return 'Track my Yadony parcel #$trackingNumber in real time:\n$link';
  }

  @override
  String get ticketTrackingNumberSectionLabel => 'TRACKING NUMBER';

  @override
  String get ticketTrackingNumberCopiedSnackbar => 'Number copied';

  @override
  String get ticketHeaderTagline => 'YADONY · PARCEL TRANSPORT';

  @override
  String get ticketDepartureLabel => 'Departure';

  @override
  String get ticketArrivalLabel => 'Arrival';

  @override
  String get shipmentBadgeInTransit => 'IN TRANSIT';

  @override
  String get shipmentBadgeArrived => 'ARRIVED';

  @override
  String get shipmentBadgeHandedOver => 'HANDED OVER';

  @override
  String get shipmentBadgeToHandOver => 'DROP-OFF DUE';

  @override
  String get shipmentBadgeWaiting => 'PENDING';

  @override
  String get shipmentBadgeDelivered => 'DELIVERED';

  @override
  String get shipmentBadgeCancelled => 'CANCELED';

  @override
  String get shipmentBadgeRejected => 'DECLINED';

  @override
  String get shipmentBadgeNoShow => 'NO-SHOW';

  @override
  String get shipmentBadgeExpired => 'EXPIRED';

  @override
  String get shipmentBadgeParcelRefused => 'PARCEL REFUSED';

  @override
  String get shipmentStepAcceptedLabel =>
      'Drop-off with the traveler coming up';

  @override
  String get shipmentStepHandedOverLabel =>
      'Parcel handed over to the traveler';

  @override
  String shipmentStepInTransitLabel(String city) {
    return 'In flight to $city';
  }

  @override
  String get shipmentDestinationFallback => 'destination';

  @override
  String get shipmentStepArrivedLabel => 'Arrived, ready to be picked up';

  @override
  String get shipmentStepDeliveredLabel => 'Delivered to destination';

  @override
  String get shipmentCtaTrackParcel => 'Track the parcel →';

  @override
  String get shipmentCtaViewQr => 'View the QR →';

  @override
  String get shipmentCtaDetails => 'Details →';

  @override
  String shipmentParcelWeightLabel(String weight) {
    return 'Parcel $weight';
  }

  @override
  String shipmentParcelWeightForRecipientLabel(
    String weight,
    String recipient,
  ) {
    return 'Parcel $weight · for $recipient';
  }

  @override
  String get shipmentStepperHandedOverLabel => 'Handed over';

  @override
  String get shipmentStepperEmbarkedLabel => 'Boarded';

  @override
  String get shipmentStepperInFlightLabel => 'In flight';

  @override
  String get shipmentStepperArrivedLabel => 'Arrived';

  @override
  String get shipmentStepperDeliveryLabel => 'Delivery';

  @override
  String get shipmentStatusFilterTitle => 'Filter by status';

  @override
  String shipmentStatusFilterApplyWithCount(int count) {
    return 'Apply ($count)';
  }

  @override
  String get shipmentGroupInProgress => 'In progress';

  @override
  String get shipmentGroupWaiting => 'Pending';

  @override
  String get shipmentGroupDelivered => 'Delivered';

  @override
  String get shipmentGroupNotCompleted => 'Not completed';

  @override
  String get shipmentStatusToHandOverOption => 'Drop-off due';

  @override
  String get shipmentStatusHandedOverOption => 'Handed over';

  @override
  String get shipmentStatusInTransitOption => 'In transit';

  @override
  String get shipmentStatusArrivedOption => 'Arrived';

  @override
  String get shipmentStatusAwaitingPaymentOption => 'To pay';

  @override
  String get shipmentStatusPaidOption => 'Paid';

  @override
  String get shipmentStatusDeliveredOption => 'Delivered';

  @override
  String get shipmentStatusCancelledOption => 'Canceled';

  @override
  String get shipmentStatusRejectedOption => 'Declined';

  @override
  String get shipmentStatusParcelRefusedOption => 'Parcel refused';

  @override
  String get shipmentStatusNoShowOption => 'No-show';

  @override
  String get shipmentStatusExpiredOption => 'Expired';

  @override
  String get shipmentPeriodFilterTitle => 'Filter by period';

  @override
  String get shipmentPeriodBasisDepartureLabel => 'Departure date';

  @override
  String get shipmentPeriodBasisCreationLabel => 'Creation date';

  @override
  String get shipmentPeriodLast3MonthsLabel => 'Last 3 months';

  @override
  String get shipmentPeriodThisYearLabel => 'This year';

  @override
  String get shipmentPeriodAllLabel => 'All time';

  @override
  String get shipmentPeriodCustomLabel => 'Custom';

  @override
  String get shipmentPeriodCustomSelectedLabel => 'Custom ✓';

  @override
  String shipmentReimbursementInfoMessage(String cap) {
    return 'In case of confirmed loss after investigation, Yadony reimburses up to $cap € under conditions.';
  }

  @override
  String get shipmentReimbursementSeeConditionsButton => 'See conditions';

  @override
  String get shipmentSearchFieldHint => 'City, recipient, traveler…';

  @override
  String shipmentResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
    );
    return '$_temp0';
  }

  @override
  String get shipmentClearAllFiltersLabel => 'Clear all';

  @override
  String get shipmentDeletedSnackbar => 'Shipment deleted';

  @override
  String get shipmentDeleteConfirmTitle => 'Delete this shipment?';

  @override
  String get shipmentDeleteConfirmMessage =>
      'It will be removed from your history. This action is irreversible.';

  @override
  String get shipmentEmptyTitle => 'No shipments yet';

  @override
  String get shipmentEmptyDescription =>
      'Find a traveler and send your parcel to Africa.';

  @override
  String get shipmentEmptySearchTripAction => 'Search for a trip';

  @override
  String get shipmentFilteredEmptyMessage => 'No shipment matches your filters';

  @override
  String get shipmentLoadErrorTitle => 'Loading error';

  @override
  String get shipmentMesColisHeaderTitle => 'My parcels';

  @override
  String get shipmentTabEnRouteLabel => 'On the way';

  @override
  String get shipmentTabPubliesLabel => 'Posted';

  @override
  String get bidListFilterToReview => 'To review';

  @override
  String get bidListFilterAccepted => 'Accepted';

  @override
  String get bidListFilterCompleted => 'Completed';

  @override
  String bidListRequestsToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests to review',
      one: '$count request to review',
    );
    return '$_temp0';
  }

  @override
  String get bidListEmptyAcceptedTitle => 'No accepted requests';

  @override
  String get bidListEmptyAcceptedDescription =>
      'You haven\'t accepted any requests yet.';

  @override
  String get bidListSearchHint => 'Name or tracking number…';

  @override
  String bidListChipAll(int count) {
    return 'All ($count)';
  }

  @override
  String bidListChipActive(int count) {
    return 'Active ($count)';
  }

  @override
  String bidListChipClosed(int count) {
    return 'Closed ($count)';
  }

  @override
  String get bidListNoResultTitle => 'No results';

  @override
  String get bidListEmptyShipmentsTitle => 'No shipments';

  @override
  String bidListNoResultDescription(String query) {
    return 'No shipment matches “$query”.';
  }

  @override
  String get bidListEmptyShipmentsDescription =>
      'No shipment in this category.';

  @override
  String get bidListScanChipLabel => 'Scan QR code';

  @override
  String bidListHiddenOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers hidden (minimum price on)',
      one: '$count offer hidden (minimum price on)',
    );
    return '$_temp0';
  }

  @override
  String get bidListAcceptedSnackbar => 'Request accepted!';

  @override
  String get bidListRejectedSnackbar => 'Request declined.';

  @override
  String get bidListDeletedSnackbar => 'Request deleted.';

  @override
  String get bidListCardDeclinedSheetTitle => 'Payment declined';

  @override
  String get bidListCardDeclinedHint =>
      'Change the card used for your service fee to accept this request.';

  @override
  String get bidListChangeCommissionCardButton => 'Change my service fee card';

  @override
  String get bidListWalletInsufficientTitle => 'Insufficient balance';

  @override
  String get bidListWalletInsufficientHint =>
      'Top up your wallet or pay the service fee directly by card.';

  @override
  String get bidListWalletTopupButton => 'Top up my wallet';

  @override
  String get bidListPayByCardButton => 'Pay by card';

  @override
  String get bidListAddCardButton => 'Add a card';

  @override
  String get bidListDeclineDialogTitle => 'Decline this request?';

  @override
  String get bidListDeclineDialogMessage =>
      'The sender will be notified. This action is irreversible.';

  @override
  String get bidListDeclineButton => 'Decline';

  @override
  String get bidListDeleteDialogTitle => 'Delete this request?';

  @override
  String get bidListDeleteDialogMessage =>
      'This declined request will be permanently removed from your list.';

  @override
  String bidListPendingTitleWithCount(int count) {
    return 'To review ($count)';
  }

  @override
  String get bidListEmptyPendingTitle => 'No requests to review';

  @override
  String get bidListEmptyPendingDescription =>
      'Share your listing to receive requests.';

  @override
  String get bidListDemandesTitle => 'Requests';

  @override
  String get bidListDemandesSearchHint => 'Sender, tracking number…';

  @override
  String get bidListNoSearchResultDescription =>
      'No request matches your search.';

  @override
  String get bidListEmptyNoRequestsDescription =>
      'Post a trip to receive requests from senders.';

  @override
  String get bidListEmptyAcceptedArchiveDescription =>
      'Requests you accept will appear here.';

  @override
  String get bidListEmptyCompletedTitle => 'No completed requests';

  @override
  String get bidListEmptyCompletedDescription =>
      'Your closed requests will be archived here.';

  @override
  String get tripOwnerDeletedSnackbar => 'Trip deleted';

  @override
  String get tripOwnerPublishedTitle => 'Trip posted!';

  @override
  String tripOwnerPublishedSubtitle(String dep, String arr) {
    return 'Your trip $dep → $arr is live.';
  }

  @override
  String get tripOwnerShareMyTrip => 'Share my trip';

  @override
  String tripOwnerShareMessage(
    String dep,
    String arr,
    String date,
    String url,
  ) {
    return '✈️ I\'m traveling $dep → $arr on $date with room in my luggage!\nBook your kilos on Yadony 📦\n$url';
  }

  @override
  String get tripOwnerDraftBannerTitle => 'This trip is a draft';

  @override
  String get tripOwnerDraftBannerMessage =>
      'It\'s invisible to senders until it\'s published.';

  @override
  String get tripOwnerMarkArrivedButton => 'Arrived at destination';

  @override
  String get tripOwnerEditInstructionsButton => 'Edit pickup instructions';

  @override
  String get tripOwnerDeleteBlockedTitle => 'Deletion not possible';

  @override
  String get tripOwnerDeleteBlockedMessage =>
      'A parcel has already been accepted on this trip. To remove it, you must first cancel the trip: the sender will be automatically refunded.';

  @override
  String get tripOwnerCancelTripButton => 'Cancel the trip';

  @override
  String get tripOwnerProLimitTitle => 'Monthly limit reached';

  @override
  String get bidListCardAmountLabel => 'AMOUNT';

  @override
  String get bidListCardFlatRateLabel => 'Flat rate';

  @override
  String bidListCardTrackingNumberLabel(String number) {
    return 'No. $number';
  }

  @override
  String get bidListAcceptButton => 'Accept';

  @override
  String get bidListCashPaymentHint =>
      '💵 Cash payment: awaiting your response';

  @override
  String get bidListEscrowPaymentHint =>
      '💳 Payment received: awaiting your response';

  @override
  String get bidListStatusAccepted => 'Accepted';

  @override
  String get bidListStatusAwaitingPayment => 'Payment pending';

  @override
  String get bidListStatusHandedOver => 'On the way';

  @override
  String get bidListStatusInTransit => 'In transit';

  @override
  String get bidListStatusArrived => 'Arrived';

  @override
  String get bidListStatusDelivered => 'Delivered';

  @override
  String get bidListStatusNoShow => 'No-show';

  @override
  String get bidListStatusParcelRefused => 'Parcel refused';

  @override
  String get bidListStatusCancelled => 'Canceled';

  @override
  String get tripOwnerPublishTile => 'Post';

  @override
  String get tripOwnerPosterTile => 'Poster';

  @override
  String get tripOwnerUnpublishTile => 'Unpublish';

  @override
  String get tripOwnerUnpublishDialogTitle => 'Unpublish this trip?';

  @override
  String get tripOwnerUnpublishDialogMessage =>
      'The trip will no longer be visible and will stay in your drafts.';

  @override
  String get tripOwnerRequestsTile => 'Requests';

  @override
  String get tripOwnerRequestsDisabledMessage => 'No requests to review';

  @override
  String get tripOwnerParcelsTile => 'Parcels';

  @override
  String get tripOwnerNoParcelsMessage => 'No parcels on board';

  @override
  String get tripOwnerEditDisabledMessage =>
      'Editable only while there\'s no request';

  @override
  String get tripOwnerDeleteDialogTitle => 'Delete this trip?';

  @override
  String get tripOwnerDeleteCancelledMessage =>
      'This action is irreversible. The canceled trip and all associated requests will be permanently removed from the platform.';

  @override
  String get tripOwnerDeleteActiveMessage =>
      'This action is irreversible. The trip will no longer be visible to senders.';

  @override
  String get tripOwnerCancelTile => 'Cancel';

  @override
  String get tripOwnerParcelsSectionTitle => 'Parcels on this trip';

  @override
  String get tripOwnerParcelsEmptyDescription =>
      'Accepted parcels will appear here.';

  @override
  String get tripOwnerParcelsFilterAll => 'All';

  @override
  String get tripOwnerParcelsStatusAccepted => 'Accepted';

  @override
  String get tripOwnerParcelsStatusAwaitingPayment => 'Payment pending';

  @override
  String get tripOwnerParcelsStatusHandedOver => 'Handed over';

  @override
  String get tripOwnerParcelsStatusInTransit => 'In transit';

  @override
  String get tripOwnerParcelsStatusArrived => 'Arrived';

  @override
  String get tripOwnerParcelsStatusDelivered => 'Delivered';

  @override
  String get tripOwnerParcelsStatusNoShow => 'No-show';

  @override
  String get tripOwnerParcelsStatusParcelRefused => 'Refused';

  @override
  String get tripOwnerParcelsStatusCancelled => 'Canceled';

  @override
  String get tripOwnerParcelsDefaultContent => 'Parcel';

  @override
  String get tripOwnerSurplusTitle => 'Open remaining kg';

  @override
  String get tripOwnerSurplusSubtitle =>
      'Make your spare capacity available to the public';

  @override
  String get tripOwnerSurplusPublishingButton => 'Posting…';

  @override
  String get tripOwnerSurplusKgValidatorEmpty => 'Enter a number of kg';

  @override
  String get tripOwnerSurplusKgValidatorMin => 'Minimum 1 kg';

  @override
  String get tripOwnerSurplusOpenedSnackbar => 'Capacity opened to the public';

  @override
  String get tripOwnerSurplusReservedLabel => 'Reserved for your sender';

  @override
  String tripOwnerSurplusReservedKgValue(String kg) {
    return '$kg kg locked';
  }

  @override
  String get tripOwnerSurplusKgSectionLabel => 'KG TO OPEN';

  @override
  String get tripOwnerSurplusPriceSectionLabel => 'PRICE PER KG';

  @override
  String get tripOwnerSurplusKgHint => 'E.g. 8';

  @override
  String get tripOwnerSurplusOtherPriceChip => 'Other';

  @override
  String get tripOwnerSurplusCustomPriceHint => 'Your price';

  @override
  String get tripOwnerSurplusCustomPriceInvalid => 'Invalid price';

  @override
  String get tripOwnerSurplusDisclaimerText =>
      'Final action: once published, your spare capacity becomes visible in search and can no longer be closed.';

  @override
  String get tripOwnerSurplusPublicPriceLabel => 'Price shown to senders';

  @override
  String get tripOwnerArrivalEditingTitle => 'Pickup instructions';

  @override
  String get tripOwnerArrivalSubtitle =>
      'Tell us where and how to pick up the parcel';

  @override
  String get tripOwnerArrivalConfirmButton => 'Confirm arrival';

  @override
  String get tripOwnerArrivedSnackbar => 'Trip marked as arrived';

  @override
  String get tripOwnerArrivalUpdatedSnackbar => 'Instructions updated';

  @override
  String get tripOwnerArrivalFieldLabel => 'Instructions';

  @override
  String get tripOwnerArrivalFieldLabelOptional => 'Instructions (optional)';

  @override
  String get tripOwnerArrivalFieldHint =>
      'E.g.: Châtelet metro station, exit 3';

  @override
  String get bidCancelDialogTitle => 'Cancel this request?';

  @override
  String get bidCancelAcceptedSubtitle =>
      'The sender will be automatically refunded.';

  @override
  String get bidCancelWarningMessage =>
      'The parcel has already been handed over. You\'ll need to return it to the sender within 3 days by entering the return code they\'ll give you.';

  @override
  String get bidCancelWarningRefundNote =>
      'The sender will be fully refunded. If the payment was in cash, no money changes hands.';

  @override
  String get bidCancelReasonRequiredHint => 'Reason for cancellation *';

  @override
  String get bidCancelReasonOptionalHint => 'Reason (optional)';

  @override
  String get bidCancelReasonRequiredError => 'Reason required';

  @override
  String get bidCancelKeepButton => 'Keep';

  @override
  String get bidCancelConfirmButton => 'Cancel the request';

  @override
  String get activityPeriod7Days => '7 days';

  @override
  String get activityPeriod30Days => '30 days';

  @override
  String get activityPeriod12Months => '12 months';

  @override
  String get activityPeriodLast7Days => 'Last 7 days';

  @override
  String get activityPeriodLast30Days => 'Last 30 days';

  @override
  String get activityPeriodLast12Months => 'Last 12 months';

  @override
  String get activityRevenueCard => 'Card';

  @override
  String get activityRevenueMobileMoney => 'Mobile money';

  @override
  String get activityRevenueCash => 'Cash';

  @override
  String get activityRevenueOther => 'Payment';

  @override
  String get activityToolMissingAddress => 'an address';

  @override
  String get activityToolMissingRecipient => 'a recipient';

  @override
  String get activityToolMissingAlert => 'an alert';

  @override
  String get activityToolMissingTemplate => 'a trip template';

  @override
  String get activityToolMissingPriceGrid => 'a price grid';

  @override
  String get activityToolCtaAddresses => 'Add an address';

  @override
  String get activityToolCtaRecipients => 'Add a recipient';

  @override
  String get activityToolCtaAlerts => 'Create an alert';

  @override
  String get activityToolCtaTemplates => 'Create a trip template';

  @override
  String get activityToolCtaPriceGrid => 'Fill in my price grid';

  @override
  String activityToolBadgeAddresses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count addresses',
      one: '$count address',
    );
    return '$_temp0';
  }

  @override
  String activityToolBadgeRecipients(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '$count recipient',
    );
    return '$_temp0';
  }

  @override
  String activityToolBadgeAlerts(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alerts',
      one: '$count alert',
    );
    return '$_temp0';
  }

  @override
  String activityToolBadgeTemplates(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count templates',
      one: '$count template',
    );
    return '$_temp0';
  }

  @override
  String get activityToolBadgePriceGridReady => 'Set up';

  @override
  String activityToolsMissing(Object items) {
    return 'You still need $items.';
  }

  @override
  String get activityToolTitleAlerts => 'My alerts';

  @override
  String get activityToolTitleTemplates => 'Trip templates';

  @override
  String get activityToolTitlePriceGrid => 'My price grid';

  @override
  String get activityToolTitleAddresses => 'My addresses';

  @override
  String get activityToolTitleRecipients => 'My recipients';

  @override
  String get activityToolSubtitleTemplates => 'Republish your usual trips';

  @override
  String get activityToolSubtitlePriceGrid => 'Item pricing for your trips';

  @override
  String get activityToolSubtitleAddresses => 'Your saved sending locations';

  @override
  String get activityToolSubtitleRecipients => 'The people you send to';

  @override
  String get activityToolBadgeUnconfigured => 'Not set up';

  @override
  String activityToolHubSemanticsReady(Object label, Object title) {
    return '$title, ready, $label';
  }

  @override
  String activityToolHubSemanticsUnconfigured(Object title) {
    return '$title, not set up';
  }

  @override
  String activityToolMenuSemanticsReady(Object badge, Object label) {
    return '$label: $badge';
  }

  @override
  String activityToolMenuSemanticsUnconfigured(Object label) {
    return '$label: not set up';
  }

  @override
  String get activityHistoryTitle => 'History';

  @override
  String get activityHistorySubtitle => 'Everything that\'s done';

  @override
  String get activityHelpTitleHub => 'Help & support';

  @override
  String get activityHelpSubtitle => 'A question, a problem?';

  @override
  String get activityAlertsSubtitleUnconfigured => 'Be notified before others';

  @override
  String get activityAlertsSubtitleCaughtUp => 'Nothing new for now';

  @override
  String get activityAlertsSubtitleDefault => 'New trips and parcels';

  @override
  String get activityHubTitle => 'Activities';

  @override
  String get activityMenuButtonTooltip => 'Menu';

  @override
  String get activitySectionCurrent => 'Right now';

  @override
  String get activitySectionStats => 'Statistics';

  @override
  String get activitySectionTools => 'Tools';

  @override
  String get activityIntroTitle => 'Send or carry, you choose';

  @override
  String get activityIntroBody =>
      'Send your parcels with trusted travelers, or carry parcels during your trips to earn money. Everything is tracked from this screen.';

  @override
  String get activityPublishParcelCta => 'Post a parcel';

  @override
  String get activityTileTripsLabel => 'Active trips';

  @override
  String get activityTileTripsSubtitle => 'Your upcoming trips';

  @override
  String get activityTileTripsEmptyHint => 'Post a trip';

  @override
  String get activityTileShipmentsLabel => 'My parcels';

  @override
  String get activityTileShipmentsSubtitle => 'Posted, negotiated, on the way';

  @override
  String get activityTileShipmentsEmptyHint => 'Send a parcel';

  @override
  String get activityTileRequestsLabel => 'Requests received';

  @override
  String get activityTileRequestsSubtitle => 'Parcels for you to carry';

  @override
  String get activityTileRequestsEmptyHint => 'None for now';

  @override
  String get activityTileNegotiationsLabel => 'Price discussions';

  @override
  String get activityTileNegotiationsSubtitle => 'Propose or accept a rate';

  @override
  String get activityTileNegotiationsEmptyHint => 'None in progress';

  @override
  String get activityRevenueTitle => 'Earnings';

  @override
  String get activityKgSoldTitle => 'Kg sold';

  @override
  String get activityStatTripsLabel => 'Trips';

  @override
  String activityStatTripsPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posted',
      one: '$count posted',
    );
    return '$_temp0';
  }

  @override
  String get activityStatParcelsLabel => 'Shipments';

  @override
  String activityStatParcelsSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sent',
      one: '$count sent',
    );
    return '$_temp0';
  }

  @override
  String get activityMenuTrackParcel => 'Track a parcel';

  @override
  String get activityMenuScanParcel => 'Scan a parcel';

  @override
  String get activityMenuSettings => 'Settings';

  @override
  String get activityMenuToolsSection => 'My tools';

  @override
  String activityMenuToolsReady(Object ready, Object total) {
    return '$ready/$total ready';
  }

  @override
  String get activityMenuAccountSection => 'My account';

  @override
  String get activityWalletTitle => 'Wallet';

  @override
  String get activityHelpTitleMenu => 'Help and support';

  @override
  String get activityDetailUnavailable => 'Details unavailable';

  @override
  String get activityKgSoldErrorBody =>
      'We couldn\'t load your kg sold. Check your connection, then try again.';

  @override
  String get activityRevenueErrorBody =>
      'We couldn\'t load your earnings. Check your connection, then try again.';

  @override
  String get activityEmptyPeriodTitle => 'No deliveries in this period';

  @override
  String get activityKgSoldEmptyBody =>
      'Kg sold will appear here once your parcels are delivered.';

  @override
  String get activityRevenueEmptyBody =>
      'Your earnings will appear here once your parcels are delivered and paid.';

  @override
  String activityKgSoldParcels(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcels',
      one: '$count parcel',
    );
    return '$_temp0';
  }

  @override
  String activityKgSoldTrips(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips',
      one: '$count trip',
    );
    return '$_temp0';
  }

  @override
  String activityKgSoldParcelsDelivered(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcels delivered',
      one: '$count parcel delivered',
    );
    return '$_temp0';
  }

  @override
  String activityKgSoldTripDeparture(Object date) {
    return 'Departed $date';
  }

  @override
  String activityDeliveries(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deliveries',
      one: '$count delivery',
    );
    return '$_temp0';
  }

  @override
  String activityRevenueConversionNote(Object total) {
    return 'On the tile, “$total” is a converted total at the day\'s rate, for reference. Here, each amount keeps its own currency.';
  }

  @override
  String get activityToolsCompleteTitle => 'Your tools are ready';

  @override
  String get activityToolsCompleteBody => 'Post a parcel or a trip in 3 taps';

  @override
  String get activityToolsStartTitle => 'Set up your tools once';

  @override
  String get activityToolsProgressTitle => 'Post in 3 taps';

  @override
  String get activityToolsStartBody =>
      'Addresses, recipients, templates, price grid, alerts: fill them in once, reuse them every time you post.';

  @override
  String activityToolsProgressBody(Object missing) {
    return '$missing Once your tools are ready, nothing to re-enter.';
  }

  @override
  String get activityToolsStartCta => 'Start with my addresses';

  @override
  String get activityToolsGaugeLabel => 'ready';

  @override
  String get activityToolsGaugeSemantics => 'Preparing your tools';

  @override
  String activityNewCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '$count new',
    );
    return '$_temp0';
  }

  @override
  String activityNewSinceLastVisit(Object label, Object title) {
    return '$title, $label since your last visit';
  }

  @override
  String bidCreateMaxWeightLabel(String maxKg) {
    return 'max $maxKg kg';
  }

  @override
  String get commonDone => 'Done';

  @override
  String get commonLater => 'Later';

  @override
  String get commonLoadError => 'Couldn\'t load';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonSomethingWentWrongDot => 'Something went wrong.';

  @override
  String get commonTakePhoto => 'Take a photo';

  @override
  String get commonPickFromGallery => 'Choose from gallery';

  @override
  String get commonImageUnsupported => 'Unsupported or too large image';

  @override
  String get commonDefault => 'Default';

  @override
  String get commonDateYesterday => 'Yesterday';

  @override
  String get currencyNameEur => 'Euro';

  @override
  String get currencyNameUsd => 'US dollar';

  @override
  String get currencyNameCad => 'Canadian dollar';

  @override
  String get currencyNameGbp => 'Pound sterling';

  @override
  String get currencyNameChf => 'Swiss franc';

  @override
  String get currencyNameXof => 'West African CFA franc';

  @override
  String get currencyNameXaf => 'Central African CFA franc';

  @override
  String get paymentCardUnavailable =>
      'Card payment is unavailable right now. Try again in a moment.';

  @override
  String get paymentFailedGeneric =>
      'The payment failed. Try again in a moment.';

  @override
  String get paymentDeclined => 'Payment declined';

  @override
  String paymentMethodsSemantics(String wallet) {
    return 'Card, $wallet, PayPal';
  }

  @override
  String paymentContextRecipient(String name) {
    return 'Shipment for $name';
  }

  @override
  String get paymentContextDefault => 'Your parcel shipment';

  @override
  String commissionCardDebitNoticeMin(String percent, String min) {
    return 'This card will be charged the service fee ($percent%, min. $min) for each cash parcel you accept.';
  }

  @override
  String commissionCardDebitNotice(String percent) {
    return 'This card will be charged the service fee ($percent%) for each cash parcel you accept.';
  }

  @override
  String get commissionCardScreenTitle => 'Service fee card';

  @override
  String get commissionCardLoadError =>
      'Something went wrong. Please try again.';

  @override
  String get paymentNotConfirmedSnackbar => 'Payment not confirmed, try again';

  @override
  String get commissionCardReplaceButton => 'Replace card';

  @override
  String get commissionCardDeleteButton => 'Delete card';

  @override
  String get commissionCardAddErrorMessage => 'Error adding the card.';

  @override
  String get commissionCardDeleteConfirmMessage =>
      'Delete this card? You won\'t be able to accept cash parcels until you register a new one.';

  @override
  String get commissionCardEmptyTitle => 'No card registered';

  @override
  String commissionCardEmptyBody(String percent) {
    return 'To accept cash payments, register a card we\'ll charge our service fee ($percent%) on for each parcel you accept.';
  }

  @override
  String get commissionCardAddButton => 'Add a card';

  @override
  String get commissionCardExpiredMessage =>
      'Your card has expired. Replace it to reactivate cash payments.';

  @override
  String commissionCardExpiringMessage(String date) {
    return 'Your card expires on $date. Remember to replace it.';
  }

  @override
  String commissionCardExpiryLabel(String date) {
    return 'Expires $date';
  }

  @override
  String get paymentAuthConfirmTitle => 'Confirm payment';

  @override
  String get paymentAuthConfirmMessage =>
      'The amount will be on hold until delivery, then paid to the traveler.';

  @override
  String get paymentScreenTitle => 'Pay for my shipment';

  @override
  String get paymentSecureNotice =>
      'Your payment is secure, released only once the recipient confirms delivery.';

  @override
  String paymentPayButtonLabel(String price) {
    return 'Pay $price';
  }

  @override
  String get paymentSummaryTitle => 'Summary';

  @override
  String get paymentSummaryWeightLabel => 'Weight';

  @override
  String get paymentSummaryPricePerKgLabel => 'Price/kg';

  @override
  String get paymentSummaryTypeLabel => 'Type';

  @override
  String get paymentSummaryFlatRateValue => 'Flat rate for items';

  @override
  String get paymentSummaryTotalLabel => 'You pay';

  @override
  String get paymentEscrowTitle => 'Shipment reserved!';

  @override
  String paymentEscrowSubtitle(String amount) {
    return '$amount is held and secured, then released once the recipient confirms delivery.';
  }

  @override
  String get paymentEscrowCta => 'View my shipments';

  @override
  String get paymentSheetTitle => 'Payment';

  @override
  String get paymentSheetConfirmedTitle => 'Payment confirmed';

  @override
  String get paymentSheetEscrowNote =>
      'Funds are on hold until the parcel is delivered, then paid to the traveler.';

  @override
  String get paymentSheetSecureFooter => 'Payment secured by Stripe';

  @override
  String get mobileMoneyAccountTitle => 'Mobile money payout';

  @override
  String get mobileMoneyAccountLoadError => 'Couldn\'t load your account';

  @override
  String get mobileMoneyExplanationActivate =>
      'Enter the mobile money number that will receive your payouts. It can be different from your Yadony number.';

  @override
  String get mobileMoneyExplanationReactivateNoPrevious =>
      'Your payout is turned off. Enter the mobile money number to turn it back on.';

  @override
  String mobileMoneyReactivateWithPrevious(String masked) {
    return 'Your payout is turned off. Enter the mobile money number to turn it back on (previous: $masked).';
  }

  @override
  String get mobileMoneyExplanationChangeNumber =>
      'Enter the new payout number. You\'ll need to check the networks again for this number.';

  @override
  String get mobileMoneyButtonActivate => 'Activate mobile money payout';

  @override
  String get mobileMoneyButtonReactivate => 'Turn back on';

  @override
  String get mobileMoneyButtonChangeNumber => 'Save the new number';

  @override
  String get mobileMoneyPayoutNumberLabel => 'Payout number';

  @override
  String get mobileMoneyConfirmNumberLabel => 'Confirm the number';

  @override
  String get mobileMoneyNetworksSectionTitle => 'Networks on this number';

  @override
  String get mobileMoneyNetworksUnavailable =>
      'Choosing networks isn\'t available yet. Your mobile operator will be detected automatically.';

  @override
  String get mobileMoneyNoNetworksAvailable =>
      'No network is available for this number.';

  @override
  String get mobileMoneyPayerChoosesNetwork =>
      'The sender pays with one of the checked networks. You receive on that same network.';

  @override
  String get mobileMoneyConfirmToSeeNetworks =>
      'Confirm your number to see the available networks.';

  @override
  String get mobileMoneyAcceptedNetworksTitle => 'Accepted networks';

  @override
  String get mobileMoneyActiveBadge => 'ACTIVE';

  @override
  String get mobileMoneyNumberLabel => 'Number';

  @override
  String get mobileMoneyNotProvided => 'Not provided';

  @override
  String get mobileMoneyCountryLabel => 'Country';

  @override
  String get mobileMoneyCurrencyLabel => 'Currency';

  @override
  String get mobileMoneyPayerChoosesOneNetwork =>
      'The sender picks one of these networks to pay. You receive on the same one.';

  @override
  String get mobileMoneyChangeNumberButton => 'Change number';

  @override
  String get mobileMoneyDisableButton => 'Turn off';

  @override
  String get mobileMoneyAllNetworks => 'All networks';

  @override
  String get mobileMoneyDetectedForNumber => 'Detected for this number';

  @override
  String get mobileMoneyAwaitingTitle => 'Mobile money payment';

  @override
  String get mobileMoneyPaymentConfirmedSecured =>
      'Payment confirmed, your shipment is secured';

  @override
  String mobileMoneyTimeLeft(String time) {
    return 'Time left $time';
  }

  @override
  String get mobileMoneyTravelerFallback => 'The traveler';

  @override
  String get mobileMoneyChooseOperatorTitle => 'Which operator?';

  @override
  String get mobileMoneyPayingNumberLabel => 'Paying number';

  @override
  String get mobileMoneyPayWithAnotherNumberOptional =>
      'Pay with a different number (optional)';

  @override
  String get mobileMoneyConfirmInWaveApp => 'You confirm in the Wave app';

  @override
  String mobileMoneyAcceptsAndReceives(String name, String networks) {
    return '$name accepts $networks and receives on the network you choose.';
  }

  @override
  String get mobileMoneyNoNetworkForPayment =>
      'No mobile money network is available for this payment.';

  @override
  String mobileMoneyNoCommonNetwork(
    String name,
    String networks,
    String country,
  ) {
    return '$name accepts $networks, which aren\'t available for your number ($country). Change the paying number or message them from the conversation.';
  }

  @override
  String mobileMoneyPay(String amount) {
    return 'Pay $amount';
  }

  @override
  String get mobileMoneyFinishInWaveApp => 'Finish the payment in the Wave app';

  @override
  String get mobileMoneyOpenWave => 'Open Wave';

  @override
  String mobileMoneyPinSent(String provider) {
    return 'Approve the payment on your phone: $provider just sent you a PIN request.';
  }

  @override
  String get mobileMoneyPinSentUnknownProvider =>
      'Approve the payment on your phone: your mobile operator just sent you a PIN request.';

  @override
  String get mobileMoneyConfirmationAutomatic =>
      'Confirmation is automatic, keep this screen open.';

  @override
  String get mobileMoneyDepositRefusedFallback =>
      'The payment was declined by the mobile operator';

  @override
  String get mobileMoneyPhoneRequiredExplanation =>
      'Your Yadony account has no phone number: enter the mobile money number that will pay.';

  @override
  String get mobileMoneyPhoneThatWillPayLabel => 'Number that will pay';

  @override
  String get mobileMoneyExpiredBid =>
      'Time\'s up. The request was canceled. Make a new offer to the traveler.';

  @override
  String get mobileMoneyExpiredNegotiation =>
      'Time\'s up. The thread is back to \"to pay\": you can retry the payment or change the payment method from the thread.';

  @override
  String get mobileMoneyPaymentConfirmedTitle => 'Payment confirmed';

  @override
  String get walletTopupMmAwaitingTitle => 'Mobile money top-up';

  @override
  String get walletTopupMmPayWithAnotherNumber => 'Pay with a different number';

  @override
  String get walletTopupMmValidateTitle => 'Approve the payment on your phone';

  @override
  String walletTopupMmRequestSent(String number, String provider) {
    return 'A payment request was sent to $number via $provider.';
  }

  @override
  String get walletTopupMmConfirmationAutomatic =>
      'Confirmation is automatic, keep this screen open.';

  @override
  String get walletTopupMmAmountLabel => 'Amount';

  @override
  String get walletTopupMmCreditedToLabel => 'Credited to';

  @override
  String walletTopupMmCreditedTo(String code) {
    return 'Yadony balance ($code)';
  }

  @override
  String get walletTopupMmExpiresInLabel => 'Expires in';

  @override
  String walletTopupMmOpenProvider(String provider) {
    return 'Open $provider';
  }

  @override
  String get walletTopupMmExpired => 'The payment wasn\'t approved in time.';

  @override
  String get walletTopupMmRefused =>
      'The payment was declined by the mobile operator.';

  @override
  String walletShortfallRequired(String amount) {
    return 'Service fee due: $amount';
  }

  @override
  String walletShortfallBalance(String amount) {
    return 'Wallet balance: $amount';
  }

  @override
  String walletShortfallCommission(String amount) {
    return 'Service fee: $amount';
  }

  @override
  String walletShortfallCovered(String currency, String amount) {
    return 'Your $currency wallet covers $amount';
  }

  @override
  String walletShortfallMissing(
    String missing,
    String converted,
    String currency,
    String balance,
  ) {
    return 'You\'re short $missing ($converted), and your $currency wallet only has $balance';
  }

  @override
  String walletShortfallCommissionConverted(String amount, String converted) {
    return 'Service fee: $amount ($converted)';
  }

  @override
  String walletShortfallTopUpHint(
    String currency,
    String balance,
    String symbol,
  ) {
    return 'Your $currency wallet only has $balance. Top up in $symbol or $currency, or pay by card.';
  }

  @override
  String get walletTitle => 'My wallet';

  @override
  String get walletInfoTooltip => 'How it works';

  @override
  String get walletInfoTitle => 'How the wallet works';

  @override
  String walletTopupConfirmed(String amount, String currency, String provider) {
    return '+$amount added to your $currency wallet, confirmed by $provider.';
  }

  @override
  String get walletRefundAbsorbedByFees =>
      'This balance can\'t be refunded: the payment provider\'s fees absorb it entirely. It stays usable to pay for your shipments.';

  @override
  String get walletEmptyTransactions => 'No transactions yet';

  @override
  String get walletHistorySectionTitle => 'History';

  @override
  String get walletEstimatedTotalLabel => 'Estimated total';

  @override
  String get walletAvailableBalanceLabel => 'Available balance';

  @override
  String get walletEstimateCompleteNote =>
      'Estimated at today\'s rate, currencies kept separate.';

  @override
  String get walletEstimatePartialNote =>
      'Partial estimate: one currency has no rate.';

  @override
  String get walletRefundRequestSentSnackbar => 'Refund request sent.';

  @override
  String get walletActionTopUp => 'Top up';

  @override
  String get walletActionRefund => 'Refund';

  @override
  String get walletActionRequests => 'Requests';

  @override
  String get walletTxTypeMobileMoneyTopUp => 'Mobile money top-up';

  @override
  String get walletTxTypeTopUp => 'Top-up';

  @override
  String get walletTxTypeBidPayment => 'Parcel payment';

  @override
  String get walletTxTypeCommission => 'Service fee';

  @override
  String get walletTxTypeRefund => 'Refund';

  @override
  String get walletTxTypeReferral => 'Referral';

  @override
  String get walletTxDateTimePattern => 'MMM d · h:mm a';

  @override
  String get walletRefundProcessingNote =>
      'Refund in progress · within 5 to 10 business days';

  @override
  String get walletRateUnavailable => 'rate unavailable';

  @override
  String walletLockedCurrencySemantics(String currency) {
    return 'Locked currency $currency, this balance stays available in its own currency';
  }

  @override
  String get walletLockedBadge => 'locked';

  @override
  String walletLockedCurrencyNote(String currency) {
    return 'Stays in its original currency ($currency).';
  }

  @override
  String get walletInfoBalanceDesc =>
      'The amount you can use to pay for a shipment or request a refund.';

  @override
  String get walletInfoTopUpDesc =>
      'Add funds by credit card. The credit appears as soon as the payment is validated.';

  @override
  String get walletInfoRefundDesc =>
      'Request a refund of your balance to your original payment method.';

  @override
  String get walletInfoRequestsDesc =>
      'Find the status of your sent refund requests.';

  @override
  String get walletInfoMultiCurrencyTitle => 'Multiple currencies';

  @override
  String get walletInfoMultiCurrencyDesc =>
      'Your money stays in the currency it was received in. The total at the top is an estimate at today\'s rate, it doesn\'t convert anything.';

  @override
  String get walletInfoChangeCurrencyTitle => 'Change currency';

  @override
  String get walletInfoChangeCurrencyDesc =>
      'The active currency can be changed in Preferences as long as your total balance is zero. Otherwise, empty your wallets first.';

  @override
  String get walletTopupMethodCard => 'Credit card';

  @override
  String get walletTopupPaymentContextLabel => 'Top-up of your Yadony balance';

  @override
  String get walletTopupSuccessTitle => 'Top-up successful!';

  @override
  String get walletTopupSuccessSubtitle =>
      'Your balance will be credited shortly.';

  @override
  String get walletTopupSuccessCta => 'See my balance';

  @override
  String get walletTopupAmountTitle => 'Top up · Step 2/2';

  @override
  String walletTopupCreditNotice(String code) {
    return 'Your Yadony balance will be credited in $code after confirmation.';
  }

  @override
  String walletTopupNoDecimalsNotice(String symbol) {
    return '$symbol doesn\'t use cents: enter a whole number.';
  }

  @override
  String walletTopupCreditedAmount(
    String currency,
    String amount,
    String active,
  ) {
    return 'Your $currency wallet will be credited $amount. Your $active wallet stays the same.';
  }

  @override
  String walletTopupCreditedPending(String currency, String active) {
    return 'Your $currency wallet will be credited the amount you enter. Your $active wallet stays the same.';
  }

  @override
  String get walletTopupProcessing => 'Processing…';

  @override
  String get walletTopupEnterAmount => 'Enter an amount';

  @override
  String walletTopupPayAmount(String amount, String symbol) {
    return 'Pay $amount $symbol';
  }

  @override
  String get walletTopupAmountLabel => 'Amount to top up';

  @override
  String walletTopupBelowMinimum(String amount) {
    return 'Minimum $amount';
  }

  @override
  String walletTopupViaMethod(String amount, String symbol, String method) {
    return 'Top up $amount $symbol via $method';
  }

  @override
  String get walletTopupMethodCardSubtitle => 'Via Stripe · Visa, Mastercard';

  @override
  String get walletTopupMethodMobileMoneySubtitle =>
      'Orange Money, Wave, MTN MoMo';

  @override
  String get walletTopupMethodTitle => 'Top up · Step 1/2';

  @override
  String get walletTopupMethodSectionLabel => 'TOP-UP METHOD';

  @override
  String get walletTopupMethodNextCta => 'Next → Amount';

  @override
  String walletTopupMethodCurrencyNotice(String code) {
    return 'The balance is credited in $code, the mobile operator\'s currency.';
  }

  @override
  String get walletTopupMethodNoNetworks =>
      'No mobile money network available for this number.';

  @override
  String get walletRefundConfirmTitle => 'Refund my balance';

  @override
  String walletRefundConfirmCta(String amount) {
    return 'Refund $amount';
  }

  @override
  String walletRefundableOnMobileMoney(String amount) {
    return 'Refundable to mobile money: $amount';
  }

  @override
  String walletRefundableOnCard(String amount) {
    return 'Refundable to your card: $amount';
  }

  @override
  String walletRefundable(String amount) {
    return 'Refundable: $amount';
  }

  @override
  String walletRefundExplainUnknown(String currency) {
    return 'The amount goes back to the payment method used for the top-up. Your $currency balance is frozen while this is processed.';
  }

  @override
  String walletRefundExplainMobileMoney(String currency) {
    return 'The amount goes back to the number that paid for the top-up, usually within a few minutes. Your $currency balance is frozen while this is processed.';
  }

  @override
  String get walletRefundExplainCard =>
      'The amount goes back to the card used for the top-up, within 5 to 10 days depending on your bank. Your balance is frozen while this is processed.';

  @override
  String get walletRefundFeeLabel => 'Refund fee';

  @override
  String get walletRefundFeeFreeValue => 'Free';

  @override
  String get walletRefundWillReceiveLabel => 'You\'ll receive';

  @override
  String walletRefundBonusNotice(String amount) {
    return '$amount in bonus isn\'t refundable and stays in your wallet.';
  }

  @override
  String get walletRefundFeeRetainedNotice =>
      'This top-up was never used: the payment provider\'s fees are withheld. They\'re canceled as soon as a top-up pays for a shipment.';

  @override
  String get walletRefundCurrencyTitle => 'Which currency to refund?';

  @override
  String get walletRefundCurrencyHint =>
      'One request per currency. You can make another one afterward.';

  @override
  String get walletRefundFeeFree => 'Refund fee: Free';

  @override
  String walletRefundFee(String amount) {
    return 'Refund fee: $amount';
  }

  @override
  String walletRefundCurrencyChoiceTitle(String amount) {
    return '$amount refundable';
  }

  @override
  String walletRefundCurrencyChoiceSubtitle(String amount) {
    return 'you get $amount';
  }

  @override
  String get walletRefundSelectionTitle => 'Choose a top-up';

  @override
  String get walletRefundSelectionSubtitle => 'Select the top-up(s) to refund';

  @override
  String get walletRefundSelectionEmpty =>
      'No top-up available for refund right now.';

  @override
  String get walletTopupDateTimePattern => 'MMM d, yyyy · h:mm a';

  @override
  String get walletRefundSelectionCta => 'Select a top-up';

  @override
  String walletRefundSelectionCount(int count) {
    return 'Refund ($count)';
  }

  @override
  String get walletRefundRequestsTitle => 'My refunds';

  @override
  String get walletRefundRequestsLoadError =>
      'Couldn\'t load your refund requests.';

  @override
  String get walletRefundRequestsEmpty => 'No refund requests yet.';

  @override
  String get walletRefundStatusInProgress => 'In progress';

  @override
  String get walletRefundStatusRefunded => 'Refunded';

  @override
  String get walletRefundStatusFailed => 'Failed';

  @override
  String get walletRefundRailManual => 'Manual';

  @override
  String get walletDatePattern => 'MMM d, yyyy';

  @override
  String walletRefundFallbackNotice(String destination) {
    return 'The refund is sent to $destination. If the mobile operator refuses it, the money is sent back via a payout to the same number.';
  }

  @override
  String walletRefundFeeDetail(String gross, String fee, String net) {
    return '$gross refundable, $fee in fees withheld, you receive $net';
  }

  @override
  String get payoutTitle => 'Get paid';

  @override
  String get payoutGaugeLabel => 'Payments';

  @override
  String get payoutBrowserLaunchFailed =>
      'Unable to open the setup page. Check that a browser is installed.';

  @override
  String get payoutPendingBanner =>
      'Sign-up started but not finished. Resume it to get paid, you\'ll find the information you already entered.';

  @override
  String get payoutRefreshStatus => 'Refresh status';

  @override
  String get payoutResumeSignup => 'Resume my sign-up';

  @override
  String get payoutConnectBankAccount => 'Connect my bank account';

  @override
  String get payoutHeroTitle => 'Connect your\nbank account';

  @override
  String get payoutHeroSubtitle =>
      'Automatically receive your payment within 24h of each confirmed delivery.';

  @override
  String get payoutBenefitSecureTitle => 'Secure payment';

  @override
  String get payoutBenefitSecureSubtitle =>
      'The money is held and secured until delivery is confirmed.';

  @override
  String get payoutBenefitFastTransferTitle => 'Fast transfer';

  @override
  String get payoutBenefitFastTransferSubtitle =>
      'Received in your account within 24h of confirmation.';

  @override
  String get payoutBenefitStripeManagedTitle => 'Managed by Stripe';

  @override
  String get payoutBenefitStripeManagedSubtitle =>
      'Identity verification and compliance are handled by Stripe.';

  @override
  String get payoutActiveTitle => 'Bank account connected';

  @override
  String get payoutActiveSubtitle =>
      'Your Stripe account is active. After each confirmed delivery, the payment is automatically transferred to your bank account within 1 to 2 business days.';

  @override
  String get payoutActiveInfoSecureSubtitle =>
      'The money is held until delivery is confirmed.';

  @override
  String get payoutActiveInfoAutoTransferTitle => 'Automatic transfer';

  @override
  String get payoutActiveInfoAutoTransferSubtitle =>
      'No action needed, Stripe transfers directly to your bank details.';

  @override
  String get payoutActiveInfoBankAccountTitle => 'To your bank account';

  @override
  String get payoutActiveInfoBankAccountSubtitle =>
      'You receive the money in the account linked to your bank details/IBAN, not in a Stripe wallet.';

  @override
  String get payoutContinueToHome => 'Continue to home';

  @override
  String get payoutSuccessTitle => 'Payments enabled ✓';

  @override
  String get payoutSuccessSubtitle =>
      'Your bank account is connected. You\'ll automatically receive your payments after each delivery.';

  @override
  String get stripeAccountDisabledTitle => 'Payments to activate';

  @override
  String get stripeAccountDisabledHeading => 'Finish setting up your payments';

  @override
  String get stripeAccountDisabledBody =>
      'Your payment account is missing some information, so it can\'t receive money yet. Posting a trip stays blocked until you complete it.';

  @override
  String get stripeAccountDisabledRequirementsHeading =>
      'What you\'ll be asked for';

  @override
  String get stripeAccountDisabledRequirementIdentity =>
      'Your identity, name, date of birth and address';

  @override
  String get stripeAccountDisabledRequirementPayout =>
      'A way to receive your earnings, IBAN or bank account';

  @override
  String get stripeAccountDisabledRequirementTerms =>
      'Acceptance of our payment provider\'s terms';

  @override
  String get stripeAccountDisabledEta =>
      'It takes about two to three minutes. You\'ll be able to pick up where you left off.';

  @override
  String get stripeAccountDisabledCta => 'Complete my information';

  @override
  String get stripeAccountContactSupport => 'Contact Yadony support';

  @override
  String get stripeAccountRejectedTitle => 'Account rejected';

  @override
  String get stripeAccountRejectedBody =>
      'Your Stripe account was rejected. You need to set up a new account to continue.';

  @override
  String stripeAccountRejectedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get stripeAccountRejectedCta => 'Set up my account again';

  @override
  String get stripeAccountRejectedBannerMessage =>
      'Your Stripe account was rejected';

  @override
  String get stripeAccountRejectedBannerCta => 'Reconfigure';

  @override
  String get stripeAccountUnavailableHeading =>
      'Not available yet\nin your country';

  @override
  String get stripeAccountUnavailableBody =>
      'Stripe doesn\'t yet allow opening a payment account from your country. You can keep carrying parcels and get paid in cash, at drop-off.';

  @override
  String get stripeAccountIdentityRequiredHeading =>
      'Verify your identity\nfirst';

  @override
  String get stripeAccountIdentityRequiredBody =>
      'To receive money, Stripe needs to link your payment account to a verified identity. It\'s just an ID document to photograph, nothing more.';

  @override
  String get stripeAccountIdentityRequiredCta => 'Verify my identity';

  @override
  String get connectOnboardingTitle => 'Stripe Connect account';

  @override
  String get connectOnboardingHeroTitle => 'Complete your\nStripe account';

  @override
  String get connectOnboardingHeroSubtitle =>
      'To post your trip and receive payments, complete your Stripe account. It takes about 5 minutes.';

  @override
  String get connectOnboardingSecurityNotice =>
      'Your data is encrypted and managed directly by Stripe: Yadony never has access to your banking information.';

  @override
  String get connectOnboardingCta => 'Complete my account';

  @override
  String get connectOnboardingBenefitTimeTitle => '5 minutes';

  @override
  String get connectOnboardingBenefitTimeSubtitle =>
      'Fast and guided step by step';

  @override
  String get connectOnboardingBenefitTransferTitle => 'Automatic transfer';

  @override
  String get connectOnboardingBenefitTransferSubtitle =>
      'Received in your account after each confirmed delivery';

  @override
  String get connectOnboardingBenefitSecureTitle => 'Secured by Stripe';

  @override
  String get connectOnboardingBenefitSecureSubtitle =>
      'World leader in online payments';

  @override
  String get connectPendingCompleteCta => 'I completed the form';

  @override
  String get connectPendingLaterCta => 'Come back later';

  @override
  String get connectPendingConfigured => 'Bank account set up!';

  @override
  String get connectPendingNotReceived =>
      'Stripe hasn\'t received all your information yet. Resume the form to finish it.';

  @override
  String get connectPendingTitle => 'Waiting for Stripe';

  @override
  String get connectPendingSubtitle =>
      'Come back here after completing the Stripe form in your browser.';

  @override
  String get walletActiveCurrencyBadge => 'active';

  @override
  String get chatPreviewPhoto => '📷 Photo';

  @override
  String get chatPreviewLocation => '📍 Shared location';

  @override
  String chatBlockedLength(int max) {
    return 'Message too long ($max characters max).';
  }

  @override
  String get chatBlockedDuplicate => 'You just sent this message.';

  @override
  String get chatBlockedRate =>
      'You\'re sending too many messages. Wait a moment.';

  @override
  String get chatBlockedContact =>
      'For your safety, keep conversations and payment on Yadony. Sharing contact details isn\'t allowed.';

  @override
  String get chatBlockedBanking => 'Sharing bank details isn\'t allowed.';

  @override
  String get chatBlockedUrl => 'External links aren\'t allowed in messages.';

  @override
  String get chatBlockedProfanity =>
      'Keep it polite: this message contains banned words.';

  @override
  String get chatDeleteConversationTitle => 'Delete conversation';

  @override
  String get chatDeleteConversationMessage =>
      'This conversation will be permanently deleted for you and the other person. It can\'t be recreated.';

  @override
  String get chatUnknownConversationLabel => 'Conversation';

  @override
  String get chatCallTooltip => 'Call';

  @override
  String chatReportUser(String name) {
    return 'Report $name';
  }

  @override
  String chatBlockUser(String name) {
    return 'Block $name';
  }

  @override
  String get chatConversationDeletedSnackbar => 'Conversation deleted';

  @override
  String get chatConnectionLostTitle => 'Connection lost';

  @override
  String get chatEmptyStateTitle => 'Start the conversation!';

  @override
  String get chatReadOnlyBannerMessage =>
      'The other person has left this conversation. You\'re in read-only mode.';

  @override
  String get chatLinkedTripLabel => 'Linked trip';

  @override
  String get chatBidStatusAccepted => 'Offer accepted';

  @override
  String get chatBidStatusDeliveryConfirmed => 'Delivery confirmed';

  @override
  String get chatBidStatusTripCancelled => 'Trip canceled';

  @override
  String get chatMessageDeleted => 'Message deleted';

  @override
  String get chatLocationMessageLabel => 'Shared location';

  @override
  String get chatSendingDisabled => 'Sending messages is disabled';

  @override
  String get chatMessageHint => 'Your message…';

  @override
  String get chatSendMessageSemantics => 'Send message';

  @override
  String get conversationListTitle => 'Messages';

  @override
  String get conversationListArchivedTooltip => 'View archived conversations';

  @override
  String get conversationListSearchHint => 'Search conversations…';

  @override
  String get conversationListEmptyResultsTitle => 'No results';

  @override
  String get conversationListEmptyTitle => 'No messages';

  @override
  String conversationListEmptySearchDescription(String query) {
    return 'No conversation matches “$query”.';
  }

  @override
  String get conversationListEmptyDescription =>
      'Your conversations will appear here\nonce an offer is accepted.';

  @override
  String get conversationFilterAll => 'All';

  @override
  String get conversationFilterUnread => 'Unread';

  @override
  String get conversationFilterActive => 'Active';

  @override
  String get conversationFilterDone => 'Done';

  @override
  String get conversationSectionToday => 'TODAY';

  @override
  String get conversationSectionThisWeek => 'THIS WEEK';

  @override
  String get conversationSectionOlder => 'OLDER';

  @override
  String get conversationArchiveAction => 'Archive';

  @override
  String get conversationArchivedSnackbar => 'Conversation archived';

  @override
  String get conversationDeleteConfirmTitle => 'Delete conversation?';

  @override
  String get conversationDeleteConfirmMessage =>
      'This action can\'t be undone.';

  @override
  String get archivedConversationsTitle => 'Archives';

  @override
  String get archivedConversationsEmptyTitle => 'No archived conversations';

  @override
  String get archivedConversationsEmptyDescription =>
      'Conversations you archive will appear here.';

  @override
  String get conversationUnarchivedSnackbar => 'Conversation unarchived';

  @override
  String get conversationUnarchiveAction => 'Unarchive';

  @override
  String get conversationLoaderNotFoundTitle => 'Conversation not found';

  @override
  String get conversationLoaderNotFoundDescription =>
      'This conversation couldn\'t be loaded.';

  @override
  String get conversationUserFallback => 'User';

  @override
  String get conversationStartedFallback => 'Conversation started';

  @override
  String get conversationTimeJustNow => 'just now';

  @override
  String get trackingStepDeparture => 'Departure';

  @override
  String get trackingStepTransit => 'Transit';

  @override
  String get trackingStepArrival => 'Arrival';

  @override
  String scanStepRecorded(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      'DEPART': 'Departure recorded',
      'TRANSIT': 'Transit recorded',
      'other': 'Arrival recorded',
    });
    return '$_temp0';
  }

  @override
  String scanStepLabel(String step) {
    return 'Step: $step';
  }

  @override
  String scanPendingSync(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scans waiting to sync',
      one: '$count scan waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String scanQueueSafe(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count scans pending. We\'ll send them as soon as you\'re back online.',
      one:
          '$count scan pending. We\'ll send it as soon as you\'re back online.',
    );
    return '$_temp0';
  }

  @override
  String get scanAgoUnderMinute => '< 1 min ago';

  @override
  String scanAgoMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String scanAgoHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String scanPhotoTooLarge(int mb) {
    return 'Photo too large (max $mb MB). Try again.';
  }

  @override
  String get scanDepartureTitle => 'Departure scan';

  @override
  String get scanTorchTooltip => 'Flashlight';

  @override
  String get scanQrReadTitle => 'QR scanned';

  @override
  String get scanStepIndicatorStatic => 'STEP 1 OF 3';

  @override
  String get scanConfirmedInSuitcase => 'Parcel loaded in the suitcase';

  @override
  String get scanPhotoWordLabel => 'Photo';

  @override
  String get scanConfirmAndContinue => 'Confirm & continue';

  @override
  String get scanTrackingNumberDialogTitle => 'Tracking number';

  @override
  String get scanTrackingNumberDialogBody =>
      'Enter the parcel\'s DON-XXXXXX number to scan.';

  @override
  String get scanNumberNotFound => 'Number not found. Check and try again.';

  @override
  String get scanQueuedTitle => 'Scan pending';

  @override
  String get scanQueuedNoConnectionBodyLong =>
      'No internet connection. The scan will sync automatically once you\'re back online.';

  @override
  String get scanUnderstoodButton => 'Got it';

  @override
  String get scanParcelDeliveredTitle => 'Parcel delivered!';

  @override
  String get scanRecordedTitle => 'Scan recorded!';

  @override
  String get scanEventTypeSectionLabel => 'Step type';

  @override
  String get scanConfirmationCodeLabel => 'Confirmation code';

  @override
  String get scanConfirmationCodeHintLong =>
      'Ask the recipient for the 6-digit code. They received it from the sender.';

  @override
  String get scanPhotoOfParcelLabel => 'Parcel photo';

  @override
  String get scanRemovePhotoSemantics => 'Remove the photo';

  @override
  String get scanGpsLocationSaved => 'GPS location recorded';

  @override
  String get scanPhotoTooLargeFixed =>
      'Photo too large (max 10 MB). Try again.';

  @override
  String get scanSubmittingConfirmation => 'Confirming...';

  @override
  String get scanSubmittingRecording => 'Saving...';

  @override
  String get scanConfirmDeliveryButton => 'Confirm delivery';

  @override
  String get scanConfirmReadingLabel => 'Confirm scan';

  @override
  String get scanConfirmParcelLabel => 'Parcel';

  @override
  String get scanConfirmStepLabel => 'Step';

  @override
  String get scanConfirmConfirmationCodeHint =>
      'Ask the recipient for the 6-digit code.';

  @override
  String get scanValidateReadingButton => 'Validate scan';

  @override
  String get scanRetakePhotoButton => 'Retake the photo';

  @override
  String get scanConfirmQueuedNoConnectionBody =>
      'No connection. The scan will sync once you\'re back online.';

  @override
  String get scanTerminateButton => 'Finish';

  @override
  String get scanHubTitle => 'Scan & Tracking';

  @override
  String get scanTrackParcelEntry => 'Track a parcel';

  @override
  String get scanChooseTripTitle => 'Choose a trip';

  @override
  String get scanChangeTripLabel => 'Change trip';

  @override
  String get scanNoTripTitle => 'No trip to handle';

  @override
  String get scanNoTripDescription =>
      'You\'ll be able to scan parcel QR codes once a request is accepted on one of your trips.';

  @override
  String get scanViewMyTripsAction => 'See my trips';

  @override
  String get scanLoadTripsErrorTitle => 'Couldn\'t load your trips';

  @override
  String get scanQuickReadSectionTitle => 'QUICK SCAN';

  @override
  String scanColisSectionTitle(int count) {
    return 'PARCELS ($count)';
  }

  @override
  String get scanNoColisConfirmed => 'No parcel confirmed on this trip yet.';

  @override
  String get scanColisRowScanBadge => 'Scan';

  @override
  String get scanHistorySectionTitle => 'SCAN HISTORY';

  @override
  String get scanNoHistoryYet => 'No scans yet';

  @override
  String get scanIdentifyTitle => 'Identify the parcel';

  @override
  String get scanOpenQrReaderTitle => 'Open QR reader';

  @override
  String get scanPointQrHint => 'Point at the parcel\'s QR code';

  @override
  String get scanOrDivider => 'OR';

  @override
  String get scanIdentifySubmit => 'Identify →';

  @override
  String get scanWhichStepTitle => 'Which step?';

  @override
  String get scanPhotoMandatoryBadge => 'Photo required';

  @override
  String get scanPhotoOptionalBadge => 'Photo optional';

  @override
  String get scanPhotoOpeningLoading => 'Opening...';

  @override
  String get scanTakePhotoButton => 'Take the photo';

  @override
  String get scanSkipPhotoButton => 'Skip: continue without a photo';

  @override
  String get scanAutoGeolocation => 'Automatic geolocation';

  @override
  String get scanQrPickerTitle => 'Scan the QR code';

  @override
  String get scanTorchToggleTooltip => 'Turn the flashlight on or off';

  @override
  String get scanQrPickerHint => 'Point at the parcel\'s QR code';

  @override
  String get scanOfflineEventPickupLabel => 'collection';

  @override
  String get scanOfflineEventTransitLabel => 'transit';

  @override
  String get scanOfflineEventDeliveredLabel => 'delivered';

  @override
  String get scanOfflineEventDefaultLabel => 'queued';

  @override
  String get scanOfflineDescPickup => 'Collection recorded';

  @override
  String get scanOfflineDescTransit => 'Transit saved';

  @override
  String get scanOfflineDescDelivered => 'Delivery saved';

  @override
  String get scanOfflineDescDefault => 'Scan saved';

  @override
  String get scanOfflineQueueTitle => 'Offline scans';

  @override
  String get scanOfflineBadge => 'Offline';

  @override
  String scanOfflineQueueSectionTitle(int count) {
    return 'QUEUE ($count)';
  }

  @override
  String get scanOfflineQueueEmpty => 'No scan pending.';

  @override
  String get scanOfflineFooterHint =>
      'Keep scanning even without a network connection.';

  @override
  String get scanQueueSafeTitle => 'Your scans are safe';

  @override
  String scanOfflineParcelCode(String code) {
    return 'parcel $code';
  }

  @override
  String get trackingSearchTitle => 'Track a parcel';

  @override
  String get trackingSearchScanTripEntry => 'Scan a trip\'s QR code';

  @override
  String get trackingSearchNumberLabel => 'Tracking number';

  @override
  String get trackingSearchNumberHint =>
      'Enter the DON-XXXXXX number to track your parcel in real time.';

  @override
  String get trackingSearchSubmit => 'Search';

  @override
  String get trackingSearchViewDetails => 'View full tracking';

  @override
  String get trackingSearchStatusPending => 'Pending';

  @override
  String get trackingSearchStatusAccepted => 'Confirmed';

  @override
  String get trackingSearchStatusPaid => 'Paid';

  @override
  String get trackingSearchStatusDroppedOff => 'Dropped off';

  @override
  String get trackingSearchStatusDelivered => 'Delivered';

  @override
  String get receptionConfirmTitle => 'Confirmation';

  @override
  String get receptionConfirmHeading => 'Confirm receipt';

  @override
  String receptionChooseInFrontOf(String name) {
    return 'In front of $name, choose:';
  }

  @override
  String get receptionTabQr => 'Scan QR';

  @override
  String get receptionTabCode => 'Enter code';

  @override
  String get receptionQrTitle => 'Scan the QR code';

  @override
  String get receptionQrDescription =>
      'Ask the traveler to show the QR code on their phone.';

  @override
  String get receptionCodeOptionLabel => 'OPTION 2 · CODE';

  @override
  String get receptionCodeTitle => 'Enter the code you received';

  @override
  String receptionCodeExpiresIn(String time) {
    return 'Sent by SMS · expires in $time';
  }

  @override
  String receptionReleaseWarning(String name) {
    return 'By confirming, you release the payment to $name. If something\'s wrong, contest first.';
  }

  @override
  String get receptionContestFirst => 'contest first';

  @override
  String get trackingTimelineTitle => 'Parcel tracking';

  @override
  String get trackingTimelineShare => 'Share tracking';

  @override
  String get trackingTimelineStepsHeader => 'STEPS';

  @override
  String get trackingEventDepartureConfirmed => 'Departure confirmed';

  @override
  String get trackingEventInTransit => 'In transit';

  @override
  String get trackingEventArrivalConfirmed => 'Arrival confirmed';

  @override
  String get trackingGpsRecorded => 'GPS location recorded';

  @override
  String get trackingOfflineScanSynced => 'Offline scan synced';

  @override
  String get trackingAwaitingConfirmationTitle => 'Awaiting confirmation';

  @override
  String get trackingAwaitingConfirmationDesc =>
      'The recipient must confirm receipt with the SMS code.';

  @override
  String get trackingEmptyTimelineTitle => 'Waiting for the departure scan';

  @override
  String get trackingEmptyTimelineDesc =>
      'The traveler will scan the QR code when the parcel is handed over.';

  @override
  String get trackingApplessTitle => 'No app needed!';

  @override
  String get trackingApplessMessage =>
      'When the traveler is at your door, you\'ll confirm with a QR code or a 4-digit code.';

  @override
  String get trackingSearchSheetTitle => 'Search for a parcel';

  @override
  String get trackingSearchSheetSubtitle => 'Format: DON-XXXXXX';

  @override
  String get cancellationConfirmTitle => 'Cancel this trip?';

  @override
  String get cancellationIrreversibleSubtitle => 'This action can\'t be undone';

  @override
  String get cancellationConfirmAction => 'Confirm cancellation';

  @override
  String get cancellationAutoRefundNotice =>
      'All affected senders will be refunded automatically.';

  @override
  String get cancellationReasonFieldLabel => 'Reason';

  @override
  String get cancellationSpecifyLabel => 'Please specify...';

  @override
  String get cancellationSpecifyHint => 'Describe your reason';

  @override
  String get cancellationSelectReasonError => 'Please select a reason';

  @override
  String get cancellationSpecifyReasonError => 'Please specify your reason';

  @override
  String get cancellationConfirmDialogMessage =>
      'This will cancel your trip and automatically refund all affected senders.';

  @override
  String get cancellationTripCanceledSnackbar => 'Trip canceled';

  @override
  String get deliveryNoShowTravelerNotDeliveringTitle =>
      'The traveler isn\'t delivering';

  @override
  String get deliveryNoShowReportAbsentRecipientTitle =>
      'Report the recipient\'s no-show';

  @override
  String get deliveryNoShowTravelerNotDeliveringSubtitle =>
      'Unreachable or refuses to hand over the parcel';

  @override
  String get deliveryNoShowReportAbsentRecipientSubtitle =>
      'If you\'re on-site and they\'re not answering';

  @override
  String get deliveryNoShowTravelerAbsentSheetTitle =>
      'The traveler didn\'t show up for the handover?';

  @override
  String get deliveryNoShowRecipientAbsentSheetTitle =>
      'The recipient didn\'t show up for the handover?';

  @override
  String get deliveryNoShowConfirmReportAction => 'Confirm the report';

  @override
  String get deliveryNoShowTravelerNotDeliveringBody =>
      'The traveler isn\'t delivering the parcel to your recipient.';

  @override
  String get deliveryNoShowRecipientAbsentBody =>
      'The recipient didn\'t show up at the handover point.';

  @override
  String get deliveryNoShowContestNotice =>
      'The other party has 24 hours to contest. The payment stays on hold during the review. No automatic payout.';

  @override
  String get rematchAlternativesTitle => 'Available alternatives';

  @override
  String get rematchAnnouncementUnavailable =>
      'This listing is no longer available';

  @override
  String get rematchNoTravelersTitle => 'No traveler available';

  @override
  String get rematchNoTravelersDescription =>
      'No traveler available within 72h: your refund is being processed';

  @override
  String rematchTravelersAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers available',
      one: '$count traveler available',
    );
    return '$_temp0';
  }

  @override
  String get rematchTripCancelledTitle => 'Trip canceled';

  @override
  String rematchSendersRefunded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count senders refunded automatically.',
      one: '$count sender refunded automatically.',
    );
    return '$_temp0';
  }

  @override
  String get rematchRefundInProgress => 'Your refund is in progress.';

  @override
  String get rematchBackHomeAction => 'Back to home';

  @override
  String get ratingRateSender => 'Rate the sender';

  @override
  String ratingRateTraveler(String name) {
    return 'Rate $name';
  }

  @override
  String get ratingSubtitle => 'Your review helps the Yadony community';

  @override
  String get ratingSubmitAction => 'Send rating';

  @override
  String get ratingCommentLabel => 'Comment (optional)';

  @override
  String get ratingCommentHint => 'Share your experience…';

  @override
  String get ratingThanksSnackbar => 'Thanks for your rating!';

  @override
  String ratingStarsSemantics(int index) {
    return 'Rate $index out of 5';
  }

  @override
  String ratingReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '$count review',
    );
    return '$_temp0';
  }

  @override
  String get ratingMyReviewsTitle => 'Reviews received';

  @override
  String get ratingAuthorFallbackName => 'Yadony user';

  @override
  String get ratingEmptyTitle => 'You haven\'t received any reviews yet';

  @override
  String get ratingEmptyDescription =>
      'Ratings and comments left by travelers will appear here.';

  @override
  String get ratingLoadErrorTitle => 'Couldn\'t load reviews';

  @override
  String get ratingReceivedHeader => 'REVIEWS RECEIVED';

  @override
  String ratingFilteredHeader(int stars, int count) {
    return '$stars★ REVIEWS · $count';
  }

  @override
  String get ratingShowAll => 'Show all';

  @override
  String ratingTotalReceived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'From $count reviews',
      one: 'From $count review',
    );
    return '$_temp0';
  }

  @override
  String ratingDistributionSemantics(int stars, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '$count review',
    );
    return '$stars stars, $_temp0';
  }

  @override
  String ratingQuotedComment(String comment) {
    return '“$comment”';
  }

  @override
  String get ratingExcludedNotice => 'Excluded from the average';

  @override
  String get cancellationReasonFlightCanceled => 'Flight canceled';

  @override
  String get cancellationReasonPersonalEmergency => 'Personal emergency';

  @override
  String get cancellationReasonHealthIssue => 'Health issue';

  @override
  String get cancellationReasonItineraryChange => 'Itinerary change';

  @override
  String get cancellationReasonOther => 'Other';

  @override
  String get ratingStarVeryDisappointing => 'Very disappointing';

  @override
  String get ratingStarDisappointing => 'Disappointing';

  @override
  String get ratingStarFair => 'Fair';

  @override
  String get ratingStarGood => 'Good';

  @override
  String get ratingStarExcellent => 'Excellent!';

  @override
  String get kycRejectionDocumentExpired =>
      'Your ID document has expired. Use a valid document and try again.';

  @override
  String get kycRejectionDocumentTypeNotSupported =>
      'This document type is not accepted. Use an ID card, a passport, or a driver\'s license.';

  @override
  String get kycRejectionDocumentUnverifiedOther =>
      'The document provided could not be read or verified. Make sure it is sharp, complete, and well lit, then try again.';

  @override
  String get kycRejectionCountryNotSupported =>
      'Your document\'s country is not supported for verification.';

  @override
  String get kycRejectionIdNumberMismatch =>
      'The information on your document could not be confirmed. Make sure it is clearly legible and try again.';

  @override
  String get kycRejectionSelfieDocumentMissingPhoto =>
      'The photo on your document could not be compared with your selfie. Try again with an ID document that has a clear photo.';

  @override
  String get kycRejectionSelfieFaceMismatch =>
      'Your selfie does not match the photo on the document. Retry the verification in good lighting conditions.';

  @override
  String get kycRejectionSelfieUnverified =>
      'Your selfie could not be verified. Try again in a well-lit place, without glasses or headwear.';

  @override
  String get kycRejectionUnderSupportedAge =>
      'Identity verification is reserved for adults.';

  @override
  String get kycRejectionConsentDeclined =>
      'You declined to give your consent, which is required to verify your identity.';

  @override
  String get kycRejectionSessionCanceled =>
      'The verification was closed before it was completed.';

  @override
  String get kycRejectionGeneric =>
      'We could not verify your identity. Make sure your document is legible and try again.';

  @override
  String get kycVerificationTitle => 'Identity verification';

  @override
  String get kycStatusNotStartedTitle => 'Verification not started';

  @override
  String get kycStatusNotStartedBody =>
      'You need to verify your identity to use all of Yadony\'s features.';

  @override
  String get kycStatusVerifiedTitle => 'Identity verified ✓';

  @override
  String get kycStatusVerifiedBodyRedirecting =>
      'Your identity has been successfully verified. Redirecting…';

  @override
  String get kycStatusVerifiedBodyClosing =>
      'Your identity has been successfully verified. Closing…';

  @override
  String get kycStatusPendingTitle => 'Verification in progress';

  @override
  String get kycStatusPendingBody =>
      'This usually takes less than a minute, sometimes a few minutes. You can close this screen, you\'ll be notified of the result.';

  @override
  String get kycStatusTimedOutTitle =>
      'Verification is taking longer than expected';

  @override
  String get kycStatusTimedOutBody =>
      'You can close this screen and come back later. Your ✓ badge will appear automatically once the verification is complete.';

  @override
  String get kycStatusRejectedTitle => 'Verification failed';

  @override
  String get kycStatusPollingIndicator => 'Automatic verification in progress';

  @override
  String get kycStatusStartAction => 'Start verification';

  @override
  String get kycStatusRetryAction => 'Retry verification';

  @override
  String get kycStatusResumeAction => 'Resume verification';

  @override
  String get kycStatusBackToApp => 'Back to the app';

  @override
  String get kycStatusContinueLater => 'Continue later';

  @override
  String get kycWebviewLoadError => 'Unable to load the verification page';

  @override
  String get kycRequiredTitle => 'Verification required';

  @override
  String get kycRequiredMessageNotStarted =>
      'To send a parcel, your identity must be verified.';

  @override
  String get kycRequiredMessageRejected =>
      'Your verification failed. Try again so you can send a parcel.';

  @override
  String get kycRequiredMessagePending =>
      'Your verification is in progress. You\'ll be able to send once your identity is validated.';

  @override
  String get kycRequiredVerifyAction => 'Verify my identity';

  @override
  String get kycInfoDuration => 'Verification takes 2 to 5 minutes';

  @override
  String get kycInfoSecureProcess => 'Secure verification process';

  @override
  String get kycOnboardingTitle => 'Verify your identity';

  @override
  String get kycOnboardingSubtitle => 'Required to post listings on Yadony';

  @override
  String get kycOnboardingStartAction => 'Start verification';

  @override
  String get kycOnboardingIdSelfieRequired => 'ID document + selfie required';

  @override
  String get profileSectionAccount => 'MY ACCOUNT';

  @override
  String get profileSectionMoney => 'MONEY';

  @override
  String get profileMoneyReceivePayments => 'Get paid';

  @override
  String get profileMoneyVerifyIdentityToActivate =>
      'Verify your identity to activate';

  @override
  String get profileMoneyMobileMoneyPayout => 'Mobile money payout';

  @override
  String get profileMoneyMobileMoneyPayoutSubtitle =>
      'CFA zone: Orange Money, Wave, MTN';

  @override
  String get profileMoneyCashCommissionCard => 'Cash service fee card';

  @override
  String get profileSectionReputation => 'MY REPUTATION';

  @override
  String get profileReputationPublicProfile => 'My public profile';

  @override
  String get profileReputationPublicProfileSubtitle => 'What others see';

  @override
  String get profileReputationMyReviews => 'Reviews received';

  @override
  String get profileSectionAdvantages => 'MY BENEFITS';

  @override
  String get profileAdvantagesProProfile => 'My Pro profile';

  @override
  String get profileAdvantagesUpgradeToPro => 'Upgrade to a Pro account';

  @override
  String get profileAdvantagesReferral => 'Referrals';

  @override
  String get profileReferralZeroInvited => '0 invited';

  @override
  String get profileAdvantagesHaveReferralCode => 'I have a referral code';

  @override
  String get profileSectionTracking => 'TRACKING';

  @override
  String get profileTrackingDisputes => 'My disputes';

  @override
  String get profileTrackingDisputesSubtitle => 'Track your disputes';

  @override
  String get profileTrackingSubscriptions => 'Following';

  @override
  String get profileTrackingSubscriptionsSubtitle =>
      'The travelers whose trips you follow';

  @override
  String get profileSectionHelp => 'HELP';

  @override
  String get profileHelpFaq => 'FAQ & help';

  @override
  String get profileHelpFaqSubtitle => 'Answers to frequently asked questions';

  @override
  String get profileHelpCommunity => 'Social media & tutorials';

  @override
  String get profileHelpCommunitySubtitle => 'Yadony videos and community';

  @override
  String get profileHelpContactSupport => 'Contact support';

  @override
  String get profileHelpContactSupportSubtitle =>
      'Response usually within 24 hours';

  @override
  String get profileContactTypePhone => 'PHONE';

  @override
  String get profileContactTypeEmail => 'EMAIL';

  @override
  String get profileNotAdded => 'Not added';

  @override
  String get profileAddBadge => '+ Add';

  @override
  String get profileAccountIdentityDocuments => 'ID documents';

  @override
  String get profileKycVerifiedLabel => 'Verified';

  @override
  String get profileKycInProgressLabel => 'In progress';

  @override
  String get profileKycToVerifyLabel => 'Verify';

  @override
  String get profileCompletionVerifyIdentity => 'Verify my identity';

  @override
  String get profileCompletionActivatePayments => 'Activate payments';

  @override
  String get profileFieldPhotoShort => 'Photo';

  @override
  String get profileFieldFirstName => 'First name';

  @override
  String get profileFieldLastNameShort => 'Last name';

  @override
  String get profileFieldEmailShort => 'Email';

  @override
  String get profileFieldPhone => 'Phone';

  @override
  String get profileFieldCity => 'City';

  @override
  String get profileFieldAbout => 'About';

  @override
  String profileCompletionSemantics(int percent) {
    return 'Account $percent percent complete. Complete now.';
  }

  @override
  String get profileCompletionCta => 'Complete your account';

  @override
  String profileCompletionShort(int percent) {
    return '$percent% complete · Complete now';
  }

  @override
  String profileItemToComplete(String label) {
    return '$label, to complete';
  }

  @override
  String get profileProBadge => 'Pro';

  @override
  String get profileChipPhoneVerified => 'Phone ✓';

  @override
  String get profileChipPhoneMissing => 'Phone missing';

  @override
  String get profileChipEmailVerified => 'Email ✓';

  @override
  String get profileChipEmailMissing => 'Email missing';

  @override
  String get profileChipIdentityVerified => 'Identity ✓';

  @override
  String get profileMenuEditProfile => 'Edit profile';

  @override
  String get profileMenuSettings => 'Settings';

  @override
  String get profileMenuAccountSection => 'My account';

  @override
  String get profileMenuExportData => 'Download my data';

  @override
  String get profileMenuExportDataSubtitle => 'GDPR export in JSON format';

  @override
  String get profileLogoutAction => 'Sign out';

  @override
  String get profileMenuDeleteAccount => 'Delete my account';

  @override
  String get profileMenuDeleteAccountSubtitle => '30-day withdrawal period';

  @override
  String get profileSkeletonLoadingSemantics => 'Loading profile';

  @override
  String get profileSkeletonUnavailableTitle => 'Profile unavailable';

  @override
  String get profileSkeletonUnavailableBody =>
      'Unable to load your account. Check your connection, then try again.';

  @override
  String profileDeletionScheduled(String date) {
    return 'Deletion scheduled for $date';
  }

  @override
  String get profileDeletionCancelAction => 'Cancel deletion';

  @override
  String get profileDeletionRefundsNotice =>
      'Refunds already in progress are not canceled.';

  @override
  String get profileWalletBalanceLabel => 'Balance';

  @override
  String get profileWalletTopUpSemantics => 'Top up wallet';

  @override
  String get profileWalletUnavailable => 'Balance unavailable';

  @override
  String get contactEditPhoneTitle => 'Edit phone number';

  @override
  String get contactSendCodeAction => 'Send code';

  @override
  String get contactVerifyAction => 'Verify';

  @override
  String get contactEditEmailTitle => 'Edit email';

  @override
  String get contactAddPhoneTitle => 'Add a phone number';

  @override
  String get contactPhoneAddedSuccess => 'Number added successfully!';

  @override
  String get contactPhoneNumberLabel => 'PHONE NUMBER';

  @override
  String get contactPhoneOtpNotice =>
      'A verification code will be sent by SMS.';

  @override
  String get contactDialCodeTitle => 'Country code';

  @override
  String get contactAddEmailTitle => 'Add an email';

  @override
  String get contactEmailVerifiedSuccess => 'Email verified successfully!';

  @override
  String get contactEmailAddressLabel => 'EMAIL ADDRESS';

  @override
  String get contactEmailOtpNotice =>
      'A verification code will be sent to this email.';

  @override
  String contactCodeSentTo(String destination) {
    return 'Code sent to $destination';
  }

  @override
  String get profileCommunityJoinTitle => 'Join the community';

  @override
  String get profileCommunityJoinSubtitle => 'Find Yadony\'s official spaces.';

  @override
  String get profileCommunityActionJoin => 'Join';

  @override
  String get profileCommunityActionFollow => 'Follow';

  @override
  String get profileCommunityActionSubscribe => 'Subscribe';

  @override
  String get profileLogoutConfirmTitle => 'Sign out?';

  @override
  String get profileLogoutConfirmMessage =>
      'You\'ll need to sign in again to continue.';

  @override
  String get profileMenuButtonTooltip => 'Menu';

  @override
  String get profileFooterVersion => 'Yadony v1.0.0 · Made with ❤️ in Paris';

  @override
  String get editProfileImageOnlyError =>
      'Only images are accepted (no video).';

  @override
  String editProfilePhotoTooLarge(int maxMb) {
    return 'Photo too large (max $maxMb MB).';
  }

  @override
  String get profileEditChangePhotoSemantics => 'Change profile photo';

  @override
  String get profileEditChangePhotoLabel => 'Change photo';

  @override
  String get profileEditSectionIdentity => 'Identity';

  @override
  String get profileEditLastNameFieldLabel => 'Last name';

  @override
  String get profileEditNoBioPlaceholder => 'No bio';

  @override
  String get profileEditBioFieldLabel => 'Bio';

  @override
  String get profileEditSectionContact => 'Contact details';

  @override
  String get profileFieldEmailAllCaps => 'EMAIL';

  @override
  String get profileEditSectionPersonalInfo => 'Personal information';

  @override
  String get profileFieldCityAllCaps => 'CITY';

  @override
  String get profileEditCityPlaceholder => 'Not provided';

  @override
  String get profileEditSectionPreferences => 'Preferences';

  @override
  String get profileFieldLanguagesAllCaps => 'LANGUAGES SPOKEN';

  @override
  String get profileEditLanguagesPlaceholder => 'Not provided';

  @override
  String get profileEditLanguagesFieldLabel => 'Languages spoken';

  @override
  String get profileEditCompletionGaugeTitle => 'Profile complete';

  @override
  String get profileEditCompletionGaugeSubtitle =>
      'Photo, identity, contact details and information complete your profile';

  @override
  String get profileEditNoNamePlaceholder => 'Add your first and last name';

  @override
  String get profileAddBadgeAction => 'Add';

  @override
  String get communityEmptyTitle => 'No content yet';

  @override
  String get communityEmptyDescription =>
      'Our tutorials and community spaces will be available here soon.';

  @override
  String get communityTutorialsTitle => 'Video tutorials';

  @override
  String get communityTutorialsSubtitle =>
      'Learn the essential Yadony journeys.';

  @override
  String get profileLanguageFrench => 'French';

  @override
  String get profileLanguageWolof => 'Wolof';

  @override
  String get profileLanguageBambara => 'Bambara';

  @override
  String get profileLanguageEnglish => 'English';

  @override
  String get profileLanguageSpanish => 'Spanish';

  @override
  String get profileLanguageArabic => 'Arabic';

  @override
  String get profilePublicOwnProfileTitle => 'What others see';

  @override
  String get profilePublicTitleFallback => 'Profile';

  @override
  String get profilePublicMoreOptionsTooltip => 'More options';

  @override
  String get profilePublicReportAction => 'Report';

  @override
  String profilePublicReportUserAction(String name) {
    return 'Report $name';
  }

  @override
  String profilePublicBlockUserAction(String name) {
    return 'Block $name';
  }

  @override
  String get profilePublicLoadErrorTitle => 'Couldn\'t load profile';

  @override
  String profilePublicRatingLine(String rating, int count, String memberSince) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '$count review',
    );
    return '⭐ $rating · $_temp0 · $memberSince';
  }

  @override
  String get profilePublicVerified => '✓ Verified';

  @override
  String get profilePublicProBadge => 'Pro';

  @override
  String get profilePublicStatRatingLabel => 'Rating';

  @override
  String get profilePublicStatDeliveriesLabel => 'Deliveries';

  @override
  String get profilePublicAboutSectionLabel => 'ABOUT';

  @override
  String get profilePublicLanguagesSectionLabel => 'LANGUAGES';

  @override
  String get profilePublicBadgesSectionLabel => 'BADGES';

  @override
  String get profilePublicContactCallLabel => 'Reachable by call';

  @override
  String get profilePublicContactMessageLabel => 'Reachable by message';

  @override
  String get profilePublicContactBothLabel => 'Call & message';

  @override
  String get profilePublicAvailabilitySectionLabel => 'AVAILABILITY';

  @override
  String profilePublicRespondsWithin(int hours) {
    return 'Replies in < ${hours}h';
  }

  @override
  String get profilePublicRecentReviewsSectionLabel => 'RECENT REVIEWS';

  @override
  String get profilePublicNoReviewsYet => 'No reviews yet.';

  @override
  String profilePublicSeeAllReviews(int count) {
    return 'See all reviews ($count) ›';
  }

  @override
  String get profileUserFallback => 'User';

  @override
  String get followFollowButton => 'Follow';

  @override
  String get followFollowingButton => 'Following ✓';

  @override
  String get followUnfollowDialogTitle => 'Unfollow?';

  @override
  String get followUnfollowButton => 'Unfollow';

  @override
  String get profilePublicUnfollowDialogMessage =>
      'You will no longer receive this traveler\'s notifications.';

  @override
  String get profilePublicEnablePushTooltip => 'Turn on notifications';

  @override
  String get profilePublicDisablePushTooltip => 'Turn off notifications';

  @override
  String get shipmentsHistoryTitle => 'Delivery history';

  @override
  String get shipmentsHistoryEmptyTitle => 'No completed deliveries';

  @override
  String get shipmentsHistoryEmptyDescription =>
      'Your completed deliveries will appear here.';

  @override
  String shipmentsHistoryDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }

  @override
  String get shipmentsHistoryDetailsButton => 'See details';

  @override
  String get allReviewsSheetTitle => 'Reviews';

  @override
  String get faqFindAnswerTitle => 'Find an answer';

  @override
  String get faqFindAnswerSubtitle =>
      'Search for an answer or browse categories.';

  @override
  String get faqSearchHint => 'Search help';

  @override
  String get faqEmptyResultsTitle => 'No results';

  @override
  String get faqEmptyResultsDescription =>
      'Try different keywords or contact our team.';

  @override
  String get faqContactCardTitle => 'Didn\'t find your answer?';

  @override
  String get faqContactCardSubtitle => 'Our team is here to help.';

  @override
  String get faqAccountTitle => 'Account & identity';

  @override
  String get faqAnnouncementsTitle => 'Listings & requests';

  @override
  String get faqPaymentsTitle => 'Payments & refunds';

  @override
  String get faqDeliveryTitle => 'Tracking & delivery';

  @override
  String get faqSafetyTitle => 'Security & data';

  @override
  String get faqAccountIdentityRequiredQ =>
      'Why is identity verification required?';

  @override
  String get faqAccountIdentityRequiredA =>
      'It may be required by our payment partners and by regulations that apply to certain transactions. It also helps us fight fraud and protect Yadony users.';

  @override
  String get faqAccountIdentityDelayQ => 'How long does verification take?';

  @override
  String get faqAccountIdentityDelayA =>
      'Verification is often completed within minutes. If a manual review is needed, it can take longer.';

  @override
  String get faqAccountIdentityDocumentsQ => 'Which documents are accepted?';

  @override
  String get faqAccountIdentityDocumentsA =>
      'National ID card, passport, or a valid residence permit. The document must be legible and not expired.';

  @override
  String get faqAccountWithoutIdentityQ =>
      'Can I use Yadony without verifying my identity?';

  @override
  String get faqAccountWithoutIdentityA =>
      'You can browse listings without verifying your identity. Some actions, such as sending, carrying parcels, or receiving payments, may require verification.';

  @override
  String get faqAnnouncementsPublishTripQ =>
      'How do I post a trip as a traveler?';

  @override
  String get faqAnnouncementsPublishTripA =>
      'From Home or Activity, choose \"Post a trip\". Enter the departure city, the destination, the date and the available capacity.';

  @override
  String get faqAnnouncementsPublishRequestQ =>
      'How do I post a parcel request?';

  @override
  String get faqAnnouncementsPublishRequestA =>
      'From Home or Activity, choose \"Post a parcel\". Describe the parcel, its estimated weight and the recipient. Matching travelers will then be able to make an offer.';

  @override
  String get faqAnnouncementsEditRequestQ =>
      'Can I edit my request after posting it?';

  @override
  String get faqAnnouncementsEditRequestA =>
      'You can edit a request as long as no offer has been accepted. Once one is accepted, contact support if important information needs to be corrected.';

  @override
  String get faqPaymentsPaymentTimingQ => 'When am I charged?';

  @override
  String get faqPaymentsPaymentTimingA =>
      'For a card payment, the funds are held and secured when the offer is accepted, then released as the delivery progresses. For cash and Mobile Money, follow the instructions shown when you choose your payment method.';

  @override
  String get faqPaymentsRefundQ => 'How does the refund work if I cancel?';

  @override
  String get faqPaymentsRefundA =>
      'The refund depends on the payment method and when the cancellation happens. A card payment is credited back to the original method after processing. For Mobile Money, the timing depends on the operator. In cash, Yadony doesn\'t hold the funds and can\'t process the refund automatically.';

  @override
  String faqPaymentsCommissionQ(String percent) {
    return 'Why is there a $percent% service fee?';
  }

  @override
  String get faqPaymentsCommissionA =>
      'The service fee covers payment costs, support, fraud prevention and the development of the platform.';

  @override
  String get faqPaymentsPaymentSecurityQ => 'Are payments secure?';

  @override
  String get faqPaymentsPaymentSecurityA =>
      'Online payments are processed by the providers listed in the app. Yadony doesn\'t store your full card details. A cash payment isn\'t held and secured: never pay outside the process set up in the app.';

  @override
  String get faqDeliveryHandoverQrQ => 'How does the drop-off QR code work?';

  @override
  String get faqDeliveryHandoverQrA =>
      'At drop-off, the QR code confirms the parcel was taken in charge and starts tracking. Without a connection, the scan is stored on the device and synced once you\'re back online.';

  @override
  String get faqDeliveryParcelMissingQ =>
      'What should I do if the parcel doesn\'t arrive?';

  @override
  String get faqDeliveryParcelMissingA =>
      'Open a dispute from \"My disputes\" as soon as you notice the problem. Add the photos, messages and tracking information available. The applicable deadlines are shown in the reporting flow.';

  @override
  String get faqDeliveryDeliveryDelayQ => 'What\'s the average delivery time?';

  @override
  String get faqDeliveryDeliveryDelayA =>
      'The delay depends on the chosen trip and the date announced by the traveler. Always check the trip details before accepting an offer.';

  @override
  String get faqSafetyLostParcelQ => 'What happens if my parcel is lost?';

  @override
  String faqSafetyLostParcelA(String cap) {
    return 'Yadony doesn\'t automatically cover the loss of a parcel. After investigation, a refund of up to $cap € may be granted if all conditions are met:\n\n• card payment made within Yadony;\n• no payment or agreement made outside the platform;\n• drop-off and handover QR codes used;\n• dispute opened within 15 days of the expected date;\n• content complying with allowed items.\n\nAny decision remains subject to approval by the Yadony team.';
  }

  @override
  String get faqSafetyDisputeQ =>
      'What should I do if I have a dispute with a traveler?';

  @override
  String get faqSafetyDisputeA =>
      'Open \"My disputes\" from your profile and provide the relevant details: photos, messages and tracking. Our team then reviews the case and keeps you informed in the app.';

  @override
  String get faqSafetyPersonalDataQ => 'Is my personal data protected?';

  @override
  String get faqSafetyPersonalDataA =>
      'Yadony applies security measures to protect your data and doesn\'t sell your personal information. You can review the privacy policy and manage your preferences in Settings.';

  @override
  String get faqSafetyDeleteAccountQ => 'How do I delete my account?';

  @override
  String get faqSafetyDeleteAccountA =>
      'In Settings → Data and account → Delete my account, you can choose a reversible 30-day pause or an immediate, permanent deletion. An ongoing transaction may temporarily block deletion.';

  @override
  String get helpTutorialScreenTitle => 'Video tutorial';

  @override
  String get helpTutorialNotFoundTitle => 'Tutorial not found';

  @override
  String get helpTutorialNotFoundDescription =>
      'This tutorial is no longer available.';

  @override
  String get helpTutorialSubscribeChannelButton => 'Subscribe to the channel';

  @override
  String helpTutorialPlayerSemanticsLabel(String title) {
    return 'Video player: $title';
  }

  @override
  String get helpTutorialPlaybackErrorTitle => 'Playback unavailable';

  @override
  String get helpTutorialPlaybackErrorDescription =>
      'Check your connection or open the video directly in YouTube.';

  @override
  String get helpTutorialOpenInYoutubeButton => 'Open in YouTube';

  @override
  String helpContextualCardSemanticsLabel(String title) {
    return 'Need help? Watch the tutorial $title';
  }

  @override
  String get helpContextualCardLabel => 'Need help? Watch the tutorial';

  @override
  String get helpContextualCardDismissTooltip => 'Hide this tip';

  @override
  String helpTutorialCardSemanticsLabel(String title) {
    return 'Watch the tutorial $title';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'APPEARANCE';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsThemeSubtitle => 'Overrides the system setting';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeAuto => 'Auto';

  @override
  String get settingsSectionLanguage => 'LANGUAGE & COMMUNICATION';

  @override
  String get settingsSectionDestinations => 'FAVORITE DESTINATIONS';

  @override
  String get settingsDestinationsLabel => 'Destinations';

  @override
  String get settingsNoDestination => 'None';

  @override
  String get settingsSectionSecurityData => 'SECURITY & DATA';

  @override
  String get securityTitle => 'Security';

  @override
  String get settingsSecuritySubtitle => 'Biometrics, PIN, sessions';

  @override
  String get settingsPrivacyLabel => 'Privacy';

  @override
  String get settingsPrivacySubtitle => 'Profile visibility, phone number';

  @override
  String get settingsMyData => 'My data';

  @override
  String get settingsMyDataSubtitle => 'GDPR export';

  @override
  String get settingsSectionPersonalization => 'PERSONALIZATION';

  @override
  String get settingsNotificationsLabel => 'Notifications';

  @override
  String get settingsNotificationsSubtitle => 'By alert type';

  @override
  String get settingsPreferencesLabel => 'Preferences';

  @override
  String get settingsPreferencesSubtitle => 'kg/lbs, currency, pickup radius';

  @override
  String get settingsAccessibilityLabel => 'Accessibility';

  @override
  String get settingsAccessibilitySubtitle => 'Contrast, font size';

  @override
  String get settingsResetGuidanceLabel => 'Show suggestions again';

  @override
  String get settingsResetGuidanceSubtitle =>
      'Brings back the closed cards (Search screen)';

  @override
  String get settingsResetGuidanceSnackbar =>
      'Suggestions and tutorials shown again.';

  @override
  String get settingsSectionInformation => 'INFORMATION';

  @override
  String get settingsTermsLabel => 'Terms of Use';

  @override
  String get settingsPrivacyPolicyLabel => 'Privacy Policy';

  @override
  String get settingsReportProblemLabel => 'Report a problem';

  @override
  String get settingsReportProblemSubtitle =>
      'Incident, bug, dispute (with screenshots)';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get settingsDiagnosticsSubtitle => 'Version, report a bug';

  @override
  String get devicesTitle => 'Signed-in devices';

  @override
  String get devicesSubtitle => 'View and revoke active sessions';

  @override
  String get pinRemovedMessage =>
      'PIN removed, the app will open without a code';

  @override
  String get securitySectionPayments => 'PAYMENTS';

  @override
  String get securityBiometricBeforePayment => 'Biometrics before payment';

  @override
  String get securityFingerprintOrFaceId => 'Fingerprint or Face ID';

  @override
  String get securityUnavailableOnDevice => 'Not available on this device';

  @override
  String get securitySectionApplication => 'APPLICATION';

  @override
  String get securityAppLockTitle => 'App lock';

  @override
  String get securityAppLockBiometricSubtitle =>
      'Biometrics or Face ID on launch';

  @override
  String get securityAppLockNeedsPinSubtitle =>
      'Requires enabling the PIN code below';

  @override
  String get securitySectionAuthentication => 'AUTHENTICATION';

  @override
  String get securityPinOnLaunchTitle => 'PIN on launch';

  @override
  String get securityPinRequestedSubtitle =>
      'Requested every time you open Yadony';

  @override
  String get securityPinDisabledSubtitle =>
      'Disabled, the app opens without a code';

  @override
  String get pinChangeTitle => 'Change PIN';

  @override
  String get securityPinCodeLength => '6-digit code';

  @override
  String get securitySectionSession => 'SESSION';

  @override
  String get pinCreateTitle => 'Create a PIN';

  @override
  String get pinIncorrectCode => 'Incorrect code';

  @override
  String get pinCreatedMessage => 'PIN enabled, it will be requested on launch';

  @override
  String get pinChangedMessage => 'PIN changed';

  @override
  String get pinCodesMismatch => 'The codes don\'t match';

  @override
  String get pinEnterCurrentSubtitle => 'Enter your current code';

  @override
  String get pinCreateNewSubtitle =>
      'Choose a 6-digit code, it will be requested on launch';

  @override
  String get pinEnterNewSubtitle => 'Create your new code';

  @override
  String get pinConfirmCreateSubtitle => 'Enter the same code to confirm';

  @override
  String get pinConfirmChangeSubtitle => 'Confirm the new code';

  @override
  String get devicesRevokeAllOthers => 'Sign out of all other devices';

  @override
  String get devicesActiveNow => 'Active now';

  @override
  String devicesAgoMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String devicesAgoHours(int hours) {
    return '$hours h ago';
  }

  @override
  String devicesAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }

  @override
  String get devicesAgoYesterday => 'yesterday';

  @override
  String get devicesThisDevice => 'This device';

  @override
  String get devicesRevoke => 'Revoke';

  @override
  String devicesSignedInCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You\'re signed in on $count devices',
      one: 'You\'re signed in on $count device',
    );
    return '$_temp0';
  }

  @override
  String get devicesLoadError => 'Couldn\'t load your devices';

  @override
  String get devicesRevokeError => 'Error while revoking';

  @override
  String get devicesRevokeAllError => 'Error while signing out';

  @override
  String get devicesUnknown => 'Unknown device';

  @override
  String get legalOpenInBrowser => 'Open in browser';

  @override
  String get legalPageLoadError => 'Couldn\'t load the page';

  @override
  String get legalPageLoadErrorHint => 'Check your connection and try again.';

  @override
  String get diagnosticsSectionApplication => 'APPLICATION';

  @override
  String get diagnosticsVersionLabel => 'Version';

  @override
  String get diagnosticsSectionConnectivity => 'CONNECTIVITY';

  @override
  String get diagnosticsApiStatusLabel => 'API status';

  @override
  String get diagnosticsSectionSupport => 'SUPPORT';

  @override
  String get diagnosticsReportBugLabel => 'Report a bug';

  @override
  String get diagnosticsCopyUserIdLabel => 'Copy my user ID';

  @override
  String get diagnosticsCopyUserIdSubtitle => 'Useful for support';

  @override
  String get diagnosticsOnline => 'Online';

  @override
  String get diagnosticsOffline => 'Offline';

  @override
  String get diagnosticsTest => 'Test';

  @override
  String get diagnosticsIdCopiedMessage => 'ID copied to clipboard';

  @override
  String get dataSettingsSectionYourData => 'YOUR DATA';

  @override
  String get dataSettingsDownloadLabel => 'Download my data';

  @override
  String get dataSettingsDownloadSubtitle => 'GDPR export in JSON format';

  @override
  String get dataSettingsExportStartedMessage =>
      'Export started. You\'ll receive an email with the download link within 72h.';

  @override
  String get pinConfirmSheetTitle => 'Confirm your PIN';

  @override
  String get pinConfirmSheetSubtitle => 'Enter your code to confirm';

  @override
  String pinAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts left',
      one: '$count attempt left',
    );
    return '$_temp0';
  }

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacySaveFailedMessage =>
      'Setting not saved, check your connection.';

  @override
  String get privacySectionWhoCanContact => 'WHO CAN CONTACT ME';

  @override
  String get privacyKycOnlyLabel => 'Verified profiles only';

  @override
  String get privacyKycOnlySubtitle =>
      'Only users who have verified their identity can send you an offer';

  @override
  String get privacyHidePhoneLabel => 'Hide my number';

  @override
  String get privacyHidePhoneSubtitle =>
      'Your number is never shared, even after an offer is accepted. Your exchanges go through Yadony messaging.';

  @override
  String get privacySectionBlocking => 'BLOCKING';

  @override
  String get privacySectionAppImprovement => 'APP IMPROVEMENT';

  @override
  String get privacyDataFooterNote =>
      'To download your data or delete your account, go to Settings › Data.';

  @override
  String get privacyBannerPhoneHiddenTitle => 'Your number stays hidden';

  @override
  String get privacyBannerPhoneProtectedTitle => 'Your number is protected';

  @override
  String get privacyBannerPhoneHiddenBody =>
      'Your number is never shared with anyone, even once the deal is done. Your partners reach you through Yadony messaging, and you can still call theirs.';

  @override
  String get privacyBannerPhoneProtectedBody =>
      'No one sees your number until an offer is accepted. Once the deal is done, you and your partner exchange numbers to arrange the drop-off.';

  @override
  String get privacyUnverifiedExposureNotice =>
      'Unverified profiles can send you requests. Yadony is not responsible for any difficulties encountered with them.';

  @override
  String get privacyAnalyticsConsentLabel => 'Usage statistics';

  @override
  String get privacyAnalyticsConsentSubtitle =>
      'Anonymous usage measurement to improve the app. Never your payments or your identity.';

  @override
  String get blockedUsersTitle => 'Blocked users';

  @override
  String get blockedUsersCardSubtitle => 'Manage the people you\'ve blocked';

  @override
  String get blockedUsersListIntro =>
      'A blocked person no longer sees your listings and can no longer send you an offer. You no longer see theirs either.';

  @override
  String get blockedUsersToday => 'Blocked today';

  @override
  String get blockedUsersYesterday => 'Blocked yesterday';

  @override
  String blockedUsersDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blocked $count days ago',
      one: 'Blocked $count day ago',
    );
    return '$_temp0';
  }

  @override
  String blockedUsersWeeksAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blocked $count weeks ago',
      one: 'Blocked $count week ago',
    );
    return '$_temp0';
  }

  @override
  String blockedUsersOnDate(String date) {
    return 'Blocked on $date';
  }

  @override
  String get blockedUsersUnblock => 'Unblock';

  @override
  String get blockedUsersEmptyTitle => 'You haven\'t blocked anyone';

  @override
  String get blockedUsersEmptySubtitle => 'People you block will appear here.';

  @override
  String get blockedUsersLoadError => 'Couldn\'t load blocked users';

  @override
  String get blockConfirmError => 'Something went wrong. Try again later.';

  @override
  String get settingsSyncFailed => 'Couldn\'t sync. Try again.';

  @override
  String get a11yTitle => 'Accessibility';

  @override
  String get a11ySectionText => 'TEXT';

  @override
  String get a11yFollowSystemLabel => 'Follow phone settings';

  @override
  String get a11yFollowSystemSubtitle =>
      'Text size follows the one set on your phone';

  @override
  String get a11yBoldTextLabel => 'Bold text';

  @override
  String get a11yBoldTextSubtitle => 'Thickens all text in the app';

  @override
  String get a11ySectionDisplay => 'DISPLAY';

  @override
  String get a11yHighContrastLabel => 'High contrast';

  @override
  String get a11yHighContrastSubtitle =>
      'Strengthens text, borders and dividers';

  @override
  String get a11yUnderlineLinksLabel => 'Underline links';

  @override
  String get a11yUnderlineLinksSubtitle =>
      'Links are no longer indicated by color alone';

  @override
  String get a11yReinforceLabelsLabel => 'Reinforce labels';

  @override
  String get a11yReinforceLabelsSubtitle =>
      'Adds an icon and a word to statuses indicated by color';

  @override
  String get a11ySectionMotion => 'MOTION';

  @override
  String get a11yReduceMotionLabel => 'Reduce animations';

  @override
  String get a11yReduceMotionSubtitle =>
      'Removes transitions, fade-ins and loading effects';

  @override
  String get a11ySectionMessagesActions => 'MESSAGES AND ACTIONS';

  @override
  String get a11yPersistentMessagesLabel => 'Keep messages displayed';

  @override
  String get a11yPersistentMessagesSubtitle =>
      'Messages stay visible until you dismiss them';

  @override
  String get a11yConfirmActionsLabel => 'Confirm important actions';

  @override
  String get a11yConfirmActionsSubtitle =>
      'Asks for confirmation before a payment, a cancellation or a deletion';

  @override
  String get a11yOpenSystemSettingsLabel => 'Open phone settings';

  @override
  String get a11yOpenSystemSettingsSubtitle =>
      'System text size, contrast and animations';

  @override
  String get a11yResetAll => 'Reset all';

  @override
  String get a11yResetAllMessage =>
      'All accessibility settings will return to their original value.';

  @override
  String get a11yPreviewLabel => 'Preview';

  @override
  String get a11yPreviewUrgentLabel => 'Urgent';

  @override
  String get a11yTextSizeLabel => 'Text size';

  @override
  String a11yPercent(int percent) {
    return '$percent%';
  }

  @override
  String a11yTextSizeDisabledSemantics(String percent) {
    return 'Text size, $percent, off';
  }

  @override
  String get a11yModeSystem => 'Follow phone';

  @override
  String get a11yModeOn => 'Always on';

  @override
  String get a11yModeOff => 'Always off';

  @override
  String get a11yModeSystemShort => 'Automatic';

  @override
  String get a11yModeOnShort => 'On';

  @override
  String get a11yModeOffShort => 'Off';

  @override
  String get a11yModeSystemSubtitle => 'Uses the setting defined on your phone';

  @override
  String get a11yModeFixedSubtitle => 'Regardless of the phone setting';

  @override
  String get privacyUnverifiedWarningTitle => 'Accept unverified profiles?';

  @override
  String get privacyUnverifiedWarningSubtitle =>
      'This option is not recommended by Yadony.';

  @override
  String get privacyUnverifiedWarningAccept => 'Accept anyway';

  @override
  String get privacyUnverifiedWarningConsequence1 =>
      'All users will be able to send you a request, whether they\'ve verified their identity or not.';

  @override
  String get privacyUnverifiedWarningConsequence2 =>
      'Yadony cannot confirm the identity of an unverified profile, nor their name, nor their documents.';

  @override
  String get privacyUnverifiedWarningConsequence3 =>
      'Yadony is not responsible for any difficulties you may encounter with an unverified profile.';

  @override
  String get privacyUnverifiedWarningReversible =>
      'You can turn this setting back on at any time. Requests already received are not affected.';

  @override
  String get privacyUnverifiedWarningCheckbox =>
      'I understand and accept this risk.';

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSettingsSectionCritical => 'CRITICAL PROTECTIONS';

  @override
  String get notificationSettingsDeliveryConfirmedLabel => 'Delivery confirmed';

  @override
  String get notificationSettingsSmsFallbackSubtitle =>
      'Automatic SMS if push not received';

  @override
  String get notificationSettingsPaymentReceivedLabel => 'Payment received';

  @override
  String get notificationSettingsDisputeOpenedLabel => 'Dispute opened';

  @override
  String get notificationSettingsSectionActivity => 'ACTIVITY';

  @override
  String get notificationSettingsBidsLabel => 'Matches & bids';

  @override
  String get notificationSettingsBidsSubtitle =>
      'Requests, acceptances, drop-off, cancellation…';

  @override
  String get notificationSettingsCorridorLabel => 'New trips';

  @override
  String get notificationSettingsCorridorSubtitle =>
      'Route alerts and followed travelers';

  @override
  String get notificationSettingsNegotiationsLabel => 'Price discussions';

  @override
  String get notificationSettingsNegotiationsSubtitle =>
      'Offers, counteroffers, payments…';

  @override
  String get notificationSettingsMessagesLabel => 'Messages';

  @override
  String get notificationSettingsMessagesSubtitle => 'New messages received';

  @override
  String get notificationSettingsAlwaysOnBadge => 'Always on';

  @override
  String get notificationSettingsCriticalBannerText =>
      'These notifications protect your transactions. They cannot be turned off.';

  @override
  String get notificationSettingsPackageMatchLabel => 'New matching parcels';

  @override
  String get notificationSettingsPackageMatchSubtitle =>
      'When a parcel matches one of your trips';

  @override
  String get prefsTitle => 'Preferences';

  @override
  String get prefsSectionUnits => 'UNITS';

  @override
  String get prefsWeightUnitLabel => 'Weight unit';

  @override
  String get prefsSectionCurrency => 'CURRENCY';

  @override
  String get prefsCountryLabel => 'Country';

  @override
  String get prefsCountryLockedSubtitle =>
      'Locked: a shipment is in progress or your payment account has been created';

  @override
  String get prefsCountryPlaceholder => 'Choose my country';

  @override
  String get prefsCurrencyLabel => 'Currency';

  @override
  String get prefsCurrencyLockedSubtitle =>
      'Locked: empty your wallet to change it';

  @override
  String get prefsDisplayCurrencyLabel => 'Display currency';

  @override
  String get prefsDisplayCurrencySubtitle =>
      'Prices posted in another currency are converted for reference only';

  @override
  String get prefsAutoLabel => 'Automatic';

  @override
  String get prefsSectionGeolocation => 'GEOLOCATION';

  @override
  String get prefsPickupRadiusLabel => 'Collection radius';

  @override
  String get prefsCountrySearchHint => 'Search for a country';

  @override
  String get prefsCountryNotFound => 'No country found';

  @override
  String get prefsAutoCurrencySubtitle => 'Follow my account\'s currency';

  @override
  String get prefsSectionMyTrips => 'MY TRIPS';

  @override
  String get prefsTravelerBadge => 'Traveler';

  @override
  String get prefsDefaultWeightLabel => 'Default weight';

  @override
  String get prefsDefaultWeightSubtitle => 'Pre-fills your listings';

  @override
  String get prefsMinPriceLabel => 'Minimum price';

  @override
  String prefsMinPriceNone(String symbol) {
    return '0 $symbol = no filter';
  }

  @override
  String get prefsMinPriceValueNone => 'None';

  @override
  String get prefsContactModeLabel => 'Contact method';

  @override
  String get prefsContactModeCall => 'Call';

  @override
  String get prefsContactModeMessage => 'Message';

  @override
  String get prefsContactModeBoth => 'Both';

  @override
  String get prefsResponseDelayLabel => 'Response delay';

  @override
  String get prefsResponseDelayHint => 'e.g. 3';

  @override
  String get deletionSheetTitle => 'Delete my account';

  @override
  String get deletionSoftConfirmLabel => 'Confirm the pause';

  @override
  String get deletionSoftConfirmDialogMessage =>
      'Your account will be suspended for 30 days. You can reactivate it from your profile.';

  @override
  String get deletionRequestedSnackbar =>
      'Your account will be deleted in 30 days. You can cancel from your profile. Refunds already started won\'t be canceled.';

  @override
  String get deletionModeSoftTitle => '30-day pause';

  @override
  String get deletionModeSoftBadge => 'REVERSIBLE';

  @override
  String get deletionModeSoftDescription =>
      'Your account is suspended. You can come back at any time within 30 days. After that, your personal data is pseudonymized (GDPR).';

  @override
  String get deletionModeHardTitle => 'Delete permanently';

  @override
  String get deletionModeHardBadge => 'IRREVERSIBLE';

  @override
  String get deletionModeHardDescription =>
      'All your personal data is erased immediately. This action is final and cannot be undone.';

  @override
  String get deletionReasonSectionTitle => 'Reason (optional)';

  @override
  String get deletionReasonNotUsing => 'I no longer use the service';

  @override
  String get deletionReasonPrivacy => 'Privacy concern';

  @override
  String get deletionReasonTooManyNotifications => 'Too many notifications';

  @override
  String get deletionReasonOther => 'Other reason';

  @override
  String get deletionContinueArrow => 'Continue →';

  @override
  String deletionWalletRefundRequestedMessage(String amounts) {
    return 'Request sent for $amounts. A team member will contact you about the refund.';
  }

  @override
  String get deletionWalletBalanceInfo =>
      'You have an available balance. It will automatically be refunded after your account is deleted. You can also request it now.';

  @override
  String get deletionRequestRefundNowButton => 'Request refund now';

  @override
  String deletionManualRailMessage(String amount) {
    return 'Balance of $amount: a team member will contact you about the refund.';
  }

  @override
  String deletionRefundableOnCardMessage(String amount) {
    return '$amount will be refunded to your card as soon as you request deletion.';
  }

  @override
  String deletionInFlightMessage(String amount) {
    return '$amount is already being refunded.';
  }

  @override
  String deletionBonusLostLabel(String amount) {
    return 'Referral bonus lost: $amount';
  }

  @override
  String deletionBonusForfeitedMessage(String amount) {
    return '$amount in bonus will be permanently lost when the account is deleted.';
  }

  @override
  String deletionBalanceAbsorbedByFeesMessage(String amount) {
    return 'Balance of $amount not refundable: the payment provider\'s fees absorb it entirely.';
  }

  @override
  String deletionRefundableWithFeeMessage(String refundable, String fee) {
    return '$refundable refundable, $fee in fees';
  }

  @override
  String deletionFeelessDestinationMessage(String destination) {
    return 'To $destination, no fees';
  }

  @override
  String deletionSettlementRefundedOnRequest(String amounts) {
    return '$amounts will be refunded as soon as you request it.';
  }

  @override
  String deletionSettlementBonusLost(String amounts) {
    return '$amounts in bonus will be permanently lost when the account is deleted.';
  }

  @override
  String get deletionBlockedActiveTransactions =>
      'You have a shipment being delivered, with funds on hold. You can delete your account once the delivery is confirmed.';

  @override
  String get deletionBlockedGeneric => 'Deletion isn\'t possible right now.';

  @override
  String get deletionFinalStepTitle => 'Last step';

  @override
  String get deletionFinalStepWarning =>
      'All your personal data will be erased immediately and permanently. This action is irreversible.';

  @override
  String get deletionFinalStepAcknowledgement =>
      'I understand that this deletion is final and irreversible.';

  @override
  String get deletionEscrowBlockedTitle => 'Deletion isn\'t possible right now';

  @override
  String get deletionEscrowBlockedMessage =>
      'One of your shipments is being delivered and its funds are on hold. You can delete your account once the delivery has been confirmed.';

  @override
  String get deletionEscrowBlockedCta => 'View my shipments';

  @override
  String get errorEscrowBlockedTitle => 'Can\'t delete your account yet';

  @override
  String get errorEscrowBlockedMessage =>
      'You have a payment in progress. You can delete your account once the delivery is confirmed.';

  @override
  String get notificationChannelTransactionalName => 'Yadony notifications';

  @override
  String get notificationChannelTransactionalDescription =>
      'Payments, deliveries and updates on your shipments';

  @override
  String get notificationChannelGeneralName => 'Yadony news';

  @override
  String get notificationChannelGeneralDescription =>
      'Matches, invitations and general information';

  @override
  String get notificationAgeNow => 'now';

  @override
  String notificationAgeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String notificationAgeHours(int hours) {
    return '$hours h';
  }

  @override
  String notificationAgeDays(int days) {
    return '${days}d';
  }

  @override
  String get notificationSectionNew => 'New';

  @override
  String get notificationSectionEarlier => 'Earlier';

  @override
  String get notificationSheetTitle => 'Notifications';

  @override
  String get notificationMarkAllRead => 'Read all';

  @override
  String get notificationLoadErrorTitle => 'Loading error';

  @override
  String get notificationLoadErrorDescription =>
      'We couldn\'t load your notifications.';

  @override
  String get notificationEmptyTitle => 'No notifications';

  @override
  String get notificationEmptyDescription =>
      'Your notifications will appear here.';

  @override
  String get notificationRouteMissing =>
      'This notification doesn\'t lead anywhere anymore.';

  @override
  String get notificationAnnouncementsCardTitle => 'Yadony announcements';

  @override
  String get notificationAnnouncementsLoadErrorDescription =>
      'We couldn\'t load the announcements.';

  @override
  String get notificationAnnouncementsEmptyTitle => 'No announcements';

  @override
  String get notificationAnnouncementsEmptyDescription =>
      'News and information from Yadony will appear here.';

  @override
  String get notificationDetailFallbackTitle => 'Notification';

  @override
  String get notificationDetailAnnouncementTitle => 'Yadony announcement';

  @override
  String get notificationDetailNotFoundTitle => 'Notification not found';

  @override
  String get notificationDetailNotFoundDescription =>
      'It may have been deleted, or the network is unavailable.';

  @override
  String get disputeDetailTitle => 'Dispute';

  @override
  String disputeOtherParty(String role, String name) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'SENDER': 'Traveler: $name',
      'other': 'Sender: $name',
    });
    return '$_temp0';
  }

  @override
  String get disputeShipmentDeleted => 'Shipment deleted';

  @override
  String disputeParcelWeight(String kg) {
    return 'Shipment $kg kg';
  }

  @override
  String get disputeDetailFrozenNotice =>
      'Refund on hold during the review. The Yadony team decides within 72 business hours.';

  @override
  String get disputeDetailTimelineSectionTitle => 'TRACKING';

  @override
  String get disputeDetailDecisionSectionTitle => 'DECISION';

  @override
  String get disputeDetailResolvedInFavor => 'Resolved in your favor';

  @override
  String get disputeDetailResolved => 'Dispute resolved';

  @override
  String get disputeDetailCompensationPaid => 'Compensation paid';

  @override
  String get disputeDetailContactSupport => 'Contact support';

  @override
  String get disputeListTitle => 'My disputes';

  @override
  String get disputeListLoadErrorTitle => 'We couldn\'t load your disputes';

  @override
  String get disputeListEmptyTitle => 'No disputes';

  @override
  String get disputeListEmptyDescription =>
      'Good news! A dispute opens automatically if you contest a traveler\'s no-show at drop-off.';

  @override
  String get disputeListEmptyAction => 'A problem with a shipment?';

  @override
  String get disputeTypeContestedNoShow => 'No-show contest';

  @override
  String get disputeTypeRecipientNoShow => 'Recipient no-show';

  @override
  String get disputeTypeDeliveryFailure => 'Delivery failure';

  @override
  String get disputeStatusOpen => 'Under review';

  @override
  String get disputeStatusResolved => 'Resolved';

  @override
  String disputeOpenedOn(String date) {
    return 'Opened on $date';
  }

  @override
  String disputeOpenedAndResolved(String opened, String resolved) {
    return 'Opened on $opened · Resolved on $resolved';
  }

  @override
  String get disputeCardFrozenNotice =>
      'Refund on hold during the review. Response within 72h.';

  @override
  String get disputeTimelineOpenedTitle => 'Dispute opened';

  @override
  String disputeTimelineContestedTraveler(String date) {
    return '$date · you contested the traveler\'s no-show';
  }

  @override
  String disputeTimelineContestedSender(String date) {
    return '$date · the sender contested a no-show at drop-off';
  }

  @override
  String get disputeTimelineReviewedSubtitle => 'reviewed by the Yadony team';

  @override
  String get disputeTimelineUnderReviewSubtitle =>
      'currently under review by the Yadony team';

  @override
  String get disputeTimelineDecisionTitleDone => 'Decision made';

  @override
  String get disputeTimelineDecisionTitlePending => 'Decision';

  @override
  String get disputeTimelineDecisionEta => 'within 72h';

  @override
  String get supportCategoryAccount => 'Account';

  @override
  String get supportCategoryKyc => 'Identity verification';

  @override
  String get supportCategoryPayment => 'Payment';

  @override
  String get supportCategoryTrip => 'Trip';

  @override
  String get supportCategoryPackage => 'Parcel';

  @override
  String get supportCategoryDelivery => 'Delivery';

  @override
  String get supportCategoryOther => 'Other';

  @override
  String get supportStatusNew => 'New';

  @override
  String get supportStatusAssigned => 'In progress';

  @override
  String get supportStatusWaitingUser => 'Reply received';

  @override
  String get supportStatusWaitingSupport => 'Awaiting support';

  @override
  String get supportStatusResolved => 'Resolved';

  @override
  String get supportTicketResolvedError =>
      'This ticket is resolved. Open a new one for another issue.';

  @override
  String get supportGenericError => 'Something went wrong. Try again.';

  @override
  String get supportScreenTitle => 'Support';

  @override
  String get supportHomeLoadErrorTitle => 'We couldn\'t load support';

  @override
  String get supportConnectionCheckFallback =>
      'Check your connection and try again.';

  @override
  String get supportHomeFaqTitle => 'Frequently asked questions';

  @override
  String get supportHomeFaqSubtitle =>
      'The answer might already be there. If not, open a ticket.';

  @override
  String get supportHomeMyTicketsTitle => 'My tickets';

  @override
  String get supportHomeNoTicketsMessage =>
      'No tickets yet. A problem the assistant couldn\'t solve? Open a ticket, the Yadony team will get back to you.';

  @override
  String get supportContactCta => 'Contact support';

  @override
  String get supportCreateTicketCategoryLabel => 'Category';

  @override
  String get supportCreateTicketSubjectLabel => 'Subject';

  @override
  String get supportCreateTicketSubjectHint => 'Summarize your problem';

  @override
  String get supportCreateTicketMessageLabel => 'Message';

  @override
  String get supportCreateTicketMessageHint => 'Describe what\'s happening';

  @override
  String get supportTicketFallbackTitle => 'Support ticket';

  @override
  String get supportTicketNotFoundTitle => 'Ticket not found';

  @override
  String get supportBrandName => 'Support Yadony';

  @override
  String get supportViewImageLabel => 'View image fullscreen';

  @override
  String supportPhotoIndex(int index, int count) {
    return 'Photo $index of $count';
  }

  @override
  String get supportResolvedBannerMessage =>
      'This ticket is resolved. Another issue? Open a new ticket from the Support page.';

  @override
  String get supportMessageHint => 'Your message';

  @override
  String get supportAttachTooltip => 'Attach an image';

  @override
  String get supportRemoveAttachmentLabel => 'Remove this image';

  @override
  String get supportConversationDefaultPreview =>
      'A question? Our team will get back to you here.';
}
