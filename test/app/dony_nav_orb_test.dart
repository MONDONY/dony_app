import 'dart:ui' show Tristate;

import 'package:dony/app/widgets/dony_nav_orb.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scheme = ColorScheme.light(primary: DonyColors.primary);

  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(useMaterial3: true, colorScheme: scheme),
    home: Scaffold(body: Center(child: child)),
  );

  group('DonyNavOrb', () {
    testWidgets('affiche l\'icône scanner (scan-line)', (tester) async {
      await tester.pumpWidget(host(DonyNavOrb(active: false, onTap: () {})));

      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'scan-line'),
        findsOneWidget,
      );
    });

    testWidgets('sphère ronde à la taille demandée', (tester) async {
      await tester.pumpWidget(host(DonyNavOrb(active: false, onTap: () {})));

      final box = tester.getSize(find.byType(DonyNavOrb));
      expect(box.width, 58);
      expect(box.height, 58);
    });

    testWidgets('expose Semantics bouton + Suivi, sélectionné si actif', (
      tester,
    ) async {
      await tester.pumpWidget(host(DonyNavOrb(active: true, onTap: () {})));

      final node = tester.getSemantics(find.bySemanticsLabel('Suivi'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
    });

    testWidgets('non sélectionné quand inactif', (tester) async {
      await tester.pumpWidget(host(DonyNavOrb(active: false, onTap: () {})));

      final node = tester.getSemantics(find.bySemanticsLabel('Suivi'));
      expect(node.flagsCollection.isSelected, Tristate.isFalse);
    });

    testWidgets('onTap déclenché au tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(DonyNavOrb(active: false, onTap: () => tapped = true)),
      );

      await tester.tap(find.byType(DonyNavOrb));
      expect(tapped, isTrue);
    });
  });
}
