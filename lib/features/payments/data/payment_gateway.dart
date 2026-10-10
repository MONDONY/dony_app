import 'dart:io';

import 'package:dony/core/error/report_severity.dart';
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

/// Adresse de retour dans l'app après une redirection Stripe (3-D Secure,
/// page de la banque). Le schéma `yadony` est déclaré côté iOS et Android ; le
/// plugin Stripe consomme ce lien natif avant Flutter, et `_handleDeepLink`
/// l'ignore (chemin absent de sa liste blanche).
const String kStripeReturnUrl = 'yadony://stripe-redirect';

/// Paramètres communs à toutes les feuilles Stripe de l'app : paiement d'une
/// offre, d'une négociation et carte de commission.
///
/// Link est coupé. Une carte enregistrée « avec Link » redemandait une
/// vérification Link au paiement suivant, qui échouait (refus sur une carte
/// déjà enregistrée, Sentry FLUTTER-CR) ou laissait l'utilisateur coincé dans
/// l'écran Link sans retour possible vers l'app (Sentry FLUTTER-D5). Les
/// cartes sont donc enregistrées directement sur le client Stripe Yadony.
SetupPaymentSheetParameters yadonyPaymentSheetParameters({
  String? paymentIntentClientSecret,
  String? setupIntentClientSecret,
  String? customerId,
  String? customerEphemeralKeySecret,
}) => SetupPaymentSheetParameters(
  paymentIntentClientSecret: paymentIntentClientSecret,
  setupIntentClientSecret: setupIntentClientSecret,
  customerId: customerId,
  customerEphemeralKeySecret: customerEphemeralKeySecret,
  merchantDisplayName: 'Yadony', // i18n-ignore : nom de marque
  style: ThemeMode.system,
  returnURL: kStripeReturnUrl,
  linkDisplayParams: const LinkDisplayParams(linkDisplay: LinkDisplay.never),
);

/// L'utilisateur a fermé/annulé le flux de confirmation (wallet, 3DS, PayPal,
/// PaymentSheet carte).
/// Non bloquant : la sheet revient à l'état prêt, sans message d'erreur.
class PaymentCancelledException implements Exception {
  const PaymentCancelledException();
}

/// Échec de confirmation Stripe (carte refusée, PayPal en échec…).
///
/// [message] est nullable et n'est renseigné que par une exception construite
/// par l'app : un échec venu du SDK ([PaymentConfirmationException.fromStripe])
/// n'en porte jamais, l'UI affiche le libellé traduit de sa catégorie
/// ([classifyStripeFailure]).
///
/// Les champs `stripe*` décrivent l'erreur brute du SDK : ils ne s'affichent
/// jamais, ils servent au diagnostic remonté à Sentry (FLUTTER-7S) et à
/// décider si l'échec mérite d'y remonter ([reportSeverity], FLUTTER-G5).
class PaymentConfirmationException implements Exception, SeverityAwareError {
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

  /// Le SDK n'a donné aucun code Stripe : seul son `FailureCode` est connu
  /// (FLUTTER-G5, `Failed` nu sur Android quand l'erreur native n'est pas une
  /// `StripeException`).
  bool get hasNoStripeDetail =>
      stripeErrorCode == null && declineCode == null && stripeErrorType == null;

  /// Refus de la carte par la banque (type `card_error` ou code de refus
  /// connu) : échec normal du parcours, l'utilisateur peut réessayer.
  bool get isCardError =>
      stripeErrorType == cardErrorType ||
      cardDeclineCodes.contains(stripeErrorCode) ||
      cardDeclineCodes.contains(declineCode);

  /// Vérification 3-D Secure de la banque non aboutie.
  bool get isAuthenticationFailure =>
      authenticationFailureCodes.contains(stripeErrorCode) ||
      authenticationFailureCodes.contains(declineCode);

  /// Refus carte et échec 3-D Secure sont attendus : jamais remontés à Sentry.
  /// Un `Failed` sans aucun code reste remonté, en `warning`. Tout le reste
  /// (api_error, invalid_request_error, rate_limit_error, erreur locale du
  /// SDK typée…) est une erreur. Une exception construite par l'app n'est pas
  /// remontée par les appelants ([isFromStripe] faux).
  @override
  ReportSeverity get reportSeverity {
    if (!isFromStripe) return ReportSeverity.error;
    if (isCardError || isAuthenticationFailure) {
      return ReportSeverity.expected;
    }
    if (hasNoStripeDetail) return ReportSeverity.warning;
    return ReportSeverity.error;
  }

  static const cardErrorType = 'card_error';

