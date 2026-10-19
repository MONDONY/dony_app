import 'package:dony/core/config/payment_methods_flag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(resetPaymentMethodFlagsForTest);

  test('repli : tout éteint tant que rien n\'est chargé', () {
    expect(paymentMethodFlagsListenable.value, PaymentMethodFlags.none);
  });

  test('fromJson : champ absent (ancien serveur) ou non booléen = faux', () {
    expect(PaymentMethodFlags.fromJson(const {}), PaymentMethodFlags.none);
    expect(
      PaymentMethodFlags.fromJson(const {
        'applePayEnabled': true,
        'googlePayEnabled': 'true',
        'paypalEnabled': null,
      }),
      const PaymentMethodFlags(applePay: true),
    );
    expect(
      PaymentMethodFlags.fromJson(const {
        'applePayEnabled': false,
        'googlePayEnabled': true,
        'paypalEnabled': true,
      }),
      const PaymentMethodFlags(googlePay: true, paypal: true),
    );
  });

  test('walletEnabledFor : Apple Pay sur iOS, Google Pay sur Android', () {
    const apple = PaymentMethodFlags(applePay: true);
    const google = PaymentMethodFlags(googlePay: true);
    expect(apple.walletEnabledFor(TargetPlatform.iOS), isTrue);
    expect(apple.walletEnabledFor(TargetPlatform.android), isFalse);
    expect(google.walletEnabledFor(TargetPlatform.android), isTrue);
    expect(google.walletEnabledFor(TargetPlatform.iOS), isFalse);
    expect(
      const PaymentMethodFlags(
        applePay: true,
        googlePay: true,
      ).walletEnabledFor(TargetPlatform.macOS),
      isFalse,
    );
  });

  test('setPaymentMethodFlags notifie, égalité et toString', () {
    var notified = 0;
    void listener() => notified++;
    paymentMethodFlagsListenable.addListener(listener);
    setPaymentMethodFlags(const PaymentMethodFlags(paypal: true));
    paymentMethodFlagsListenable.removeListener(listener);
    expect(notified, 1);
    expect(paymentMethodFlagsListenable.value.paypal, isTrue);
    expect(
      const PaymentMethodFlags(paypal: true).hashCode,
      const PaymentMethodFlags(paypal: true).hashCode,
    );
    expect(const PaymentMethodFlags().toString(), contains('paypal: false'));
  });
}
