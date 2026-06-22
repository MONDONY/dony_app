import 'package:dony/core/network/network_metrics_collector.dart';
import 'package:flutter_test/flutter_test.dart';

RequestSample s(String path, {int status = 200, int dur = 100, int ts = 0}) =>
    RequestSample(method: 'GET', path: path, status: status, durationMs: dur,
        reqBytes: 0, respBytes: 500, startTsMs: ts);

void main() {
  test('normalizePath remplace les UUID/ids par :id', () {
    expect(NetworkMetricsCollector.normalizePath(
        '/announcements/3fa85f64-5717-4562-b3fc-2c963f66afa6/trip'),
        '/announcements/:id/trip');
    expect(NetworkMetricsCollector.normalizePath('/favorites/trip/42'),
        '/favorites/trip/:id');
  });

  test('aggregate calcule count, p50, p95, max, errorRate par endpoint', () {
    final c = NetworkMetricsCollector();
    for (final d in [100, 200, 300, 400, 500]) {
      c.record(s('/x', dur: d));
    }
    c.record(s('/x', status: 500, dur: 600));
    final stats = c.aggregate().firstWhere((e) => e.key == 'GET /x');
    expect(stats.count, 6);
    expect(stats.maxMs, 600);
    expect(stats.p95 >= 500, isTrue);
    expect(stats.errorRate, closeTo(1 / 6, 0.001));
  });

  test('burst détecté si >=3 appels du meme endpoint en <500ms', () {
    final c = NetworkMetricsCollector();
    c..record(s('/y', ts: 0))..record(s('/y', ts: 100))..record(s('/y', ts: 300));
    expect(c.aggregate().firstWhere((e) => e.key == 'GET /y').burst, isTrue);
  });

  test('pas de burst si appels espacés', () {
    final c = NetworkMetricsCollector();
    c..record(s('/z', ts: 0))..record(s('/z', ts: 800))..record(s('/z', ts: 1700));
    expect(c.aggregate().firstWhere((e) => e.key == 'GET /z').burst, isFalse);
  });
}
