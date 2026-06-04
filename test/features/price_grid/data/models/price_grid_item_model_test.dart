import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PriceGridItemModel', () {
    const item = PriceGridItemModel(
      id: 'uuid-1',
      label: 'Valise cabine',
      unitPriceNet: 10.0,
      unitPriceDisplay: 11.20,
      position: 0,
    );

    test('should create from JSON correctly', () {
      final json = {
        'id': 'uuid-1',
        'label': 'Valise cabine',
        'unitPriceNet': 10.0,
        'unitPriceDisplay': 11.20,
        'position': 0,
      };

      final model = PriceGridItemModel.fromJson(json);

      expect(model.id, 'uuid-1');
      expect(model.label, 'Valise cabine');
      expect(model.unitPriceNet, 10.0);
      expect(model.unitPriceDisplay, 11.20);
      expect(model.position, 0);
    });

    test('should convert to JSON correctly', () {
      final json = item.toJson();

      expect(json['id'], 'uuid-1');
      expect(json['label'], 'Valise cabine');
      expect(json['unitPriceNet'], 10.0);
      expect(json['unitPriceDisplay'], 11.20);
      expect(json['position'], 0);
    });

    test('should be equal when properties are same', () {
      const item1 = PriceGridItemModel(
        id: 'uuid-1',
        label: 'Valise cabine',
        unitPriceNet: 10.0,
        unitPriceDisplay: 11.20,
        position: 0,
      );
      const item2 = PriceGridItemModel(
        id: 'uuid-1',
        label: 'Valise cabine',
        unitPriceNet: 10.0,
        unitPriceDisplay: 11.20,
        position: 0,
      );

      expect(item1, equals(item2));
    });

    test('should convert int to double for unitPriceNet', () {
      final json = {
        'id': 'uuid-1',
        'label': 'Test',
        'unitPriceNet': 10, // int
        'unitPriceDisplay': 11.2,
        'position': 0,
      };

      final model = PriceGridItemModel.fromJson(json);
      expect(model.unitPriceNet, 10.0);
      expect(model.unitPriceNet, isA<double>());
    });
  });
}
