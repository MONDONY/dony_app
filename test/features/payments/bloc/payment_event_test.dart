// ignore_for_file: prefer_const_constructors
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentConnectAccountRequested', () {
    test('props is empty', () {
      expect(PaymentConnectAccountRequested().props, isEmpty);
    });
  });

  group('PaymentOnboardingStatusChecked', () {
    test('props is empty', () {
      expect(PaymentOnboardingStatusChecked().props, isEmpty);
    });
  });

  group('PaymentInitiated', () {
    test('props contains bidId', () {
      final e = PaymentInitiated('bid-001');
      expect(e.props, ['bid-001']);
    });

    test('equality', () {
      expect(PaymentInitiated('bid-001'), PaymentInitiated('bid-001'));
    });
  });

  group('PaymentSheetCompleted', () {
    test('props is empty', () {
      expect(PaymentSheetCompleted().props, isEmpty);
    });
  });

  group('PaymentFailed', () {
    test('props contains message', () {
      final e = PaymentFailed('Erreur carte');
      expect(e.props, ['Erreur carte']);
    });

    test('equality', () {
      expect(PaymentFailed('msg'), PaymentFailed('msg'));
    });
  });
}
