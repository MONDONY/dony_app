import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/ratings/presentation/widgets/star_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trouve le nœud sémantique portant exactement [label].
SemanticsNode _nodeWithLabel(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(label);
  expect(finder, findsOneWidget, reason: 'aucun nœud nommé « $label »');
  return tester.getSemantics(finder);
}

void main() {
  group('sélecteur d\'étoiles', () {
    // Ce parcours était entièrement inaccessible : cinq zones tappables muettes,
    // sans valeur ni état annoncés. Noter un voyageur exigeait de voir l'écran.
    Future<void> pump(WidgetTester tester, int selected) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StarSelector(selected: selected, onSelect: (_) {}),
        ),
      ),
    );

    testWidgets('chaque étoile annonce sa valeur', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, 0);
      for (var i = 1; i <= 5; i++) {
        expect(
          find.bySemanticsLabel('Noter $i sur 5'),
          findsOneWidget,
          reason: 'l\'étoile $i doit dire quelle note elle applique',
        );
      }
      handle.dispose();
    });

    testWidgets('seule la note choisie est marquée sélectionnée', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, 3);
      expect(
        _nodeWithLabel(
          tester,
          'Noter 3 sur 5',
        ).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      // Pas « toutes les étoiles jusqu'à 3 » : on choisit une note, pas trois.
      expect(
        _nodeWithLabel(
          tester,
          'Noter 2 sur 5',
        ).hasFlag(SemanticsFlag.isSelected),
        isFalse,
      );
      expect(
        _nodeWithLabel(
          tester,
          'Noter 4 sur 5',
        ).hasFlag(SemanticsFlag.isSelected),
        isFalse,
      );
      handle.dispose();
    });

    testWidgets('les étoiles forment un choix exclusif', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, 2);
      expect(
        _nodeWithLabel(
          tester,
          'Noter 2 sur 5',
        ).hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup),
        isTrue,
        reason: 'sinon le lecteur d\'écran présente cinq boutons indépendants',
      );
      handle.dispose();
    });

    testWidgets('taper une étoile remonte bien sa valeur', (tester) async {
      // Garde-fou : `excludeSemantics` masque l'icône, il ne doit pas casser
      // le geste.
      final handle = tester.ensureSemantics();
      int? choisi;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StarSelector(selected: 0, onSelect: (v) => choisi = v),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Noter 4 sur 5'));
      expect(choisi, 4);
      handle.dispose();
    });
  });
}
