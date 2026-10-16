import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/network/maintenance_signal.dart';
import 'package:dony/core/network/retry_on_transient_error_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Répond toujours [status] avec [body].
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.status, this.body);

  final int status;
  final String body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Response<dynamic> _response(int status, Object? data) => Response<dynamic>(
  requestOptions: RequestOptions(path: '/x'),
  statusCode: status,
  data: data,
);

const _maintenanceBody =
    '{"code":"maintenance","detail":"Pause","estimatedEndAt":"2026-10-16T14:30:00Z"}';

void main() {
  group('isMaintenanceResponse', () {
    test('vrai seulement pour le 503 au code maintenance', () {
      expect(
        isMaintenanceResponse(_response(503, {'code': 'maintenance'})),
        isTrue,
      );
      expect(
        isMaintenanceResponse(_response(503, {'code': 'service-busy'})),
        isFalse,
      );
      expect(isMaintenanceResponse(_response(503, 'html')), isFalse);
      expect(
        isMaintenanceResponse(_response(500, {'code': 'maintenance'})),
        isFalse,
      );
      expect(isMaintenanceResponse(null), isFalse);
    });
  });

  group('MaintenanceNotice.fromProblem', () {
    test('lit detail et estimatedEndAt', () {
      final notice = MaintenanceNotice.fromProblem({
        'detail': 'Pause',
        'estimatedEndAt': '2026-10-16T14:30:00Z',
      });
      expect(notice.message, 'Pause');
      expect(notice.estimatedEndAt, DateTime.utc(2026, 10, 16, 14, 30));
    });

    test('corps illisible : notice vide', () {
      final notice = MaintenanceNotice.fromProblem('oops');
      expect(notice.message, isNull);
      expect(notice.estimatedEndAt, isNull);
      expect(
        MaintenanceNotice.fromProblem({'estimatedEndAt': 3}).estimatedEndAt,
        isNull,
      );
    });
  });

  test(
    "l'intercepteur publie le 503 de maintenance et ne le rejoue pas",
    () async {
      final signal = MaintenanceSignal();
      final notices = <MaintenanceNotice>[];
      final sub = signal.notices.listen(notices.add);
      addTearDown(sub.cancel);
      final adapter = _FixedAdapter(503, _maintenanceBody);
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter;
      dio.interceptors
        ..add(MaintenanceInterceptor(signal))
        ..add(RetryOnTransientErrorInterceptor(dio, sleep: (_) async {}));

      await expectLater(
        dio.get<dynamic>('/announcements'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(adapter.calls, 1, reason: 'jamais rejoué');
      expect(notices, hasLength(1));
      expect(notices.single.message, 'Pause');
    },
  );

  test("un autre 503 n'est pas publié (et reste rejoué)", () async {
    final signal = MaintenanceSignal();
    final notices = <MaintenanceNotice>[];
    final sub = signal.notices.listen(notices.add);
    addTearDown(sub.cancel);
    final adapter = _FixedAdapter(503, '{"code":"service-busy"}');
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    dio.interceptors
      ..add(MaintenanceInterceptor(signal))
      ..add(RetryOnTransientErrorInterceptor(dio, sleep: (_) async {}));

    await expectLater(
      dio.get<dynamic>('/announcements'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(adapter.calls, greaterThan(1));
    expect(notices, isEmpty);
  });
}