  /// Codes Stripe (`code` ou `decline_code`) d'un refus par la banque ou
  /// d'une saisie de carte invalide.
  static const cardDeclineCodes = {
    'card_declined',
    'insufficient_funds',
    'expired_card',
    'incorrect_cvc',
    'incorrect_number',
    'invalid_cvc',
    'invalid_number',
    'invalid_expiry_month',
    'invalid_expiry_year',
    'do_not_honor',
    'generic_decline',
    'lost_card',
    'stolen_card',
    'processing_error',
    'card_velocity_exceeded',
    'withdrawal_count_limit_exceeded',
    'pickup_card',
    'restricted_card',
    'transaction_not_allowed',
    'card_not_supported',
    'currency_not_supported',
    'fraudulent',
  };

  /// Codes Stripe d'une authentification 3-D Secure non aboutie.
  static const authenticationFailureCodes = {
    'payment_intent_authentication_failure',
    'setup_intent_authentication_failure',
    'authentication_required',
  };
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

const _kStripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

/// Google Pay doit tourner dans son environnement de test quand la clé
/// Stripe est une clé de test (staging, dev) : en production, Google refuse
/// les cartes de test et le paiement échouait (FLUTTER-CK, FLUTTER-CJ).
@visibleForTesting
bool isGooglePayTestEnv(String publishableKey) =>
    publishableKey.startsWith('pk_test'); // i18n-ignore : préfixe de clé Stripe

class StripePaymentGateway implements PaymentGateway {
  StripePaymentGateway({String publishableKey = _kStripePublishableKey})
    : _googlePayTestEnv = isGooglePayTestEnv(publishableKey);

  final bool _googlePayTestEnv;

  @override
  Future<bool> isPlatformPaySupported() =>
      Stripe.instance.isPlatformPaySupported(
        googlePay: Platform.isAndroid
            ? IsGooglePaySupportedParams(testEnv: _googlePayTestEnv)
            : null,
      );

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
                testEnv: _googlePayTestEnv,
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
      paymentSheetParameters: yadonyPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        customerId: customerId,
        customerEphemeralKeySecret: customerEphemeralKeySecret,
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
/// Aucun texte du SDK n'atteint l'écran : un message technique
/// (« FragmentManager has been destroyed », FLUTTER-CJ) reste dans
/// `stripeMessage`, pour Sentry seulement, et l'UI affiche le libellé traduit
/// de la catégorie (refus de carte, 3-D Secure… FLUTTER-G5).
///
/// Partagé par la feuille de paiement et l'écran de carte de commission.
Exception mapStripeException(StripeException e) {
  if (e.error.code == FailureCode.Canceled) {
    return const PaymentCancelledException();
  }
  return PaymentConfirmationException.fromStripe(
    null,
    stripeCode: e.error.code.name,
    stripeErrorCode: e.error.stripeErrorCode,
    declineCode: e.error.declineCode,
    stripeErrorType: e.error.type,
    stripeMessage: e.error.message,
  );
}

/// Catégorie d'un échec Stripe pour l'utilisateur, commune à la feuille de
/// paiement et à l'enregistrement de la carte de commission (FLUTTER-CJ).
enum StripeFailureKind {
  /// Refus de la carte par la banque : l'utilisateur peut essayer une autre
  /// carte.
  cardDeclined,

  /// Vérification 3-D Secure de la banque non aboutie.
  authenticationFailed,

  /// La feuille n'a pas pu s'ouvrir : échec à l'ouverture ou erreur locale du
  /// SDK, sans type Stripe (« FragmentManager has been destroyed »).
  sheetUnavailable,

  /// Toute autre erreur Stripe typée (api_error, invalid_request_error…).
  generic,
}

/// Classe un échec issu du SDK. [opening] : l'échec vient de
/// `initPaymentSheet`, avant tout affichage.
StripeFailureKind classifyStripeFailure(
  PaymentConfirmationException e, {
  bool opening = false,
}) {
  // 3-D Secure d'abord : `authentication_required` peut arriver en
  // `card_error`.
  if (e.isAuthenticationFailure) return StripeFailureKind.authenticationFailed;
  if (e.isCardError) return StripeFailureKind.cardDeclined;
  if (opening || e.stripeErrorType == null) {
    return StripeFailureKind.sheetUnavailable;
  }
  return StripeFailureKind.generic;
}

/// Contexte Sentry d'un échec Stripe : codes fermés du SDK et message brut
/// tronqué à 200 caractères (générique, sans donnée de carte ni d'identité).
/// `stripe_detail: none` signale un échec sans aucun code Stripe (FLUTTER-G5).
/// Clés autorisées par `ErrorReportingService` (FLUTTER-7S, FLUTTER-CJ).
Map<String, Object> stripeFailureContext(PaymentConfirmationException e) {
  final message = e.stripeMessage;
  return {
    if (e.hasNoStripeDetail) 'stripe_detail': 'none',
    'stripe_code': ?e.stripeCode,
    'stripe_error_code': ?e.stripeErrorCode,
    'decline_code': ?e.declineCode,
    'stripe_error_type': ?e.stripeErrorType,
    'stripe_message': ?(message == null || message.length <= 200
        ? message
        : message.substring(0, 200)),
  };
}
