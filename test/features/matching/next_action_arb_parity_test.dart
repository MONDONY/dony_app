import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chaque clé nextAction* existe en FR et en EN, sans tiret cadratin', () {
    Map<String, dynamic> read(String f) =>
        jsonDecode(File('lib/l10n/$f').readAsStringSync())
            as Map<String, dynamic>;
    final fr = read('app_fr.arb');
    final en = read('app_en.arb');
    Set<String> keys(Map<String, dynamic> m) =>
        m.keys.where((k) => k.startsWith('nextAction')).toSet();
    expect(keys(fr), isNotEmpty);
    expect(keys(en), keys(fr));
    for (final k in keys(fr)) {
      expect(fr[k], isNot(contains('—')), reason: k);
      expect(en[k], isNot(contains('—')), reason: k);
      expect(fr[k], isNot(contains(RegExp(r'\b\d{6}\b'))), reason: k);
    }
  });
}
