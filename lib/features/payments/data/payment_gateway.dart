import 'dart:io';

import 'package:flutter_stripe/flutter_stripe.dart';

/// L'utilisateur a fermé/annulé le flux de confirmation (wallet, 3DS, PayPal).
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
/// La saisie carte reste dans le composant natif Stripe (CardFormField) —
/// [confirmWithNewCard] consomme l'état interne du SDK, jamais un numéro brut.
abstract class PaymentGateway {
  Future<bool> isPlatformPaySupported();

  Future<void> confirmPlatformPay({
    required String clientSecret,
    required double amountEur,
  });

  Future<void> confirmPayPal(String clientSecret);

  Future<void> confirmWithSavedCard({
    required String clientSecret,
    required String paymentMethodId,
  });

  Future<void> confirmWithNewCard(String clientSecret);
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
                          label: 'dony',
                          amount: amountEur.toStringAsFixed(2),
                        ),
                      ],
                    ),
                  )
                : const PlatformPayConfirmParams.googlePay(
                    googlePay: GooglePayParams(
                      merchantCountryCode: 'FR',
                      currencyCode: 'EUR',
                      merchantName: 'dony',
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
  Future<void> confirmWithSavedCard({
    required String clientSecret,
    required String paymentMethodId,
  }) =>
      _mapStripeErrors(() => Stripe.instance.confirmPayment(
            paymentIntentClientSecret: clientSecret,
            data: PaymentMethodParams.cardFromMethodId(
              paymentMethodData: PaymentMethodDataCardFromMethod(
                paymentMethodId: paymentMethodId,
              ),
            ),
          ));

  @override
  Future<void> confirmWithNewCard(String clientSecret) =>
      _mapStripeErrors(() => Stripe.instance.confirmPayment(
            paymentIntentClientSecret: clientSecret,
            data: const PaymentMethodParams.card(
              paymentMethodData: PaymentMethodData(),
            ),
          ));

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
