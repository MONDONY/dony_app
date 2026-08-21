import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/network/offline_fast_fail_interceptor.dart';
import 'package:dony/core/network/retry_on_transient_error_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

/// N'est jamais censé être appelé quand l'interface est absente — l'échec
/// doit survenir avant que Dio n'atteigne l'adaptateur HTTP.
class _FailIfCalledAdapter implements HttpClientAdapter {
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _MockConnectivity connectivity;
  late _FailIfCalledAdapter adapter;
  late Dio dio;

  Dio buildDio() {
    connectivity = _MockConnectivity();
    adapter = _FailIfCalledAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(OfflineFastFailInterceptor(connectivity));
    return dio;
  }

  test('aucune interface réseau → échoue avant tout appel réseau', () async {
    final d = buildDio();
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.none]);

    await expectLater(
      () => d.get<Map<String, dynamic>>('/x'),
      throwsA(
        isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.connectionError)
            .having((e) => e.message, 'message', 'Aucune connexion réseau'),
      ),
    );
    expect(adapter.callCount, 0);
  });

  test(
    'aucune interface réseau → ne relance pas via RetryOnTransientErrorInterceptor',
    () async {
      final d = buildDio();
      // Ajouté après : dans le sens onError c'est lui qui voit l'erreur en
      // premier, exactement comme dans ApiClient (voir son commentaire
      // d'assemblage).
      d.interceptors.add(RetryOnTransientErrorInterceptor(d));
      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);

      await expectLater(
        () => d.get<Map<String, dynamic>>('/x'),
        throwsA(anything),
      );

      expect(adapter.callCount, 0);
    },
  );

  test('interface wifi présente → laisse passer la requête', () async {
    final d = buildDio();
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);

    final response = await d.get<Map<String, dynamic>>('/x');

    expect(response.statusCode, 200);
    expect(adapter.callCount, 1);
  });

  test(
    'plusieurs résultats dont un actif → laisse passer la requête',
    () async {
      final d = buildDio();
      when(() => connectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.none, ConnectivityResult.mobile],
      );

      final response = await d.get<Map<String, dynamic>>('/x');

      expect(response.statusCode, 200);
    },
  );

  test(
    'none puis wifi au ré-essai (cold start) → laisse passer la requête',
    () async {
      final d = buildDio();
      var callCount = 0;
      when(() => connectivity.checkConnectivity()).thenAnswer((_) async {
        callCount++;
        // 1er appel : plugin pas encore stabilisé après relance de l'app.
        // 2e appel (après le 1er ré-essai) : l'interface est bien là.
        return callCount == 1
            ? [ConnectivityResult.none]
            : [ConnectivityResult.wifi];
      });

      final response = await d.get<Map<String, dynamic>>('/x');

      expect(response.statusCode, 200);
      expect(callCount, 2);
    },
  );

  test(
    'none à chaque ré-essai → échoue quand même, sans hameçon transitoire',
    () async {
      final d = buildDio();
      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);

      await expectLater(
        () => d.get<Map<String, dynamic>>('/x'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 0);
      verify(() => connectivity.checkConnectivity()).called(3);
    },
  );
}
