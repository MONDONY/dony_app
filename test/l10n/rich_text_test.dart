import 'package:dony/l10n/rich_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emphasizedSpans', () {
    const style = TextStyle(fontWeight: FontWeight.bold);

    test('découpe le texte en trois spans, le milieu stylé', () {
      final spans = emphasizedSpans(
        "Si le colis n'arrive pas, on vous rembourse jusqu'à 200 € via le fonds de garantie.",
        "jusqu'à 200 €",
        style: style,
      );

      expect(spans, hasLength(3));
      final before = spans[0] as TextSpan;
      final middle = spans[1] as TextSpan;
      final after = spans[2] as TextSpan;
      expect(before.text, "Si le colis n'arrive pas, on vous rembourse ");
      expect(middle.text, "jusqu'à 200 €");
      expect(middle.style, style);
      expect(after.text, ' via le fonds de garantie.');
    });

    test('part absent du texte : un seul span sans style', () {
      final spans = emphasizedSpans(
        'Un texte quelconque.',
        'introuvable',
        style: style,
      );

      expect(spans, hasLength(1));
      final only = spans.single as TextSpan;
      expect(only.text, 'Un texte quelconque.');
      expect(only.style, isNull);
    });

    test('part vide : un seul span, tout le texte', () {
      final spans = emphasizedSpans('Un texte quelconque.', '', style: style);

      expect(spans, hasLength(1));
      final only = spans.single as TextSpan;
      expect(only.text, 'Un texte quelconque.');
      expect(only.style, isNull);
    });

    test(
      'part répété plusieurs fois : seule la première occurrence est stylée',
      () {
        // « 5 € » apparaît deux fois : le comportement documenté est de ne
        // styler que la première occurrence, la seconde restant dans le
        // span « après », en texte normal.
        final spans = emphasizedSpans(
          'Envoie pour 5 €, reçois 5 € de bonus.',
          '5 €',
          style: style,
        );

        expect(spans, hasLength(3));
        final before = spans[0] as TextSpan;
        final middle = spans[1] as TextSpan;
        final after = spans[2] as TextSpan;
        expect(before.text, 'Envoie pour ');
        expect(middle.text, '5 €');
        expect(middle.style, style);
        // La seconde occurrence de « 5 € » reste dans le span « après »,
        // non stylée.
        expect(after.text, ', reçois 5 € de bonus.');
        expect(after.style, isNull);
      },
    );

    test('le recognizer est porté par le span du milieu uniquement', () {
      final recognizer = TapGestureRecognizer();
      addTearDown(recognizer.dispose);

      final spans = emphasizedSpans(
        'Voir les conditions ici pour en savoir plus.',
        'ici',
        recognizer: recognizer,
      );

      expect(spans, hasLength(3));
      final before = spans[0] as TextSpan;
      final middle = spans[1] as TextSpan;
      final after = spans[2] as TextSpan;
      expect(before.recognizer, isNull);
      expect(middle.recognizer, recognizer);
      expect(after.recognizer, isNull);
    });
  });
}
