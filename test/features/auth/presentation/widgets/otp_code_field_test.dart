import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/presentation/widgets/otp_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Widget wrap({ValueChanged<String>? onCompleted}) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: OtpCodeField(controller: controller, onCompleted: onCompleted),
      ),
    ),
  );

  // Sans cet indice, le téléphone ne propose pas le code reçu par SMS au-dessus
  // du clavier : les testeurs allaient le chercher dans Messages, où iOS range
  // les expéditeurs inconnus hors de la liste principale.
  testWidgets('déclare le remplissage automatique d\'un code à usage unique', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(Pinput),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
  });

  // Les six anciennes cases acceptaient un chiffre chacune : un code collé ou
  // rempli d'un bloc était tronqué au premier chiffre.
  testWidgets('un code arrivé d\'un bloc remplit les six cases', (
    tester,
  ) async {
    String? completed;
    await tester.pumpWidget(wrap(onCompleted: (code) => completed = code));

    await tester.enterText(find.byType(Pinput), '482913');
    await tester.pump();

    expect(controller.text, '482913');
    expect(completed, '482913');
    for (final digit in '482913'.split('')) {
      expect(find.text(digit), findsOneWidget);
    }
  });

  testWidgets('ne rend la main qu\'aux six chiffres, et refuse les lettres', (
    tester,
  ) async {
    String? completed;
    await tester.pumpWidget(wrap(onCompleted: (code) => completed = code));

    await tester.enterText(find.byType(Pinput), '48a2');
    await tester.pump();

    expect(controller.text, isNot(contains('a')));
    expect(completed, isNull);
  });
}
