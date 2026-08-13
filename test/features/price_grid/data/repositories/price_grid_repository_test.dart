import 'package:dony/features/price_grid/data/datasources/price_grid_datasource.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPriceGridDatasource extends Mock implements PriceGridDatasource {}

void main() {
  late MockPriceGridDatasource mockDatasource;
  late PriceGridRepository repository;

  const item1 = PriceGridItemModel(
    id: 'uuid-1',
    label: 'Valise cabine',
    unitPriceNet: 10.0,
    unitPriceDisplay: 11.20,
    position: 0,
  );

  const item2 = PriceGridItemModel(
    id: 'uuid-2',
    label: 'Sac à dos 50L',
    unitPriceNet: 15.0,
    unitPriceDisplay: 16.80,
    position: 1,
  );

  setUp(() {
    mockDatasource = MockPriceGridDatasource();
    repository = PriceGridRepository(mockDatasource);
  });

  group('PriceGridRepository', () {
    test('getItems delegates to datasource', () async {
      when(
        () => mockDatasource.getItems(),
      ).thenAnswer((_) async => [item1, item2]);

      final result = await repository.getItems();

      expect(result, [item1, item2]);
      verify(() => mockDatasource.getItems()).called(1);
    });

    test('addItem delegates to datasource', () async {
      when(
        () => mockDatasource.addItem(
          label: any(named: 'label'),
          unitPriceNet: any(named: 'unitPriceNet'),
        ),
      ).thenAnswer((_) async => item1);

      final result = await repository.addItem(
        label: 'Valise cabine',
        unitPriceNet: 10.0,
      );

      expect(result, item1);
      verify(
        () =>
            mockDatasource.addItem(label: 'Valise cabine', unitPriceNet: 10.0),
      ).called(1);
    });

    test('updateItem delegates to datasource', () async {
      when(
        () => mockDatasource.updateItem(
          itemId: any(named: 'itemId'),
          label: any(named: 'label'),
          unitPriceNet: any(named: 'unitPriceNet'),
        ),
      ).thenAnswer((_) async => item1);

      final result = await repository.updateItem(
        itemId: 'uuid-1',
        label: 'Valise cabine',
        unitPriceNet: 10.0,
      );

      expect(result, item1);
      verify(
        () => mockDatasource.updateItem(
          itemId: 'uuid-1',
          label: 'Valise cabine',
          unitPriceNet: 10.0,
        ),
      ).called(1);
    });

    test('deleteItem delegates to datasource', () async {
      when(() => mockDatasource.deleteItem('uuid-1')).thenAnswer((_) async {});

      await repository.deleteItem('uuid-1');

      verify(() => mockDatasource.deleteItem('uuid-1')).called(1);
    });

    test('reorder delegates to datasource', () async {
      when(
        () => mockDatasource.reorder(['uuid-2', 'uuid-1']),
      ).thenAnswer((_) async => [item2, item1]);

      final result = await repository.reorder(['uuid-2', 'uuid-1']);

      expect(result, [item2, item1]);
      verify(() => mockDatasource.reorder(['uuid-2', 'uuid-1'])).called(1);
    });
  });
}
