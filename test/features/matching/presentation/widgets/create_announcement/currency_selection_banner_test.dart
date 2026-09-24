// Tests de CurrencySelectionBanner — bandeau de sélection de la devise de
// publication, étape "Trajet" du formulaire de création d'annonce.
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/currency_selection_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

Widget _host(SupportedCurrency currency) {
  return MaterialApp(
    home: Scaffold(
      body: CurrencySelectionBanner(
        currencyNotifier: ValueNotifier<SupportedCurrency>(currency),
      ),
    ),
  );
}

void main() {
  group('CurrencySelectionBanner', () {
    testWidgets('affiche "Publié en Euro (EUR)" et le bouton "Changer"', (
      tester,
    ) async {
      await tester.pumpWidget(_host(SupportedCurrency.eur));
      expect(find.text('Publié en Euro (EUR)'), findsOneWidget);
      expect(find.text('Changer'), findsOneWidget);
    });
  });

  // ── Group: English (i18n) ─────────────────────────────────────────────────

  group('CurrencySelectionBanner — English', () {
    testWidgets('affiche "Posted in Euro (EUR)" et le bouton "Change"', (
      tester,
    ) async {
      useEnglish();
      await tester.pumpWidget(_host(SupportedCurrency.eur));
      expect(find.text('Posted in Euro (EUR)'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });
  });
}
