import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path, [int code = 200]) => Response(
  data: data,
  statusCode: code,
  requestOptions: RequestOptions(path: path),
);

DioException _status(int code, String path) => DioException(
  requestOptions: RequestOptions(path: path),
  response: Response(
    statusCode: code,
    requestOptions: RequestOptions(path: path),
  ),
  type: DioExceptionType.badResponse,
);

Map<String, dynamic> _results(List<String> ok, List<String> ko) => {
  'results': [
    for (final id in ok) {'id': id, 'success': true, 'status': 204},
    for (final id in ko)
      {'id': id, 'success': false, 'status': 403, 'error': 'access-denied'},
  ],
  'succeeded': ok.length,
  'failed': ko.length,
};

void main() {
  late _MockApiClient client;
  late _MockDio dio;
  late ConversationRepository repository;

  setUp(() {
    client = _MockApiClient();
    dio = _MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = ConversationRepository(client);
  });

  group('actions groupées (FLUTTER-M4)', () {
    test('archive : un appel groupé, résultat lu par id', () async {
      when(
        () =>
            dio.post('/conversations/batch/archive', data: any(named: 'data')),
      ).thenAnswer(
        (_) async =>
            _ok(_results(['a'], ['b']), '/conversations/batch/archive'),
      );

      final result = await repository.archiveConversations(['a', 'b', 'a']);

      expect(result.succeeded, ['a']);
      expect(result.failed, ['b']);
      expect(result.hasFailures, isTrue);
      verify(
        () => dio.post(
          '/conversations/batch/archive',
          data: {
            'ids': ['a', 'b'],
          },
        ),
      ).called(1);
    });

    test('un id sans ligne de résultat compte comme un échec', () async {
      when(
        () => dio.post(
          '/conversations/batch/unarchive',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(_results(['a'], []), '/conversations/batch/unarchive'),
      );

      final result = await repository.unarchiveConversations(['a', 'z']);

      expect(result.succeeded, ['a']);
      expect(result.failed, ['z']);
    });

    test('corps illisible : tout est en échec', () async {
      final result = BatchConversationResult.fromJson('oops', ['a']);
      expect(result.failed, ['a']);
      expect(result.succeeded, isEmpty);
    });

    test('au-delà de 100 ids, découpe en lots de 100', () async {
      final ids = [for (var i = 0; i < 230; i++) 'id-$i'];
      when(
        () => dio.post('/conversations/batch/delete', data: any(named: 'data')),
      ).thenAnswer((inv) async {
        final sent = ((inv.namedArguments[#data] as Map)['ids'] as List)
            .cast<String>();
        return _ok(_results(sent, []), '/conversations/batch/delete');
      });

      final result = await repository.deleteConversations(ids);

      expect(result.succeeded, ids);
      final sizes = verify(
        () => dio.post(
          '/conversations/batch/delete',
          data: captureAny(named: 'data'),
        ),
      ).captured.map((d) => ((d as Map)['ids'] as List).length);
      expect(sizes, [100, 100, 30]);
    });

    test('back antérieur (404) : repli sur les appels unitaires, puis plus de '
        'tentative groupée', () async {
      when(
        () => dio.post('/conversations/batch/delete', data: any(named: 'data')),
      ).thenThrow(_status(404, '/conversations/batch/delete'));
      when(() => dio.delete(any())).thenAnswer(
        (inv) async => _ok(null, inv.positionalArguments.first as String, 204),
      );
      when(
        () => dio.delete('/conversations/b'),
      ).thenThrow(_status(403, '/conversations/b'));

      final first = await repository.deleteConversations(['a', 'b', 'c']);
      expect(first.succeeded, ['a', 'c']);
      expect(first.failed, ['b']);

      final second = await repository.deleteConversations(['d']);
      expect(second.succeeded, ['d']);
      verify(
        () => dio.post('/conversations/batch/delete', data: any(named: 'data')),
      ).called(1);
      verify(() => dio.delete('/conversations/d')).called(1);
    });

    for (final code in [400, 405]) {
      test('back antérieur ($code) : repli sur /{id}/archive', () async {
        when(
          () => dio.post(
            '/conversations/batch/archive',
            data: any(named: 'data'),
          ),
        ).thenThrow(_status(code, '/conversations/batch/archive'));
        when(
          () => dio.post('/conversations/a/archive'),
        ).thenAnswer((_) async => _ok(null, '/conversations/a/archive', 204));
        when(
          () => dio.post('/conversations/b/archive'),
        ).thenAnswer((_) async => _ok(null, '/conversations/b/archive', 204));

        final result = await repository.archiveConversations(['a', 'b']);

        expect(result.succeeded, ['a', 'b']);
        expect(result.failed, isEmpty);
      });
    }

    test('repli : au plus 4 appels unitaires simultanés', () async {
      when(
        () => dio.post(
          '/conversations/batch/unarchive',
          data: any(named: 'data'),
        ),
      ).thenThrow(_status(404, '/conversations/batch/unarchive'));
      var inFlight = 0;
      var peak = 0;
      when(() => dio.post(any(that: endsWith('/unarchive')))).thenAnswer((
        inv,
      ) async {
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return _ok(null, inv.positionalArguments.first as String, 204);
      });

      final ids = [for (var i = 0; i < 12; i++) 'u$i'];
      final result = await repository.unarchiveConversations(ids);

      expect(result.succeeded, ids);
      expect(peak, ConversationRepository.fallbackConcurrency);
    });

    test('erreur serveur (500) ou réseau : remonte à l\'appelant', () async {
      when(
        () =>
            dio.post('/conversations/batch/archive', data: any(named: 'data')),
      ).thenThrow(_status(500, '/conversations/batch/archive'));

      expect(
        () => repository.archiveConversations(['a']),
        throwsA(isA<DioException>()),
      );
    });
  });
}
