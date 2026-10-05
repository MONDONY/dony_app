import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isGooglePayTestEnv (FLUTTER-CK / FLUTTER-CJ)', () {
    test('clé de test → environnement de test Google Pay', () {
      expect(isGooglePayTestEnv('pk_test_51abc'), isTrue);
    });

    test('clé live → environnement de production', () {
      expect(isGooglePayTestEnv('pk_live_51abc'), isFalse);
    });

    test('clé absente → production (jamais de test par défaut)', () {
      expect(isGooglePayTestEnv(''), isFalse);
    });
  });
}
