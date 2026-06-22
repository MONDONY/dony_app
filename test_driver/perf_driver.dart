// test_driver/perf_driver.dart
//
// Driver host-side : lit les données de timeline écrites par le test via
// binding.reportData et les sérialise en JSON dans build/perf/.
//
// Lancement :
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf/perf_scenarios_test.dart \
//     --dart-define-from-file=env.dev.json \
//     --profile
//
// Shape de reportData produite par traceAction(reportKey: scenario) :
//   binding.reportData[scenario] = <raw timeline Map> (traceEvents, etc.)
//
// Les entrées non-timeline (e.g. les maps RSS écrites par A10 sous la clé
// '<scenario>_rss') sont écrites telles quelles dans build/perf/<key>.json
// plutôt que d'être passées à Timeline.fromJson (qui crasherait sur l'absence
// de la clé 'traceEvents').
//
// Le driver calcule lui-même le résumé via Timeline + TimelineSummary
// (disponibles uniquement côté host via package:flutter_driver) et produit :
//   build/perf/<scenario>.timeline.json
//   build/perf/<scenario>.summary.json
// Pour les entrées non-timeline :
//   build/perf/<key>.json

import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (Map<String, dynamic>? data) async {
        if (data == null) {
          return;
        }
        final dir = Directory('build/perf')..createSync(recursive: true);
        for (final entry in data.entries) {
          final scenario = entry.key;
          final value = entry.value;
          // List entries (e.g. raw-<scenario> per-request network samples
          // written by dumpNetwork) are serialized as-is. waterfall.dart reads
          // build/perf/raw-<scenario>.json as a JSON List.
          if (value is List) {
            File('${dir.path}/$scenario.json')
                .writeAsStringSync(jsonEncode(value));
            continue;
          }
          if (value is! Map<String, dynamic>) {
            continue;
          }
          // Only summarize real timeline entries (they always have 'traceEvents').
          // Non-timeline maps (e.g. the '_rss' memory-delta map written by A10)
          // are written as plain JSON so the data is not lost.
          if (!value.containsKey('traceEvents')) {
            File('${dir.path}/$scenario.json')
                .writeAsStringSync(jsonEncode(value));
            continue;
          }
          // Write raw timeline.
          File('${dir.path}/$scenario.timeline.json')
              .writeAsStringSync(jsonEncode(value));
          // Compute summary on the host side where Timeline/TimelineSummary
          // are available. This produces average_frame_build_time_millis etc.
          final timeline = Timeline.fromJson(value);
          final summary = TimelineSummary.summarize(timeline);
          File('${dir.path}/$scenario.summary.json')
              .writeAsStringSync(jsonEncode(summary.summaryJson));
        }
      },
    );
