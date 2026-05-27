import 'package:flutter_test/flutter_test.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';

void main() {
  group('BidPaymentMethod', () {
    test('has wave and orangeMoney values', () {
      expect(BidPaymentMethod.wave, isNotNull);
      expect(BidPaymentMethod.orangeMoney, isNotNull);
    });

    test('wave serializes to WAVE', () {
      expect(BidPaymentMethod.wave.name.toUpperCase(), 'WAVE');
    });

    test('orangeMoney is distinct from wave', () {
      expect(BidPaymentMethod.orangeMoney, isNot(BidPaymentMethod.wave));
    });

    test('wave is distinct from stripe', () {
      expect(BidPaymentMethod.wave, isNot(BidPaymentMethod.stripe));
    });

    test('orangeMoney is distinct from cash', () {
      expect(BidPaymentMethod.orangeMoney, isNot(BidPaymentMethod.cash));
    });
  });
}
