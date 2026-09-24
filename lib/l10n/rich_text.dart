import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Découpe [text] à la première occurrence de [part] pour construire une
/// phrase avec un segment en gras ou cliquable, sans jamais assembler la
/// phrase à partir de fragments traduits séparément (Ruling « Aucune phrase
/// découpée » — le message complet reste une seule clé ARB à paramètre, et
/// c'est cette fonction qui retrouve la valeur du paramètre dans le texte déjà
/// rendu pour la mettre en forme).
///
/// Rend `[avant, part stylé/cliquable, après]` : trois [InlineSpan] au plus,
/// les segments vides étant omis par [TextSpan] lui-même. Si [part] est vide
/// ou absent de [text], rend un seul span portant tout le texte, sans style ni
/// recognizer — jamais de crash sur une traduction où le paramètre change de
/// forme.
List<InlineSpan> emphasizedSpans(
  String text,
  String part, {
  TextStyle? style,
  GestureRecognizer? recognizer,
}) {
  if (part.isEmpty) {
    return [TextSpan(text: text)];
  }
  final index = text.indexOf(part);
  if (index < 0) {
    return [TextSpan(text: text)];
  }
  final before = text.substring(0, index);
  final after = text.substring(index + part.length);
  return [
    TextSpan(text: before),
    TextSpan(text: part, style: style, recognizer: recognizer),
    TextSpan(text: after),
  ];
}
