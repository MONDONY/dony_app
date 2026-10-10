import 'dart:async';
import 'dart:io' show HandshakeException, HttpException, SocketException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../helpers/l10n_test_helpers.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _MockDeviceIdService extends Mock implements DeviceIdService {}

/// Marqueur : la tentative échoue sans réponse (API injoignable).
class _ConnError {
  const _ConnError();
}

/// Marqueur : l'adaptateur lève cette erreur `dart:io` brute, que dio range
/// en `DioExceptionType.unknown` (socket coupée par Android en arrière-plan).
class _RawError {
  const _RawError(this.error);

  final Object error;
}

/// Adaptateur factice : rejoue la file de résultats, une entrée par appel
/// réseau, et note chaque appel dans le journal partagé.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.queue, this.log);

  final List<Object> queue;
  final List<String> log;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final result = queue[requests.length];
    requests.add(options);
    log.add('fetch ${options.method}');
    if (result is _RawError) throw result.error;
    if (result is _ConnError) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'Connection refused',
      );
    }
    final (status, body) = result is (int, String)
        ? result
        : (result as int, status200Body);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [
          body.startsWith('<') ? 'text/html' : Headers.jsonContentType,
        ],
      },
    );
  }

  static const status200Body = '{}';

  @override
  void close({bool force = false}) {}
}

class _RecordingSink implements ErrorReportingSink {
  _RecordingSink(this.log);

  final List<String> log;
  final List<Map<String, Object>> contexts = [];
  final List<Object> errors = [];

  @override
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  }) async {
    log.add('report');
    errors.add(error);
    contexts.add(context);
  }
}

class _FakeTokenSource implements AuthTokenSource {
  int forcedRefreshes = 0;
  int calls = 0;

  @override
  Future<String?> idToken({required bool forceRefresh}) async {
    calls++;
    if (forceRefresh) forcedRefreshes++;
    return 'token-$forcedRefreshes';
  }
}

