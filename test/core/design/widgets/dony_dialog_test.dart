import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Widget _harness({
  String? cancelLabel,
  bool showCancel = true,
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
            showCancel: showCancel,
          );
          onResult(r);
        },
        child: const Text('ouvrir'),
      ),
    ),
  ),
);

/// Harness sans aucun libellé : vérifie les défauts résolus par [DonyDialog]
/// lui-même (`commonConfirm`/`commonCancel`), jamais surchargés ici.
Widget _defaultsHarness({required void Function(bool?) onResult}) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final r = await DonyDialog.show(
                context,
                title: 'Titre',
                message: 'Message',
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

  testWidgets('showCancel: false : un seul bouton, qui rend true', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      _harness(showCancel: false, onResult: (r) => result = r),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.text('Oui'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets(
    'sans confirmLabel/cancelLabel : les défauts français sont affichés',
    (tester) async {
      await tester.pumpWidget(_defaultsHarness(onResult: (_) {}));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    },
  );

  testWidgets(
    'sans confirmLabel/cancelLabel, en anglais : les défauts sont traduits',
    (tester) async {
      useEnglish();
      await tester.pumpWidget(_defaultsHarness(onResult: (_) {}));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );

  testWidgets('confirmDiscard affiche le texte français par défaut', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await DonyDialog.confirmDiscard(context);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
    expect(find.text('Quitter'), findsOneWidget);
    expect(find.text('Continuer la saisie'), findsOneWidget);

    await tester.tap(find.text('Quitter'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('confirmDiscard en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => DonyDialog.confirmDiscard(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Leave without saving?'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
  });
}
