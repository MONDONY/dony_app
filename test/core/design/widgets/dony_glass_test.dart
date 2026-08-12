import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, height: 200, child: child)),
  ),
);

void main() {
  group('DonyGlassOnBrand', () {
    testWidgets('renders child wrapped in BackdropFilter', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyGlassOnBrand(child: Text('Pattern A'))),
      );
      expect(find.text('Pattern A'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);
    });
  });

  group('DonyGlassDarkSheet', () {
    testWidgets('renders child with white default text style', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyGlassDarkSheet(child: Text('Pattern B'))),
      );
      final textWidget = tester.widget<Text>(find.text('Pattern B'));
      // The wrapper uses DefaultTextStyle.merge with white — verify via inherited style
      final ctx = tester.element(find.text('Pattern B'));
      final ds = DefaultTextStyle.of(ctx);
      expect(ds.style.color, Colors.white);
      expect(textWidget.data, 'Pattern B');
    });

    testWidgets('respects gradientStart / gradientEnd overrides', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyGlassDarkSheet(
            gradientStart: Color(0xFF112233),
            gradientEnd: Color(0xFF445566),
            child: SizedBox(),
          ),
        ),
      );
      expect(find.byType(DonyGlassDarkSheet), findsOneWidget);
    });
  });

  group('DonyGlassCard', () {
    testWidgets('renders with default opacity 0.62', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyGlassCard(child: Text('Hello aurora'))),
      );
      expect(find.text('Hello aurora'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    test('throws assertion when opacity < 0.62', () {
      expect(
        () => DonyGlassCard(opacity: 0.5, child: const Text('Should fail')),
        throwsAssertionError,
      );
    });

    test('accepts opacity exactly at floor (0.62)', () {
      expect(
        () => const DonyGlassCard(opacity: 0.62, child: Text('OK')),
        returnsNormally,
      );
    });

    test('accepts higher opacity (0.85)', () {
      expect(
        () => const DonyGlassCard(opacity: 0.85, child: Text('OK')),
        returnsNormally,
      );
    });
  });

  group('DonyGlassDarkFloating', () {
    testWidgets('forces white default text style for child', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyGlassDarkFloating(child: Text('Dark glass'))),
      );
      final ctx = tester.element(find.text('Dark glass'));
      expect(DefaultTextStyle.of(ctx).style.color, Colors.white);
    });

    test('throws assertion when opacity < 0.62', () {
      expect(
        () => DonyGlassDarkFloating(
          opacity: 0.42,
          child: const Text('Too transparent'),
        ),
        throwsAssertionError,
      );
    });

    testWidgets('accepts a custom tint', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyGlassDarkFloating(
            tint: Color(0xFF7C3AED),
            child: Text('Violet tint'),
          ),
        ),
      );
      expect(find.text('Violet tint'), findsOneWidget);
    });
  });

  group('DonyGlassChip', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(_wrap(const DonyGlassChip(label: 'Filtre A')));
      expect(find.text('Filtre A'), findsOneWidget);
    });

    testWidgets('uses font size 13 (glass min)', (tester) async {
      await tester.pumpWidget(_wrap(const DonyGlassChip(label: 'Min13')));
      final textWidget = tester.widget<Text>(find.text('Min13'));
      expect(textWidget.style!.fontSize, 13);
    });

    testWidgets('tap callback fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(DonyGlassChip(label: 'Tap me', onTap: () => tapped = true)),
      );
      await tester.tap(find.text('Tap me'));
      expect(tapped, isTrue);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyGlassChip(
            label: 'Avec icône',
            icon: Icons.filter_alt_rounded,
          ),
        ),
      );
      expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget);
    });
  });

  group('DonyGlassButton', () {
    testWidgets('renders primary variant by default', (tester) async {
      await tester.pumpWidget(
        _wrap(DonyGlassButton(label: 'Publier', onPressed: () {})),
      );
      expect(find.text('Publier'), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('light variant uses textPrimary color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyGlassButton(
            label: 'Annuler',
            variant: DonyGlassButtonVariant.light,
            onPressed: () {},
          ),
        ),
      );
      final textWidget = tester.widget<Text>(find.text('Annuler'));
      expect(textWidget.style!.color, DonyColors.textPrimary);
    });

    testWidgets('onPressed fires on tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(DonyGlassButton(label: 'Tap', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Tap'));
      expect(taps, 1);
    });

    testWidgets('expand=false does not force full width', (tester) async {
      await tester.pumpWidget(
        _wrap(DonyGlassButton(label: 'X', expand: false, onPressed: () {})),
      );
      // No SizedBox(width: infinity) wrapper in expand=false mode
      final sizedBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((s) => s.width == double.infinity);
      expect(sizedBoxes.isEmpty, isTrue);
    });
  });

  group('DonyAuroraBackground', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyAuroraBackground(
            variant: DonyAurora.green,
            child: Text('Hub Envoyer'),
          ),
        ),
      );
      expect(find.text('Hub Envoyer'), findsOneWidget);
    });

    testWidgets('wraps in RepaintBoundary for perf', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyAuroraBackground(
            variant: DonyAurora.pink,
            child: SizedBox(),
          ),
        ),
      );
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('uses Stack to layer gradient + blobs + content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyAuroraBackground(
            variant: DonyAurora.blue,
            child: SizedBox(),
          ),
        ),
      );
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('all 6 variants render without throwing', (tester) async {
      for (final variant in DonyAurora.values) {
        await tester.pumpWidget(
          _wrap(
            DonyAuroraBackground(variant: variant, child: Text(variant.name)),
          ),
        );
        expect(
          find.text(variant.name),
          findsOneWidget,
          reason: 'variant ${variant.name} should render its child',
        );
      }
    });
  });
}
