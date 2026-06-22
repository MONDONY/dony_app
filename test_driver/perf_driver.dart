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
// Pour chaque scénario la shape de reportData est :
//   { '<scenario>': { 'timeline': Map<String,dynamic>, 'summary': Map<String,dynamic> } }
// Le test y écrit le résultat via binding.traceAction(reportKey: scenario) ;
// le driver lit cette map et produit :
//   build/perf/<scenario>.timeline.json
//   build/perf/<scenario>.summary.json

import 'dart:convert';
import 'dart:io';
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
          if (value is Map) {
            final m = Map<String, dynamic>.from(value);
            final timeline = m['timeline'];
            final summary = m['summary'];
            if (timeline != null) {
              File('${dir.path}/$scenario.timeline.json')
                  .writeAsStringSync(jsonEncode(timeline));
            }
            if (summary != null) {
              File('${dir.path}/$scenario.summary.json')
                  .writeAsStringSync(jsonEncode(summary));
            }
          }
        }
      },
    );
