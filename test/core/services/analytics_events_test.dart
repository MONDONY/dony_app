import 'package:dony/core/services/analytics_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all event names are non-empty snake_case strings', () {
    final events = [
      AnalyticsEvents.signupStarted,
      AnalyticsEvents.otpSubmitted,
      AnalyticsEvents.signupCompleted,
      AnalyticsEvents.analyticsConsentAnswered,
      AnalyticsEvents.countryOnboardingSelected,
      AnalyticsEvents.countryOnboardingSkipped,
      AnalyticsEvents.loginSuccess,
      AnalyticsEvents.loginFailed,
      AnalyticsEvents.kycStarted,
      AnalyticsEvents.kycCompleted,
      AnalyticsEvents.firstStepsChoice,
      AnalyticsEvents.homePublishSheetOpened,
      AnalyticsEvents.homePublishTapped,
      AnalyticsEvents.kycFailed,
      AnalyticsEvents.announcementCreated,
      AnalyticsEvents.announcementViewed,
      AnalyticsEvents.bidSubmitted,
      AnalyticsEvents.bidAccepted,
      AnalyticsEvents.bidRejected,
      AnalyticsEvents.paymentInitiated,
      AnalyticsEvents.paymentSucceeded,
      AnalyticsEvents.connectOnboardingLinkOpened,
      AnalyticsEvents.connectOnboardingCompleted,
      AnalyticsEvents.connectOnboardingStillPending,
      AnalyticsEvents.connectOnboardingFailed,
      AnalyticsEvents.paymentFailed,
      AnalyticsEvents.mobileMoneyAwaiting,
      AnalyticsEvents.qrScanSuccess,
      AnalyticsEvents.deliveryConfirmed,
      AnalyticsEvents.packageRequestCreated,
      AnalyticsEvents.packageRequestSearched,
      AnalyticsEvents.negotiationOfferMade,
      AnalyticsEvents.negotiationOfferAccepted,
      AnalyticsEvents.conversationOpened,
      AnalyticsEvents.messageSent,
      AnalyticsEvents.walletTopupStarted,
      AnalyticsEvents.walletTopupCompleted,
      AnalyticsEvents.walletActiveCurrencySwitched,
      AnalyticsEvents.ratingSubmitted,
      AnalyticsEvents.storeReviewRequested,
      AnalyticsEvents.storeListingOpened,
      AnalyticsEvents.cancellationInitiated,
      AnalyticsEvents.rematchAccepted,
      AnalyticsEvents.upgradeToProStarted,
      AnalyticsEvents.referralShared,
      AnalyticsEvents.analyticsConsentChanged,
      AnalyticsEvents.accountDeletionRequested,
      AnalyticsEvents.aiFormDraftOpened,
      AnalyticsEvents.aiFormDraftVoiceUsed,
      AnalyticsEvents.aiFormDraftTurn,
      AnalyticsEvents.aiFormDraftReady,
      AnalyticsEvents.aiFormDraftApplied,
      AnalyticsEvents.aiFormDraftDegraded,
      AnalyticsEvents.aiFormDraftQuotaExceeded,
      AnalyticsEvents.bidSupplementSheetOpened,
      AnalyticsEvents.bidSupplementRequested,
      AnalyticsEvents.bidSupplementRequestFailed,
      AnalyticsEvents.bidSupplementWithdrawn,
      AnalyticsEvents.bidSupplementViewed,
      AnalyticsEvents.bidSupplementDeclined,
      AnalyticsEvents.bidSupplementActionFailed,
      AnalyticsEvents.bidSupplementCashAccepted,
      AnalyticsEvents.bidSupplementCommissionResumed,
      AnalyticsEvents.handoverBlockedSupplement,
      AnalyticsEvents.bidAmendmentSheetOpened,
      AnalyticsEvents.bidAmendmentRequested,
      AnalyticsEvents.bidAmendmentRequestFailed,
      AnalyticsEvents.bidAmendmentViewed,
      AnalyticsEvents.bidAmendmentCancelled,
      AnalyticsEvents.bidAmendmentAccepted,
      AnalyticsEvents.bidAmendmentDeclined,
      AnalyticsEvents.bidAmendmentNotBrought,
      AnalyticsEvents.bidAmendmentActionFailed,
      AnalyticsEvents.bidAmendmentPaymentStarted,
      AnalyticsEvents.handoverBlockedAmendment,
      AnalyticsEvents.blocError,
    ];
    for (final e in events) {
      expect(e, isNotEmpty);
      expect(e, matches(RegExp(r'^[a-z][a-z_]+$')));
    }
    expect(
      events.toSet().length,
      events.length,
      reason: 'Duplicate event name',
    );
  });

  test('noms exacts des événements de la modification d\'un colis', () {
    expect(
      AnalyticsEvents.bidAmendmentSheetOpened,
      'bid_amendment_sheet_opened',
    );
    expect(AnalyticsEvents.bidAmendmentRequested, 'bid_amendment_requested');
    expect(
      AnalyticsEvents.bidAmendmentRequestFailed,
      'bid_amendment_request_failed',
    );
    expect(AnalyticsEvents.bidAmendmentViewed, 'bid_amendment_viewed');
    expect(AnalyticsEvents.bidAmendmentCancelled, 'bid_amendment_cancelled');
    expect(AnalyticsEvents.bidAmendmentAccepted, 'bid_amendment_accepted');
    expect(AnalyticsEvents.bidAmendmentDeclined, 'bid_amendment_declined');
    expect(AnalyticsEvents.bidAmendmentNotBrought, 'bid_amendment_not_brought');
    expect(
      AnalyticsEvents.bidAmendmentActionFailed,
      'bid_amendment_action_failed',
    );
    expect(
      AnalyticsEvents.bidAmendmentPaymentStarted,
      'bid_amendment_payment_started',
    );
    expect(
      AnalyticsEvents.handoverBlockedAmendment,
      'handover_blocked_amendment',
    );
  });
}