void main() {
  late List<String> log;
  late _FakeAdapter adapter;
  late _RecordingSink sink;
  late _FakeTokenSource tokens;
  late List<Breadcrumb> crumbs;

  Dio build(List<Object> queue) {
    log = [];
    crumbs = [];
    sink = _RecordingSink(log);
    tokens = _FakeTokenSource();
    final connectivity = _MockConnectivity();
    when(
      connectivity.checkConnectivity,
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    final deviceId = _MockDeviceIdService();
    when(deviceId.getDeviceId).thenAnswer((_) async => 'device-1');

    final client = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      deviceIdService: deviceId,
      errorReporter: ErrorReportingService(sink),
      tokenSource: tokens,
      connectivity: connectivity,
      retrySleep: (_) async {},
      breadcrumbSink: (crumb) {
        crumbs.add(crumb);
        log.add('crumb ${crumb.data?['status_code'] ?? 'none'}');
      },
    );
    adapter = _FakeAdapter(queue, log);
    client.dio.httpClientAdapter = adapter;
    return client.dio;
  }

  /// Laisse partir le report Sentry, lancé sans attente.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  Matcher appError<T extends AppException>() =>
      isA<DioException>().having((e) => e.error, 'error', isA<T>());

  group('chaîne complète (FLUTTER-J1)', () {
    test(
      '502 persistant sur GET : retries, breadcrumbs, un seul report, exception',
      () async {
        final dio = build([502, 502, 502, 502]);

        await expectLater(
          dio.get<dynamic>('/announcements'),
          throwsA(appError<ServiceUnavailableException>()),
        );
        await flush();

        expect(log, [
          'fetch GET',
          'crumb 502',
          'fetch GET',
          'crumb 502',
          'fetch GET',
          'crumb 502',
          'fetch GET',
          'crumb 502',
          'report',
        ]);
        expect(sink.contexts.single['operation'], 'http.GET');
        expect(sink.contexts.single['status_code'], 502);
        expect(sink.contexts.single['retry_count'], 3);
        expect(sink.contexts.single['endpoint'], '/api/v1/announcements');
      },
    );

    test('502 puis 200 sur GET : résolu, aucun report', () async {
      final dio = build([502, 200]);

      final response = await dio.get<dynamic>('/announcements');
      await flush();

      expect(response.statusCode, 200);
      expect(log, ['fetch GET', 'crumb 502', 'fetch GET', 'crumb 200']);
      expect(crumbs.last.data?['status_code'], 200);
    });

    test(
      '502 sur POST sans clé d\'idempotence : pas de retry, report, exception',
      () async {
        final dio = build([502, 200]);

        await expectLater(
          dio.post<dynamic>('/announcements', data: {'kg': 5}),
          throwsA(appError<ServiceUnavailableException>()),
        );
        await flush();

        expect(adapter.requests, hasLength(1));
        expect(log, ['fetch POST', 'crumb 502', 'report']);
        expect(sink.contexts.single['retry_count'], 0);
      },
    );

    test('502 sur POST avec clé d\'idempotence : rejoué', () async {
      final dio = build([502, 200]);

      final response = await dio.post<dynamic>(
        '/payments/pay',
        options: Options(headers: {'Idempotency-Key': 'k-1'}),
      );

      expect(response.statusCode, 200);
      expect(adapter.requests, hasLength(2));
    });

    test('429 Nginx sur GET : rejoué selon la règle existante', () async {
      final dio = build([(429, '<html>429</html>'), 200]);

      final response = await dio.get<dynamic>('/users/me');
      await flush();

      expect(response.statusCode, 200);
      expect(adapter.requests, hasLength(2));
      expect(log.where((e) => e == 'report'), isEmpty);
    });

    test(
      '429 persistant : maxRetries puis exception, jamais rapporté',
      () async {
        final dio = build([
          (429, '<html>429</html>'),
          (429, '<html>429</html>'),
          (429, '<html>429</html>'),
        ]);

        await expectLater(
          dio.get<dynamic>('/users/me'),
          throwsA(appError<RateLimitException>()),
        );
        await flush();

        expect(adapter.requests, hasLength(3));
        expect(log.where((e) => e == 'report'), isEmpty);
      },
    );

    test('429 Nginx sur POST sans clé : jamais rejoué', () async {
      final dio = build([(429, '<html>429</html>'), 200]);

      await expectLater(
        dio.post<dynamic>('/bids'),
        throwsA(appError<RateLimitException>()),
      );
      expect(adapter.requests, hasLength(1));
    });

    test(
      '401 sur GET : jeton rafraîchi une fois, requête rejouée et résolue',
      () async {
        final dio = build([401, 200]);

        final response = await dio.get<dynamic>('/users/me');

        expect(response.statusCode, 200);
        expect(tokens.forcedRefreshes, 1);
        expect(adapter.requests, hasLength(2));
        expect(
          adapter.requests.last.headers['Authorization'],
          'Bearer token-1',
        );
      },
    );

    test('401 persistant : un seul rafraîchissement, pas de boucle', () async {
      final dio = build([401, 401, 401]);

      await expectLater(
        dio.get<dynamic>('/users/me'),
        throwsA(appError<UnauthorizedException>()),
      );
      await flush();

      expect(tokens.forcedRefreshes, 1);
      expect(adapter.requests, hasLength(2));
      expect(log.where((e) => e == 'report'), isEmpty);
    });

    test('401 sur POST : jeton rafraîchi, requête jamais rejouée', () async {
      final dio = build([401, 200]);

      await expectLater(
        dio.post<dynamic>('/announcements'),
        throwsA(appError<UnauthorizedException>()),
      );

      expect(tokens.forcedRefreshes, 1);
      expect(adapter.requests, hasLength(1));
    });

    for (final status in [403, 404, 409, 422]) {
      test('$status métier attendu : exception typée, aucun report', () async {
        final dio = build([(status, '{"code":"x-refused","detail":"Refusé"}')]);

        await expectLater(
          dio.post<dynamic>('/bids'),
          throwsA(isA<DioException>()),
        );
        await flush();

        expect(adapter.requests, hasLength(1));
        expect(log, ['fetch POST', 'crumb $status']);
      });
    }

    test('API injoignable : service indisponible, jamais rapporté', () async {
      final dio = build([const _ConnError(), const _ConnError()]);

      await expectLater(
        dio.post<dynamic>('/announcements'),
        throwsA(appError<ServiceUnavailableException>()),
      );
      await flush();

      expect(log.where((e) => e == 'report'), isEmpty);
    });

    group('connexion perdue sans réponse (FLUTTER-JQ)', () {
      for (final (label, error) in [
        (
          'SocketException',
          const SocketException('Software caused connection abort'),
        ),
        (
          'HttpException « Connection closed »',
          const HttpException(
            'Connection closed before full header was received',
          ),
        ),
        (
          'HandshakeException réseau',
          const HandshakeException('Connection terminated during handshake'),
        ),
      ]) {
        test('$label : hors ligne, jamais rapporté', () async {
          final dio = build([_RawError(error)]);

          await expectLater(
            dio.get<dynamic>('/notifications/unread-count'),
            throwsA(appError<OfflineException>()),
          );
          await flush();

          expect(log.where((e) => e == 'report'), isEmpty);
        });
      }

      test('certificat refusé : toujours rapporté (épinglage TLS)', () async {
        final dio = build([
          const _RawError(
            HandshakeException('Handshake error: CERTIFICATE_VERIFY_FAILED'),
          ),
        ]);

        await expectLater(
          dio.get<dynamic>('/notifications/unread-count'),
          throwsA(isA<DioException>()),
        );
        await flush();

        expect(log.where((e) => e == 'report'), hasLength(1));
      });

      test('500 sur le compteur : toujours rapporté', () async {
        final dio = build([500, 500, 500, 500]);

        await expectLater(
          dio.get<dynamic>('/notifications/unread-count'),
          throwsA(appError<ServerException>()),
        );
        await flush();

        expect(log.where((e) => e == 'report'), hasLength(1));
        expect(sink.contexts.single['status_code'], 500);
      });
    });

    test('même panne répétée : un seul report par fenêtre', () async {
      final dio = build([502, 502, 503]);

      for (var i = 0; i < 2; i++) {
        await expectLater(
          dio.post<dynamic>('/announcements'),
          throwsA(isA<DioException>()),
        );
      }
      await expectLater(
        dio.post<dynamic>('/announcements'),
        throwsA(isA<DioException>()),
      );
      await flush();

      // 502 deux fois → un report ; 503 sur le même chemin → un autre.
      expect(log.where((e) => e == 'report'), hasLength(2));
    });

    test('redémarrage de l\'API : 503 sur plusieurs routes, un seul report '
        'sous une empreinte sans route', () async {
      final dio = build([503, 503, 503]);

      for (final path in ['/users/me', '/bids/mine', '/announcements']) {
        await expectLater(
          dio.post<dynamic>(path),
          throwsA(appError<ServiceUnavailableException>()),
        );
      }
      await flush();

      expect(log.where((e) => e == 'report'), hasLength(1));
      final context = sink.contexts.single;
      expect(
        context[SentryErrorReportingSink.fingerprintKey],
        'http-transient-503',
      );
      // La route reste connue (tag), hors de l'empreinte.
      expect(context['endpoint'], '/api/v1/users/me');
    });

    test('500 : pas une panne transitoire, un report par route', () async {
      final dio = build([500, 500]);

      for (final path in ['/users/me', '/bids/mine']) {
        await expectLater(
          dio.post<dynamic>(path),
          throwsA(isA<DioException>()),
        );
      }
      await flush();

      expect(log.where((e) => e == 'report'), hasLength(2));
      expect(
        sink.contexts.every(
          (c) => !c.containsKey(SentryErrorReportingSink.fingerprintKey),
        ),
        isTrue,
      );
    });

    test(
      'FLUTTER-JP : 400 phone-otp-invalid (code faux), aucun report',
      () async {
        final dio = build([
          (400, '{"code":"phone-otp-invalid","detail":"Code invalide"}'),
        ]);

        await expectLater(
          dio.post<dynamic>('/auth/phone/verify'),
          throwsA(appError<ValidationException>()),
        );
        await flush();

        expect(log, ['fetch POST', 'crumb 400']);
      },
    );

    test('aucune donnée sensible dans le report ni le breadcrumb', () async {
      final dio = build([(500, '{"detail":"+33612345678 refusé"}')]);

      await expectLater(
        dio.post<dynamic>(
          '/tracking/ab12cd34ef56gh78ij90kl/events',
          data: {'phone': '+33612345678'},
        ),
        throwsA(appError<ServerException>()),
      );
      await flush();

      final context = sink.contexts.single;
      expect(context['endpoint'], '/api/v1/tracking/:token/events');
      expect(context.toString(), isNot(contains('+336')));
      expect(context.toString(), isNot(contains('Bearer')));
      expect(sink.errors.single.toString(), isNot(contains('+336')));
      expect(crumbs.single.data?['path'], '/api/v1/tracking/:token/events');
    });
  });

  group('message utilisateur', () {
    test('502 → « Service momentanément indisponible »', () async {
      final dio = build([502]);

      Object? caught;
      try {
        await dio.post<dynamic>('/announcements');
      } on DioException catch (e) {
        caught = e;
      }
      final error = unwrapDioError(caught!);
      final presentation = ErrorCatalog.lookup(error);

      expect(error.code, 'SERVICE_UNAVAILABLE');
      expect(
        presentation.message,
        'Service momentanément indisponible, réessayez dans un instant.',
      );
      expect(
        error.message,
        'Service momentanément indisponible, réessayez dans un instant.',
      );
    });

    test('503 et 504, en anglais', () {
      useEnglish();
      for (final status in [503, 504]) {
        final options = RequestOptions(path: '/x');
        final error = mapHttpError(
          DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: status),
          ),
        );
        expect(error, isA<ServiceUnavailableException>());
        expect(
          ErrorCatalog.lookup(error).message,
          'Service temporarily unavailable, please try again in a moment.',
        );
      }
    });

    test('500 reste « Erreur serveur »', () {
      final options = RequestOptions(path: '/x');
      final error = mapHttpError(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 500),
        ),
      );
      expect(error, isNot(isA<ServiceUnavailableException>()));
      expect(error.code, 'SERVER_ERROR');
    });

    test('délai dépassé → TimeoutException, annulation → CANCELLED', () {
      final options = RequestOptions(path: '/x');
      expect(
        mapHttpError(
          DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
        isA<TimeoutException>(),
      );
      expect(
        mapHttpError(
          DioException(requestOptions: options, type: DioExceptionType.cancel),
        ).code,
        'CANCELLED',
      );
    });

    test('socket coupée sans réponse → OfflineException', () {
      final options = RequestOptions(path: '/x');
      expect(
        mapHttpError(
          DioException(
            requestOptions: options,
            error: const SocketException('Connection reset by peer'),
          ),
        ),
        isA<OfflineException>(),
      );
      // Une erreur inconnue sans rapport avec le réseau garde l'ancien sort.
      expect(
        mapHttpError(
          DioException(requestOptions: options, error: StateError('x')),
        ),
        isA<NetworkException>(),
      );
    });

    test('erreur déjà convertie : rendue telle quelle', () {
      const original = ConflictException('x', code: 'c');
      expect(
        mapHttpError(
          DioException(requestOptions: RequestOptions(), error: original),
        ),
        same(original),
      );
    });
  });
}
