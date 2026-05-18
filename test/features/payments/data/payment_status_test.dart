import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentStatus.fromString', () {
    test('parses PENDING', () {
      expect(PaymentStatus.fromString('PENDING'), PaymentStatus.pending);
    });

    test('parses ESCROW', () {
      expect(PaymentStatus.fromString('ESCROW'), PaymentStatus.escrow);
    });

    test('parses RELEASED', () {
      expect(PaymentStatus.fromString('RELEASED'), PaymentStatus.released);
    });

    test('parses REFUNDED', () {
      expect(PaymentStatus.fromString('REFUNDED'), PaymentStatus.refunded);
    });

    test('parses FAILED', () {
      expect(PaymentStatus.fromString('FAILED'), PaymentStatus.failed);
    });

    test('parses CANCELLED', () {
      expect(PaymentStatus.fromString('CANCELLED'), PaymentStatus.cancelled);
    });

    test('falls back to pending for unknown value', () {
      expect(PaymentStatus.fromString('UNKNOWN_XYZ'), PaymentStatus.pending);
    });

    test('is case-insensitive', () {
      expect(PaymentStatus.fromString('released'), PaymentStatus.released);
    });
  });

  group('PaymentModel.disputed field', () {
    test('fromJson parses disputed: true with RELEASED status', () {
      final json = {
        'id': 'pay_123',
        'bidId': 'bid_456',
        'amount': 50.0,
        'commissionAmount': 6.0,
        'status': 'RELEASED',
        'disputed': true,
      };
      final model = PaymentModel.fromJson(json);
      expect(model.disputed, isTrue);
      expect(model.status, PaymentStatus.released);
    });

    test('fromJson parses ESCROW status', () {
      final json = {
        'id': 'pay_123',
        'bidId': 'bid_456',
        'amount': 50.0,
        'commissionAmount': 6.0,
        'status': 'ESCROW',
      };
      final model = PaymentModel.fromJson(json);
      expect(model.status, PaymentStatus.escrow);
      expect(model.disputed, isFalse);
    });

    test('fromJson parses CANCELLED status', () {
      final json = {
        'id': 'pay_123',
        'bidId': 'bid_456',
        'amount': 50.0,
        'commissionAmount': 6.0,
        'status': 'CANCELLED',
      };
      final model = PaymentModel.fromJson(json);
      expect(model.status, PaymentStatus.cancelled);
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
