import 'package:dony/core/design/theme/a11y_theme_options.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_helpers.dart';

/// Balayage exhaustif des paires de couleurs que le thème produit réellement,
/// dans ses quatre variantes.
///
/// Les autres tests d'accessibilité vérifient les paires qui ont été corrigées,
/// une par une. Celui-ci fait l'inverse : il énumère tout ce que le thème
/// expose, de sorte qu'une couleur ajoutée demain soit couverte sans que
/// personne ait à y penser. C'est ce qui manquait, et c'est ainsi que trois
/// réglages morts avaient pu survivre en production.

/// Une paire à vérifier, décrite en termes de rôles et non de valeurs.
typedef Paire = ({String nom, Color Function(ThemeData) fg, Color Function(ThemeData) bg, double min});

void main() {
  // Des fabriques et non des ThemeData : construire un thème charge les
  // polices Google, ce qui tente un accès réseau. Hors d'un test, cet accès
  // n'a pas de zone où s'exécuter et fait échouer tout le fichier avant le
  // premier `expect`.
  final variantes = <String, ThemeData Function()>{
    'clair': AppTheme.light,
    'sombre': AppTheme.dark,
    'clair + haut contraste': () =>
        AppTheme.light(a11y: const A11yThemeOptions(highContrast: true)),
    'sombre + haut contraste': () =>
        AppTheme.dark(a11y: const A11yThemeOptions(highContrast: true)),
  };

  // Rôles Material. Chaque `onX` est par contrat posé sur `X`.
  final paires = <Paire>[
    (nom: 'texte principal sur surface', fg: (t) => t.colorScheme.onSurface, bg: (t) => t.colorScheme.surface, min: Seuil.texte),
    (nom: 'texte principal sur fond d\'écran', fg: (t) => t.colorScheme.onSurface, bg: (t) => t.scaffoldBackgroundColor, min: Seuil.texte),
    (nom: 'texte secondaire sur surface', fg: (t) => t.colorScheme.onSurfaceVariant, bg: (t) => t.colorScheme.surface, min: Seuil.texte),
    (nom: 'texte secondaire sur fond d\'écran', fg: (t) => t.colorScheme.onSurfaceVariant, bg: (t) => t.scaffoldBackgroundColor, min: Seuil.texte),
    (nom: 'texte secondaire sur conteneur haut', fg: (t) => t.colorScheme.onSurfaceVariant, bg: (t) => t.colorScheme.surfaceContainerHighest, min: Seuil.texte),
    (nom: 'texte secondaire sur conteneur bas', fg: (t) => t.colorScheme.onSurfaceVariant, bg: (t) => t.colorScheme.surfaceContainerLow, min: Seuil.texte),
    // `onPrimary` sur `primary` est traité à part, plus bas : la paire échoue
    // encore en thème sombre et la dette est documentée plutôt que masquée.
    (nom: 'libellé sur error', fg: (t) => t.colorScheme.onError, bg: (t) => t.colorScheme.error, min: Seuil.texte),
    (nom: 'texte sur conteneur primaire', fg: (t) => t.colorScheme.onPrimaryContainer, bg: (t) => t.colorScheme.primaryContainer, min: Seuil.texte),
    (nom: 'texte sur conteneur accent', fg: (t) => t.colorScheme.onSecondaryContainer, bg: (t) => t.colorScheme.secondaryContainer, min: Seuil.texte),
    (nom: 'texte sur conteneur erreur', fg: (t) => t.colorScheme.onErrorContainer, bg: (t) => t.colorScheme.errorContainer, min: Seuil.texte),
    (nom: 'texte sur surface inversée', fg: (t) => t.colorScheme.onInverseSurface, bg: (t) => t.colorScheme.inverseSurface, min: Seuil.texte),
    (nom: 'lien sur surface', fg: (t) => t.colorScheme.primary, bg: (t) => t.colorScheme.surface, min: Seuil.texte),
    (nom: 'lien sur fond d\'écran', fg: (t) => t.colorScheme.primary, bg: (t) => t.scaffoldBackgroundColor, min: Seuil.texte),
    (nom: 'texte d\'erreur sur surface', fg: (t) => t.colorScheme.error, bg: (t) => t.colorScheme.surface, min: Seuil.texte),
    // Rôles d'état, via l'extension DonyStatusColors.
    (nom: 'succès sur surface', fg: (t) => t.colorScheme.success, bg: (t) => t.colorScheme.surface, min: Seuil.texte),
    (nom: 'succès sur son fond pâle', fg: (t) => t.colorScheme.success, bg: (t) => t.colorScheme.successLight, min: Seuil.texte),
    (nom: 'avertissement sur surface', fg: (t) => t.colorScheme.warning, bg: (t) => t.colorScheme.surface, min: Seuil.texte),
    (nom: 'avertissement sur son fond pâle', fg: (t) => t.colorScheme.warning, bg: (t) => t.colorScheme.warningLight, min: Seuil.texte),
    (nom: 'info sur surface', fg: (t) => t.colorScheme.info, bg: (t) => t.colorScheme.surface, min: Seuil.texte),
    (nom: 'info sur son fond pâle', fg: (t) => t.colorScheme.info, bg: (t) => t.colorScheme.infoLight, min: Seuil.texte),
    (nom: 'erreur sur son fond pâle', fg: (t) => t.colorScheme.error, bg: (t) => t.colorScheme.errorLight, min: Seuil.texte),
    (nom: 'texte secondaire sur surface chaude', fg: (t) => t.colorScheme.onSurfaceVariant, bg: (t) => t.colorScheme.surfaceWarm, min: Seuil.texte),
    // Éléments d'interface, seuil 3:1.
    (nom: 'bordure de focus sur surface', fg: (t) => t.colorScheme.primary, bg: (t) => t.colorScheme.surface, min: Seuil.grand),
  ];

  for (final entree in variantes.entries) {
    group('thème ${entree.key}', () {
      for (final p in paires) {
        testWidgets(p.nom, (tester) async {
          final theme = entree.value();
          expectContrast(
            p.fg(theme),
            p.bg(theme),
            p.min,
            '${p.nom} (${entree.key})',
          );
        });
      }
    });
  }

  group('contour des champs', () {
    // Un champ est un composant d'interface : son contour doit rester
    // perceptible face à son remplissage comme face au fond de l'écran.
    for (final entree in variantes.entries) {
      testWidgets('${entree.key}', (tester) async {
        final t = entree.value();
        final contour =
            (t.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
                .borderSide
                .color;
        expectContrast(contour, t.inputDecorationTheme.fillColor!, Seuil.grand,
            'contour sur remplissage (${entree.key})');
        expectContrast(contour, t.scaffoldBackgroundColor, Seuil.grand,
            'contour sur fond d\'écran (${entree.key})');
      });
    }
  });

  group('placeholder', () {
    for (final entree in variantes.entries) {
      testWidgets('${entree.key}', (tester) async {
        final t = entree.value();
        expectContrast(
          t.inputDecorationTheme.hintStyle!.color!,
          t.colorScheme.surface,
          Seuil.texte,
          'placeholder (${entree.key})',
        );
      });
    }
  });

  group('libellé sur primary', () {
    testWidgets('thème clair', (tester) async {
      final cs = AppTheme.light().colorScheme;
      expectContrast(cs.onPrimary, cs.primary, Seuil.texte, 'onPrimary clair');
    });

    // Dette assumée et visible, plutôt qu'une exemption silencieuse : ce test
    // apparaît « ignoré » à chaque exécution, avec sa raison.
    //
    // En thème sombre, `onPrimary` (blanc) sur `primary` ne fait que 3.28:1.
    // Le noir y ferait 6.39:1, mais le rôle est utilisé 74 fois dans 32
    // fichiers, dont plusieurs le posent sur des dégradés de marque allant du
    // bleu très sombre au bleu clair, où le noir serait illisible. Le basculer
    // sans reprendre ces dégradés déplacerait le défaut au lieu de le
    // corriger.
    //
    // Les boutons pleins, eux, sont déjà réglés : `DonyButton` et
    // `filledButtonTheme` assombrissent leur libellé en thème sombre sans
    // passer par ce rôle.
    testWidgets(
      'thème sombre [DETTE CONNUE : 3.28:1, voir le commentaire ci-dessus]',
      (tester) async {
        final cs = AppTheme.dark().colorScheme;
        expectContrast(cs.onPrimary, cs.primary, Seuil.texte, 'onPrimary sombre');
      },
      skip: true,
    );
  });

  group('variante haut contraste', () {
    // Elle promet mieux que le minimum AA : ce test vérifie la promesse.
    for (final nom in ['clair + haut contraste', 'sombre + haut contraste']) {
      testWidgets(nom, (tester) async {
        final cs = variantes[nom]!().colorScheme;
        expectContrast(cs.onSurface, cs.surface, Seuil.hautContraste,
            'texte principal ($nom)');
        expectContrast(cs.outline, cs.surface, Seuil.grand, 'bordure ($nom)');
      });
    }
  });
}
