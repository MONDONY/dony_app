import 'package:dony/features/tracking/presentation/screens/qr_scanner_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isFinalDeliveryStep', () {
    test('reconnaît "livré" / "livraison" / "Colis livré"', () {
      expect(isFinalDeliveryStep('Colis livré'), isTrue);
      expect(isFinalDeliveryStep('Livraison terminée'), isTrue);
      expect(isFinalDeliveryStep('LIVRÉ'), isTrue);
    });

    test('reconnaît "remis"', () {
      expect(isFinalDeliveryStep('Remis au destinataire'), isTrue);
    });

    test('reconnaît "delivered" (fallback EN)', () {
      expect(isFinalDeliveryStep('Package delivered'), isTrue);
    });

    test('renvoie false pour étapes intermédiaires', () {
      expect(isFinalDeliveryStep('Embarqué'), isFalse);
      expect(isFinalDeliveryStep('En vol'), isFalse);
      expect(isFinalDeliveryStep('Retiré au point relais'), isFalse);
      expect(isFinalDeliveryStep(''), isFalse);
    });
  });
}
