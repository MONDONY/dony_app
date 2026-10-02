import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
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
///
/// [message] est nullable : le SDK Stripe ne garantit ni `localizedMessage`
/// ni `message` sur son erreur. Quand présent, c'est déjà le message localisé
/// par Stripe dans la langue du téléphone (`localizedMessage`) — affiché tel
/// quel. `null` retombe sur le libellé générique de la raison côté UI.
///
/// Les champs `stripe*` décrivent l'erreur brute du SDK quand l'échec vient
/// de lui ([PaymentConfirmationException.fromStripe]) : ils ne s'affichent
/// jamais, ils servent au diagnostic remonté à Sentry (FLUTTER-7S, un échec
/// de carte n'y laissait aucune trace, seul le message générique s'affichait).
class PaymentConfirmationException implements Exception {
  final String? message;

  /// `FailureCode` du SDK (`Failed`, `Timeout`, `Unknown`), jamais `Canceled`
  /// (mappé en [PaymentCancelledException]).
  final String? stripeCode;

  /// Code d'erreur Stripe (ex. `card_declined`, `expired_card`).
  final String? stripeErrorCode;

  /// Motif de refus de la banque (ex. `insufficient_funds`).
  final String? declineCode;

  /// Type d'erreur Stripe (ex. `card_error`, `invalid_request_error`).
  final String? stripeErrorType;

  /// Message brut, non localisé, du SDK.
  final String? stripeMessage;

  const PaymentConfirmationException([this.message])
    : stripeCode = null,
      stripeErrorCode = null,
      declineCode = null,
      stripeErrorType = null,
      stripeMessage = null;

  const PaymentConfirmationException.fromStripe(
    this.message, {
    required this.stripeCode,
    this.stripeErrorCode,
    this.declineCode,
    this.stripeErrorType,
    this.stripeMessage,
  });

  /// Vrai quand l'échec vient du SDK Stripe et mérite un diagnostic.
  bool get isFromStripe => stripeCode != null;
}

/// Abstraction testable du SDK flutter_stripe pour la DonyPaymentSheet.
/// La saisie carte passe exclusivement par la PaymentSheet native Stripe
/// ([initPaymentSheet] + [presentPaymentSheet]) — jamais de numéro brut côté
/// Yadony.
abstract class PaymentGateway {
  Future<bool> isPlatformPaySupported();

  Future<void> confirmPlatformPay({
    required String clientSecret,
    required double amountEur,
    String currencyCode = 'EUR',
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
    String currencyCode = 'EUR',
  }) => _mapStripeErrors(
    () => Stripe.instance.confirmPlatformPayPaymentIntent(
      clientSecret: clientSecret,
      confirmParams: Platform.isIOS
          ? PlatformPayConfirmParams.applePay(
              applePay: ApplePayParams(
                merchantCountryCode: 'FR',
                currencyCode: currencyCode.toUpperCase(),
                cartItems: [
                  ApplePayCartSummaryItem.immediate(
                    label: 'Yadony', // i18n-ignore : nom de marque
                    amount: amountEur.toStringAsFixed(2),
                  ),
                ],
              ),
            )
          : PlatformPayConfirmParams.googlePay(
              googlePay: GooglePayParams(
                merchantCountryCode: 'FR',
                currencyCode: currencyCode.toUpperCase(),
                merchantName: 'Yadony', // i18n-ignore : nom de marque
              ),
            ),
    ),
  );

  @override
  Future<void> confirmPayPal(String clientSecret) => _mapStripeErrors(
    () => Stripe.instance.confirmPayment(
      paymentIntentClientSecret: clientSecret,
      data: const PaymentMethodParams.payPal(
        paymentMethodData: PaymentMethodData(),
      ),
    ),
  );

  @override
  Future<void> initPaymentSheet({
    required String clientSecret,
    required String customerId,
    required String customerEphemeralKeySecret,
  }) => _mapStripeErrors(
    () => Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        customerId: customerId,
        customerEphemeralKeySecret: customerEphemeralKeySecret,
        merchantDisplayName: 'Yadony', // i18n-ignore : nom de marque
        style: ThemeMode.system,
      ),
    ),
  );

  @override
  Future<void> presentPaymentSheet() =>
      _mapStripeErrors(() => Stripe.instance.presentPaymentSheet());

  Future<void> _mapStripeErrors(Future<Object?> Function() action) async {
    try {
      await action();
    } on StripeException catch (e) {
      throw mapStripeException(e);
    }
  }
}

/// Traduit une erreur du SDK Stripe en exception du domaine : annulation par
/// l'utilisateur ([PaymentCancelledException], silencieuse) ou échec
/// ([PaymentConfirmationException] portant les codes du SDK pour Sentry).
///
/// Pas de repli français ici : `message` reste `null` quand le SDK ne
/// fournit rien, et c'est l'UI qui affiche alors le libellé générique de la
/// raison (`PaymentSheetFailureReason.declined`).
@visibleForTesting
Exception mapStripeException(StripeException e) {
  if (e.error.code == FailureCode.Canceled) {
    return const PaymentCancelledException();
  }
  return PaymentConfirmationException.fromStripe(
    e.error.localizedMessage ?? e.error.message,
    stripeCode: e.error.code.name,
    stripeErrorCode: e.error.stripeErrorCode,
    declineCode: e.error.declineCode,
    stripeErrorType: e.error.type,
    stripeMessage: e.error.message,
  );
}
