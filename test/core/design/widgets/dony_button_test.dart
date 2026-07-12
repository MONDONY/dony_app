import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

Widget _wrapDark(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );

Finder _inkWellIn(Finder parent) =>
    find.descendant(of: parent, matching: find.byType(InkWell));

void main() {
  group('DonyButton', () {
    // ─── Variants rendering ─────────────────────────────────────────────────

    testWidgets('primary variant renders InkWell (gradient button)', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Test', onPressed: () {}),
      ));
      expect(find.text('Test'), findsOneWidget);
      expect(_inkWellIn(find.byType(DonyButton)), findsOneWidget);
    });

    testWidgets('secondary variant renders OutlinedButton', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Test',
          onPressed: () {},
          variant: DonyButtonVariant.secondary,
        ),
      ));
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('ghost variant renders TextButton', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Test',
          onPressed: () {},
          variant: DonyButtonVariant.ghost,
        ),
      ));
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('destructive variant renders InkWell (gradient button)', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Test',
          onPressed: () {},
          variant: DonyButtonVariant.destructive,
        ),
      ));
      expect(find.text('Test'), findsOneWidget);
      expect(_inkWellIn(find.byType(DonyButton)), findsOneWidget);
    });

    testWidgets('success variant renders InkWell (gradient button)', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Test',
          onPressed: () {},
          variant: DonyButtonVariant.success,
        ),
      ));
      expect(find.text('Test'), findsOneWidget);
      expect(_inkWellIn(find.byType(DonyButton)), findsOneWidget);
    });

    // ─── Dark mode ──────────────────────────────────────────────────────────

    testWidgets('primary dark mode renders InkWell', (tester) async {
      await tester.pumpWidget(_wrapDark(
        DonyButton(label: 'Dark', onPressed: () {}),
      ));
      expect(find.text('Dark'), findsOneWidget);
      expect(_inkWellIn(find.byType(DonyButton)), findsOneWidget);
    });

    // ─── Disabled state ─────────────────────────────────────────────────────

    testWidgets('disabled primary: InkWell.onTap is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyButton(label: 'Test', onPressed: null),
      ));
      final inkWell = tester.widget<InkWell>(
        _inkWellIn(find.byType(DonyButton)),
      );
      expect(inkWell.onTap, isNull);
    });

    testWidgets('disabled secondary: OutlinedButton.onPressed is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyButton(
          label: 'Test',
          onPressed: null,
          variant: DonyButtonVariant.secondary,
        ),
      ));
      final btn = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(btn.onPressed, isNull);
    });

    // ─── Icons ──────────────────────────────────────────────────────────────

    testWidgets('shows leading icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Test',
          onPressed: () {},
          icon: Icons.send,
        ),
      ));
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows trailing icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Test',
          onPressed: () {},
          iconRight: Icons.arrow_forward,
        ),
      ));
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    // ─── Full width ─────────────────────────────────────────────────────────

    testWidgets('is full width by default', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Full', onPressed: () {}),
      ));
      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.fullWidth, isTrue);
    });

    testWidgets('fullWidth false sets compact size', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Compact', onPressed: () {}, fullWidth: false),
      ));
      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.fullWidth, isFalse);
    });

    // ─── Tap ────────────────────────────────────────────────────────────────

    testWidgets('tap triggers onPressed callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Tap', onPressed: () => tapped = true),
      ));
      await tester.tap(_inkWellIn(find.byType(DonyButton)));
      expect(tapped, isTrue);
    });

    testWidgets('secondary tap triggers onPressed callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Tap',
          onPressed: () => tapped = true,
          variant: DonyButtonVariant.secondary,
        ),
      ));
      await tester.tap(find.byType(OutlinedButton));
      expect(tapped, isTrue);
    });

    // ─── Loading ────────────────────────────────────────────────────────────

    testWidgets('isLoading shows CircularProgressIndicator (primary)', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Loading', onPressed: () {}, isLoading: true),
      ));
      final inkWell = tester.widget<InkWell>(
        _inkWellIn(find.byType(DonyButton)),
      );
      expect(inkWell.onTap, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('secondary loading disables button', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Loading',
          onPressed: () {},
          variant: DonyButtonVariant.secondary,
          isLoading: true,
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final btn = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('ghost loading disables button', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Loading',
          onPressed: () {},
          variant: DonyButtonVariant.ghost,
          isLoading: true,
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final btn = tester.widget<TextButton>(find.byType(TextButton));
      expect(btn.onPressed, isNull);
    });

    // ─── Accent variant ─────────────────────────────────────────────────────

    testWidgets('DonyButtonVariant.accent renders with terracotta gradient background',
        (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Voir mon trajet',
          variant: DonyButtonVariant.accent,
          onPressed: () {},
        ),
      ));
      await tester.pump();

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;

      expect(
        gradient.colors,
        containsAll(<Color>[const Color(0xFFD96A3A)]),
      );
    });
  });
}
