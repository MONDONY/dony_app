// ignore_for_file: prefer_const_constructors
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

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

  group('BidCheckoutPaymentRequested', () {
    BidCheckoutPaymentRequested make({
      double amount = 42,
      String currency = 'EUR',
      List<String> types = const ['card'],
    }) => BidCheckoutPaymentRequested(
      clientSecret: 'pi_secret',
      publishableKey: 'pk',
      bidId: 'bid-001',
      amountEur: amount,
      currencyCode: currency,
      paymentMethodTypes: types,
    );

    test('égalité sur tous les champs du paiement', () {
      expectValueEquality(make, [
        make(amount: 43),
        make(currency: 'XOF'),
        make(types: const ['card', 'paypal']),
      ]);
    });
  });

  group('PaymentOnboardingRefreshRequested', () {
    test('sans champ, distinct de la vérification de statut', () {
      expectValueEquality(() => PaymentOnboardingRefreshRequested(), [
        PaymentOnboardingStatusChecked(),
      ]);
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
