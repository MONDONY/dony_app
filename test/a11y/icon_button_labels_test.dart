import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un `IconButton` sans `tooltip` n'a aucun nom accessible : un lecteur
/// d'écran l'annonce « bouton », sans dire ce qu'il fait. Ce test balaie les
/// sources plutôt que le rendu, parce que le défaut est une omission à
/// l'écriture et qu'aucun test de widget ne le verrait à moins de monter tous
/// les écrans.
///
/// Le `tooltip` est le bon véhicule ici : il sert à la fois d'infobulle
/// visuelle et de nom accessible.
void main() {
  test('tout IconButton porte un nom accessible', () {
    // Exceptions justifiées : le nom est fourni autrement, par un `Semantics`
    // englobant. Toute nouvelle entrée doit dire pourquoi.
    const exemptions = <String, String>{
      'lib/features/matching/presentation/widgets/create_announcement/capacity_control.dart':
          'enveloppé dans Semantics(label: semanticLabel, button: true)',
    };

    final defauts = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (exemptions.containsKey(entity.path)) continue;

      final source = entity.readAsStringSync();
      for (final match in RegExp('IconButton\\(').allMatches(source)) {
        // Fenêtre bornée au prochain IconButton, pour ne pas attribuer à
        // celui-ci le tooltip du suivant. Large, car un IconButton commenté
        // peut pousser son `tooltip` loin de sa première ligne : à 600
        // caractères ce test signalait un bouton pourtant étiqueté.
        var fenetre = source.substring(
          match.start,
          (match.start + 1500).clamp(0, source.length),
        );
        final suivant = fenetre.indexOf('IconButton(', 5);
        if (suivant > 0) fenetre = fenetre.substring(0, suivant);

        if (!fenetre.contains('tooltip:')) {
          final ligne =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          defauts.add('${entity.path}:$ligne');
        }
      }
    }

    expect(
      defauts,
      isEmpty,
      reason:
          'IconButton sans tooltip, donc sans nom accessible :\n'
          '${defauts.join('\n')}\n\n'
          "Ajoutez `tooltip: '...'`, ou enveloppez d'un Semantics(label:) et "
          'déclarez le fichier dans les exemptions de ce test.',
    );
  });
}
