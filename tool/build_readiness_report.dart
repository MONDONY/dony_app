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

  final template = await templateFile.readAsString();

  final sections = <String, String?>{
    'SECTION_PERF': await _readReportIfExists(perfReportPath),
    'SECTION_NETWORK': await _readReportIfExists(networkReportPath),
    'SECTION_WATERFALL': await _readReportIfExists(waterfallReportPath),
  };

  final content = assemble(template, sections);

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

/// Replaces each marker pair in [template] with the corresponding value from
/// [sections]. Keys in [sections] are bare section names (e.g. 'SECTION_PERF');
/// the function looks for `<!-- KEY_START -->` / `<!-- KEY_END -->` markers.
///
/// If a section value is null or empty, the placeholder
/// '_(non généré — lancer scripts/perf.sh sur un device)_' is used instead.
///
/// Returns the assembled string. The template is not mutated.
String assemble(String template, Map<String, String?> sections) {
  var content = template;
  for (final entry in sections.entries) {
    final replacement = (entry.value == null || entry.value!.isEmpty)
        ? '_(non généré — lancer scripts/perf.sh sur un device)_'
        : entry.value!;
    content = _replaceSection(
      content,
      '${entry.key}_START',
      '${entry.key}_END',
      replacement,
    );
  }
  return content;
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

Future<String?> _readReportIfExists(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }

  try {
    return await file.readAsString();
  } catch (e) {
    return '_(erreur lors de la lecture : $e)_';
  }
}
