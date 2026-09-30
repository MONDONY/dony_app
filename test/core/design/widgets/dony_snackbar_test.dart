import 'package:dony/core/design/design_system.dart';
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
    testWidgets('show() displays a SnackBar with the given message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness((ctx) => DonySnackbar.show(ctx, message: 'Hello')),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('error variant shows SnackBar', (tester) async {
      await tester.pumpWidget(
        _harness(
          (ctx) => DonySnackbar.show(
            ctx,
            message: 'Error!',
            type: DonySnackbarType.error,
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Error!'), findsOneWidget);
    });

    testWidgets('success variant shows SnackBar', (tester) async {
      await tester.pumpWidget(
        _harness(
          (ctx) => DonySnackbar.show(
            ctx,
            message: 'Done!',
            type: DonySnackbarType.success,
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows SnackBarAction when actionLabel provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          (ctx) => DonySnackbar.show(
            ctx,
            message: 'Undo action',
            actionLabel: 'ANNULER',
            onAction: () {},
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBarAction), findsOneWidget);
    });

    testWidgets('affiche le titre quand fourni', (tester) async {
      await tester.pumpWidget(
        _harness(
          (ctx) =>
              DonySnackbar.show(ctx, message: 'Le message', title: 'Mon titre'),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Mon titre'), findsOneWidget);
      expect(find.text('Le message'), findsOneWidget);
    });

    testWidgets('dedup: appel identique en < 400ms — un seul toast', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness((ctx) {
          DonySnackbar.show(
            ctx,
            message: 'msg dupe',
            type: DonySnackbarType.error,
          );
          DonySnackbar.show(
            ctx,
            message: 'msg dupe',
            type: DonySnackbarType.error,
          );
        }, label: 'ShowDouble'),
      );
      await tester.tap(find.text('ShowDouble'));
      await tester.pump();
      expect(find.text('msg dupe'), findsOneWidget);
    });

    testWidgets('onAction callback appelé quand action pressée', (
      tester,
    ) async {
      bool called = false;
      await tester.pumpWidget(
        _harness(
          (ctx) => DonySnackbar.show(
            ctx,
            message: 'msg',
            actionLabel: 'Annuler',
            onAction: () => called = true,
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      // Invoquer directement le callback (SnackBarAction est hors viewport dans le test runner)
      final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      action.onPressed();
      expect(called, isTrue);
    });

    testWidgets('warning variant shows SnackBar', (tester) async {
      await tester.pumpWidget(
        _harness(
          (ctx) => DonySnackbar.show(
            ctx,
            message: 'Attention',
            type: DonySnackbarType.warning,
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Attention'), findsOneWidget);
    });
  });

  // FLUTTER-4W / 4P : depuis une feuille, le snackbar du Scaffold de la page
  // s'affichait sous la feuille, invisible. Il passe au-dessus.
  group('DonySnackbar depuis une feuille modale', () {
    Future<void> openSheetAndShow(WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          (ctx) => showModalBottomSheet<void>(
            context: ctx,
            useRootNavigator: true,
            builder: (sheetCtx) => SizedBox(
              height: 300,
              child: Center(
                child: TextButton(
                  onPressed: () => DonySnackbar.show(
                    sheetCtx,
                    message: 'Refusé par le serveur',
                    type: DonySnackbarType.warning,
                  ),
                  child: const Text('Envoyer'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
    }

    testWidgets('affiché par-dessus la feuille, pas en SnackBar dessous', (
      tester,
    ) async {
      await openSheetAndShow(tester);

      expect(
        find.byKey(const Key('dony-snackbar-above-modal')),
        findsOneWidget,
      );
      expect(find.text('Refusé par le serveur'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // La feuille reste ouverte.
      expect(find.text('Envoyer'), findsOneWidget);
    });

    testWidgets('disparaît seul après sa durée', (tester) async {
      await openSheetAndShow(tester);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Refusé par le serveur'), findsNothing);
    });

    testWidgets('un tap le ferme', (tester) async {
      await openSheetAndShow(tester);

      await tester.tap(find.byKey(const Key('dony-snackbar-above-modal')));
      await tester.pumpAndSettle();

      expect(find.text('Refusé par le serveur'), findsNothing);
    });
  });

  testWidgets('feuille fermée puis message : SnackBar normal de la page', (
    tester,
  ) async {
    DonySnackbar.clearDedup();
    await tester.pumpWidget(
      _harness(
        (ctx) => showModalBottomSheet<void>(
          context: ctx,
          useRootNavigator: true,
          builder: (sheetCtx) => TextButton(
            onPressed: () {
              Navigator.of(sheetCtx, rootNavigator: true).pop();
              DonySnackbar.show(sheetCtx, message: 'Demande envoyée');
            },
            child: const Text('Fermer'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('dony-snackbar-above-modal')), findsNothing);
  });
}
