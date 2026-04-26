import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('DonyButton', () {
    testWidgets('primary variant renders FilledButton', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Test', onPressed: () {}),
      ));
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
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

    testWidgets('destructive variant renders FilledButton', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(
          label: 'Test',
          onPressed: () {},
          variant: DonyButtonVariant.destructive,
        ),
      ));
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyButton(label: 'Test', onPressed: null),
      ));
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
    });

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

    testWidgets('is full width by default', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Full', onPressed: () {}),
      ));
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(DonyButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, double.infinity);
    });

    testWidgets('tap triggers onPressed callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Tap', onPressed: () => tapped = true),
      ));
      await tester.tap(find.byType(FilledButton));
      expect(tapped, isTrue);
    });
  });
}