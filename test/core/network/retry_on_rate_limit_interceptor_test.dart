import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dony/core/network/retry_on_rate_limit_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptateur de test : renvoie les statuts de la file dans l'ordre, un par
/// appel — simule un serveur qui répond différemment à chaque tentative.
class _QueueHttpClientAdapter implements HttpClientAdapter {
  _QueueHttpClientAdapter(this.statusQueue);

  final List<int> statusQueue;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final status = statusQueue[callCount];
    callCount++;
    return ResponseBody.fromString('{}', status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _QueueHttpClientAdapter adapter;

  Dio buildDio(List<int> statusQueue) {
    adapter = _QueueHttpClientAdapter(statusQueue);
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(RetryOnRateLimitInterceptor(dio, random: Random(0)));
    return dio;
  }

  test('429 puis 200 → retente et résout avec la réponse de la 2e tentative',
      () async {
    final d = buildDio([429, 200]);

    final response = await d.get<Map<String, dynamic>>('/x');

    expect(response.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  test('429 persistant au-delà de maxRetries → propage l\'erreur 429',
      () async {
    final d = buildDio([429, 429, 429]);

    await expectLater(
      () => d.get<Map<String, dynamic>>('/x'),
      throwsA(isA<DioException>().having(
        (e) => e.response?.statusCode,
        'statusCode',
        429,
      )),
    );
    // 1 tentative initiale + maxRetries(2) = 3 appels réseau au total.
    expect(adapter.callCount, RetryOnRateLimitInterceptor.maxRetries + 1);
  });

  test('erreur non-429 (ex. 500) → aucune tentative supplémentaire', () async {
    final d = buildDio([500]);

    await expectLater(
      () => d.get<Map<String, dynamic>>('/x'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });
}
