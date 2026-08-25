import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

const _stripePublishableKeyDefault = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
);

/// Params uniques de la PaymentSheet Stripe pour Yadony (Approche A).
///
/// Affiche Carte + Apple Pay + Google Pay + PayPal dans la feuille native :
/// - Apple Pay / Google Pay = wallets carte (config client ci-dessous).
/// - PayPal = activé côté PaymentIntent (`payment_method_types`) + dashboard.
///
/// `returnURL` est OBLIGATOIRE : les PaymentIntents incluent désormais des moyens
/// « redirect-based » (PayPal) et le 3D Secure des cartes EU exigent une URL de
/// retour vers l'app, sinon la PaymentSheet refuse de s'ouvrir. Le retour du
/// scheme `yadony://` est intercepté en interne par le SDK Stripe.
///
/// `testEnv` Google Pay est dérivé de la clé publiable (`pk_test` → sandbox),
/// pour ne pas introduire un nouvel env. [stripePublishableKey] permet de
/// l'injecter en test.
SetupPaymentSheetParameters donyPaymentSheetParams(
  String clientSecret, {
  String stripePublishableKey = _stripePublishableKeyDefault,
}) {
  return SetupPaymentSheetParameters(
    merchantDisplayName: 'Yadony',
    paymentIntentClientSecret: clientSecret,
    style: ThemeMode.light,
    returnURL: 'yadony://stripe/payment-return',
    applePay: const PaymentSheetApplePay(merchantCountryCode: 'FR'),
    googlePay: PaymentSheetGooglePay(
      merchantCountryCode: 'FR',
      testEnv: stripePublishableKey.startsWith('pk_test'),
    ),
  );
}
