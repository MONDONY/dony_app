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

  final statusJson = {
    'bidId': bidId,
    'bidStatus': 'AWAITING_PAYMENT',
    'paymentStatus': 'PENDING',
    'deadlineAt': '2026-05-27T20:00:00',
    'amount': 50.0,
    'currency': 'XOF',
    'deposit': {
      'id': 'deposit-1',
      'status': 'ACCEPTED',
      'providerLabel': 'Orange Money',
      'msisdnMasked': '+221 •••• 67',
      'authorizationUrl': null,
      'failureCode': null,
      'failureMessage': null,
    },
  };

  setUp(() {
    apiClient = MockApiClient();
    dio = MockDio();
    when(() => apiClient.dio).thenReturn(dio);
    datasource = MobileMoneyRemoteDatasource(apiClient);
  });

  group('MobileMoneyRemoteDatasource', () {
    group('getStatus', () {
      test(
        'appelle GET /bids/{bidId}/mobile-money/status et parse le statut',
        () async {
          when(
            () => dio.get<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/status',
            ),
          ).thenAnswer(
            (_) async => Response(
              data: statusJson,
              statusCode: 200,
              requestOptions: RequestOptions(
                path: '/bids/$bidId/mobile-money/status',
              ),
            ),
          );

          final result = await datasource.getStatus(bidId);

          expect(result.bidId, bidId);
          expect(result.paymentStatus, 'PENDING');
          expect(result.deposit?.providerLabel, 'Orange Money');
        },
      );

      test('propage la DioException sur erreur réseau', () async {
        when(
          () =>
              dio.get<Map<String, dynamic>>('/bids/$bidId/mobile-money/status'),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(
              path: '/bids/$bidId/mobile-money/status',
            ),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        expect(datasource.getStatus(bidId), throwsA(isA<DioException>()));
      });

      test('propage la DioException sur 404', () async {
        when(
          () =>
              dio.get<Map<String, dynamic>>('/bids/$bidId/mobile-money/status'),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(
              path: '/bids/$bidId/mobile-money/status',
            ),
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(
                path: '/bids/$bidId/mobile-money/status',
              ),
            ),
          ),
        );

        expect(datasource.getStatus(bidId), throwsA(isA<DioException>()));
      });
    });

    group('initiate', () {
      test('sans phoneNumber : POST sans corps', () async {
        dynamic capturedData = 'non-appelé';
        when(
          () => dio.post<Map<String, dynamic>>(
            '/bids/$bidId/mobile-money/initiate',
            data: any(named: 'data'),
          ),
        ).thenAnswer((invocation) async {
          capturedData = invocation.namedArguments[const Symbol('data')];
          return Response(
            data: statusJson,
            statusCode: 200,
            requestOptions: RequestOptions(
              path: '/bids/$bidId/mobile-money/initiate',
            ),
          );
        });

        final result = await datasource.initiate(bidId);

        expect(result.bidId, bidId);
        expect(capturedData, isNull);
      });

      test('avec phoneNumber vide : POST sans corps', () async {
        dynamic capturedData = 'non-appelé';
        when(
          () => dio.post<Map<String, dynamic>>(
            '/bids/$bidId/mobile-money/initiate',
            data: any(named: 'data'),
          ),
        ).thenAnswer((invocation) async {
          capturedData = invocation.namedArguments[const Symbol('data')];
          return Response(
            data: statusJson,
            statusCode: 200,
            requestOptions: RequestOptions(
              path: '/bids/$bidId/mobile-money/initiate',
            ),
          );
        });

        await datasource.initiate(bidId, phoneNumber: '');

        expect(capturedData, isNull);
      });

      test(
        'avec phoneNumber composé uniquement d\'espaces : POST sans corps',
        () async {
          dynamic capturedData = 'non-appelé';
          when(
            () => dio.post<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/initiate',
              data: any(named: 'data'),
            ),
          ).thenAnswer((invocation) async {
            capturedData = invocation.namedArguments[const Symbol('data')];
            return Response(
              data: statusJson,
              statusCode: 200,
              requestOptions: RequestOptions(
                path: '/bids/$bidId/mobile-money/initiate',
              ),
            );
          });

          await datasource.initiate(bidId, phoneNumber: '   ');

          expect(capturedData, isNull);
        },
      );

      test(
        'avec phoneNumber renseigné : POST {phoneNumber} après trim()',
        () async {
          dynamic capturedData = 'non-appelé';
          when(
            () => dio.post<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/initiate',
              data: any(named: 'data'),
            ),
          ).thenAnswer((invocation) async {
            capturedData = invocation.namedArguments[const Symbol('data')];
            return Response(
              data: statusJson,
              statusCode: 200,
              requestOptions: RequestOptions(
                path: '/bids/$bidId/mobile-money/initiate',
              ),
            );
          });

          final result = await datasource.initiate(
            bidId,
            phoneNumber: '  +221771234567  ',
          );

          expect(result.bidId, bidId);
          expect(capturedData, isA<Map>());
          expect((capturedData as Map)['phoneNumber'], '+221771234567');
        },
      );

      test('propage la DioException', () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            '/bids/$bidId/mobile-money/initiate',
            data: any(named: 'data'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(
              path: '/bids/$bidId/mobile-money/initiate',
            ),
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 403,
              requestOptions: RequestOptions(
                path: '/bids/$bidId/mobile-money/initiate',
              ),
            ),
          ),
        );

        expect(datasource.initiate(bidId), throwsA(isA<DioException>()));
      });
    });

    group('accept', () {
      test(
        'appelle POST /bids/{bidId}/mobile-money/accept sans corps',
        () async {
          when(
            () => dio.post<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/accept',
            ),
          ).thenAnswer(
            (_) async => Response(
              data: statusJson,
              statusCode: 200,
              requestOptions: RequestOptions(
                path: '/bids/$bidId/mobile-money/accept',
              ),
            ),
          );

          final result = await datasource.accept(bidId);

          expect(result.bidId, bidId);
          verify(
            () => dio.post<Map<String, dynamic>>(
              '/bids/$bidId/mobile-money/accept',
            ),
          ).called(1);
        },
      );

      test('propage la DioException', () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            '/bids/$bidId/mobile-money/accept',
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(
              path: '/bids/$bidId/mobile-money/accept',
            ),
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 422,
              requestOptions: RequestOptions(
                path: '/bids/$bidId/mobile-money/accept',
              ),
            ),
          ),
        );

        expect(datasource.accept(bidId), throwsA(isA<DioException>()));
      });
    });
  });
}
