import 'package:dio/dio.dart';
import 'package:dony/core/money/currency_fallback.dart';
import 'package:dony/core/money/currency_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    CurrencyRegistry.instance.resetToFallbackForTest();
  });

  group('kFallbackCurrencies', () {
    test('couvre EUR, XOF et XAF', () {
      final codes = kFallbackCurrencies.map((c) => c.code).toSet();
      expect(codes, {'EUR', 'XOF', 'XAF'});
    });
  });

  group('CurrencyRegistry.sync', () {
    test('remplace le fallback quand le backend répond', () async {
      when(() => mockDio.get<List<dynamic>>('/config/currencies')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          data: [
            {'code': 'EUR', 'minorUnit': 2, 'symbol': '€'},
            {
              'code': 'XOF',
              'minorUnit': 0,
              'symbol': 'F CFA',
              'pegRateToEur': 700.0,
              'roundingIncrement': 5,
            },
          ],
          requestOptions: RequestOptions(path: '/config/currencies'),
          statusCode: 200,
        ),
      );

      await CurrencyRegistry.instance.sync(mockDio);

      expect(CurrencyRegistry.instance['XOF']?.pegRateToEur, 700.0);
      // Le backend n'a renvoyé que EUR/XOF : XAF (fallback) n'est plus dans le registre.
      expect(CurrencyRegistry.instance['XAF'], isNull);
    });

    test('conserve le fallback si le backend est injoignable', () async {
      when(() => mockDio.get<List<dynamic>>('/config/currencies')).thenThrow(
        DioException(requestOptions: RequestOptions(path: '/config/currencies')),
      );

      await CurrencyRegistry.instance.sync(mockDio);

      expect(CurrencyRegistry.instance['XOF']?.pegRateToEur, 655.957);
      expect(CurrencyRegistry.instance['XAF']?.pegRateToEur, 655.957);
      expect(CurrencyRegistry.instance['EUR'], isNotNull);
    });

    test('réponse vide conserve le fallback', () async {
      when(() => mockDio.get<List<dynamic>>('/config/currencies')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          data: <dynamic>[],
          requestOptions: RequestOptions(path: '/config/currencies'),
          statusCode: 200,
        ),
      );

      await CurrencyRegistry.instance.sync(mockDio);

      expect(CurrencyRegistry.instance['XOF']?.pegRateToEur, 655.957);
    });
  });
}
