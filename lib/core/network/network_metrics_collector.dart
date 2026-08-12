class RequestSample {
  final String method, path;
  final int status, durationMs, reqBytes, respBytes, startTsMs;
  const RequestSample({
    required this.method,
    required this.path,
    required this.status,
    required this.durationMs,
    required this.reqBytes,
    required this.respBytes,
    required this.startTsMs,
  });
}

class EndpointStats {
  final String key;
  final int count, p50, p95, maxMs, totalBytes;
  final double errorRate;
  final bool burst;
  const EndpointStats({
    required this.key,
    required this.count,
    required this.p50,
    required this.p95,
    required this.maxMs,
    required this.totalBytes,
    required this.errorRate,
    required this.burst,
  });
  Map<String, dynamic> toJson() => {
    'key': key,
    'count': count,
    'p50': p50,
    'p95': p95,
    'maxMs': maxMs,
    'totalBytes': totalBytes,
    'errorRate': errorRate,
    'burst': burst,
  };
}

class NetworkMetricsCollector {
  final List<RequestSample> _samples = [];
  static const _burstWindowMs = 500;
  static const _burstCount = 3;

  void record(RequestSample s) => _samples.add(s);
  void clear() => _samples.clear();

  static String normalizePath(String path) => path
      .replaceAll(RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}'), ':id')
      .replaceAll(RegExp(r'/\d+'), '/:id');

  static int _pct(List<int> sorted, double p) {
    if (sorted.isEmpty) {
      return 0;
    }
    final idx = ((sorted.length - 1) * p).round();
    return sorted[idx];
  }

  List<EndpointStats> aggregate() {
    final byKey = <String, List<RequestSample>>{};
    for (final s in _samples) {
      final key = '${s.method} ${normalizePath(s.path)}';
      byKey.putIfAbsent(key, () => []).add(s);
    }
    final out = <EndpointStats>[];
    byKey.forEach((key, list) {
      final durs = list.map((e) => e.durationMs).toList()..sort();
      final errs = list.where((e) => e.status >= 400).length;
      // burst: une fenêtre glissante de _burstWindowMs contenant >= _burstCount départs
      final ts = list.map((e) => e.startTsMs).toList()..sort();
      var burst = false;
      for (var i = 0; i + _burstCount - 1 < ts.length; i++) {
        if (ts[i + _burstCount - 1] - ts[i] <= _burstWindowMs) {
          burst = true;
          break;
        }
      }
      out.add(
        EndpointStats(
          key: key,
          count: list.length,
          p50: _pct(durs, 0.50),
          p95: _pct(durs, 0.95),
          maxMs: durs.isEmpty ? 0 : durs.last,
          totalBytes: list.fold(0, (a, e) => a + e.reqBytes + e.respBytes),
          errorRate: list.isEmpty ? 0 : errs / list.length,
          burst: burst,
        ),
      );
    });
    return out;
  }

  Map<String, dynamic> toJson() => {
    'endpoints': aggregate().map((e) => e.toJson()).toList(),
  };

  List<Map<String, dynamic>> rawSamplesJson() => _samples
      .map(
        (s) => {
          'path': normalizePath(s.path),
          'startTsMs': s.startTsMs,
          'durationMs': s.durationMs,
        },
      )
      .toList();
}
