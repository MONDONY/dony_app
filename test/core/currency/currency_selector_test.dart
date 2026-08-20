import 'package:dony/core/currency/currency_selector.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/currency_test_doubles.dart';

void main() {
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    required List<CurrencyPaymentOption> options,
    SupportedCurrency? initialCurrency,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CurrencySelector.show(
                context,
                options: options,
                initialCurrency: initialCurrency,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('la devise du portefeuille est proposée par défaut', (
    tester,
  ) async {
    registerCurrencyPreference('USD');

    await pumpAndOpen(
      tester,
      options: [
        const CurrencyPaymentOption(
          currency: SupportedCurrency.usd,
          availablePaymentMethods: {BidPaymentMethod.cash},
        ),
      ],
    );

    // La feuille annonce d'emblée les moyens de paiement de la devise du
    // portefeuille (USD), sans que l'utilisateur ait rien sélectionné.
    expect(find.text('Espèces uniquement en USD'), findsOneWidget);
    expect(find.text('Confirmer USD'), findsOneWidget);
  });

  testWidgets('sans devise en cache, la sélection retombe sur EUR', (
    tester,
  ) async {
    registerCurrencyPreference(null);

    await pumpAndOpen(
      tester,
      options: [
        const CurrencyPaymentOption(
          currency: SupportedCurrency.eur,
          availablePaymentMethods: {
            BidPaymentMethod.stripe,
            BidPaymentMethod.cash,
          },
        ),
      ],
    );

    expect(find.text('Carte et espèces disponibles en EUR'), findsOneWidget);
    expect(find.text('Confirmer EUR'), findsOneWidget);
  });

  testWidgets('choisir une devise sans rail carte annoncé par le serveur '
      'affiche que seule l\'espèce sera possible', (tester) async {
    registerCurrencyPreference('EUR');

    await pumpAndOpen(
      tester,
      options: [
        const CurrencyPaymentOption(
          currency: SupportedCurrency.eur,
          availablePaymentMethods: {
            BidPaymentMethod.stripe,
            BidPaymentMethod.cash,
          },
        ),
        // XOF : le serveur n'annonce que l'espèce (devise non prise en
        // charge par Stripe, ou voyageur sans Connect) — le composant ne
        // recalcule rien, il relaie tel quel.
        const CurrencyPaymentOption(
          currency: SupportedCurrency.xof,
          availablePaymentMethods: {BidPaymentMethod.cash},
        ),
      ],
    );

    // Départ : EUR a le rail carte d'après le serveur.
    expect(find.text('Carte et espèces disponibles en EUR'), findsOneWidget);

    await tester.tap(find.text('${SupportedCurrency.xof.displayName} (XOF)'));
    await tester.pumpAndSettle();

    expect(find.text('Espèces uniquement en XOF'), findsOneWidget);
    expect(find.text('Carte et espèces disponibles en EUR'), findsNothing);
    expect(find.text('Confirmer XOF'), findsOneWidget);
  });

  testWidgets('le message est explicite sur le pourquoi de l\'espèce seule', (
    tester,
  ) async {
    registerCurrencyPreference('XAF');

    await pumpAndOpen(
      tester,
      options: [
        const CurrencyPaymentOption(
          currency: SupportedCurrency.xaf,
          availablePaymentMethods: {BidPaymentMethod.cash},
        ),
      ],
    );

    expect(
      find.textContaining('voyageur n\'a pas encore activé les paiements'),
      findsOneWidget,
    );
    expect(
      find.textContaining('n\'est pas prise en charge par Stripe'),
      findsOneWidget,
    );
  });

  testWidgets('une devise absente des options reçues du serveur est traitée '
      'comme espèces uniquement, jamais comme carte disponible', (
    tester,
  ) async {
    registerCurrencyPreference('GBP');

    // Aucune option fournie pour GBP : le composant ne doit jamais
    // supposer que la carte est disponible faute de donnée serveur.
    await pumpAndOpen(tester, options: const []);

    expect(find.text('Espèces uniquement en GBP'), findsOneWidget);
  });

  testWidgets('aucun tiret cadratin dans les libellés affichés', (
    tester,
  ) async {
    registerCurrencyPreference('EUR');

    await pumpAndOpen(
      tester,
      options: [
        const CurrencyPaymentOption(
          currency: SupportedCurrency.eur,
          availablePaymentMethods: {
            BidPaymentMethod.stripe,
            BidPaymentMethod.cash,
          },
        ),
        const CurrencyPaymentOption(
          currency: SupportedCurrency.xof,
          availablePaymentMethods: {BidPaymentMethod.cash},
        ),
      ],
    );

    await tester.tap(find.text('${SupportedCurrency.xof.displayName} (XOF)'));
    await tester.pumpAndSettle();

    final texts = tester.widgetList<Text>(find.byType(Text));
    for (final widget in texts) {
      final value = widget.data;
      if (value != null) {
        expect(value.contains('—'), isFalse, reason: value);
      }
    }
  });
}
