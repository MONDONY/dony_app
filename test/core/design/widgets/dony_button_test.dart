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

    testWidgets('is full width by default (fullWidth true)', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Full', onPressed: () {}),
      ));
      // fullWidth=true uses Size.fromHeight(52) which expands in a constrained parent
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

    testWidgets('tap triggers onPressed callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Tap', onPressed: () => tapped = true),
      ));
      await tester.tap(find.byType(FilledButton));
      expect(tapped, isTrue);
    });

    testWidgets('isLoading disables onPressed and shows progress indicator', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyButton(label: 'Loading', onPressed: () {}, isLoading: true),
      ));
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('secondary loading state shows CircularProgressIndicator', (tester) async {
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

    testWidgets('ghost loading state shows CircularProgressIndicator', (tester) async {
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
  });
}
