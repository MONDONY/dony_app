import 'package:dony/core/config/pro_flag.dart';
import 'package:dony/features/billing/presentation/pro_limit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monte un bouton qui ouvre le dialogue et capture sa valeur de retour :
/// c'est elle que les appelants utilisent pour décider de naviguer.
Widget _harness(void Function(bool) onResult) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final goPro = await showProLimitReachedDialog(
            context,
            title: 'Limite de brouillons atteinte',
            message: 'Limite de 1 brouillon(s) atteinte.',
          );
          onResult(goPro);
        },
        child: const Text('ouvrir'),
      ),
    ),
  ),
);

void main() {
  tearDown(() => setProEnabled(kProEnabledDefault));

  group('offre PRO ouverte', () {
    setUp(() => setProEnabled(true));

    testWidgets('propose « Passer en PRO » et rend true quand on le choisit', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(_harness((r) => result = r));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Limite de brouillons atteinte'), findsOneWidget);
      expect(find.text('Passer en PRO'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);

      await tester.tap(find.text('Passer en PRO'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('rend false quand on remet à plus tard', (tester) async {
      bool? result;
      await tester.pumpWidget(_harness((r) => result = r));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('offre PRO fermée', () {
    setUp(() => setProEnabled(false));

    testWidgets(
      'informe sans proposer de passer en PRO, et ne rend jamais true',
      (tester) async {
        bool? result;
        await tester.pumpWidget(_harness((r) => result = r));
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();

        // Le message serveur reste dit : la limite existe bel et bien.
        expect(find.text('Limite de brouillons atteinte'), findsOneWidget);
        expect(find.text('Limite de 1 brouillon(s) atteinte.'), findsOneWidget);
        // Mais aucune issue PRO : elle mènerait à une route redirigée.
        expect(find.text('Passer en PRO'), findsNothing);
        expect(find.text('Plus tard'), findsNothing);
        expect(find.text('Compris'), findsOneWidget);

        await tester.tap(find.text('Compris'));
        await tester.pumpAndSettle();

        expect(result, isFalse);
        expect(find.text('Limite de brouillons atteinte'), findsNothing);
      },
    );
  });
}
