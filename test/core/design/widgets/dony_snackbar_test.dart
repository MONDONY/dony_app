import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DonySnackbar', () {
    testWidgets('show() displays a SnackBar with the given message', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => DonySnackbar.show(context, message: 'Hello'),
              child: const Text('Show'),
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('error variant shows SnackBar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => DonySnackbar.show(
                context,
                message: 'Error!',
                type: DonySnackbarType.error,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Error!'), findsOneWidget);
    });

    testWidgets('success variant shows SnackBar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => DonySnackbar.show(
                context,
                message: 'Done!',
                type: DonySnackbarType.success,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}