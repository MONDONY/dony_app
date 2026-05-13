import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_select_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

/// Drains flutter_animate timers by pumping the animation duration,
/// then disposes the widget tree to avoid leaking pending timers.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('DonySelectBar', () {
    // ── Nothing selected ────────────────────────────────────────────────────

    testWidgets(
        'nothing selected — shows DonyButton with defaultLabel, no context row',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const DonySelectBar(
          defaultLabel: 'Sélectionner',
          onConfirm: null,
        ),
      ));
      await tester.pump(); // settle initial frame

      // Button uses defaultLabel
      expect(find.text('Sélectionner'), findsOneWidget);

      // DonyButton is rendered
      expect(find.byType(DonyButton), findsOneWidget);

      // No context row text (no selectedSummary)
      expect(find.text('Paris → Dakar'), findsNothing);

      // The DonyButton has onPressed == null (disabled)
      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.onPressed, isNull);

      await _drain(tester);
    });

    testWidgets('nothing selected — confirmedLabel is not shown', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonySelectBar(
          defaultLabel: 'Choisir un trajet',
          confirmedLabel: 'Confirmer',
          onConfirm: null,
        ),
      ));
      await tester.pump();

      expect(find.text('Choisir un trajet'), findsOneWidget);
      expect(find.text('Confirmer'), findsNothing);

      await _drain(tester);
    });

    // ── Item selected ───────────────────────────────────────────────────────

    testWidgets(
        'item selected — context row visible, DonyButton with confirmedLabel',
        (tester) async {
      var confirmed = false;

      await tester.pumpWidget(_wrap(
        DonySelectBar(
          defaultLabel: 'Sélectionner',
          confirmedLabel: 'Confirmer la sélection',
          selectedSummary: 'Paris → Dakar sélectionné',
          selectedCount: '1 trajet',
          onConfirm: () => confirmed = true,
        ),
      ));
      // Pump through the 200ms animation
      await tester.pump(const Duration(milliseconds: 250));

      // Context row — summary text
      expect(find.text('Paris → Dakar sélectionné'), findsOneWidget);

      // Context row — count with checkmark
      expect(find.text('✓ 1 trajet'), findsOneWidget);

      // Button shows confirmedLabel
      expect(find.text('Confirmer la sélection'), findsOneWidget);
      expect(find.text('Sélectionner'), findsNothing);

      // Button is enabled (onConfirm provided)
      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.onPressed, isNotNull);

      // Suppress unused variable warning
      expect(confirmed, isFalse);

      await _drain(tester);
    });

    testWidgets('item selected without selectedCount — no count text shown',
        (tester) async {
      await tester.pumpWidget(_wrap(
        DonySelectBar(
          selectedSummary: 'Paris → Dakar sélectionné',
          // selectedCount omitted
          onConfirm: () {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Paris → Dakar sélectionné'), findsOneWidget);
      // No "✓ …" text
      expect(find.textContaining('✓'), findsNothing);

      await _drain(tester);
    });

    testWidgets('item selected — onConfirm callback fires on tap',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(_wrap(
        DonySelectBar(
          selectedSummary: 'Paris → Dakar',
          selectedCount: '1 trajet',
          onConfirm: () => tapped = true,
          confirmedLabel: 'Confirmer',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      // Tap the InkWell inside DonyButton
      final inkWell = find.descendant(
        of: find.byType(DonyButton),
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWell);
      expect(tapped, isTrue);

      await _drain(tester);
    });

    // ── isLoading ───────────────────────────────────────────────────────────

    testWidgets('isLoading: true — DonyButton receives isLoading: true',
        (tester) async {
      await tester.pumpWidget(_wrap(
        DonySelectBar(
          selectedSummary: 'Paris → Dakar',
          onConfirm: () {},
          isLoading: true,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.isLoading, isTrue);

      // CircularProgressIndicator visible when loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await _drain(tester);
    });

    testWidgets('isLoading: false (default) — no spinner shown', (tester) async {
      await tester.pumpWidget(_wrap(
        DonySelectBar(
          selectedSummary: 'Paris → Dakar',
          onConfirm: () {},
          // isLoading defaults to false
        ),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.isLoading, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await _drain(tester);
    });

    // ── Default labels ───────────────────────────────────────────────────────

    testWidgets('default label values match spec', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonySelectBar(onConfirm: null),
      ));
      await tester.pump();

      final bar = tester.widget<DonySelectBar>(find.byType(DonySelectBar));
      expect(bar.defaultLabel, equals('Sélectionner'));
      expect(bar.confirmedLabel, equals('Confirmer la sélection'));

      await _drain(tester);
    });
  });
}
