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

  // FLUTTER-GP : depuis Flutter 3.44, `SnackBar.persist` vaut `action != null`
  // par défaut — un message avec action ne disparaissait jamais.
  group('FLUTTER-GP : durée des messages avec action', () {
    Widget host({bool persistent = false}) => MaterialApp(
      theme: AppTheme.light(),
      home: AccessibilityScope(
        underlineLinks: false,
        reinforceLabels: false,
        persistentMessages: persistent,
        confirmImportantActions: false,
        child: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  onPressed: () => DonySnackbar.show(
                    context,
                    message: 'Avec action',
                    actionLabel: 'Voir',
                    onAction: () {},
                  ),
                  child: const Text('action'),
                ),
                ElevatedButton(
                  onPressed: () => DonySnackbar.show(
                    context,
                    message: 'Archivé',
                    actionLabel: 'Annuler',
                    onAction: () {},
                  ),
                  child: const Text('undo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('message avec action : disparaît après 4 s', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('action'));
      await tester.pump();
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);
      // Fin de l'animation d'entrée : le minuteur démarre là.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 3200));
      expect(find.text('Avec action'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Avec action'), findsNothing);
    });

    testWidgets('« Annuler » : reste 6 s puis disparaît', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('undo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Archivé'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(find.text('Archivé'), findsNothing);
    });

    testWidgets('option « messages persistants » : le message reste', (
      tester,
    ) async {
      await tester.pumpWidget(host(persistent: true));
      await tester.tap(find.text('action'));
      await tester.pump();
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isTrue);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Avec action'), findsOneWidget);
    });
  });
}
