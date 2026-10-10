import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dony/core/network/retry_on_transient_error_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Marqueur : la prochaine tentative doit échouer par une erreur de
/// connexion (pas de réponse HTTP du tout), pas un statut.
class _ConnError {
  const _ConnError();
}

/// Marqueur : la tentative dépasse le délai de réception.
class _Timeout {
  const _Timeout();
}

/// Adaptateur de test : rejoue les résultats de la file dans l'ordre, un par
/// appel — simule un serveur en cold start (timeout/erreur réseau puis 200).
class _QueueHttpClientAdapter implements HttpClientAdapter {
  _QueueHttpClientAdapter(this.queue);

  final List<Object> queue;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final result = queue[callCount];
    callCount++;
    if (result is _Timeout) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    if (result is _ConnError) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'Connection refused',
      );
    }
    final status = result as int;
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _QueueHttpClientAdapter adapter;

  Dio buildDio(List<Object> queue) {
    adapter = _QueueHttpClientAdapter(queue);
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryOnTransientErrorInterceptor(
        dio,
        random: Random(0),
        sleep: (_) async {},
      ),
    );
    return dio;
  }

  test('GET : 500 puis 200 → retente et résout avec la 2e tentative', () async {
    final d = buildDio([500, 200]);

    final response = await d.get<Map<String, dynamic>>('/x');

    expect(response.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  test('GET : erreur de connexion puis 200 → retente et résout', () async {
    final d = buildDio([const _ConnError(), 200]);

    final response = await d.get<Map<String, dynamic>>('/x');

    expect(response.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  test(
    'GET : 500 persistant au-delà de maxRetries → propage l\'erreur',
    () async {
      final d = buildDio([500, 500, 500, 500]);

      await expectLater(
        () => d.get<Map<String, dynamic>>('/x'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
      // 1 tentative initiale + maxRetries(3) = 4 appels réseau au total.
      expect(
        adapter.callCount,
        RetryOnTransientErrorInterceptor.maxRetries + 1,
      );
    },
  );

  test('GET : 404 → jamais retenté (pas transitoire)', () async {
    final d = buildDio([404]);

    await expectLater(
      () => d.get<Map<String, dynamic>>('/x'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test('POST : 500 → jamais retenté (écriture non idempotente)', () async {
    final d = buildDio([500, 200]);

    await expectLater(
      () => d.post<Map<String, dynamic>>('/x'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test(
    'GET avec skipTransientRetry : erreur transitoire → jamais retenté',
    () async {
      final d = buildDio([const _ConnError(), 200]);

      await expectLater(
        () => d.get<Map<String, dynamic>>(
          '/x',
          options: Options(extra: {'skipTransientRetry': true}),
        ),
        throwsA(isA<DioException>()),
      );
      // L'appelant gère son propre retry (ex. splash screen) — un seul appel
      // réseau ici, pas de cumul avec la boucle de retry de l'appelant.
      expect(adapter.callCount, 1);
    },
  );

  test('GET : délai de réception dépassé → une seule relance', () async {
    final d = buildDio([const _Timeout(), const _Timeout(), 200]);

    await expectLater(
      () => d.get<Map<String, dynamic>>('/x'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.receiveTimeout,
        ),
      ),
    );
    expect(adapter.callCount, 2);
  });

  test('POST avec clé d\'idempotence : 503 → rejoué', () async {
    final d = buildDio([503, 200]);

    final response = await d.post<Map<String, dynamic>>(
      '/x',
      options: Options(headers: {'Idempotency-Key': 'k-1'}),
    );

    expect(response.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  test('échec final : profondeur de relance rétablie à 0', () async {
    final d = buildDio([500, 500, 500, 500]);

    try {
      await d.get<Map<String, dynamic>>('/x');
      fail('doit échouer');
    } on DioException catch (e) {
      expect(e.requestOptions.extra['_retryDepth'], 0);
      expect(e.requestOptions.extra['_retryTransientAttempt'], 3);
    }
  });
}
