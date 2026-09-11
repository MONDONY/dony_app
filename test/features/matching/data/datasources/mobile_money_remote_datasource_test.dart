import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient apiClient;
  late MockDio dio;
  late MobileMoneyRemoteDatasource datasource;

  const bidId = '550e8400-e29b-41d4-a716-446655440000';
  const threadId = '660e8400-e29b-41d4-a716-446655440000';
  const bidScope = MobileMoneyScope.bid(bidId);
  const negotiationScope = MobileMoneyScope.negotiation(threadId);

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

          final result = await datasource.getStatus(bidScope);

          expect(result.subjectId, bidId);
          expect(result.paymentStatus, 'PENDING');
          expect(result.deposit?.providerLabel, 'Orange Money');
        },
      );

      test(
        'portée négociation : appelle GET /negotiations/{id}/mobile-money/status',
        () async {
          final threadJson = {
            'threadId': threadId,
            'paymentStatus': 'PENDING',
          };
          when(
            () => dio.get<Map<String, dynamic>>(
              '/negotiations/$threadId/mobile-money/status',
            ),
          ).thenAnswer(
            (_) async => Response(
              data: threadJson,
              statusCode: 200,
              requestOptions: RequestOptions(
                path: '/negotiations/$threadId/mobile-money/status',
              ),
            ),
          );

          final result = await datasource.getStatus(negotiationScope);

          expect(result.subjectId, threadId);
          expect(result.subjectStatus, isNull);
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

        expect(datasource.getStatus(bidScope), throwsA(isA<DioException>()));
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

        expect(datasource.getStatus(bidScope), throwsA(isA<DioException>()));
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

        final result = await datasource.initiate(bidScope);

        expect(result.subjectId, bidId);
        expect(capturedData, isNull);
      });

      test(
        'portée négociation : appelle POST /negotiations/{id}/mobile-money/initiate',
        () async {
          final threadJson = {
            'threadId': threadId,
            'paymentStatus': 'PENDING',
          };
          dynamic capturedData = 'non-appelé';
          when(
            () => dio.post<Map<String, dynamic>>(
              '/negotiations/$threadId/mobile-money/initiate',
              data: any(named: 'data'),
            ),
          ).thenAnswer((invocation) async {
            capturedData = invocation.namedArguments[const Symbol('data')];
            return Response(
              data: threadJson,
              statusCode: 200,
              requestOptions: RequestOptions(
                path: '/negotiations/$threadId/mobile-money/initiate',
              ),
            );
          });

          final result = await datasource.initiate(negotiationScope);

          expect(result.subjectId, threadId);
          expect(capturedData, isNull);
        },
      );

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

        await datasource.initiate(bidScope, phoneNumber: '');

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

          await datasource.initiate(bidScope, phoneNumber: '   ');

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
            bidScope,
            phoneNumber: '  +221771234567  ',
          );

          expect(result.subjectId, bidId);
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

        expect(datasource.initiate(bidScope), throwsA(isA<DioException>()));
      });
    });
  });
}
