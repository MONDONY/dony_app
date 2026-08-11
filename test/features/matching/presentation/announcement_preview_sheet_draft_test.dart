import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required VoidCallback onConfirm,
  VoidCallback? onSaveDraft,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AnnouncementPreviewSheet.show(
              context,
              formState: const AnnouncementFormState(),
              onConfirm: onConfirm,
              onSaveDraft: onSaveDraft,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('affiche le prix de l’aperçu en CAD sans conversion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnouncementPreviewSheet(
            currency: SupportedCurrency.cad,
            formState: const AnnouncementFormState(
              pricePerKg: 5,
              availableKg: 10,
            ),
            onConfirm: () {},
          ),
        ),
      ),
    );

    expect(find.text(r'CA$5.00/kg · estimation CA$50.00 net'), findsOneWidget);
    expect(find.textContaining('€/kg'), findsNothing);
  });

  testWidgets(
      'l\'aperçu propose Publier et Enregistrer comme brouillon',
      (tester) async {
    var published = false;
    var savedDraft = false;
    await tester.pumpWidget(_app(
      onConfirm: () => published = true,
      onSaveDraft: () => savedDraft = true,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Publier l\'annonce'), findsOneWidget);
    expect(find.text('Enregistrer comme brouillon'), findsOneWidget);

    await tester.tap(find.text('Enregistrer comme brouillon'));
    await tester.pumpAndSettle();

    expect(savedDraft, isTrue);
    expect(published, isFalse);
  });

  testWidgets(
      'sans onSaveDraft, seul le bouton Publier est affiché',
      (tester) async {
    await tester.pumpWidget(_app(onConfirm: () {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Publier l\'annonce'), findsOneWidget);
    expect(find.text('Enregistrer comme brouillon'), findsNothing);
  });
}
