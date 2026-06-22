import 'dart:io';

Future<void> main() async {
  const templatePath = 'reports/PRODUCTION-READINESS.template.md';
  const outputPath = 'reports/PRODUCTION-READINESS.md';
  const perfReportPath = 'reports/perf-report.md';
  const networkReportPath = 'reports/network-report.md';
  const waterfallReportPath = 'reports/waterfall-report.md';

  // Read template
  final templateFile = File(templatePath);
  if (!templateFile.existsSync()) {
    stderr.writeln('Error: Template not found at $templatePath');
    exit(1);
  }

  var content = await templateFile.readAsString();

  // Replace Perf section
  content = _replaceSection(
    content,
    'SECTION_PERF_START',
    'SECTION_PERF_END',
    await _readReportIfExists(perfReportPath),
  );

  // Replace Network section
  content = _replaceSection(
    content,
    'SECTION_NETWORK_START',
    'SECTION_NETWORK_END',
    await _readReportIfExists(networkReportPath),
  );

  // Replace Waterfall section
  content = _replaceSection(
    content,
    'SECTION_WATERFALL_START',
    'SECTION_WATERFALL_END',
    await _readReportIfExists(waterfallReportPath),
  );

  // Write consolidated report
  final outputFile = File(outputPath);
  await outputFile.writeAsString(content);

  final perfExists = File(perfReportPath).existsSync();
  final networkExists = File(networkReportPath).existsSync();
  final waterfallExists = File(waterfallReportPath).existsSync();

  final status = <String>[];
  status.add(perfExists ? '✅ perf' : '⏸ perf');
  status.add(networkExists ? '✅ network' : '⏸ network');
  status.add(waterfallExists ? '✅ waterfall' : '⏸ waterfall');

  stdout.writeln('Assembly complete: $outputPath (${status.join(', ')})');
}

String _replaceSection(
  String content,
  String startMarker,
  String endMarker,
  String replacement,
) {
  final startTag = '<!-- $startMarker -->';
  final endTag = '<!-- $endMarker -->';

  final startIdx = content.indexOf(startTag);
  final endIdx = content.indexOf(endTag);

  if (startIdx == -1 || endIdx == -1) {
    return content;
  }

  final before = content.substring(0, startIdx + startTag.length);
  final after = content.substring(endIdx);

  return '$before\n$replacement\n$after';
}

Future<String> _readReportIfExists(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    return '_(non généré — lancer scripts/perf.sh sur un device)_';
  }

  try {
    return await file.readAsString();
  } catch (e) {
    return '_(erreur lors de la lecture : $e)_';
  }
}
