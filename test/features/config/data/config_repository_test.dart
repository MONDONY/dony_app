import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/config/data/config_datasource.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late ConfigDatasource datasource;
  late ConfigRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.dio).thenReturn(mockDio);
    datasource = ConfigDatasource(mockApiClient);
    repository = ConfigRepository(datasource);
  });

  group('ConfigDatasource', () {
    test('getCommissionRate returns rate from API response', () async {
      when(() => mockDio.get('/config/commission-rate')).thenAnswer(
        (_) async => Response(
          data: {'rate': 0.12},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/commission-rate'),
        ),
      );

      final rate = await datasource.getCommissionRate();
      expect(rate, 0.12);
    });

    test('getCommissionRate handles integer rate value', () async {
      when(() => mockDio.get('/config/commission-rate')).thenAnswer(
        (_) async => Response(
          data: {'rate': 0},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/commission-rate'),
        ),
      );

      final rate = await datasource.getCommissionRate();
      expect(rate, 0.0);
    });

    test('getCommissionRate throws on network error', () async {
      when(() => mockDio.get('/config/commission-rate')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/commission-rate'),
          message: 'Network error',
        ),
      );

      expect(
        () => datasource.getCommissionRate(),
        throwsA(isA<DioException>()),
      );
    });

    test('getUrgencyThresholdDays returns threshold from API response', () async {
      when(() => mockDio.get('/config/urgency-threshold')).thenAnswer(
        (_) async => Response(
          data: {'thresholdDays': 3},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/urgency-threshold'),
        ),
      );

      final days = await datasource.getUrgencyThresholdDays();
      expect(days, 3);
    });

    test('getUrgencyThresholdDays throws on network error', () async {
      when(() => mockDio.get('/config/urgency-threshold')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/urgency-threshold'),
          message: 'Network error',
        ),
      );

      expect(
        () => datasource.getUrgencyThresholdDays(),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ConfigRepository', () {
    test('getCommissionRate delegates to datasource', () async {
      when(() => mockDio.get('/config/commission-rate')).thenAnswer(
        (_) async => Response(
          data: {'rate': 0.15},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/commission-rate'),
        ),
      );

      final rate = await repository.getCommissionRate();
      expect(rate, 0.15);
    });

    test('getCommissionRate rethrows network exceptions', () async {
      when(() => mockDio.get('/config/commission-rate')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/commission-rate'),
          message: 'Server error',
        ),
      );

      expect(
        () => repository.getCommissionRate(),
        throwsA(isA<Exception>()),
      );
    });

    test('getUrgencyThresholdDays delegates to datasource', () async {
      when(() => mockDio.get('/config/urgency-threshold')).thenAnswer(
        (_) async => Response(
          data: {'thresholdDays': 5},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/urgency-threshold'),
        ),
      );

      final days = await repository.getUrgencyThresholdDays();
      expect(days, 5);
    });

    test('getUrgencyThresholdDays rethrows network exceptions', () async {
      when(() => mockDio.get('/config/urgency-threshold')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/urgency-threshold'),
          message: 'Server error',
        ),
      );

      expect(
        () => repository.getUrgencyThresholdDays(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
