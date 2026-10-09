import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Seg { a, b }

Future<void> _pump(
  WidgetTester tester, {
  required _Seg selected,
  required ValueChanged<_Seg> onSelect,
  int? countA,
  int? countB,
  DonySegmentCountStyle style = DonySegmentCountStyle.alert,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SizedBox(
        width: 320,
        child: DonySegmentedControl<_Seg>(
          selected: selected,
          onSelect: onSelect,
          segments: [
            DonySegment(
              key: const Key('seg-a'),
              value: _Seg.a,
              label: 'Alpha',
              count: countA,
              countStyle: style,
            ),
            DonySegment(
              key: const Key('seg-b'),
              value: _Seg.b,
              label: 'Beta',
              count: countB,
              countStyle: style,
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('tap → onSelect avec la valeur du segment', (tester) async {
    _Seg? tapped;
    await _pump(tester, selected: _Seg.a, onSelect: (v) => tapped = v);
    await tester.tap(find.byKey(const Key('seg-b')));
    expect(tapped, _Seg.b);
  });

  testWidgets('zone tappable sur toute la hauteur du segment', (tester) async {
    await _pump(tester, selected: _Seg.a, onSelect: (_) {});
    expect(
      tester.getSize(find.byKey(const Key('seg-a'))).height,
      greaterThanOrEqualTo(38),
    );
  });

  testWidgets('alerte : pastille au-dessus de zéro seulement, 99+', (
    tester,
  ) async {
    await _pump(
      tester,
      selected: _Seg.a,
      onSelect: (_) {},
      countA: 0,
      countB: 120,
    );
    expect(find.text('0'), findsNothing);
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('neutre : zéro affiché, chiffres tabulaires', (tester) async {
    await _pump(
      tester,
      selected: _Seg.b,
      onSelect: (_) {},
      countA: 0,
      countB: 3,
      style: DonySegmentCountStyle.neutral,
    );
    final zero = tester.widget<Text>(find.text('0'));
    expect(
      zero.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('segment choisi annoncé « sélectionné »', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, selected: _Seg.b, onSelect: (_) {});
    expect(
      tester.getSemantics(find.byKey(const Key('seg-b'))),
      matchesSemantics(
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        label: 'Beta',
      ),
    );
    handle.dispose();
  });

  // FLUTTER-HN : escales facultatives, aucune option choisie.
  testWidgets('aucun segment choisi : capsule masquée', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: DonySegmentedControl<_Seg?>(
              selected: null,
              onSelect: (_) {},
              segments: const [
                DonySegment(value: _Seg.a, label: 'Alpha'),
                DonySegment(value: _Seg.b, label: 'Beta'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 0);
  });
}
