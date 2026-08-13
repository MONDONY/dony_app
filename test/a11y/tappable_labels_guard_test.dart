import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Une zone tappable qui ne contient qu'une icône n'a aucun nom accessible :
/// un lecteur d'écran l'annonce « bouton », sans dire ce qu'elle fait. Ce test
/// balaie les sources, parce que le défaut est une omission à l'écriture et
/// qu'aucun test de widget ne le verrait sans monter tous les écrans.
///
/// Une zone tappable qui contient du texte est saine : le texte lui sert de
/// nom. Le balayage ne signale donc que celles qui n'en ont pas.
void main() {
  /// Position de la parenthèse fermant celle ouverte à [start].
  int fermeture(String source, int start) {
    var profondeur = 0;
    var ouvert = false;
    for (var i = start; i < source.length && i < start + 20000; i++) {
      final c = source[i];
      if (c == '(') {
        profondeur++;
        ouvert = true;
      } else if (c == ')') {
        profondeur--;
        if (ouvert && profondeur == 0) return i;
      }
    }
    return (start + 20000).clamp(0, source.length);
  }

  test('toute zone tappable à icône seule porte un nom accessible', () {
    // Exceptions justifiées : le nom est fourni par un Semantics englobant que
    // le balayage ne voit pas, parce qu'il est trop haut au-dessus de la zone.
    // Toute nouvelle entrée doit dire pourquoi.
    const exemptions = <String, String>{
      'lib/features/ratings/presentation/widgets/star_selector.dart':
          'Semantics(label: Noter N sur 5) englobant, hors fenêtre de lecture',
    };

    final defauts = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (exemptions.containsKey(entity.path)) continue;

      final source = entity.readAsStringSync();
      for (final mot in ['GestureDetector(', 'InkWell(']) {
        for (final m in RegExp(RegExp.escape(mot)).allMatches(source)) {
          final corps = source.substring(
            m.start,
            fermeture(source, m.start + mot.length - 1),
          );

          if (!corps.contains('onTap')) continue;
          // Sans icône, ce n'est pas le motif visé.
          if (!corps.contains('DonyIcon(') && !corps.contains('Icon(')) {
            continue;
          }
          // Du texte dans le sous-arbre fournit déjà le nom.
          if (RegExp("Text\\(|Text\\.rich|label:\\s*'").hasMatch(corps)) {
            continue;
          }
          // Nom posé à l'intérieur, ou juste au-dessus.
          if (corps.contains('Semantics(') || corps.contains('tooltip:')) {
            continue;
          }
          final avant = source.substring(0, m.start).split('\n');
          final contexte = avant.sublist(
            avant.length < 10 ? 0 : avant.length - 10,
          );
          if (contexte.any(
            (l) => l.contains('Semantics(') || l.contains('Tooltip('),
          )) {
            continue;
          }

          final ligne =
              '\n'.allMatches(source.substring(0, m.start)).length + 1;
          defauts.add('${entity.path}:$ligne');
        }
      }
    }

    expect(
      defauts,
      isEmpty,
      reason:
          'zones tappables à icône seule, sans nom accessible :\n'
          '${defauts.join('\n')}\n\n'
          "Enveloppez d'un Semantics(button: true, label: '...'), ou "
          'déclarez le fichier dans les exemptions de ce test.',
    );
  });
}
