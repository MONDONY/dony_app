import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche le budget de l’aperçu en CAD sans conversion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => PackageRequestPreviewSheet.show(
                context,
                currency: SupportedCurrency.cad,
                formState: const PackageRequestFormState(totalBudgetEur: 40),
                onConfirm: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final budget = CurrencyFormatter.formatOrPlain(40, SupportedCurrency.cad);
    expect(find.text('Budget indicatif : $budget'), findsOneWidget);
    expect(find.textContaining('40 €'), findsNothing);
  });

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    VoidCallback? onSaveDraft,
    required VoidCallback onConfirm,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => PackageRequestPreviewSheet.show(
                context,
                formState: const PackageRequestFormState(
                  departureCity: 'Paris',
                  arrivalCity: 'Dakar',
                ),
                onConfirm: onConfirm,
                onSaveDraft: onSaveDraft,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('sans onSaveDraft, seul le bouton Publier est affiché', (
    tester,
  ) async {
    await pumpAndOpen(tester, onConfirm: () {});
    expect(find.byKey(const Key('preview-publish')), findsOneWidget);
    expect(find.byKey(const Key('preview-save-draft')), findsNothing);
  });

  testWidgets('avec onSaveDraft, les deux boutons sont affichés', (
    tester,
  ) async {
    await pumpAndOpen(tester, onConfirm: () {}, onSaveDraft: () {});
    expect(find.byKey(const Key('preview-publish')), findsOneWidget);
    expect(find.byKey(const Key('preview-save-draft')), findsOneWidget);
  });

  testWidgets('tap sur Publier appelle onConfirm', (tester) async {
    var confirmed = false;
    await pumpAndOpen(tester, onConfirm: () => confirmed = true);
    await tester.tap(find.byKey(const Key('preview-publish')));
    expect(confirmed, isTrue);
  });

  testWidgets('tap sur Enregistrer en brouillon appelle onSaveDraft', (
    tester,
  ) async {
    var drafted = false;
    await pumpAndOpen(
      tester,
      onConfirm: () {},
      onSaveDraft: () => drafted = true,
    );
    await tester.tap(find.byKey(const Key('preview-save-draft')));
    expect(drafted, isTrue);
  });
}
