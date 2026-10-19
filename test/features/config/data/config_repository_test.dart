import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
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

  group('ConfigDatasource — getExchangeRates', () {
    test('mappe la liste rates en map code -> taux', () async {
      when(() => mockDio.get('/config/exchange-rates')).thenAnswer(
        (_) async => Response(
          data: {
            'rates': [
              {'currency': 'EUR', 'unitsPerEur': 1},
              {'currency': 'USD', 'unitsPerEur': 1.1642},
              {'currency': 'XOF', 'unitsPerEur': 655.957},
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/exchange-rates'),
        ),
      );

      final rates = await datasource.getExchangeRates();

      expect(rates, {'EUR': 1.0, 'USD': 1.1642, 'XOF': 655.957});
    });

    test('le repository propage la map et unwrap les erreurs Dio', () async {
      when(() => mockDio.get('/config/exchange-rates')).thenAnswer(
        (_) async => Response(
          data: {
            'rates': [
              {'currency': 'CAD', 'unitsPerEur': 1.6},
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/exchange-rates'),
        ),
      );

      expect(await repository.getExchangeRates(), {'CAD': 1.6});

      when(() => mockDio.get('/config/exchange-rates')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/exchange-rates'),
          message: 'Network error',
        ),
      );

      expect(repository.getExchangeRates(), throwsA(isA<Exception>()));
    });
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

    test(
      'getUrgencyThresholdDays returns threshold from API response',
      () async {
        when(() => mockDio.get('/config/urgency-threshold')).thenAnswer(
          (_) async => Response(
            data: {'thresholdDays': 3},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/config/urgency-threshold'),
          ),
        );

        final days = await datasource.getUrgencyThresholdDays();
        expect(days, 3);
      },
    );

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

    test(
      'getReimbursementCap returns maxAmountEur from API response',
      () async {
        when(() => mockDio.get('/config/reimbursement-cap')).thenAnswer(
          (_) async => Response(
            data: {'maxAmountEur': 50},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/config/reimbursement-cap'),
          ),
        );

        final cap = await datasource.getReimbursementCap();
        expect(cap, 50.0);
      },
    );

    test('getReimbursementCap throws on network error', () async {
      when(() => mockDio.get('/config/reimbursement-cap')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/reimbursement-cap'),
          message: 'Network error',
        ),
      );

      expect(
        () => datasource.getReimbursementCap(),
        throwsA(isA<DioException>()),
      );
    });

    test('getSmsEnabled returns enabled flag from API response', () async {
      when(() => mockDio.get('/config/sms-enabled')).thenAnswer(
        (_) async => Response(
          data: {'enabled': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/sms-enabled'),
        ),
      );

      final enabled = await datasource.getSmsEnabled();
      expect(enabled, true);
    });

    test('getSmsEnabled throws on network error', () async {
      when(() => mockDio.get('/config/sms-enabled')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/sms-enabled'),
          message: 'Network error',
        ),
      );

      expect(() => datasource.getSmsEnabled(), throwsA(isA<DioException>()));
    });

    test('getProEnabled returns enabled flag from API response', () async {
      when(() => mockDio.get('/config/pro-enabled')).thenAnswer(
        (_) async => Response(
          data: {'enabled': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/pro-enabled'),
        ),
      );

      final enabled = await datasource.getProEnabled();
      expect(enabled, true);
    });

    test('getProEnabled throws on network error', () async {
      when(() => mockDio.get('/config/pro-enabled')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/pro-enabled'),
          message: 'Network error',
        ),
      );

      expect(() => datasource.getProEnabled(), throwsA(isA<DioException>()));
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

      expect(() => repository.getCommissionRate(), throwsA(isA<Exception>()));
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

    test('getReimbursementCap delegates to datasource', () async {
      when(() => mockDio.get('/config/reimbursement-cap')).thenAnswer(
        (_) async => Response(
          data: {'maxAmountEur': 75},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/reimbursement-cap'),
        ),
      );

      final cap = await repository.getReimbursementCap();
      expect(cap, 75.0);
    });

    test('getReimbursementCap rethrows network exceptions', () async {
      when(() => mockDio.get('/config/reimbursement-cap')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/reimbursement-cap'),
          message: 'Server error',
        ),
      );

      expect(() => repository.getReimbursementCap(), throwsA(isA<Exception>()));
    });

    test('getSmsEnabled delegates to datasource', () async {
      when(() => mockDio.get('/config/sms-enabled')).thenAnswer(
        (_) async => Response(
          data: {'enabled': false},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/sms-enabled'),
        ),
      );

      final enabled = await repository.getSmsEnabled();
      expect(enabled, false);
    });

    test('getProEnabled delegates to datasource', () async {
      when(() => mockDio.get('/config/pro-enabled')).thenAnswer(
        (_) async => Response(
          data: {'enabled': false},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/pro-enabled'),
        ),
      );

      final enabled = await repository.getProEnabled();
      expect(enabled, false);
    });

    test('getProEnabled rethrows network exceptions', () async {
      when(() => mockDio.get('/config/pro-enabled')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/pro-enabled'),
          message: 'Server error',
        ),
      );

      expect(() => repository.getProEnabled(), throwsA(isA<Exception>()));
    });

    test('getSmsEnabled rethrows network exceptions', () async {
      when(() => mockDio.get('/config/sms-enabled')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/sms-enabled'),
          message: 'Server error',
        ),
      );

      expect(() => repository.getSmsEnabled(), throwsA(isA<Exception>()));
    });
  });

  group('Grilles de commission', () {
    Map<String, dynamic> gridJson(String id, String from) => {
      'gridId': id,
      'effectiveFrom': from,
      'tiers': [
        {'fromEur': 0, 'rate': 0.07},
        {'fromEur': '100', 'rate': '0.06'},
      ],
      'minimums': {'EUR': 1.0, 'XOF': '650'},
    };

    DioException notFound(String path) => DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        statusCode: 404,
        requestOptions: RequestOptions(path: path),
      ),
      type: DioExceptionType.badResponse,
    );

    void stubGet(String path, Object data) {
      when(() => mockDio.get(path)).thenAnswer(
        (_) async => Response(
          data: data,
          statusCode: 200,
          requestOptions: RequestOptions(path: path),
        ),
      );
    }

    test('getCommissionGrid lit current et next', () async {
      stubGet('/config/commission-grid', {
        'current': gridJson('g1', '2026-10-01T00:00:00'),
        'next': gridJson('g2', '2026-11-20T09:00:00'),
      });

      final config = await repository.getCommissionGrid();

      expect(config.current?.id, 'g1');
      expect(config.next?.id, 'g2');
      expect(config.next?.effectiveFrom, DateTime.utc(2026, 11, 20, 9));
      expect(config.current?.minimumFor('XOF'), 650);
      expect(config.current?.tiers[1].rate, 0.06);
    });

    test('getCommissionGrid lit current null', () async {
      stubGet('/config/commission-grid', {
        'current': null,
        'next': gridJson('g2', '2026-11-20T09:00:00'),
      });

      final config = await repository.getCommissionGrid();

      expect(config.current, isNull);
      expect(config.next?.id, 'g2');
    });

    test('getCommissionGrid renvoie none sur 404', () async {
      when(
        () => mockDio.get('/config/commission-grid'),
      ).thenThrow(notFound('/config/commission-grid'));

      expect(
        await repository.getCommissionGrid(),
        same(CommissionGridConfig.none),
      );
    });

    test('getCommissionGrid relaie une erreur 500 en AppException', () async {
      when(() => mockDio.get('/config/commission-grid')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/config/commission-grid'),
          error: const ServerException('boom'),
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: '/config/commission-grid'),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(repository.getCommissionGrid(), throwsA(isA<AppException>()));
    });

    test('getCommissionGridById lit la grille', () async {
      stubGet(
        '/config/commission-grid/g1',
        gridJson('g1', '2026-10-01T00:00:00'),
      );

      final grid = await repository.getCommissionGridById('g1');

      expect(grid?.id, 'g1');
      expect(grid?.tiers, hasLength(2));
    });

    test('getCommissionGridById renvoie null sur 404', () async {
      when(
        () => mockDio.get('/config/commission-grid/inconnue'),
      ).thenThrow(notFound('/config/commission-grid/inconnue'));

      expect(await repository.getCommissionGridById('inconnue'), isNull);
    });
  });
}
