import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/tracking/data/tracking_photo_upload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('handover-sender-noshow-pending', () {
    const error = ConflictException(
      'd',
      code: 'handover-sender-noshow-pending',
    );

    test('est un refus « pour l\'instant » : l\'étape reste en file', () {
      expect(isRetryLaterTrackingRejection(error), isTrue);
    });

    test('n\'est pas un refus définitif', () {
      expect(isDefinitiveTrackingRejection(error), isFalse);
    });
  });

  test('422 bid-not-accepted reste un refus définitif', () {
    const error = ValidationException('d', code: 'bid-not-accepted');
    expect(isRetryLaterTrackingRejection(error), isFalse);
    expect(isDefinitiveTrackingRejection(error), isTrue);
  });

  test('chaque refus « pour l\'instant » a son événement', () {
    expect(
      handoverBlockedEvent('handover-supplement-pending'),
      AnalyticsEvents.handoverBlockedSupplement,
    );
    expect(
      handoverBlockedEvent('handover-amendment-pending'),
      AnalyticsEvents.handoverBlockedAmendment,
    );
    expect(
      handoverBlockedEvent('handover-sender-noshow-pending'),
      AnalyticsEvents.handoverBlockedSenderNoShow,
    );
    for (final code in handoverRetryLaterCodes) {
      expect(handoverBlockedEvent(code), isNotNull, reason: code);
    }
  });
}
