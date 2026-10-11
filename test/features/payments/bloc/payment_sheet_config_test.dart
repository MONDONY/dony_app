// Constructeurs appelés à l'exécution : deux instances `const` identiques
// court-circuitent la comparaison Equatable.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  PaymentSheetConfig make({
    String secret = 'pi_123_secret_abc',
    double amount = 42,
    String currency = 'EUR',
    List<String> types = const ['card'],
  }) => PaymentSheetConfig(
    clientSecret: secret,
    amountEur: amount,
    currencyCode: currency,
    paymentMethodTypes: types,
  );

  test('égalité sur le secret, le montant, la devise et les moyens', () {
    expectValueEquality(make, [
      make(secret: 'pi_456_secret_abc'),
      make(amount: 43),
      make(currency: 'XOF'),
      make(types: const ['card', 'paypal']),
    ]);
  });

  test('paymentIntentId : préfixe du clientSecret', () {
    expect(make().paymentIntentId, 'pi_123');
  });
}
