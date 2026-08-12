import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/price_grid/data/datasources/price_grid_datasource.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late PriceGridDatasource datasource;

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
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.dio).thenReturn(mockDio);
    datasource = PriceGridDatasource(mockApiClient);
  });

  group('PriceGridDatasource', () {
    group('getItems', () {
      test('should return list of items when successful', () async {
        final responseData = [
          {
            'id': 'uuid-1',
            'label': 'Valise cabine',
            'unitPriceNet': 10.0,
            'unitPriceDisplay': 11.20,
            'position': 0,
          },
          {
            'id': 'uuid-2',
            'label': 'Sac à dos 50L',
            'unitPriceNet': 15.0,
            'unitPriceDisplay': 16.80,
            'position': 1,
          },
        ];

        when(() => mockDio.get('/travelers/me/price-grid'))
            .thenAnswer((_) async => Response(
                  data: responseData,
                  statusCode: 200,
                  requestOptions: RequestOptions(path: ''),
                ));

        final result = await datasource.getItems();

        expect(result, [item1, item2]);
        verify(() => mockDio.get('/travelers/me/price-grid')).called(1);
      });

      test('should throw when getItems fails', () async {
        when(() => mockDio.get('/travelers/me/price-grid'))
            .thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.unknown,
            ));

        expect(() => datasource.getItems(), throwsA(isA<DioException>()));
      });
    });

    group('addItem', () {
      test('should add item and return created item', () async {
        when(() => mockDio.post(
              '/travelers/me/price-grid/items',
              data: {
                'label': 'Valise cabine',
                'unitPriceNet': 10.0,
              },
            )).thenAnswer((_) async => Response(
              data: {
                'id': 'uuid-1',
                'label': 'Valise cabine',
                'unitPriceNet': 10.0,
                'unitPriceDisplay': 11.20,
                'position': 0,
              },
              statusCode: 201,
              requestOptions: RequestOptions(path: ''),
            ));

        final result = await datasource.addItem(
          label: 'Valise cabine',
          unitPriceNet: 10.0,
        );

        expect(result, item1);
        verify(() => mockDio.post(
              '/travelers/me/price-grid/items',
              data: {
                'label': 'Valise cabine',
                'unitPriceNet': 10.0,
              },
            )).called(1);
      });
    });

    group('updateItem', () {
      test('should update item and return updated item', () async {
        when(() => mockDio.put(
              '/travelers/me/price-grid/items/uuid-1',
              data: {
                'label': 'Valise 23kg',
                'unitPriceNet': 20.0,
              },
            )).thenAnswer((_) async => Response(
              data: {
                'id': 'uuid-1',
                'label': 'Valise 23kg',
                'unitPriceNet': 20.0,
                'unitPriceDisplay': 22.4,
                'position': 0,
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final result = await datasource.updateItem(
          itemId: 'uuid-1',
          label: 'Valise 23kg',
          unitPriceNet: 20.0,
        );

        expect(result.label, 'Valise 23kg');
        expect(result.unitPriceNet, 20.0);
      });
    });

    group('deleteItem', () {
      test('should delete item successfully', () async {
        when(() => mockDio.delete('/travelers/me/price-grid/items/uuid-1'))
            .thenAnswer((_) async => Response(
              statusCode: 204,
              requestOptions: RequestOptions(path: ''),
            ));

        await datasource.deleteItem('uuid-1');

        verify(() => mockDio.delete('/travelers/me/price-grid/items/uuid-1'))
            .called(1);
      });
    });

    group('reorder', () {
      test('should reorder items and return new order', () async {
        final reorderedData = [
          {
            'id': 'uuid-2',
            'label': 'Sac à dos 50L',
            'unitPriceNet': 15.0,
            'unitPriceDisplay': 16.80,
            'position': 0,
          },
          {
            'id': 'uuid-1',
            'label': 'Valise cabine',
            'unitPriceNet': 10.0,
            'unitPriceDisplay': 11.20,
            'position': 1,
          },
        ];

        when(() => mockDio.put(
              '/travelers/me/price-grid/reorder',
              data: ['uuid-2', 'uuid-1'],
            )).thenAnswer((_) async => Response(
              data: reorderedData,
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final result = await datasource.reorder(['uuid-2', 'uuid-1']);

        expect(result.length, 2);
        expect(result[0].id, 'uuid-2');
        expect(result[1].id, 'uuid-1');
      });
    });
  });
}
