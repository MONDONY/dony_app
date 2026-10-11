import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:mocktail/mocktail.dart';

/// Réponse programmée pour [RecordingAdapter] : corps JSON et statut HTTP.
class StubResponse {
  const StubResponse(this.body, {this.status = 200});

  final Object? body;
  final int status;
}

/// Adaptateur Dio factice : enregistre chaque requête et rend la réponse
/// programmée pour `MÉTHODE chemin` (ou la réponse par défaut).
///
/// Permet de vérifier la méthode, le chemin, la query et le corps réellement
/// envoyés, tout en laissant Dio décoder le JSON comme en production.
class RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, StubResponse> _stubs = {};
  StubResponse fallback = const StubResponse(null, status: 204);

  /// Si renseigné, chaque requête échoue avec une [DioException] de ce type
  /// (coupure réseau, délai dépassé…), sans réponse HTTP.
  DioExceptionType? failWith;

  void on(String method, String path, Object? body, {int status = 200}) {
    _stubs['${method.toUpperCase()} $path'] = StubResponse(
      body,
      status: status,
    );
  }

  RequestOptions get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final failure = failWith;
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure);
    }
    final stub = _stubs['${options.method} ${options.path}'] ?? fallback;
    final body = stub.body;
    if (body == null) {
      return ResponseBody.fromString('', stub.status);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      stub.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class MockApiClient extends Mock implements ApiClient {}

/// Un [Dio] réel branché sur un [RecordingAdapter], et un [ApiClient] factice
/// qui l'expose.
class RecordingApi {
  RecordingApi() {
    dio.httpClientAdapter = adapter;
    when(() => client.dio).thenReturn(dio);
  }

  final RecordingAdapter adapter = RecordingAdapter();
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  final MockApiClient client = MockApiClient();

  RequestOptions get last => adapter.last;
  List<RequestOptions> get requests => adapter.requests;

  void on(String method, String path, Object? body, {int status = 200}) =>
      adapter.on(method, path, body, status: status);
}
