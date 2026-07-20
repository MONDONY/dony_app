import 'package:dony/core/services/analytics_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all event names are non-empty snake_case strings', () {
    final events = [
      AnalyticsEvents.signupStarted,
      AnalyticsEvents.otpSubmitted,
      AnalyticsEvents.signupCompleted,
      AnalyticsEvents.analyticsConsentAnswered,
      AnalyticsEvents.loginSuccess,
      AnalyticsEvents.loginFailed,
      AnalyticsEvents.kycStarted,
      AnalyticsEvents.kycCompleted,
      AnalyticsEvents.kycFailed,
      AnalyticsEvents.announcementCreated,
      AnalyticsEvents.announcementViewed,
      AnalyticsEvents.bidSubmitted,
      AnalyticsEvents.bidAccepted,
      AnalyticsEvents.bidRejected,
      AnalyticsEvents.paymentInitiated,
      AnalyticsEvents.paymentSucceeded,
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
      AnalyticsEvents.ratingSubmitted,
      AnalyticsEvents.cancellationInitiated,
      AnalyticsEvents.rematchAccepted,
      AnalyticsEvents.upgradeToProStarted,
      AnalyticsEvents.referralShared,
      AnalyticsEvents.analyticsConsentChanged,
      AnalyticsEvents.accountDeletionRequested,
      AnalyticsEvents.blocError,
    ];
    for (final e in events) {
      expect(e, isNotEmpty);
      expect(e, matches(RegExp(r'^[a-z][a-z_]+$')));
    }
    expect(events.toSet().length, events.length, reason: 'Duplicate event name');
  });
}
