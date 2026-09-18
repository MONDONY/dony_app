import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_currency_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const xof = WalletCurrencyBalanceModel(
    currency: 'XOF',
    balance: 10000,
    active: false,
    refundEligible: true,
    refundableAmount: 10000,
    refundFeeAmount: 100,
    refundNetAmount: 9900,
  );
  const eur = WalletCurrencyBalanceModel(
    currency: 'EUR',
    balance: 40,
    active: true,
    refundEligible: true,
    refundableAmount: 40,
    refundFeeAmount: 1.5,
    refundNetAmount: 38.5,
  );

  Future<WalletCurrencyBalanceModel?> pumpAndOpen(WidgetTester tester) async {
    WalletCurrencyBalanceModel? chosen;
    late Future<WalletCurrencyBalanceModel?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: DonyButton(
              label: 'Ouvrir',
              onPressed: () {
                result = WalletRefundCurrencySheet.show(context, balances: const [eur, xof]);
                result.then((v) => chosen = v);
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    return Future.value(chosen);
  }

  testWidgets('liste une ligne par devise éligible avec brut, frais et net', (tester) async {
    await pumpAndOpen(tester);

    expect(find.text('Quelle devise rembourser ?'), findsOneWidget);
    expect(find.byKey(const Key('wallet-refund-currency-EUR')), findsOneWidget);
    expect(find.byKey(const Key('wallet-refund-currency-XOF')), findsOneWidget);
    expect(find.textContaining('remboursables'), findsNWidgets(2));
    expect(find.textContaining('tu reçois'), findsNWidgets(2));
    expect(find.byType(DonyExpandableChoice<String?>), findsOneWidget);
    // Pas de bouton dans le contenu scrollable : le bouton « Continuer » est
    // dans stickyBottom (le bouton « Ouvrir » qui a déclenché la sheet reste
    // monté sous la modale, d'où le finder ciblé sur le texte plutôt que sur
    // le type DonyButton générique).
    expect(find.widgetWithText(DonyButton, 'Continuer'), findsOneWidget);
  });

  testWidgets('le bouton reste inactif tant qu\'aucune devise n\'est choisie', (tester) async {
    await pumpAndOpen(tester);

    final button = tester.widget<DonyButton>(
      find.widgetWithText(DonyButton, 'Continuer'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('choisir une devise puis continuer renvoie ce solde', (tester) async {
    WalletCurrencyBalanceModel? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: DonyButton(
              label: 'Ouvrir',
              onPressed: () async {
                chosen = await WalletRefundCurrencySheet.show(context, balances: const [eur, xof]);
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wallet-refund-currency-XOF')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(chosen?.currency, 'XOF');
  });
}
