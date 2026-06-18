import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

const _stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

/// Params uniques de la PaymentSheet Stripe pour dony (Approche A).
///
/// Affiche Carte + Apple Pay + Google Pay + PayPal dans la feuille native :
/// - Apple Pay / Google Pay = wallets carte (config client ci-dessous).
/// - PayPal = activé côté PaymentIntent (`payment_method_types`) + dashboard ;
///   le retour de redirection passe par `Stripe.urlScheme` (réglé dans main.dart).
///
/// `testEnv` Google Pay est dérivé de la clé publiable (`pk_test` → sandbox),
/// pour ne pas introduire un nouvel env.
SetupPaymentSheetParameters donyPaymentSheetParams(String clientSecret) {
  return SetupPaymentSheetParameters(
    merchantDisplayName: 'dony',
    paymentIntentClientSecret: clientSecret,
    style: ThemeMode.light,
    applePay: const PaymentSheetApplePay(merchantCountryCode: 'FR'),
    googlePay: PaymentSheetGooglePay(
      merchantCountryCode: 'FR',
      testEnv: _stripePublishableKey.startsWith('pk_test'),
    ),
  );
}
