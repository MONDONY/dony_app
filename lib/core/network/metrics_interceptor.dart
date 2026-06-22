import 'package:dio/dio.dart';
import 'package:dony/core/network/network_metrics_collector.dart';

class MetricsInterceptor extends Interceptor {
  MetricsInterceptor(this.collector);
  final NetworkMetricsCollector collector;
  static final NetworkMetricsCollector globalCollector = NetworkMetricsCollector();

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_perf_start'] = _nowMs();
    handler.next(options);
  }

  void _record(RequestOptions o, int? status, dynamic data) {
    final start = (o.extra['_perf_start'] as int?) ?? _nowMs();
    final respBytes = data is String ? data.length : (data?.toString().length ?? 0);
    collector.record(RequestSample(
      method: o.method, path: o.path, status: status ?? 0,
      durationMs: _nowMs() - start,
      reqBytes: o.data is String ? (o.data as String).length : 0,
      respBytes: respBytes, startTsMs: start,
    ));
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _record(response.requestOptions, response.statusCode, response.data);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(err.requestOptions, err.response?.statusCode ?? 0, err.response?.data);
    handler.next(err);
  }
}
