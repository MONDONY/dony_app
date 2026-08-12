import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/network/metrics_interceptor.dart';
import 'package:dony/core/network/network_metrics_collector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onResponse enregistre un RequestSample dans le collector', () {
    final collector = NetworkMetricsCollector();
    final interceptor = MetricsInterceptor(collector);
    final opts = RequestOptions(path: '/announcements/search', method: 'GET');
    try { interceptor.onRequest(opts, RequestInterceptorHandler()); } catch (_) {}
    final resp = Response(requestOptions: opts, statusCode: 200, data: {'a': 1});
    try {
      interceptor.onResponse(resp, ResponseInterceptorHandler());
    } catch (_) {}
    final stats = collector.aggregate();
    expect(stats.single.key, 'GET /announcements/search');
    expect(stats.single.count, 1);
  });

  test('onError enregistre aussi un sample avec status >=400', () async {
    final collector = NetworkMetricsCollector();
    final interceptor = MetricsInterceptor(collector);
    final opts = RequestOptions(path: '/x', method: 'GET');
    try { interceptor.onRequest(opts, RequestInterceptorHandler()); } catch (_) {}
    final err = DioException(
      requestOptions: opts,
      response: Response(requestOptions: opts, statusCode: 500),
    );
    // ErrorInterceptorHandler.next() calls completer.completeError() which
    // sends an unhandled async error into the zone. Use runZonedGuarded to
    // absorb it — the important thing is the side-effect on collector.
    await runZonedGuarded(
      () async {
        try {
          interceptor.onError(err, ErrorInterceptorHandler());
        } catch (_) {}
        // Let any async completer errors flush before asserting.
        await Future<void>.delayed(Duration.zero);
      },
      (_, __) {}, // swallow zone errors from handler.next()
    );
    expect(collector.aggregate().single.errorRate, 1.0);
  });

  test('respBytes utilise Content-Length (pas toString) pour un corps JSON', () {
    final collector = NetworkMetricsCollector();
    final interceptor = MetricsInterceptor(collector);
    final opts = RequestOptions(path: '/announcements/search', method: 'GET');
    try { interceptor.onRequest(opts, RequestInterceptorHandler()); } catch (_) {}
    final resp = Response(
      requestOptions: opts,
      statusCode: 200,
      data: {'a': 1}, // Map JSON parsé : toString().length ≈ 8, non pertinent
      headers: Headers.fromMap({
        Headers.contentLengthHeader: ['1234'],
      }),
    );
    try { interceptor.onResponse(resp, ResponseInterceptorHandler()); } catch (_) {}
    // totalBytes = reqBytes(0, GET) + respBytes → doit valoir le Content-Length.
    expect(collector.aggregate().single.totalBytes, 1234);
  });
}
