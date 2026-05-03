import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AddressAutocompleteService service;

  setUp(() {
    mockDio = MockDio();
    service = AddressAutocompleteService(dio: mockDio);
  });

  group('search', () {
    test('search_returnsSuggestions', () async {
      when(() => mockDio.post<dynamic>(
        '/addresses/autocomplete',
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/addresses/autocomplete'),
        statusCode: 200,
        data: [
          {
            'placeId': 'ChIJi...',
            'mainText': '12 rue Victor Hugo',
            'secondaryText': 'Lyon, France',
          }
        ],
      ));

      final results = await service.search('12 rue Victor', 'tok-123');

      expect(results.length, 1);
      expect(results.first.placeId, 'ChIJi...');
      expect(results.first.mainText, '12 rue Victor Hugo');
      expect(results.first.secondaryText, 'Lyon, France');
    });

    test('search_usesCache_secondCallNoHttp', () async {
      when(() => mockDio.post<dynamic>(
        '/addresses/autocomplete',
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/addresses/autocomplete'),
        statusCode: 200,
        data: const <dynamic>[],
      ));

      await service.search('Lyon', 'tok-1');
      await service.search('Lyon', 'tok-1'); // same query, same token → cache hit

      verify(() => mockDio.post<dynamic>(
        '/addresses/autocomplete',
        data: any(named: 'data'),
      )).called(1); // only one HTTP call despite two invocations
    });

    test('search_differentSessionToken_bypassesCache', () async {
      when(() => mockDio.post<dynamic>(
        '/addresses/autocomplete',
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/addresses/autocomplete'),
        statusCode: 200,
        data: const <dynamic>[],
      ));

      await service.search('Lyon', 'tok-1');
      await service.search('Lyon', 'tok-2'); // same query, different token → no cache hit

      verify(() => mockDio.post<dynamic>(
        '/addresses/autocomplete',
        data: any(named: 'data'),
      )).called(2); // two HTTP calls because session tokens differ
    });

    test('search_offline_throwsDioException', () async {
      when(() => mockDio.post<dynamic>(
        '/addresses/autocomplete',
        data: any(named: 'data'),
      )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/addresses/autocomplete'),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => service.search('Paris', 'tok-err'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('resolvePlace', () {
    test('resolvePlace_returnsAddressData', () async {
      when(() => mockDio.post<dynamic>(
        '/addresses/details',
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/addresses/details'),
        statusCode: 200,
        data: {
          'label': '12 Rue Victor Hugo, 69002 Lyon, France',
          'lat': 45.7484,
          'lng': 4.8467,
        },
      ));

      final result = await service.resolvePlace('ChIJi...', 'tok-abc');

      expect(result.label, '12 Rue Victor Hugo, 69002 Lyon, France');
      expect(result.lat, 45.7484);
      expect(result.lng, 4.8467);
    });
  });

  group('reverseGeocode', () {
    test('reverseGeocode_returnsAddress', () async {
      when(() => mockDio.post<dynamic>(
        '/addresses/reverse',
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/addresses/reverse'),
        statusCode: 200,
        data: {
          'label': 'Plateau, Dakar, Sénégal',
          'lat': 14.693,
          'lng': -17.447,
        },
      ));

      final result = await service.reverseGeocode(14.693, -17.447);

      expect(result, isNotNull);
      expect(result!.label, 'Plateau, Dakar, Sénégal');
      expect(result.lat, 14.693);
    });

    test('reverseGeocode_notFound_returnsNull', () async {
      when(() => mockDio.post<dynamic>(
        '/addresses/reverse',
        data: any(named: 'data'),
      )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/addresses/reverse'),
        response: Response(
          requestOptions: RequestOptions(path: '/addresses/reverse'),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      ));

      final result = await service.reverseGeocode(0.0, 0.0);
      expect(result, isNull);
    });
  });
}
