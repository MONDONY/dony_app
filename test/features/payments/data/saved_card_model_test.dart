import 'package:dony/features/payments/data/models/saved_card_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedCardModel.fromJson', () {
    test('parses all fields', () {
      final m = SavedCardModel.fromJson({
        'id': 'pm_1',
        'brand': 'visa',
        'last4': '4242',
        'expMonth': 8,
        'expYear': 2027,
      });

      expect(m.id, 'pm_1');
      expect(m.brand, 'visa');
      expect(m.last4, '4242');
      expect(m.expMonth, 8);
      expect(m.expYear, 2027);
    });
  });

  group('displayLabel', () {
    test('capitalise la marque', () {
      const m = SavedCardModel(
        id: 'pm_1',
        brand: 'visa',
        last4: '4242',
        expMonth: 8,
        expYear: 2027,
      );
      expect(m.displayLabel, 'Visa •••• 4242');
    });

    test('mastercard', () {
      const m = SavedCardModel(
        id: 'pm_2',
        brand: 'mastercard',
        last4: '4444',
        expMonth: 1,
        expYear: 2028,
      );
      expect(m.displayLabel, 'Mastercard •••• 4444');
    });
  });
}
