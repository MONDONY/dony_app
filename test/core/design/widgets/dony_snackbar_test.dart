import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(void Function(BuildContext) onTap, {String label = 'Show'}) =>
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => onTap(context),
            child: Text(label),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    DonySnackbar.clearDedup();
  });

  group('DonySnackbar', () {
    testWidgets('show() displays a SnackBar with the given message',
        (tester) async {
      await tester.pumpWidget(
          _harness((ctx) => DonySnackbar.show(ctx, message: 'Hello')));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('error variant shows SnackBar', (tester) async {
      await tester.pumpWidget(_harness((ctx) => DonySnackbar.show(
            ctx,
            message: 'Error!',
            type: DonySnackbarType.error,
          )));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Error!'), findsOneWidget);
    });

    testWidgets('success variant shows SnackBar', (tester) async {
      await tester.pumpWidget(_harness((ctx) => DonySnackbar.show(
            ctx,
            message: 'Done!',
            type: DonySnackbarType.success,
          )));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows SnackBarAction when actionLabel provided',
        (tester) async {
      await tester.pumpWidget(_harness((ctx) => DonySnackbar.show(
            ctx,
            message: 'Undo action',
            actionLabel: 'ANNULER',
            onAction: () {},
          )));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBarAction), findsOneWidget);
    });

    testWidgets('affiche le titre quand fourni', (tester) async {
      await tester.pumpWidget(_harness((ctx) => DonySnackbar.show(
            ctx,
            message: 'Le message',
            title: 'Mon titre',
          )));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Mon titre'), findsOneWidget);
      expect(find.text('Le message'), findsOneWidget);
    });

    testWidgets('dedup: appel identique en < 400ms — un seul toast',
        (tester) async {
      await tester.pumpWidget(_harness((ctx) {
        DonySnackbar.show(ctx, message: 'msg dupe', type: DonySnackbarType.error);
        DonySnackbar.show(ctx, message: 'msg dupe', type: DonySnackbarType.error);
      }, label: 'ShowDouble'));
      await tester.tap(find.text('ShowDouble'));
      await tester.pump();
      expect(find.text('msg dupe'), findsOneWidget);
    });

    testWidgets('onAction callback appelé quand action pressée', (tester) async {
      bool called = false;
      await tester.pumpWidget(_harness((ctx) => DonySnackbar.show(
            ctx,
            message: 'msg',
            actionLabel: 'Annuler',
            onAction: () => called = true,
          )));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      // Invoquer directement le callback (SnackBarAction est hors viewport dans le test runner)
      final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      action.onPressed();
      expect(called, isTrue);
    });

    testWidgets('warning variant shows SnackBar', (tester) async {
      await tester.pumpWidget(_harness((ctx) => DonySnackbar.show(
            ctx,
            message: 'Attention',
            type: DonySnackbarType.warning,
          )));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Attention'), findsOneWidget);
    });
  });
}
