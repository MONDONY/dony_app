import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/analytics_consent_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApi;
  late MockDio mockDio;
  late ApiAnalyticsConsentRemote remote;

  setUp(() {
    mockApi = MockApiClient();
    mockDio = MockDio();
    when(() => mockApi.dio).thenReturn(mockDio);
    remote = ApiAnalyticsConsentRemote(mockApi);
  });

  Response<dynamic> resp(Object? data) => Response<dynamic>(
    data: data,
    requestOptions: RequestOptions(path: '/auth/me/analytics-consent'),
    statusCode: 200,
  );

  group('fetch', () {
    test('GET /auth/me/analytics-consent returns granted=true', () async {
      when(() => mockDio.get('/auth/me/analytics-consent')).thenAnswer(
        (_) async => resp({
          'granted': true,
          'consentAt': '2026-06-03T04:55:08.960Z',
          'policyVersion': '1.0',
        }),
      );

      final result = await remote.fetch();

      expect(result, isTrue);
      verify(() => mockDio.get('/auth/me/analytics-consent')).called(1);
    });

    test('returns false when backend says granted=false', () async {
      when(
        () => mockDio.get('/auth/me/analytics-consent'),
      ).thenAnswer((_) async => resp({'granted': false}));

      expect(await remote.fetch(), isFalse);
    });

    test('returns null when backend has never recorded a response', () async {
      when(() => mockDio.get('/auth/me/analytics-consent')).thenAnswer(
        (_) async =>
            resp({'granted': null, 'consentAt': null, 'policyVersion': null}),
      );

      expect(await remote.fetch(), isNull);
    });

    test('returns null when payload is not a map', () async {
      when(
        () => mockDio.get('/auth/me/analytics-consent'),
      ).thenAnswer((_) async => resp('unexpected'));

      expect(await remote.fetch(), isNull);
    });
  });

  group('push', () {
    test('PUT /auth/me/analytics-consent sends the full body', () async {
      when(
        () =>
            mockDio.put('/auth/me/analytics-consent', data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/me/analytics-consent'),
          statusCode: 204,
        ),
      );

      await remote.push(granted: true, policyVersion: '1.0', source: 'manual');

      verify(
        () => mockDio.put(
          '/auth/me/analytics-consent',
          data: {'granted': true, 'policyVersion': '1.0', 'source': 'manual'},
        ),
      ).called(1);
    });
  });
}
