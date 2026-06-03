abstract final class AnalyticsEvents {
  // Auth
  static const signupStarted            = 'signup_started';
  static const otpSubmitted             = 'otp_submitted';
  static const signupCompleted          = 'signup_completed';
  static const analyticsConsentAnswered = 'analytics_consent_answered';
  static const loginSuccess             = 'login_success';
  static const loginFailed              = 'login_failed';

  // KYC
  static const kycStarted   = 'kyc_started';
  static const kycCompleted = 'kyc_completed';
  static const kycFailed    = 'kyc_failed';

  // Announcements
  static const announcementCreated = 'announcement_created';
  static const announcementViewed  = 'announcement_viewed';

  // Bids
  static const bidSubmitted = 'bid_submitted';
  static const bidAccepted  = 'bid_accepted';
  static const bidRejected  = 'bid_rejected';

  // Payments
  static const paymentInitiated    = 'payment_initiated';
  static const paymentSucceeded    = 'payment_succeeded';
  static const paymentFailed       = 'payment_failed';
  static const mobileMoneyAwaiting = 'mobile_money_awaiting';

  // Tracking / QR
  static const qrScanSuccess     = 'qr_scan_success';
  static const deliveryConfirmed = 'delivery_confirmed';

  // Package Request
  static const packageRequestCreated    = 'package_request_created';
  static const packageRequestSearched   = 'package_request_searched';
  static const negotiationOfferMade     = 'negotiation_offer_made';
  static const negotiationOfferAccepted = 'negotiation_offer_accepted';

  // Messaging
  static const conversationOpened = 'conversation_opened';
  static const messageSent        = 'message_sent';

  // Wallet
  static const walletTopupStarted   = 'wallet_topup_started';
  static const walletTopupCompleted = 'wallet_topup_completed';

  // Ratings
  static const ratingSubmitted = 'rating_submitted';

  // Cancellations
  static const cancellationInitiated = 'cancellation_initiated';
  static const rematchAccepted       = 'rematch_accepted';

  // Profile
  static const becomeTravelerStarted = 'become_traveler_started';
  static const upgradeToProStarted   = 'upgrade_to_pro_started';

  // Referral
  static const referralShared = 'referral_shared';

  // Settings
  static const analyticsConsentChanged  = 'analytics_consent_changed';
  static const accountDeletionRequested = 'account_deletion_requested';

  // Envois
  static const shipmentFilterApplied = 'shipment_filter_applied';

  // Errors (BlocObserver)
  static const blocError = 'bloc_error';
}
