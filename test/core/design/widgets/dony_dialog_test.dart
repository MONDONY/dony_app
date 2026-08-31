import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required String? cancelLabel,
  required void Function(bool?) onResult,
}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final r = await DonyDialog.show(
            context,
            title: 'Titre',
            message: 'Message',
            confirmLabel: 'Oui',
            cancelLabel: cancelLabel,
          );
          onResult(r);
        },
        child: const Text('ouvrir'),
      ),
    ),
  ),
);

void main() {
  testWidgets('deux boutons par défaut : le secondaire rend false', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      _harness(cancelLabel: 'Non', onResult: (r) => result = r),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.text('Non'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('cancelLabel null : un seul bouton, qui rend true', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      _harness(cancelLabel: null, onResult: (r) => result = r),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.text('Oui'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
