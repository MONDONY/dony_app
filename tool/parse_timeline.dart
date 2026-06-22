// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const _avgGood = 8.0, _avgWarn = 12.0, _worstGood = 16.67, _worstWarn = 33.0;
const _jankGood = 0.01, _jankWarn = 0.05;

String verdictFor(Map<String, dynamic> s) {
  double d(String k) => (s[k] as num?)?.toDouble() ?? 0;
  final frames = (s['frame_count'] as num?)?.toInt() ?? 1;
  final jankBuild = (s['missed_frame_build_budget_count'] as num? ?? 0) / frames;
  final jankRaster = (s['missed_frame_rasterizer_budget_count'] as num? ?? 0) / frames;
  bool fail(double v, double warn) => v > warn;
  bool warnL(double v, double good) => v > good;
  if (fail(d('average_frame_build_time_millis'), _avgWarn) ||
      fail(d('worst_frame_build_time_millis'), _worstWarn) ||
      jankBuild > _jankWarn ||
      jankRaster > _jankWarn ||
      fail(d('average_frame_rasterizer_time_millis'), _avgWarn)) {
    return 'FAIL';
  }
  if (warnL(d('average_frame_build_time_millis'), _avgGood) ||
      warnL(d('worst_frame_build_time_millis'), _worstGood) ||
      jankBuild > _jankGood ||
      jankRaster > _jankGood ||
      warnL(d('average_frame_rasterizer_time_millis'), _avgGood)) {
    return 'WARN';
  }
  return 'PASS';
}

String renderReport(Map<String, Map<String, dynamic>> byScenario) {
  final b = StringBuffer('# Perf report (FPS / jank)\n\n')
    ..writeln('| Scénario | avg build | worst build | %jank | avg raster | Verdict |')
    ..writeln('|---|---|---|---|---|---|');
  byScenario.forEach((name, s) {
    final frames = (s['frame_count'] as num?)?.toInt() ?? 1;
    final jank = ((s['missed_frame_build_budget_count'] as num? ?? 0) / frames * 100).toStringAsFixed(1);
    b.writeln('| $name | ${s['average_frame_build_time_millis']} | '
        '${s['worst_frame_build_time_millis']} | $jank% | '
        '${s['average_frame_rasterizer_time_millis']} | ${verdictFor(s)} |');
  });
  b.writeln('\n> ⚠️ Émulateur/Simulateur : seul FAIL est fiable. Reconfirmer ✅/⚠️ sur device réel.');
  return b.toString();
}

void main(List<String> args) {
  final dir = Directory('build/perf');
  final byScenario = <String, Map<String, dynamic>>{};
  if (dir.existsSync()) {
    for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.summary.json'))) {
      final name = f.uri.pathSegments.last.replaceAll('.summary.json', '');
      byScenario[name] = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    }
  }
  Directory('reports').createSync(recursive: true);
  File('reports/perf-report.md').writeAsStringSync(renderReport(byScenario));
  stdout.writeln('wrote reports/perf-report.md (${byScenario.length} scénarios)');
}
