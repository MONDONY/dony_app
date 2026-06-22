import 'package:test/test.dart';

// Import the function under test directly via relative path.
// dart test resolves tool/ relative to the package root.
import '../../tool/waterfall.dart';

void main() {
  group('detectWaterfalls', () {
    test('returns finding for 3 strictly sequential requests', () {
      final samples = [
        {'path': '/api/trips', 'startTsMs': 0, 'durationMs': 100},
        {'path': '/api/bids', 'startTsMs': 100, 'durationMs': 80},
        {'path': '/api/payments', 'startTsMs': 180, 'durationMs': 120},
      ];

      final findings = detectWaterfalls(samples);

      expect(findings, isNotEmpty);
      expect(findings.first, contains('WATERFALL'));
      expect(findings.first, contains('3 sequential requests'));
      expect(findings.first, contains('/api/trips'));
      expect(findings.first, contains('/api/bids'));
      expect(findings.first, contains('/api/payments'));
    });

    test('returns finding for chain of 4 sequential requests', () {
      final samples = [
        {'path': '/a', 'startTsMs': 0, 'durationMs': 50},
        {'path': '/b', 'startTsMs': 50, 'durationMs': 50},
        {'path': '/c', 'startTsMs': 100, 'durationMs': 50},
        {'path': '/d', 'startTsMs': 150, 'durationMs': 50},
      ];

      final findings = detectWaterfalls(samples);

      expect(findings, isNotEmpty);
      expect(findings.first, contains('4 sequential requests'));
    });

    test('returns empty for 3 parallel/overlapping requests', () {
      // All three start at the same time → overlapping, not sequential.
      final samples = [
        {'path': '/api/trips', 'startTsMs': 0, 'durationMs': 200},
        {'path': '/api/bids', 'startTsMs': 0, 'durationMs': 150},
        {'path': '/api/payments', 'startTsMs': 0, 'durationMs': 180},
      ];

      final findings = detectWaterfalls(samples);

      expect(findings, isEmpty);
    });

    test('returns empty for interleaved requests (partially overlapping)', () {
      // /b starts before /a ends → not strictly sequential.
      final samples = [
        {'path': '/a', 'startTsMs': 0, 'durationMs': 100},
        {'path': '/b', 'startTsMs': 50, 'durationMs': 100},
        {'path': '/c', 'startTsMs': 100, 'durationMs': 100},
      ];

      final findings = detectWaterfalls(samples);

      // /a ends at 100, /b starts at 50 → breaks strict sequence at start
      // /b ends at 150, /c starts at 100 → also overlapping
      expect(findings, isEmpty);
    });

    test('returns empty for fewer than 3 samples', () {
      final samples = [
        {'path': '/a', 'startTsMs': 0, 'durationMs': 100},
        {'path': '/b', 'startTsMs': 100, 'durationMs': 100},
      ];

      final findings = detectWaterfalls(samples);

      expect(findings, isEmpty);
    });

    test('returns empty for empty list', () {
      final findings = detectWaterfalls([]);
      expect(findings, isEmpty);
    });

    test('handles unsorted input (sorts by startTsMs)', () {
      // Provide in reverse order.
      final samples = [
        {'path': '/c', 'startTsMs': 200, 'durationMs': 50},
        {'path': '/a', 'startTsMs': 0, 'durationMs': 100},
        {'path': '/b', 'startTsMs': 100, 'durationMs': 100},
      ];

      final findings = detectWaterfalls(samples);

      expect(findings, isNotEmpty);
      expect(findings.first, contains('3 sequential requests'));
    });

    test('exactly 3 sequential is a waterfall boundary', () {
      final samples = [
        {'path': '/x', 'startTsMs': 0, 'durationMs': 10},
        {'path': '/y', 'startTsMs': 10, 'durationMs': 10},
        {'path': '/z', 'startTsMs': 20, 'durationMs': 10},
      ];

      final findings = detectWaterfalls(samples);

      expect(findings.length, equals(1));
    });

    test('total duration is correct in finding', () {
      // Chain: 0..100, 100..180, 180..300 → total = 300ms
      final samples = [
        {'path': '/a', 'startTsMs': 0, 'durationMs': 100},
        {'path': '/b', 'startTsMs': 100, 'durationMs': 80},
        {'path': '/c', 'startTsMs': 180, 'durationMs': 120},
      ];

      final findings = detectWaterfalls(samples);

      expect(findings.first, contains('300ms'));
    });

    test('détecte une séquence avec léger chevauchement (< tolérance 15ms)', () {
      // /b démarre 8ms avant la fin de /a, /c 7ms avant la fin de /b : des
      // overlaps sous la tolérance de 15ms → toujours considérés séquentiels
      // (les timers réels ne sont pas précis à la milliseconde).
      final samples = [
        {'path': '/a', 'startTsMs': 0, 'durationMs': 100}, // fin 100
        {'path': '/b', 'startTsMs': 92, 'durationMs': 100}, // overlap 8ms, fin 192
        {'path': '/c', 'startTsMs': 185, 'durationMs': 50}, // overlap 7ms
      ];

      final findings = detectWaterfalls(samples);

      expect(findings, isNotEmpty);
      expect(findings.first, contains('3 sequential requests'));
    });
  });
}
