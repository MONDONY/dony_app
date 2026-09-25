import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/datasources/user_language_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApi;
  late MockDio mockDio;
  late UserLanguageRemoteDatasource datasource;

  setUp(() {
    mockApi = MockApiClient();
    mockDio = MockDio();
    when(() => mockApi.dio).thenReturn(mockDio);
    datasource = UserLanguageRemoteDatasource(mockApi);
  });

  group('UserLanguageRemoteDatasource', () {
    test(
      'update appelle PATCH /users/me/preferences avec {language: languageCode} et renvoie true',
      () async {
        when(
          () =>
              mockDio.patch('/users/me/preferences', data: {'language': 'en'}),
        ).thenAnswer(
          (_) async =>
              Response(requestOptions: RequestOptions(), statusCode: 200),
        );

        final result = await datasource.update('en');

        expect(result, isTrue);
        verify(
          () =>
              mockDio.patch('/users/me/preferences', data: {'language': 'en'}),
        ).called(1);
      },
    );

    test('404 (backend plus ancien) → renvoie false sans relancer', () async {
      when(
        () => mockDio.patch('/users/me/preferences', data: {'language': 'fr'}),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/me/preferences'),
          response: Response(
            requestOptions: RequestOptions(path: '/users/me/preferences'),
            statusCode: 404,
          ),
        ),
      );

      final result = await datasource.update('fr');

      expect(result, isFalse);
    });

    test('500 → relance l\'exception', () async {
      when(
        () => mockDio.patch('/users/me/preferences', data: {'language': 'fr'}),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/me/preferences'),
          response: Response(
            requestOptions: RequestOptions(path: '/users/me/preferences'),
            statusCode: 500,
          ),
        ),
      );

      expect(() => datasource.update('fr'), throwsA(isA<DioException>()));
    });
  });
}
