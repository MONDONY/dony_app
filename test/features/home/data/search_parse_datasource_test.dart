import 'package:dio/dio.dart';
import 'package:dony/features/home/data/datasources/search_parse_datasource.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late SearchParseDatasource datasource;

  setUp(() {
    mockDio = MockDio();
    datasource = SearchParseDatasource(dio: mockDio);
  });

  group('SearchParseDatasource.parse', () {
    test(
      'poste le texte et le mode wireifié, désérialise la réponse',
      () async {
        when(
          () => mockDio.post<dynamic>(
            '/search/parse',
            data: {'text': 'colis 10kg vers Dakar', 'mode': 'PACKAGES'},
          ),
        ).thenAnswer(
          (_) async => Response(
            data: {
              'filters': {'arrivalCity': 'Dakar', 'maxWeight': 10},
              'recognized': [
                {'field': 'arrivalCity', 'value': 'Dakar'},
              ],
              'unresolved': [],
            },
            statusCode: 200,
            requestOptions: RequestOptions(),
          ),
        );

        final result = await datasource.parse(
          'colis 10kg vers Dakar',
          SearchMode.parcels,
        );

        expect(result.filters['arrivalCity'], 'Dakar');
        expect(result.recognized, hasLength(1));
        verify(
          () => mockDio.post<dynamic>(
            '/search/parse',
            data: {'text': 'colis 10kg vers Dakar', 'mode': 'PACKAGES'},
          ),
        ).called(1);
      },
    );

    test('mode trips est wireifié en TRIPS, jamais TRIP ni PARCELS', () async {
      when(
        () => mockDio.post<dynamic>(
          '/search/parse',
          data: {'text': 'Paris Dakar', 'mode': 'TRIPS'},
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {'filters': {}, 'recognized': [], 'unresolved': []},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      await datasource.parse('Paris Dakar', SearchMode.trips);

      verify(
        () => mockDio.post<dynamic>(
          '/search/parse',
          data: {'text': 'Paris Dakar', 'mode': 'TRIPS'},
        ),
      ).called(1);
    });

    test('propage l\'erreur réseau sans l\'avaler', () async {
      when(
        () => mockDio.post<dynamic>('/search/parse', data: any(named: 'data')),
      ).thenThrow(DioException(requestOptions: RequestOptions()));

      expect(
        () => datasource.parse('x', SearchMode.trips),
        throwsA(isA<DioException>()),
      );
    });
  });
}
