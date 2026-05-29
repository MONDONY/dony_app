import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient apiClient;
  late MockDio dio;
  late MobileMoneyRemoteDatasource datasource;

  const bidId = '550e8400-e29b-41d4-a716-446655440000';

  final _paymentJson = {
    'id': 'payment-id-1',
    'status': 'PENDING',
    'amount': 50.0,
    'currency': 'XOF',
    'paymentLink': 'https://wave.test/pay?ref=wave_abc',
    'expiresAt': '2026-05-27T20:00:00.000',
    'failureReason': null,
  };

  setUp(() {
    apiClient = MockApiClient();
    dio = MockDio();
    when(() => apiClient.dio).thenReturn(dio);
    datasource = MobileMoneyRemoteDatasource(apiClient);
  });

  group('MobileMoneyRemoteDatasource', () {
    group('getStatus', () {
      test('returns MobileMoneyPaymentModel on success', () async {
        when(() => dio.get<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/status',
            )).thenAnswer((_) async => Response(
              data: _paymentJson,
              statusCode: 200,
              requestOptions:
                  RequestOptions(path: '/bids/$bidId/mobile-money/status'),
            ));

        final result = await datasource.getStatus(bidId);

        expect(result.id, 'payment-id-1');
        expect(result.status, 'PENDING');
        expect(result.paymentLink, contains('wave.test'));
      });

      test('propagates DioException on network error', () async {
        when(() => dio.get<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/status',
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/$bidId/mobile-money/status'),
          type: DioExceptionType.connectionTimeout,
        ));

        expect(
          datasource.getStatus(bidId),
          throwsA(isA<DioException>()),
        );
      });

      test('propagates DioException on 404', () async {
        when(() => dio.get<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/status',
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/$bidId/mobile-money/status'),
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 404,
            requestOptions: RequestOptions(path: '/bids/$bidId/mobile-money/status'),
          ),
        ));

        expect(
          datasource.getStatus(bidId),
          throwsA(isA<DioException>()),
        );
      });
    });

    group('regenerateLink', () {
      test('calls POST /bids/{bidId}/mobile-money/initiate and returns model',
          () async {
        final newPaymentJson = {
          'id': 'payment-id-2',
          'status': 'PENDING',
          'amount': 50.0,
          'currency': 'XOF',
          'paymentLink': 'https://wave.test/pay?ref=wave_new',
          'expiresAt': '2026-05-27T21:00:00.000',
          'failureReason': null,
        };

        when(() => dio.post<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/initiate',
            )).thenAnswer((_) async => Response(
              data: newPaymentJson,
              statusCode: 201,
              requestOptions: RequestOptions(
                  path: '/bids/$bidId/mobile-money/initiate'),
            ));

        final result = await datasource.regenerateLink(bidId);

        verify(() => dio.post<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/initiate',
            )).called(1);
        expect(result.id, 'payment-id-2');
        expect(result.paymentLink, contains('ref=wave_new'));
      });

      test('propagates DioException on 403', () async {
        when(() => dio.post<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/initiate',
            )).thenThrow(DioException(
          requestOptions: RequestOptions(
              path: '/bids/$bidId/mobile-money/initiate'),
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 403,
            requestOptions: RequestOptions(
                path: '/bids/$bidId/mobile-money/initiate'),
          ),
        ));

        expect(
          datasource.regenerateLink(bidId),
          throwsA(isA<DioException>()),
        );
      });
    });
  });
}
