import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _minimalBid({String pm = 'STRIPE', String? cs}) => {
  'id': 'bid1',
  'announcementId': 'ann1',
  'senderId': 'sender1',
  'weightKg': 5.0,
  'status': 'PENDING',
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
  if (pm != 'STRIPE') 'paymentMethod': pm,
  'commissionStatus': ?cs,
};

void main() {
  test('bid defaults to STRIPE payment method', () {
    final b = BidModel.fromJson(_minimalBid());
    expect(b.paymentMethod, BidPaymentMethod.stripe);
    expect(b.commissionStatus, isNull);
  });

  test('parses CASH payment method', () {
    final b = BidModel.fromJson(_minimalBid(pm: 'CASH'));
    expect(b.paymentMethod, BidPaymentMethod.cash);
  });

  test('parses commissionStatus CHARGED', () {
    final b = BidModel.fromJson(_minimalBid(pm: 'CASH', cs: 'CHARGED'));
    expect(b.commissionStatus, CommissionStatus.charged);
  });

  test('parses all commission statuses', () {
    for (final entry in {
      'PENDING': CommissionStatus.pending,
      'REQUIRES_3DS': CommissionStatus.requires3ds,
      'CHARGED': CommissionStatus.charged,
      'FAILED': CommissionStatus.failed,
      'REFUNDED': CommissionStatus.refunded,
    }.entries) {
      final b = BidModel.fromJson(_minimalBid(cs: entry.key));
      expect(b.commissionStatus, entry.value, reason: entry.key);
    }
  });

  test('parses WAVE payment method', () {
    final b = BidModel.fromJson(_minimalBid(pm: 'WAVE'));
    expect(b.paymentMethod, BidPaymentMethod.wave);
  });

  test('parses ORANGE_MONEY payment method', () {
    final b = BidModel.fromJson(_minimalBid(pm: 'ORANGE_MONEY'));
    expect(b.paymentMethod, BidPaymentMethod.orangeMoney);
  });

  test('serializes WAVE to JSON correctly', () {
    final b = BidModel.fromJson(_minimalBid(pm: 'WAVE'));
    expect(b.toJson()['paymentMethod'], 'WAVE');
  });

  test('serializes ORANGE_MONEY to JSON correctly', () {
    final b = BidModel.fromJson(_minimalBid(pm: 'ORANGE_MONEY'));
    expect(b.toJson()['paymentMethod'], 'ORANGE_MONEY');
  });
}
