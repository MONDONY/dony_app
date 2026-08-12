import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T data, String path) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late KycRepository repo;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repo = KycRepository(mockClient);
  });

  group('createSession', () {
    test('returns session data map', () async {
      final sessionData = <String, dynamic>{
        'sessionId': 'vs_123',
        'clientSecret': 'secret_abc',
      };
      when(() => mockDio.post<Map<String, dynamic>>('/kyc/session'))
          .thenAnswer((_) async =>
              _ok<Map<String, dynamic>>(sessionData, '/kyc/session'));

      final result = await repo.createSession();

      expect(result['sessionId'], 'vs_123');
      expect(result['clientSecret'], 'secret_abc');
    });

    test('throws when response data is null', () async {
      when(() => mockDio.post<Map<String, dynamic>>('/kyc/session'))
          .thenAnswer((_) async => Response(
                data: null,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/kyc/session'),
              ));

      expect(() => repo.createSession(), throwsA(isA<Exception>()));
    });
  });

  group('getStatus', () {
    test('returns status data map', () async {
      final statusData = <String, dynamic>{
        'status': 'PENDING',
        'requiresAction': false,
      };
      when(() => mockDio.get<Map<String, dynamic>>('/kyc/status'))
          .thenAnswer((_) async =>
              _ok<Map<String, dynamic>>(statusData, '/kyc/status'));

      final result = await repo.getStatus();

      expect(result['status'], 'PENDING');
    });

    test('throws when response data is null', () async {
      when(() => mockDio.get<Map<String, dynamic>>('/kyc/status'))
          .thenAnswer((_) async => Response(
                data: null,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/kyc/status'),
              ));

      expect(() => repo.getStatus(), throwsA(isA<Exception>()));
    });
  });
}
