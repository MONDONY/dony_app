import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dony/core/network/retry_on_rate_limit_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptateur de test : renvoie les statuts de la file dans l'ordre, un par
/// appel — simule un serveur qui répond différemment à chaque tentative.
class _QueueHttpClientAdapter implements HttpClientAdapter {
  _QueueHttpClientAdapter(
    this.statusQueue, {
    this.body = '{}',
    this.html = false,
  });

  final List<int> statusQueue;
  final String body;
  final bool html;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = statusQueue[callCount];
    callCount++;
    return ResponseBody.fromString(
      status == 200 ? '{}' : body,
      status,
      headers: {
        Headers.contentTypeHeader: [
          html && status != 200 ? 'text/html' : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _QueueHttpClientAdapter adapter;

  Dio buildDio(List<int> statusQueue, {String body = '{}', bool html = false}) {
    adapter = _QueueHttpClientAdapter(statusQueue, body: body, html: html);
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryOnRateLimitInterceptor(dio, random: Random(0), sleep: (_) async {}),
    );
    return dio;
  }

  test(
    '429 puis 200 → retente et résout avec la réponse de la 2e tentative',
    () async {
      final d = buildDio([429, 200]);

      final response = await d.get<Map<String, dynamic>>('/x');

      expect(response.statusCode, 200);
      expect(adapter.callCount, 2);
    },
  );

  test(
    '429 persistant au-delà de maxRetries → propage l\'erreur 429',
    () async {
      final d = buildDio([429, 429, 429]);

      await expectLater(
        () => d.get<Map<String, dynamic>>('/x'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            429,
          ),
        ),
      );
      // 1 tentative initiale + maxRetries(2) = 3 appels réseau au total.
      expect(adapter.callCount, RetryOnRateLimitInterceptor.maxRetries + 1);
    },
  );

  test('erreur non-429 (ex. 500) → aucune tentative supplémentaire', () async {
    final d = buildDio([500]);

    await expectLater(
      () => d.get<Map<String, dynamic>>('/x'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test('429 sur un envoi multipart → jamais rejoué (FLUTTER-B4)', () async {
    final d = buildDio([429, 200]);

    await expectLater(
      () => d.post<Map<String, dynamic>>(
        '/conversations/c/images',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes([1, 2, 3], filename: 'p.jpg'),
        }),
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          429,
        ),
      ),
    );
    expect(adapter.callCount, 1);
  });

  // 429 métier : la réponse ne changerait pas, l'écran affiche le délai.
  for (final body in [
    '{"code":"code-request-too-soon","nextRequestAllowedAt":"2026-10-09T10:15:00Z"}',
    '{"code":"recipient-replacement-too-soon"}',
    '{"retryAfterSeconds":540}',
    '{"code":"photo-upload-quota-exceeded"}',
    '{"code":"tracking-photo-limit-reached"}',
  ]) {
    test('429 métier $body → jamais rejoué', () async {
      final d = buildDio([429, 200], body: body);

      await expectLater(
        () => d.post<Map<String, dynamic>>('/tracking/b/request-code'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            429,
          ),
        ),
      );
      expect(adapter.callCount, 1);
    });
  }

  test('429 Nginx (HTML) → rejoué', () async {
    final d = buildDio(
      [429, 200],
      body: '<html><body>429 Too Many Requests</body></html>',
      html: true,
    );

    final response = await d.get<Map<String, dynamic>>('/x');

    expect(response.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  test('429 Nginx sur POST sans clé d\'idempotence → jamais rejoué', () async {
    final d = buildDio([429, 200], body: '<html>429</html>', html: true);

    await expectLater(
      () => d.post<Map<String, dynamic>>('/bids'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test('429 Nginx sur POST avec clé d\'idempotence → rejoué', () async {
    final d = buildDio([429, 200], body: '<html>429</html>', html: true);

    final response = await d.post<Map<String, dynamic>>(
      '/bids',
      options: Options(headers: {'Idempotency-Key': 'k-1'}),
    );

    expect(response.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  group('isBusinessRateLimit', () {
    test('code ou retryAfterSeconds : métier', () {
      expect(
        RetryOnRateLimitInterceptor.isBusinessRateLimit({'code': 'x'}),
        isTrue,
      );
      expect(
        RetryOnRateLimitInterceptor.isBusinessRateLimit({
          'retryAfterSeconds': 1,
        }),
        isTrue,
      );
      expect(
        RetryOnRateLimitInterceptor.isBusinessRateLimit('{"code":"x"}'),
        isTrue,
      );
    });

    test('vide, HTML, code vide, JSON illisible : générique', () {
      for (final body in <Object?>[
        null,
        '',
        '<html></html>',
        '{pas du json',
        <String, dynamic>{},
        {'code': ' '},
        {'detail': 'x'},
      ]) {
        expect(
          RetryOnRateLimitInterceptor.isBusinessRateLimit(body),
          isFalse,
          reason: '$body',
        );
      }
    });
  });
}
