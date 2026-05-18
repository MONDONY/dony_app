import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentStatus.fromString', () {
    test('parses PENDING', () {
      expect(PaymentStatus.fromString('PENDING'), PaymentStatus.pending);
    });

    test('parses AUTHORIZED', () {
      expect(PaymentStatus.fromString('AUTHORIZED'), PaymentStatus.authorized);
    });

    test('parses CAPTURED', () {
      expect(PaymentStatus.fromString('CAPTURED'), PaymentStatus.captured);
    });

    test('parses REFUNDED', () {
      expect(PaymentStatus.fromString('REFUNDED'), PaymentStatus.refunded);
    });

    test('parses FAILED', () {
      expect(PaymentStatus.fromString('FAILED'), PaymentStatus.failed);
    });

    test('parses DISPUTED', () {
      expect(PaymentStatus.fromString('DISPUTED'), PaymentStatus.disputed);
    });

    test('parses CANCELED', () {
      expect(PaymentStatus.fromString('CANCELED'), PaymentStatus.canceled);
    });

    test('falls back to pending for unknown value', () {
      expect(PaymentStatus.fromString('UNKNOWN_XYZ'), PaymentStatus.pending);
    });

    test('is case-insensitive', () {
      expect(PaymentStatus.fromString('captured'), PaymentStatus.captured);
    });
  });

  group('PaymentModel.disputed field', () {
    test('fromJson parses disputed: true', () {
      final json = {
        'id': 'pay_123',
        'bidId': 'bid_456',
        'amount': 50.0,
        'commissionAmount': 6.0,
        'status': 'CAPTURED',
        'disputed': true,
      };
      final model = PaymentModel.fromJson(json);
      expect(model.disputed, isTrue);
      expect(model.status, PaymentStatus.captured);
    });

    test('fromJson defaults disputed to false when absent', () {
      final json = {
        'id': 'pay_123',
        'bidId': 'bid_456',
        'amount': 50.0,
        'commissionAmount': 6.0,
        'status': 'PENDING',
      };
      final model = PaymentModel.fromJson(json);
      expect(model.disputed, isFalse);
    });
  });
}
