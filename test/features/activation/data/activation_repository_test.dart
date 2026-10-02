import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/activation/data/activation_repository.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late ActivationRepository repository;

  setUp(() {
    dio = _MockDio();
    final client = _MockApiClient();
    when(() => client.dio).thenReturn(dio);
    repository = ActivationRepository(client);
  });

  test('fetch renvoie le statut', () async {
    when(
      () => dio.get<Map<String, dynamic>>('/users/me/activation'),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/users/me/activation'),
        data: {'intent': 'TRAVELER', 'firstActionDone': false},
      ),
    );
    final s = await repository.fetch();
    expect(s?.intent, UserIntent.traveler);
    expect(s?.firstActionDone, isFalse);
  });

  test('fetch renvoie null sur 404 (ancien backend)', () async {
    final options = RequestOptions(path: '/users/me/activation');
    when(() => dio.get<Map<String, dynamic>>('/users/me/activation')).thenThrow(
      DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 404),
      ),
    );
    expect(await repository.fetch(), isNull);
  });

  test('fetch propage les autres erreurs', () async {
    final options = RequestOptions(path: '/users/me/activation');
    when(() => dio.get<Map<String, dynamic>>('/users/me/activation')).thenThrow(
      DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 500),
      ),
    );
    expect(repository.fetch, throwsA(isA<DioException>()));
  });

  test('declareIntent envoie le corps attendu', () async {
    when(() => dio.put<dynamic>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async =>
          Response(requestOptions: RequestOptions(path: '/users/me/intent')),
    );
    await repository.declareIntent(
      intent: UserIntent.both,
      destinationCountry: null,
      source: IntentSource.prompt,
    );
    verify(
      () => dio.put<dynamic>(
        '/users/me/intent',
        data: {
          'intent': 'BOTH',
          'destinationCountry': null,
          'source': 'PROMPT',
        },
      ),
    ).called(1);
  });
}
