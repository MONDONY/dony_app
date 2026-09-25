import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../helpers/l10n_test_helpers.dart';

Widget _app({required VoidCallback onConfirm, VoidCallback? onSaveDraft}) =>
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
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  testWidgets('affiche le prix de l’aperçu en CAD sans conversion', (
    tester,
  ) async {
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

    final price = CurrencyFormatter.formatOrPlain(5, SupportedCurrency.cad);
    final net = CurrencyFormatter.formatOrPlain(50, SupportedCurrency.cad);
    expect(find.text('$price/kg · estimation $net net'), findsOneWidget);
    expect(find.textContaining('€/kg'), findsNothing);
  });

  testWidgets('l\'aperçu propose Publier et Enregistrer comme brouillon', (
    tester,
  ) async {
    var published = false;
    var savedDraft = false;
    await tester.pumpWidget(
      _app(
        onConfirm: () => published = true,
        onSaveDraft: () => savedDraft = true,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Publier l\'annonce'), findsOneWidget);
    expect(find.text('Enregistrer comme brouillon'), findsOneWidget);

    await tester.tap(find.text('Enregistrer comme brouillon'));
    await tester.pumpAndSettle();

    expect(savedDraft, isTrue);
    expect(published, isFalse);
  });

  testWidgets('sans onSaveDraft, seul le bouton Publier est affiché', (
    tester,
  ) async {
    await tester.pumpWidget(_app(onConfirm: () {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Publier l\'annonce'), findsOneWidget);
    expect(find.text('Enregistrer comme brouillon'), findsNothing);
  });

  testWidgets('en anglais : boutons Publier/Enregistrer traduits', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(_app(onConfirm: () {}, onSaveDraft: () {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Post the listing'), findsOneWidget);
    expect(find.text('Save as draft'), findsOneWidget);
    expect(find.text('Publier l\'annonce'), findsNothing);
  });

  testWidgets(
    'date de départ fr non-régression (motif dd MMM yyyy inchangé, zéro de tête)',
    (tester) async {
      final date = DateTime(2026, 10, 6, 14, 5);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementPreviewSheet(
              formState: AnnouncementFormState(
                pricePerKg: 5,
                availableKg: 10,
                departureDate: date,
              ),
              onConfirm: () {},
            ),
          ),
        ),
      );

      expect(
        find.textContaining(DateFormat('dd MMM yyyy', 'fr').format(date)),
        findsOneWidget,
      );
    },
  );

  testWidgets('date de départ en anglais (pas de zéro de tête)', (
    tester,
  ) async {
    useEnglish();
    final date = DateTime(2026, 10, 6, 14, 5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnouncementPreviewSheet(
            formState: AnnouncementFormState(
              pricePerKg: 5,
              availableKg: 10,
              departureDate: date,
            ),
            onConfirm: () {},
          ),
        ),
      ),
    );

    expect(
      find.textContaining(DateFormat.yMMMd('en').format(date)),
      findsOneWidget,
    );
    expect(find.textContaining('06 Oct'), findsNothing);
  });
}
