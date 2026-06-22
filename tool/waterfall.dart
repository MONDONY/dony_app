// ignore_for_file: avoid_print
// Waterfall detection for raw network samples.
//
// A "waterfall" is detected when ≥3 requests are STRICTLY SEQUENTIAL:
// each request starts only after the previous one has fully completed.
// i.e. samples[i+1].startTsMs >= samples[i].startTsMs + samples[i].durationMs
//
// Raw sample emission is wired: the dumpNetwork helper emits both aggregated
// metrics (NetworkMetricsCollector.toJson) and raw per-request samples written
// to build/perf/raw-<scenario>.json, which this tool reads.
library;

import 'dart:convert';
import 'dart:io';

/// Detects sequential (waterfall) chains in a list of raw request samples.
///
/// Each [sample] must contain:
///   - `path`       (String)  — request path or URL
///   - `startTsMs`  (int)     — start timestamp in milliseconds
///   - `durationMs` (int)     — duration in milliseconds
///
/// Returns a list of human-readable finding strings, one per detected chain.
/// Returns an empty list when no sequential chain of ≥3 requests is found.
List<String> detectWaterfalls(List<Map<String, dynamic>> samples) {
  if (samples.length < 3) {
    return [];
  }

  // Sort by start timestamp ascending.
  final sorted = List<Map<String, dynamic>>.from(samples)
    ..sort((a, b) => (a['startTsMs'] as int).compareTo(b['startTsMs'] as int));

  final findings = <String>[];

  // Sliding window: try to extend a sequential chain starting at each index.
  int i = 0;
  while (i < sorted.length) {
    final chain = <Map<String, dynamic>>[sorted[i]];

    int j = i + 1;
    while (j < sorted.length) {
      final prev = chain.last;
      final prevEnd = (prev['startTsMs'] as int) + (prev['durationMs'] as int);
      final nextStart = sorted[j]['startTsMs'] as int;
      if (nextStart >= prevEnd) {
        chain.add(sorted[j]);
        j++;
      } else {
        break;
      }
    }

    if (chain.length >= 3) {
      final paths = chain.map((s) => s['path'] as String).join(' → ');
      final totalMs = (chain.last['startTsMs'] as int) +
          (chain.last['durationMs'] as int) -
          (chain.first['startTsMs'] as int);
      findings.add(
        'WATERFALL: ${chain.length} sequential requests (total ${totalMs}ms): $paths',
      );
      // Advance past this chain.
      i += chain.length;
    } else {
      i++;
    }
  }

  return findings;
}

void main(List<String> args) {
  final dir = Directory('build/perf');
  if (!dir.existsSync()) {
    print('No build/perf directory found. Run perf.sh first.');
    return;
  }

  final rawFiles = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.uri.pathSegments.last.startsWith('raw-') &&
          f.path.endsWith('.json'))
      .toList();

  if (rawFiles.isEmpty) {
    print(
      'No raw-<scenario>.json files found in build/perf/.\n'
      'NOTE: Raw-sample dumping is a follow-up task — the current dumpNetwork\n'
      'writes aggregated metrics only. To enable waterfall detection, extend\n'
      'dumpNetwork to also write build/perf/raw-<scenario>.json with per-request\n'
      'timestamps: [{path, startTsMs, durationMs}, ...].',
    );
    return;
  }

  final allFindings = <String>[];
  for (final f in rawFiles) {
    final scenario = f.uri.pathSegments.last
        .replaceFirst('raw-', '')
        .replaceAll('.json', '');
    final samples = (jsonDecode(f.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    final findings = detectWaterfalls(samples);
    if (findings.isEmpty) {
      print('[$scenario] No waterfall detected (${samples.length} samples).');
    } else {
      for (final finding in findings) {
        print('[$scenario] $finding');
        allFindings.add('[$scenario] $finding');
      }
    }
  }

  // Write waterfall findings to reports/waterfall-report.md.
  final reportsDir = Directory('reports')..createSync(recursive: true);
  final reportFile = File('${reportsDir.path}/waterfall-report.md');
  final buffer = StringBuffer();
  buffer.writeln('# Waterfall Report');
  buffer.writeln();
  buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buffer.writeln();
  if (allFindings.isEmpty) {
    buffer.writeln('No waterfall chains detected across ${rawFiles.length} scenario(s).');
  } else {
    buffer.writeln('## Waterfalls');
    buffer.writeln();
    for (final finding in allFindings) {
      buffer.writeln('- $finding');
    }
    buffer.writeln();
    buffer.writeln('**${allFindings.length} waterfall finding(s) found.**');
  }
  reportFile.writeAsStringSync(buffer.toString());
  print('\nReport written to ${reportFile.path}');

  if (allFindings.isNotEmpty) {
    print('${allFindings.length} waterfall finding(s) found.');
    exitCode = 1;
  }
}
