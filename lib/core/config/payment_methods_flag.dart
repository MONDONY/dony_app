import 'package:flutter/foundation.dart';

/// Moyens de paiement que le serveur autorise dans la feuille de paiement
/// (`GET /config/payment-methods`, réglages plateforme pilotés depuis le
/// back-office, YADONY-FLUTTER-PROD-11).
///
/// Repli sûr : tout faux. Un champ absent (serveur d'avant ces drapeaux), une
/// erreur réseau ou un flag pas encore chargé ne proposent que la carte,
/// jamais un bouton Apple Pay, Google Pay ou PayPal qui échouerait.
@immutable
class PaymentMethodFlags {
  final bool applePay;
  final bool googlePay;
  final bool paypal;

  const PaymentMethodFlags({
    this.applePay = false,
    this.googlePay = false,
    this.paypal = false,
  });

  static const none = PaymentMethodFlags();

  factory PaymentMethodFlags.fromJson(Map<String, dynamic> json) =>
      PaymentMethodFlags(
        applePay: json['applePayEnabled'] == true,
        googlePay: json['googlePayEnabled'] == true,
        paypal: json['paypalEnabled'] == true,
      );

  /// Apple Pay sur iOS, Google Pay sur Android, rien ailleurs.
  bool walletEnabledFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS => applePay,
    TargetPlatform.android => googlePay,
    _ => false,
  };

  @override
  bool operator ==(Object other) =>
      other is PaymentMethodFlags &&
      other.applePay == applePay &&
      other.googlePay == googlePay &&
      other.paypal == paypal;

  @override
  int get hashCode => Object.hash(applePay, googlePay, paypal);

  @override
  String toString() =>
      'PaymentMethodFlags(applePay: $applePay, googlePay: $googlePay, '
      'paypal: $paypal)';
}

final ValueNotifier<PaymentMethodFlags> _paymentMethodsNotifier = ValueNotifier(
  PaymentMethodFlags.none,
);

/// Dernière valeur connue : chargée au démarrage, puis rafraîchie à chaque
/// ouverture de la feuille de paiement.
ValueListenable<PaymentMethodFlags> get paymentMethodFlagsListenable =>
    _paymentMethodsNotifier;

void setPaymentMethodFlags(PaymentMethodFlags flags) {
  _paymentMethodsNotifier.value = flags;
}

@visibleForTesting
void resetPaymentMethodFlagsForTest() {
  _paymentMethodsNotifier.value = PaymentMethodFlags.none;
}
