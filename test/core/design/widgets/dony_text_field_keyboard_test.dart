import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// FLUTTER-A3 : toucher hors d'un champ ferme le clavier, y compris le pavé
/// numérique d'iOS qui n'a pas de touche « OK ».
void main() {
  testWidgets('un tap hors du champ lui retire le focus', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              DonyTextField(
                label: 'Téléphone', // i18n-ignore: test
                keyboardType: TextInputType.phone,
                focusNode: focus,
              ),
              const SizedBox(height: 300, key: Key('outside')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('outside')));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });
}
