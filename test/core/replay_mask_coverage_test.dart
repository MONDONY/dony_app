import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou RGPD : les textes sont visibles dans le replay de session, donc
/// tout champ de saisie doit être enveloppé dans `DonyReplayMask`.
void main() {
  test('aucun TextField ou TextFormField brut sans DonyReplayMask', () {
    final field = RegExp(
      r'(?<![A-Za-z0-9_.])(?:const\s+)?'
      r'(TextFormField|TextField|CupertinoTextField)\(',
    );
    final wrapped = RegExp(r'DonyReplayMask\(\s*child:\s*$');
    // Le champ du design system est masqué dans son propre fichier.
    const allowed = {
      'lib/core/design/widgets/dony_text_field.dart',
      'lib/core/design/widgets/dony_replay_mask.dart',
    };
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll('\\', '/');
      if (allowed.contains(path) || path.contains('/generated/')) continue;
      final src = f.readAsStringSync();
      for (final m in field.allMatches(src)) {
        final lineStart = src.lastIndexOf('\n', m.start) + 1;
        if (src.substring(lineStart, m.start).trimLeft().startsWith('//')) {
          continue;
        }
        final before = src.substring(
          (m.start - 400).clamp(0, src.length),
          m.start,
        );
        if (wrapped.hasMatch(before)) continue;
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('$path:$line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Champ de saisie non masqué dans le replay : enveloppez-le dans '
          'DonyReplayMask(child: …).',
    );
  });
}
