import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Écran étroit (360 dp), le gabarit de référence des libellés de boutons.
void useNarrowScreen(WidgetTester tester, {double width = 360}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Le texte de [finder] tient sur une ligne, sans coupure ni rétrécissement
/// (le `FittedBox` d'un `DonyButton` pleine largeur rapetisse un libellé trop
/// long au lieu de le couper : ce serait un faux positif).
void expectOneLineNotShrunk(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: finder, matching: find.byType(RichText)).first,
  );
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  expect(boxes, isNotEmpty);
  expect(
    boxes.map((b) => b.top.round()).toSet(),
    hasLength(1),
    reason: 'libellé coupé sur plusieurs lignes',
  );
  final fitted = find.descendant(of: finder, matching: find.byType(FittedBox));
  if (fitted.evaluate().isNotEmpty) {
    final box = tester.getSize(fitted.first);
    expect(
      paragraph.size.width,
      lessThanOrEqualTo(box.width + 0.5),
      reason: 'libellé rétréci pour rentrer',
    );
  }
}
