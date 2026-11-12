import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/parcel_fit_wire.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('itemSizeEntry', () {
    test('inchangé : rien à envoyer', () {
      expect(itemSizeEntry('maxItemSize', const FieldChange.keep()), isEmpty);
    });

    test('renseigné : le code de la taille', () {
      expect(itemSizeEntry('itemSize', const FieldChange.set(ItemSize.xl)), {
        'itemSize': 'XL',
      });
    });

    test('effacé : la sentinelle NONE', () {
      expect(itemSizeEntry('maxItemSize', const FieldChange.clear()), {
        'maxItemSize': 'NONE',
      });
    });
  });

  group('maxParcelWeightEntry', () {
    test('inchangé : rien à envoyer', () {
      expect(maxParcelWeightEntry(const FieldChange.keep()), isEmpty);
    });

    test('renseigné : le poids sans perte de décimale', () {
      expect(maxParcelWeightEntry(const FieldChange.set(999999.99)), {
        'maxParcelWeightKg': 999999.99,
      });
    });

    test('effacé : 0', () {
      final entry = maxParcelWeightEntry(const FieldChange.clear());
      expect(entry, {'maxParcelWeightKg': 0});
      expect(entry['maxParcelWeightKg'], isA<int>());
    });
  });

  group('FieldChange', () {
    test('ofNullable : null ne dit rien, une valeur est envoyée', () {
      expect(FieldChange.ofNullable<ItemSize>(null).isKeep, isTrue);
      expect(FieldChange.ofNullable(ItemSize.m).value, ItemSize.m);
    });

    test('setOrClear : null efface, une valeur est envoyée', () {
      expect(FieldChange.setOrClear<double>(null).isClear, isTrue);
      expect(FieldChange.setOrClear(20.0).value, 20.0);
    });
  });
}
