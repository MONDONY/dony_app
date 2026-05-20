import 'package:dony/features/kyc/presentation/widgets/kyc_required_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(String kycStatus) => MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  KycRequiredBottomSheet.show(ctx, kycStatus: kycStatus),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

void main() {
  group('KycRequiredBottomSheet', () {
    testWidgets('affiche le titre "Vérification requise"', (tester) async {
      await tester.pumpWidget(_wrap('NOT_STARTED'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Vérification requise'), findsOneWidget);
    });

    testWidgets('affiche le message par défaut pour NOT_STARTED', (tester) async {
      await tester.pumpWidget(_wrap('NOT_STARTED'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('votre identité doit être vérifiée'),
        findsOneWidget,
      );
    });

    testWidgets('affiche le message pour REJECTED', (tester) async {
      await tester.pumpWidget(_wrap('REJECTED'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Votre vérification a échoué'),
        findsOneWidget,
      );
    });

    testWidgets('affiche le message pour PENDING', (tester) async {
      await tester.pumpWidget(_wrap('PENDING'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('en cours'),
        findsOneWidget,
      );
    });

    testWidgets('affiche les deux boutons d\'action', (tester) async {
      await tester.pumpWidget(_wrap('NOT_STARTED'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Vérifier mon identité'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
    });

    testWidgets('"Plus tard" ferme le sheet', (tester) async {
      await tester.pumpWidget(_wrap('NOT_STARTED'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Vérification requise'), findsOneWidget);
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(find.text('Vérification requise'), findsNothing);
    });
  });
}
