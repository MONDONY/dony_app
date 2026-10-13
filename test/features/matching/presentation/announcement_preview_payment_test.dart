import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_preview_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../helpers/l10n_test_helpers.dart';

/// FLUTTER-GJ : le libellé « Paiement » de l'aperçu suit la liste réellement
/// envoyée (devise, carte décochée, mobile money), plus seulement
/// `cashAccepted`.
void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  Future<void> pump(
    WidgetTester tester, {
    List<String>? methods,
    bool cashAccepted = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnnouncementPreviewSheet(
            formState: AnnouncementFormState(
              pricePerKg: 5,
              availableKg: 10,
              cashAccepted: cashAccepted,
            ),
            onConfirm: () {},
            paymentMethods: methods,
          ),
        ),
      ),
    ),
  );

  testWidgets('XOF : espèces + mobile money, jamais « Carte »', (tester) async {
    await pump(tester, methods: const ['CASH', 'MOBILE_MONEY']);
    expect(find.text('Espèces + Mobile money'), findsOneWidget);
    expect(find.textContaining('Carte'), findsNothing);
  });

  testWidgets('carte décochée : espèces seules', (tester) async {
    await pump(tester, methods: const ['CASH']);
    expect(find.text('Espèces'), findsOneWidget);
    expect(find.textContaining('Carte'), findsNothing);
  });

  testWidgets('carte seule', (tester) async {
    await pump(tester, methods: const ['STRIPE']);
    expect(find.text('Carte'), findsOneWidget);
    expect(find.text('Carte + Espèces'), findsNothing);
  });

  testWidgets('carte + espèces + mobile money', (tester) async {
    await pump(tester, methods: const ['STRIPE', 'CASH', 'MOBILE_MONEY']);
    expect(find.text('Carte + Espèces + Mobile money'), findsOneWidget);
  });

  testWidgets('sans liste : repli sur cashAccepted', (tester) async {
    await pump(tester, cashAccepted: false);
    expect(find.text('Carte uniquement'), findsOneWidget);
  });

  test('paymentLabel : toutes les combinaisons, ordre stable', () {
    final l = lookupAppLocalizations(AppL10n.fr);
    expect(AnnouncementPreviewSheet.paymentLabel(l, const ['CASH']), 'Espèces');
    expect(
      AnnouncementPreviewSheet.paymentLabel(l, const ['MOBILE_MONEY']),
      'Mobile money',
    );
    expect(
      AnnouncementPreviewSheet.paymentLabel(l, const [
        'MOBILE_MONEY',
        'STRIPE',
      ]),
      'Carte + Mobile money',
    );
    expect(
      AnnouncementPreviewSheet.paymentLabel(l, const ['CASH', 'STRIPE']),
      'Carte + Espèces',
    );
  });

  testWidgets('anglais', (tester) async {
    useEnglish();
    await pump(tester, methods: const ['CASH', 'MOBILE_MONEY']);
    expect(find.text('Cash + Mobile money'), findsOneWidget);
  });

  testWidgets('FLUTTER-GK : devise du voyage rappelée dans l\'aperçu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnnouncementPreviewSheet(
              formState: const AnnouncementFormState(
                pricePerKg: 3000,
                availableKg: 10,
              ),
              onConfirm: () {},
              currency: SupportedCurrency.xof,
              paymentMethods: const ['CASH'],
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('preview-currency-row')), findsOneWidget);
    expect(find.text('Devise : Franc CFA Ouest (XOF)'), findsOneWidget);
    // Sans rappel, la devise est figée : pas de « Modifier ».
    expect(find.byKey(const Key('preview-currency-change')), findsNothing);
  });

  group('FLUTTER-NN : devise en tête du récapitulatif, modifiable', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      required VoidCallback onChange,
      SupportedCurrency currency = SupportedCurrency.eur,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AnnouncementPreviewSheet.show(
                  context,
                  formState: const AnnouncementFormState(
                    departureCity: 'Paris',
                    arrivalCity: 'Dakar',
                    pricePerKg: 10,
                    availableKg: 5,
                  ),
                  onConfirm: () {},
                  currency: currency,
                  paymentMethods: const ['CASH'],
                  onChangeCurrency: onChange,
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

    testWidgets('ligne « Devise : Euro (EUR) » avant le trajet', (
      tester,
    ) async {
      await pumpSheet(tester, onChange: () {});
      expect(find.text('Devise : Euro (EUR)'), findsOneWidget);
      final currencyY = tester
          .getTopLeft(find.byKey(const Key('preview-currency-row')))
          .dy;
      final tripY = tester.getTopLeft(find.text('Paris → Dakar')).dy;
      expect(currencyY, lessThan(tripY));
    });

    testWidgets('« Modifier » appelle le retour au sélecteur de devise', (
      tester,
    ) async {
      var changes = 0;
      await pumpSheet(
        tester,
        currency: SupportedCurrency.xof,
        onChange: () => changes++,
      );
      expect(find.text('Devise : Franc CFA Ouest (XOF)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('preview-currency-change')));
      await tester.pump();
      expect(changes, 1);
    });

    testWidgets('anglais', (tester) async {
      useEnglish();
      await pumpSheet(tester, onChange: () {});
      expect(find.text('Currency: Euro (EUR)'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });
  });
}
