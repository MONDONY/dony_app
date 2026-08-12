import 'package:test/test.dart';

// Import the public assemble() function from the assembler tool.
// dart test resolves tool/ relative to the package root.
import '../../tool/build_readiness_report.dart';

/// Minimal template with one marker pair.
String _template({String section = 'SECTION_PERF'}) => '''
# Report
<!-- ${section}_START -->
<!-- ${section}_END -->
''';

void main() {
  group('assemble()', () {
    test('replaces a present marker with the section content', () {
      const template = '''
# Report
<!-- SECTION_PERF_START -->
<!-- SECTION_PERF_END -->
''';
      const perfContent = '## Perf\nAll good.';

      final result = assemble(template, {'SECTION_PERF': perfContent});

      expect(result, contains(perfContent));
      expect(result, contains('<!-- SECTION_PERF_START -->'));
      expect(result, contains('<!-- SECTION_PERF_END -->'));
    });

    test('inserts placeholder when section value is null', () {
      final template = _template();

      final result = assemble(template, {'SECTION_PERF': null});

      expect(result, contains('non généré'));
      // Original markers still present in output (before / after).
      expect(result, contains('<!-- SECTION_PERF_START -->'));
    });

    test('inserts placeholder when section value is empty string', () {
      final template = _template();

      final result = assemble(template, {'SECTION_PERF': ''});

      expect(result, contains('non généré'));
    });

    test('leaves template unchanged when marker is absent', () {
      const template = '# Report\nNo markers here.\n';

      final result = assemble(template, {'SECTION_PERF': 'some content'});

      // No marker → no replacement, template returned unchanged.
      expect(result, equals(template));
    });

    test('replaces multiple sections independently', () {
      const template = '''
# Report
<!-- SECTION_PERF_START -->
<!-- SECTION_PERF_END -->
<!-- SECTION_NETWORK_START -->
<!-- SECTION_NETWORK_END -->
''';
      const perfContent = '## Perf section';
      const networkContent = '## Network section';

      final result = assemble(template, {
        'SECTION_PERF': perfContent,
        'SECTION_NETWORK': networkContent,
      });

      expect(result, contains(perfContent));
      expect(result, contains(networkContent));
    });

    test('missing sub-report uses placeholder, present one is inlined', () {
      const template = '''
<!-- SECTION_PERF_START -->
<!-- SECTION_PERF_END -->
<!-- SECTION_NETWORK_START -->
<!-- SECTION_NETWORK_END -->
''';
      final result = assemble(template, {
        'SECTION_PERF': 'FPS: OK',
        'SECTION_NETWORK': null,
      });

      expect(result, contains('FPS: OK'));
      expect(result, contains('non généré'));
    });
  });
}
