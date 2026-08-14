import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final barFinder = find.byKey(const Key('donyKeyboardDoneBar'));

  Widget wrap({
    required Widget field,
    double keyboardHeight = 0,
    VoidCallback? onOutsideTap,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: keyboardHeight)),
      child: DonyKeyboardScope(
        child: Scaffold(
          body: Column(
            children: [
              field,
              GestureDetector(
                key: const Key('outside'),
                // opaque : reproduit un vrai bouton, qui participe à l'arène
                // de gestes. Sans ça la zone n'est même pas touchable.
                behavior: HitTestBehavior.opaque,
                onTap: onOutsideTap,
                child: const SizedBox(height: 80, width: 200),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('un tap hors du champ referme le clavier', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      wrap(field: TextField(focusNode: node, autofocus: true)),
    );
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('outside')));
    await tester.pump();

    expect(node.hasFocus, isFalse);
  });

  testWidgets('le tap hors champ ne vole pas les gestes des widgets dessous', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(field: const TextField(), onOutsideTap: () => tapped = true),
    );

    await tester.tap(find.byKey(const Key('outside')));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('barre Terminé affichée sur un champ numérique clavier ouvert', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        field: const TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        keyboardHeight: 300,
      ),
    );
    await tester.pump();

    expect(barFinder, findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
  });

  testWidgets('barre Terminé affichée sur un champ multiligne', (tester) async {
    await tester.pumpWidget(
      wrap(
        field: const TextField(autofocus: true, maxLines: 4),
        keyboardHeight: 300,
      ),
    );
    await tester.pump();

    expect(barFinder, findsOneWidget);
  });

  testWidgets('pas de barre sur un champ texte simple (touche retour dispo)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(field: const TextField(autofocus: true), keyboardHeight: 300),
    );
    await tester.pump();

    expect(barFinder, findsNothing);
  });

  testWidgets('pas de barre clavier fermé', (tester) async {
    await tester.pumpWidget(
      wrap(
        field: const TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
      ),
    );
    await tester.pump();

    expect(barFinder, findsNothing);
  });

  testWidgets('tap sur Terminé retire le focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      wrap(
        field: TextField(
          focusNode: node,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        keyboardHeight: 300,
      ),
    );
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.tap(find.text('Terminé'));
    await tester.pump();

    expect(node.hasFocus, isFalse);
  });
}
