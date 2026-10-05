import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('yadonyPaymentSheetParameters (FLUTTER-CR / FLUTTER-D5)', () {
    test('Link est coupé : jamais de carte enregistrée via Link', () {
      final params = yadonyPaymentSheetParameters(
        setupIntentClientSecret: 'seti_1_secret_x',
      );
      expect(params.linkDisplayParams?.linkDisplay, LinkDisplay.never);
    });

    test('adresse de retour yadony:// pour les redirections 3-D Secure', () {
      final params = yadonyPaymentSheetParameters(
        paymentIntentClientSecret: 'pi_1_secret_x',
      );
      expect(params.returnURL, 'yadony://stripe-redirect');
      expect(kStripeReturnUrl, 'yadony://stripe-redirect');
    });

    test('feuille de paiement : transmet intent, client et clé éphémère', () {
      final params = yadonyPaymentSheetParameters(
        paymentIntentClientSecret: 'pi_1_secret_x',
        customerId: 'cus_1',
        customerEphemeralKeySecret: 'ek_1',
      );
      expect(params.paymentIntentClientSecret, 'pi_1_secret_x');
      expect(params.setupIntentClientSecret, isNull);
      expect(params.customerId, 'cus_1');
      expect(params.customerEphemeralKeySecret, 'ek_1');
      expect(params.merchantDisplayName, 'Yadony');
      expect(params.style, ThemeMode.system);
    });

    test('feuille de carte de commission : SetupIntent seul', () {
      final params = yadonyPaymentSheetParameters(
        setupIntentClientSecret: 'seti_1_secret_x',
      );
      expect(params.setupIntentClientSecret, 'seti_1_secret_x');
      expect(params.paymentIntentClientSecret, isNull);
      expect(params.customerId, isNull);
    });
  });
}
