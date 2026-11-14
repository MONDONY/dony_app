import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'label_fit_expectations.dart';

Widget _wrap(Widget child, {double width = 200}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  group('expectButtonLabelNominal', () {
    testWidgets('accepte un libellé court', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyButton(key: const Key('b'), label: 'Réserver', onPressed: () {}),
        ),
      );
      expectButtonLabelNominal(tester, find.byKey(const Key('b')));
    });

    testWidgets('refuse un libellé que le FittedBox rétrécit', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyButton(
            key: const Key('b'),
            label: 'Un libellé artificiellement beaucoup trop long',
            onPressed: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        () => expectButtonLabelNominal(tester, find.byKey(const Key('b'))),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets(
      'l ancien contrôle (largeur du texte <= boîte) passait à tort',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            DonyButton(
              key: const Key('b'),
              label: 'Un libellé artificiellement beaucoup trop long',
              onPressed: () {},
            ),
          ),
        );
        final text = find.descendant(
          of: find.byKey(const Key('b')),
          matching: find.byType(Text),
        );
        // Le texte garde sa largeur naturelle sous le FittedBox : ce contrôle
        // ne voit pas le rétrécissement, d'où expectButtonLabelNominal.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)).first,
        );
        expect(paragraph.textSize.width, paragraph.size.width);
      },
    );
  });

  group('expectPlainLabelFits', () {
    testWidgets('accepte un libellé court', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Text('Court', key: Key('t'), maxLines: 1, softWrap: false),
          width: 120,
        ),
      );
      expectPlainLabelFits(tester, find.byKey(const Key('t')));
    });

    testWidgets('refuse un libellé plus large que sa boîte', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Text(
            'Un libellé artificiellement beaucoup trop long',
            key: Key('t'),
            maxLines: 1,
            softWrap: false,
          ),
          width: 120,
        ),
      );
      expect(
        () => expectPlainLabelFits(tester, find.byKey(const Key('t'))),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
