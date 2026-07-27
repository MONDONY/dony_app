import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_stripe/flutter_stripe.dart';

/// Version d'API Stripe attendue par le SDK natif (stripe-ios / stripe-android
/// embarqués par flutter_stripe ^12) pour la génération de la clé éphémère
/// consommée par la PaymentSheet (POST /payments/me/ephemeral-key côté
/// backend). flutter_stripe n'expose aucune constante pour cette valeur — à
/// re-vérifier lors d'une montée de version du SDK natif (stripe_ios /
/// stripe_android dans pubspec.yaml).
const String kStripeEphemeralKeyApiVersion = '2024-06-20';

/// L'utilisateur a fermé/annulé le flux de confirmation (wallet, 3DS, PayPal,
/// PaymentSheet carte).
/// Non bloquant : la sheet revient à l'état prêt, sans message d'erreur.
class PaymentCancelledException implements Exception {
  const PaymentCancelledException();
}

/// Échec de confirmation Stripe (carte refusée, PayPal en échec…).
class PaymentConfirmationException implements Exception {
  final String message;
  const PaymentConfirmationException(this.message);
}

/// Abstraction testable du SDK flutter_stripe pour la DonyPaymentSheet.
/// La saisie carte passe exclusivement par la PaymentSheet native Stripe
/// ([initPaymentSheet] + [presentPaymentSheet]) — jamais de numéro brut côté
/// yadony.
abstract class PaymentGateway {
  Future<bool> isPlatformPaySupported();

  Future<void> confirmPlatformPay({
    required String clientSecret,
    required double amountEur,
  });

  Future<void> confirmPayPal(String clientSecret);

  /// Configure la PaymentSheet native Stripe pour le PaymentIntent
  /// [clientSecret], avec le customer/clé éphémère résolus côté backend
  /// (nécessaire pour lister/enregistrer les cartes du customer).
  Future<void> initPaymentSheet({
    required String clientSecret,
    required String customerId,
    required String customerEphemeralKeySecret,
  });

  /// Affiche la PaymentSheet native — confirme automatiquement le
  /// PaymentIntent fourni à [initPaymentSheet]. Lève [PaymentCancelledException]
  /// si l'utilisateur ferme la sheet sans payer.
  Future<void> presentPaymentSheet();
}

class StripePaymentGateway implements PaymentGateway {
  @override
  Future<bool> isPlatformPaySupported() =>
      Stripe.instance.isPlatformPaySupported();

  @override
  Future<void> confirmPlatformPay({
    required String clientSecret,
    required double amountEur,
  }) =>
      _mapStripeErrors(() => Stripe.instance.confirmPlatformPayPaymentIntent(
            clientSecret: clientSecret,
            confirmParams: Platform.isIOS
                ? PlatformPayConfirmParams.applePay(
                    applePay: ApplePayParams(
                      merchantCountryCode: 'FR',
                      currencyCode: 'EUR',
                      cartItems: [
                        ApplePayCartSummaryItem.immediate(
                          label: 'Yadony',
                          amount: amountEur.toStringAsFixed(2),
                        ),
                      ],
                    ),
                  )
                : const PlatformPayConfirmParams.googlePay(
                    googlePay: GooglePayParams(
                      merchantCountryCode: 'FR',
                      currencyCode: 'EUR',
                      merchantName: 'Yadony',
                    ),
                  ),
          ));

  @override
  Future<void> confirmPayPal(String clientSecret) =>
      _mapStripeErrors(() => Stripe.instance.confirmPayment(
            paymentIntentClientSecret: clientSecret,
            data: const PaymentMethodParams.payPal(
              paymentMethodData: PaymentMethodData(),
            ),
          ));

  @override
  Future<void> initPaymentSheet({
    required String clientSecret,
    required String customerId,
    required String customerEphemeralKeySecret,
  }) =>
      _mapStripeErrors(() => Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              customerId: customerId,
              customerEphemeralKeySecret: customerEphemeralKeySecret,
              merchantDisplayName: 'Yadony',
              style: ThemeMode.system,
            ),
          ));

  @override
  Future<void> presentPaymentSheet() =>
      _mapStripeErrors(() => Stripe.instance.presentPaymentSheet());

  Future<void> _mapStripeErrors(Future<Object?> Function() action) async {
    try {
      await action();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        throw const PaymentCancelledException();
      }
      throw PaymentConfirmationException(
        e.error.localizedMessage ?? e.error.message ?? 'Paiement refusé',
      );
    }
  }
}
