import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/profile/data/models/username_availability.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

void main() {
  late _MockDio dio;
  late ProfileRepository repo;

  setUp(() {
    dio = _MockDio();
    final client = _MockApiClient();
    when(() => client.dio).thenReturn(dio);
    repo = ProfileRepository(client);
  });

  test('checkUsername lit disponibilité, motif et suggestions', () async {
    when(
      () => dio.get<dynamic>(
        '/auth/me/username/availability',
        queryParameters: {'value': 'awa'},
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => _ok({
        'available': false,
        'reason': 'TAKEN',
        'suggestions': ['awa1', 'awa.d', 'awa_d'],
      }, '/auth/me/username/availability'),
    );
    final r = await repo.checkUsername('awa');
    expect(r.available, isFalse);
    expect(r.reason, UsernameReason.taken);
    expect(r.suggestions, ['awa1', 'awa.d', 'awa_d']);
  });

  test('checkUsername tolère champs absents et motif inconnu', () async {
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => _ok({'available': false, 'reason': 'NOUVEAU'}, '/x'),
    );
    final r = await repo.checkUsername('awa');
    expect(r.reason, UsernameReason.unknown);
    expect(r.suggestions, isEmpty);
  });

  test('changeUsername envoie le corps et lit l utilisateur', () async {
    when(
      () => dio.put<dynamic>('/auth/me/username', data: {'username': 'awa.d'}),
    ).thenAnswer(
      (_) async => _ok({'id': 'u1', 'username': 'awa.d'}, '/auth/me/username'),
    );
    final user = await repo.changeUsername('awa.d');
    expect(user.username, 'awa.d');
  });

  test('une erreur HTTP typée traverse inchangée', () async {
    when(() => dio.put<dynamic>(any(), data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/auth/me/username'),
        error: const ConflictException('x', code: 'username-taken'),
      ),
    );
    expect(repo.changeUsername('awa'), throwsA(isA<ConflictException>()));
  });

  group('usernameProblemSlug', () {
    test('code prioritaire', () {
      expect(
        usernameProblemSlug(
          const ConflictException('x', code: 'username-taken'),
        ),
        'username-taken',
      );
    });
    test('suffixe du type sinon', () {
      expect(
        usernameProblemSlug(
          const ConflictException(
            'x',
            extensions: {'type': 'https://e.com/problems/username-taken'},
          ),
        ),
        'username-taken',
      );
    });
    test('rien : null', () {
      expect(usernameProblemSlug(const ConflictException('x')), isNull);
    });
  });
}
