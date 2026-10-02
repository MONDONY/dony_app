import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/calls/data/datasources/calls_datasource.dart';
import 'package:dony/features/calls/data/repositories/calls_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _response(String path, dynamic data, {int status = 200}) =>
    Response(
      data: data,
      statusCode: status,
      requestOptions: RequestOptions(path: path),
    );

void main() {
  late MockDio dio;
  late CallsRepository repository;

  setUp(() {
    dio = MockDio();
    final api = MockApiClient();
    when(() => api.dio).thenReturn(dio);
    repository = CallsRepository(CallsDatasource(api));
  });

  test('fetchToken lit /calls/token', () async {
    when(() => dio.get<dynamic>('/calls/token')).thenAnswer(
      (_) async => _response('/calls/token', {
        'apiKey': 'k',
        'userId': 'u1',
        'token': 't',
        'expiresAt': '2026-10-03T10:00:00Z',
      }),
    );

    final token = await repository.fetchToken();

    expect(token.apiKey, 'k');
    expect(token.userId, 'u1');
    expect(token.token, 't');
    expect(token.expiresAt, DateTime.utc(2026, 10, 3, 10));
  });

  test('startCall poste sur la conversation', () async {
    when(() => dio.post<dynamic>('/conversations/c1/calls')).thenAnswer(
      (_) async => _response('/conversations/c1/calls', {
        'callId': 'x1',
        'callType': 'audio_call',
      }, status: 201),
    );

    final call = await repository.startCall('c1');

    expect(call.callId, 'x1');
    expect(call.callType, 'audio_call');
  });

  test('startCall sans callType retombe sur audio_call', () async {
    when(() => dio.post<dynamic>('/conversations/c1/calls')).thenAnswer(
      (_) async =>
          _response('/conversations/c1/calls', {'callId': 'x1'}, status: 201),
    );

    expect((await repository.startCall('c1')).callType, 'audio_call');
  });

  test('une erreur RFC 7807 remonte telle quelle', () async {
    when(() => dio.post<dynamic>('/conversations/c1/calls')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/conversations/c1/calls'),
        error: const ConflictException(
          'Un appel est déjà en cours',
          code: 'call-already-in-progress',
        ),
      ),
    );

    expect(
      () => repository.startCall('c1'),
      throwsA(
        isA<DioException>().having(
          (e) => (e.error as AppException).code,
          'code',
          'call-already-in-progress',
        ),
      ),
    );
  });
}
