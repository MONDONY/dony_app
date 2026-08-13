import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BidPaymentMethod', () {
    test('has wave and orangeMoney values', () {
      expect(BidPaymentMethod.wave, isNotNull);
      expect(BidPaymentMethod.orangeMoney, isNotNull);
    });

    test('wave serializes to WAVE via apiValue', () {
      expect(BidPaymentMethod.wave.apiValue, 'WAVE');
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

    // --- Serialization tests ---

    test(
      'orangeMoney serializes to ORANGE_MONEY via apiValue (not ORANGEMONEY)',
      () {
        // Verifies that the JsonValue annotation produces 'ORANGE_MONEY' and
        // that BidPaymentMethodApi.apiValue delegates to _$BidPaymentMethodEnumMap.
        expect(BidPaymentMethod.orangeMoney.apiValue, 'ORANGE_MONEY');
        expect(BidPaymentMethod.orangeMoney.apiValue, isNot('ORANGEMONEY'));
      },
    );

    test('orangeMoney serializes to ORANGE_MONEY via BidModel.toJson()', () {
      // End-to-end check: a BidModel with paymentMethod=orangeMoney produces
      // 'ORANGE_MONEY' in its JSON representation, matching what the backend expects.
      final model = BidModel(
        id: 'test-id',
        announcementId: 'ann-id',
        senderId: 'sender-id',
        status: 'PENDING',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        paymentMethod: BidPaymentMethod.orangeMoney,
      );
      final json = model.toJson();
      expect(json['paymentMethod'], 'ORANGE_MONEY');
      expect(json['paymentMethod'], isNot('ORANGEMONEY'));
    });

    test('all payment methods serialize to their expected API strings', () {
      expect(BidPaymentMethod.stripe.apiValue, 'STRIPE');
      expect(BidPaymentMethod.cash.apiValue, 'CASH');
      expect(BidPaymentMethod.wave.apiValue, 'WAVE');
      expect(BidPaymentMethod.orangeMoney.apiValue, 'ORANGE_MONEY');
    });
  });
}
