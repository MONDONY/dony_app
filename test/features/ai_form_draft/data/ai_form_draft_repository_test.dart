import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

const _reply = {
  'draft': {'departureCity': 'Paris'},
  'understood': ['route'],
  'missing': ['departureDate'],
  'question': 'Quel jour partez-vous ?',
  'quickReplies': ['Le 15'],
  'done': false,
  'degraded': false,
  'remainingToday': 29,
};

void main() {
  late _MockApiClient api;
  late _MockDio dio;
  late AiFormDraftRepository repository;
  final now = DateTime(2026, 10, 17, 9, 30);

  setUp(() {
    api = _MockApiClient();
    dio = _MockDio();
    when(() => api.dio).thenReturn(dio);
    repository = AiFormDraftRepository(api);
  });

  RequestOptions options(String path) => RequestOptions(path: path);

  void respond(String path, Object? data) {
    when(() => dio.post(path, data: any(named: 'data'))).thenAnswer(
      (_) async => Response(requestOptions: options(path), data: data),
    );
  }

  void fail(
    String path,
    int status, {
    Object? data,
    Map<String, List<String>> headers = const {},
  }) {
    when(() => dio.post(path, data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: options(path),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options(path),
          statusCode: status,
          data: data,
          headers: Headers.fromMap(headers),
        ),
      ),
    );
  }

  Future<AiFormDraftReply> send({
    AiFormKind kind = AiFormKind.trip,
    Map<String, Object?> draft = const {},
    String? defaultCurrency = 'EUR',
  }) => repository.send(
    kind: kind,
    messages: const [AiChatMessage.user('Je voyage de Paris à Abidjan')],
    draft: draft,
    locale: 'fr',
    now: now,
    defaultCurrency: defaultCurrency,
  );

  Map<dynamic, dynamic> sentBody(String path) =>
      verify(
            () => dio.post(path, data: captureAny(named: 'data')),
          ).captured.single
          as Map<dynamic, dynamic>;

  test('premier tour : messages, langue, jour, décalage, devise', () async {
    respond('/assistant/form-draft/trip', _reply);
    final reply = await send();
    expect(reply.draft, {'departureCity': 'Paris'});
    expect(reply.question, 'Quel jour partez-vous ?');
    expect(reply.remainingToday, 29);
    final body = sentBody('/assistant/form-draft/trip');
    expect(body['messages'], [
      {'role': 'user', 'text': 'Je voyage de Paris à Abidjan'},
    ]);
    expect(body['locale'], 'fr');
    expect(body['today'], '2026-10-17');
    expect(body['timezone'], utcOffsetId(now.timeZoneOffset));
    expect(body['defaultCurrency'], 'EUR');
    // Premier tour : pas de brouillon envoyé.
    expect(body.containsKey('draft'), isFalse);
  });

  test('tour suivant : brouillon envoyé, devise absente omise', () async {
    respond('/assistant/form-draft/package-request', _reply);
    await send(
      kind: AiFormKind.packageRequest,
      draft: const {'weightKg': 5},
      defaultCurrency: null,
    );
    final body = sentBody('/assistant/form-draft/package-request');
    expect(body['draft'], {'weightKg': 5});
    expect(body.containsKey('defaultCurrency'), isFalse);
  });

  test('404 et 403 : formulaires IA éteints', () async {
    fail('/assistant/form-draft/trip', 404);
    await expectLater(send(), throwsA(isA<AiFormDraftDisabledException>()));
    fail('/assistant/form-draft/trip', 403);
    await expectLater(send(), throwsA(isA<AiFormDraftDisabledException>()));
  });

  test('429 du quota : délai lu dans le corps', () async {
    fail(
      '/assistant/form-draft/trip',
      429,
      data: {'code': 'assistant-form-draft-quota-exceeded', 'retryAfter': 3600},
    );
    await expectLater(
      send(),
      throwsA(
        isA<AiFormDraftQuotaExceededException>().having(
          (e) => e.retryAfter,
          'retryAfter',
          const Duration(hours: 1),
        ),
      ),
    );
  });

  test(
    '429 du quota : délai en chaîne, ou dans l’en-tête Retry-After',
    () async {
      fail(
        '/assistant/form-draft/trip',
        429,
        data: {
          'code': 'assistant-form-draft-quota-exceeded',
          'retryAfter': '60',
        },
      );
      await expectLater(
        send(),
        throwsA(
          isA<AiFormDraftQuotaExceededException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(minutes: 1),
          ),
        ),
      );
      fail(
        '/assistant/form-draft/trip',
        429,
        data: {'code': 'assistant-form-draft-quota-exceeded'},
        headers: {
          'retry-after': ['120'],
        },
      );
      await expectLater(
        send(),
        throwsA(
          isA<AiFormDraftQuotaExceededException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(minutes: 2),
          ),
        ),
      );
    },
  );

  test('429 du quota : instant ISO du back, converti en délai', () async {
    final at = DateTime.now().toUtc().add(const Duration(hours: 2));
    fail(
      '/assistant/form-draft/trip',
      429,
      data: {
        'code': 'assistant-form-draft-quota-exceeded',
        'retryAfter': at.toIso8601String(),
      },
    );
    await expectLater(
      send(),
      throwsA(
        isA<AiFormDraftQuotaExceededException>().having(
          (e) => e.retryAfter!.inMinutes,
          'retryAfter (min)',
          inInclusiveRange(118, 120),
        ),
      ),
    );
    fail(
      '/assistant/form-draft/trip',
      429,
      data: {
        'code': 'assistant-form-draft-quota-exceeded',
        'retryAfter': '2000-01-01T00:00:00Z',
      },
    );
    await expectLater(
      send(),
      throwsA(
        isA<AiFormDraftQuotaExceededException>().having(
          (e) => e.retryAfter,
          'retryAfter',
          Duration.zero,
        ),
      ),
    );
  });

  test('429 sans le code du quota (Nginx) : erreur réseau', () async {
    fail('/assistant/form-draft/trip', 429, data: '<html>');
    await expectLater(send(), throwsA(isA<AiFormDraftNetworkException>()));
  });

  test('422 trop de tours ; autre 422 : erreur réseau', () async {
    fail(
      '/assistant/form-draft/trip',
      422,
      data: {'code': 'form-draft-too-many-turns'},
    );
    await expectLater(send(), throwsA(isA<AiFormDraftTooManyTurnsException>()));
    fail('/assistant/form-draft/trip', 422, data: {'code': 'autre'});
    await expectLater(send(), throwsA(isA<AiFormDraftNetworkException>()));
  });

  test('coupure réseau et corps illisible : erreur réseau', () async {
    when(
      () => dio.post('/assistant/form-draft/trip', data: any(named: 'data')),
    ).thenThrow(
      DioException(
        requestOptions: options('/assistant/form-draft/trip'),
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(send(), throwsA(isA<AiFormDraftNetworkException>()));
    respond('/assistant/form-draft/trip', 'pas du json');
    await expectLater(send(), throwsA(isA<AiFormDraftNetworkException>()));
    respond('/assistant/form-draft/trip', {'remainingToday': 'beaucoup'});
    await expectLater(send(), throwsA(isA<AiFormDraftNetworkException>()));
  });

  group('formDraftEnabled', () {
    void status(Object? data) =>
        when(() => dio.get('/assistant/status')).thenAnswer(
          (_) async => Response(
            requestOptions: options('/assistant/status'),
            data: data,
          ),
        );

    test('vrai seulement si enabled et formDraftEnabled sont vrais', () async {
      status({'enabled': true, 'formDraftEnabled': true});
      expect(await repository.formDraftEnabled(), isTrue);
      status({'enabled': true, 'formDraftEnabled': false});
      expect(await repository.formDraftEnabled(), isFalse);
      status({'enabled': false, 'formDraftEnabled': true});
      expect(await repository.formDraftEnabled(), isFalse);
    });

    test('champ absent (back pas encore déployé) : faux', () async {
      status({'enabled': true});
      expect(await repository.formDraftEnabled(), isFalse);
      status('pas un objet');
      expect(await repository.formDraftEnabled(), isFalse);
    });

    test('erreur : faux, sans lever', () async {
      when(
        () => dio.get('/assistant/status'),
      ).thenThrow(DioException(requestOptions: options('/assistant/status')));
      expect(await repository.formDraftEnabled(), isFalse);
    });
  });
}
