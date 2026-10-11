import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../helpers/recording_dio.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _MockDeviceIdService extends Mock implements DeviceIdService {}

/// Source de jeton programmable : rend [token] ou lève [error].
class _TokenSource implements AuthTokenSource {
  _TokenSource({this.token, this.error});

  final String? token;
  final Object? error;
  final List<bool> forceRefreshes = [];

  @override
  Future<String?> idToken({required bool forceRefresh}) async {
    forceRefreshes.add(forceRefresh);
    if (error case final e?) throw e;
    return token;
  }
}

void main() {
  late RecordingAdapter adapter;
  late _MockDeviceIdService deviceId;

  setUp(() {
    adapter = RecordingAdapter();
    deviceId = _MockDeviceIdService();
    when(deviceId.getDeviceId).thenAnswer((_) async => 'device-1');
  });

  Dio build(
    AuthTokenSource tokens, {
    void Function(Breadcrumb)? breadcrumbSink,
  }) {
    final connectivity = _MockConnectivity();
    when(
      connectivity.checkConnectivity,
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    final client = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      deviceIdService: deviceId,
      tokenSource: tokens,
      connectivity: connectivity,
      retrySleep: (_) async {},
      breadcrumbSink: breadcrumbSink ?? (_) {},
    );
    client.dio.httpClientAdapter = adapter;
    return client.dio;
  }

  Matcher authUnavailable() => isA<DioException>().having(
    (e) => e.error,
    'error',
    isA<UnauthorizedException>().having(
      (u) => u.code,
      'code',
      'auth-token-unavailable',
    ),
  );

  group('_AuthInterceptor', () {
    test('ajoute le jeton et l’identifiant d’appareil', () async {
      final tokens = _TokenSource(token: 'tok');
      await build(tokens).get<dynamic>('/announcements');

      expect(adapter.last.headers['Authorization'], 'Bearer tok');
      expect(adapter.last.headers['X-Device-Id'], 'device-1');
      expect(tokens.forceRefreshes, [false]);
    });

    test('force le rafraîchissement sur un appel critique', () async {
      final tokens = _TokenSource(token: 'tok');
      await build(tokens).get<dynamic>('/payments/me');
      expect(tokens.forceRefreshes, [true]);
    });

    test('identifiant d’appareil illisible : la requête part sans', () async {
      when(deviceId.getDeviceId).thenThrow(
        DeviceIdUnavailableException(PlatformException(code: 'locked')),
      );
      await build(_TokenSource(token: 'tok')).get<dynamic>('/announcements');

      expect(adapter.last.headers['Authorization'], 'Bearer tok');
      expect(adapter.last.headers.containsKey('X-Device-Id'), isFalse);
    });

    test('sans session : ni jeton ni identifiant', () async {
      await build(_TokenSource()).get<dynamic>('/announcements');
      expect(adapter.last.headers.containsKey('Authorization'), isFalse);
      expect(adapter.last.headers.containsKey('X-Device-Id'), isFalse);
    });

    test(
      'Firebase pas encore initialisé : la requête part sans jeton',
      () async {
        final tokens = _TokenSource(
          error: FirebaseException(plugin: 'core', code: 'no-app'),
        );
        await build(tokens).get<dynamic>('/announcements');

        expect(adapter.requests, hasLength(1));
        expect(adapter.last.headers.containsKey('Authorization'), isFalse);
      },
    );

    test(
      'autre erreur Firebase : requête rejetée, rien n’est envoyé',
      () async {
        final tokens = _TokenSource(
          error: FirebaseException(
            plugin: 'auth',
            code: 'network-request-failed',
          ),
        );
        await expectLater(
          build(tokens).get<dynamic>('/announcements'),
          throwsA(authUnavailable()),
        );
        expect(adapter.requests, isEmpty);
      },
    );

    test('erreur inattendue : requête rejetée', () async {
      final tokens = _TokenSource(error: StateError('boom'));
      await expectLater(
        build(tokens).get<dynamic>('/announcements'),
        throwsA(authUnavailable()),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  test(
    '409 sans détail : ConflictException avec le libellé de repli',
    () async {
      adapter.on('POST', '/announcements', <String, dynamic>{}, status: 409);
      await expectLater(
        build(_TokenSource(token: 't')).post<dynamic>('/announcements'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<ConflictException>().having(
              (c) => c.message,
              'message',
              isNotEmpty,
            ),
          ),
        ),
      );
    },
  );
}
