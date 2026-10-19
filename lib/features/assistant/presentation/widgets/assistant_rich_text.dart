import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Texte riche d'une réponse de l'assistant (`answerRich` / `explanationRich`,
/// YADONY-FLUTTER-PROD-13), rendu sans paquet Markdown, dans l'esprit de
/// `emphasizedSpans` : le back n'envoie que trois balises, passées au crible.
///
/// - une ligne = un paragraphe, espacé de [DonySpacing.sm] ;
/// - `- ` en début de ligne = puce ;
/// - `**x**` = gras (w700). Une étoile orpheline reste affichée telle quelle.
///
/// Le lecteur d'écran lit le texte sans balise, en un seul nœud.
class AssistantRichText extends StatelessWidget {
  const AssistantRichText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  static const _bullet = '- ';

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final bold = style.copyWith(fontWeight: FontWeight.w700);
    return Semantics(
      label: assistantPlainText(text),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, line) in lines.indexed) ...[
              if (index > 0) const SizedBox(height: DonySpacing.sm),
              if (line.startsWith(_bullet))
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•', style: bold),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: assistantBoldSpans(
                            line.substring(_bullet.length).trimLeft(),
                            bold,
                          ),
                        ),
                        style: style,
                      ),
                    ),
                  ],
                )
              else
                Text.rich(
                  TextSpan(children: assistantBoldSpans(line, bold)),
                  style: style,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Segments d'une ligne : chaque paire `**…**` non vide en [bold], le reste
/// en texte normal. Une `**` sans fermeture reste du texte, sans planter.
List<InlineSpan> assistantBoldSpans(String line, TextStyle bold) {
  final spans = <InlineSpan>[];
  var i = 0;
  while (i < line.length) {
    final open = line.indexOf('**', i);
    final close = open < 0 ? -1 : line.indexOf('**', open + 2);
    if (open < 0 || close < 0) {
      spans.add(TextSpan(text: line.substring(i)));
      break;
    }
    if (open > i) spans.add(TextSpan(text: line.substring(i, open)));
    final inner = line.substring(open + 2, close);
    if (inner.isNotEmpty) spans.add(TextSpan(text: inner, style: bold));
    i = close + 2;
  }
  return spans;
}

/// Texte lu par le lecteur d'écran : sans `**` appariées, puces en `•`.
String assistantPlainText(String rich) {
  final out = <String>[];
  for (final raw in rich.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final body = line.startsWith('- ') ? '• ${line.substring(2)}' : line;
    out.add(
      assistantBoldSpans(
        body,
        const TextStyle(),
      ).map((s) => (s as TextSpan).text ?? '').join(),
    );
  }
  return out.join('\n');
}
