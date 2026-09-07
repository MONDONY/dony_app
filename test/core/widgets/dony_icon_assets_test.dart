import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chaque icône SVG référencée par son nom dans `lib/` doit exister dans
/// `assets/icons/`. Un nom erroné (`help-circle` au lieu de `circle-help`)
/// ne se voit ni à l'analyse ni à la compilation : il plante l'app à
/// l'affichage, en production, chez l'utilisateur qui ouvre l'écran.
void main() {
  test('toutes les icônes SVG référencées existent dans assets/icons', () {
    final patterns = [
      RegExp(r"DonyIcon\(\s*'([a-z0-9-]+)'"),
      RegExp(r"iconAsset:\s*'([a-z0-9-]+)'"),
      RegExp(r"iconName:\s*'([a-z0-9-]+)'"),
    ];

    final references = <String, Set<String>>{};
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(source)) {
          references.putIfAbsent(match.group(1)!, () => {}).add(file.path);
        }
      }
    }

    expect(
      references,
      isNotEmpty,
      reason: 'aucune icône trouvée : regex cassée',
    );

    final missing = <String>[
      for (final entry in references.entries)
        if (!File('assets/icons/${entry.key}.svg').existsSync())
          '${entry.key} (${entry.value.join(', ')})',
    ];

    expect(missing, isEmpty, reason: 'Icônes SVG manquantes : $missing');
  });
}
