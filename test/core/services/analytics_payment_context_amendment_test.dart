import 'package:dony/core/services/analytics_properties.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contextes de paiement de la modification d\'un colis', () {
    expect(AnalyticsPaymentContext.bidAmendment, 'bid_amendment');
    expect(
      AnalyticsPaymentContext.bidAmendmentCommission,
      'bid_amendment_commission',
    );
  });
}
