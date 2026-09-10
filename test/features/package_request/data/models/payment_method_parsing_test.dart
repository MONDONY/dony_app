import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'énumération plantait sur `MOBILE_MONEY`, que le backend renvoie sur les
/// fils et les demandes depuis le rail pawaPay, et sur toute valeur inconnue.
void main() {
  group('PaymentMethod.tryFromWire / setFromJson', () {
    test('connaît MOBILE_MONEY', () {
      expect(
        PaymentMethod.tryFromWire('MOBILE_MONEY'),
        PaymentMethod.mobileMoney,
      );
      expect(
        PaymentMethod.fromWire('MOBILE_MONEY').displayLabel,
        'Mobile money',
      );
    });

    test('ignore une valeur inconnue au lieu de planter', () {
      expect(PaymentMethod.tryFromWire('CRYPTO'), isNull);
      expect(PaymentMethod.tryFromWire(null), isNull);
      expect(PaymentMethod.setFromJson(['CASH', 'CRYPTO', 'MOBILE_MONEY']), {
        PaymentMethod.cash,
        PaymentMethod.mobileMoney,
      });
    });

    test('fromWire reste strict pour les appelants qui exigent une valeur', () {
      expect(() => PaymentMethod.fromWire('CRYPTO'), throwsArgumentError);
    });
  });
}
