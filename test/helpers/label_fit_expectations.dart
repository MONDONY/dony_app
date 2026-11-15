import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le libellé d'un `DonyButton` pleine largeur [button] garde sa taille
/// nominale.
///
/// En pleine largeur, `DonyButton` enveloppe son libellé dans un
/// `FittedBox(scaleDown)` : le `Text` est mis en page sans contrainte, donc
/// `didExceedMaxLines` vaut toujours faux et `textSize.width <= size.width`
/// passe même quand le libellé est rétréci. Seul le rapport entre la boîte du
/// `FittedBox` et celle du `Text` le dit : 1 à taille nominale, inférieur à 1
/// dès que le `FittedBox` réduit la police.
void expectButtonLabelNominal(
  WidgetTester tester,
  Finder button, {
  String? reason,
}) {
  final fitted = find.descendant(
    of: button,
    matching: find.byWidgetPredicate(
      (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
    ),
  );
  final text = find.descendant(of: fitted, matching: find.byType(Text));
  expect(fitted, findsOneWidget, reason: reason);
  expect(text, findsOneWidget, reason: reason);
  final scale = tester.getSize(fitted).width / tester.getSize(text).width;
  expect(
    scale,
    closeTo(1, 0.001),
    reason: '${reason ?? 'bouton'} : libellé rétréci par le FittedBox',
  );
}

/// Le libellé [label] d'un `Text` posé sans `FittedBox` (`maxLines: 1`,
/// `softWrap: false`) tient sur une ligne dans sa boîte : `softWrap: false`
/// met le texte en page sur sa largeur naturelle, la boîte, elle, est bornée
/// par le parent. Un libellé trop long dépasse donc sa boîte.
///
/// Ne convient pas à un `DonyButton` pleine largeur : voir
/// [expectButtonLabelNominal].
void expectPlainLabelFits(WidgetTester tester, Finder label, {String? reason}) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: label, matching: find.byType(RichText)).first,
  );
  expect(
    paragraph.textSize.width,
    lessThanOrEqualTo(paragraph.size.width + 0.01),
    reason: '${reason ?? 'libellé'} : texte plus large que sa boîte',
  );
}
