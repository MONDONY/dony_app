import 'package:dio/dio.dart';
import 'package:dony/core/network/network_metrics_collector.dart';

class MetricsInterceptor extends Interceptor {
  MetricsInterceptor(this.collector);
  final NetworkMetricsCollector collector;
  static final NetworkMetricsCollector globalCollector =
      NetworkMetricsCollector();

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_perf_start'] = _nowMs();
    handler.next(options);
  }

  void _record(
    RequestOptions o,
    int? status,
    dynamic data,
    Headers? respHeaders,
  ) {
    final start = (o.extra['_perf_start'] as int?) ?? _nowMs();
    collector.record(
      RequestSample(
        method: o.method,
        path: o.path,
        status: status ?? 0,
        durationMs: _nowMs() - start,
        reqBytes: o.data is String ? (o.data as String).length : 0,
        respBytes: _respBytes(data, respHeaders),
        startTsMs: start,
      ),
    );
  }

  /// Taille de la réponse en octets. Priorité au header Content-Length (le cas
  /// courant pour du JSON) ; sinon longueur réelle pour un corps String/bytes ;
  /// sinon 0 — `data.toString().length` sur un Map/List JSON parsé n'a aucun
  /// rapport avec la taille wire et fausserait la métrique.
  static int _respBytes(dynamic data, Headers? headers) {
    final cl = headers?.value(Headers.contentLengthHeader);
    final parsed = cl != null ? int.tryParse(cl) : null;
    if (parsed != null && parsed >= 0) {
      return parsed;
    }
    if (data is String) {
      return data.length;
    }
    if (data is List<int>) {
      return data.length;
    }
    return 0;
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _record(
      response.requestOptions,
      response.statusCode,
      response.data,
      response.headers,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(
      err.requestOptions,
      err.response?.statusCode ?? 0,
      err.response?.data,
      err.response?.headers,
    );
    handler.next(err);
  }
}
