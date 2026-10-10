import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_conditions.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_summary_cards.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carte « Disponible » de « Mon argent » (FLUTTER-J4) : devise active en
/// grand, autres soldes non nuls en petit.
void main() {
  const wallet = [
    MoneyAmount('EUR', 12.5),
    MoneyAmount('XOF', 5000),
    MoneyAmount('GBP', 0),
  ];

  group('orderBalances', () {
    test(
      'devise active en tête, les autres dans leur ordre, zéros retirés',
      () {
        final b = orderBalances(wallet, 'xof');
        expect(b.main?.currency, 'XOF');
        expect(b.others.map((a) => a.currency), ['EUR']);
      },
    );

    test('sans devise active (ancien back) : le premier', () {
      final b = orderBalances(wallet, null);
      expect(b.main?.currency, 'EUR');
      expect(b.others.map((a) => a.currency), ['XOF']);
    });

    test('devise active absente des soldes : le premier', () {
      expect(orderBalances(wallet, 'USD').main?.currency, 'EUR');
    });

    test('devise active à zéro : reste en grand', () {
      final b = orderBalances(wallet, 'GBP');
      expect(b.main?.currency, 'GBP');
      expect(b.others.map((a) => a.currency), ['EUR', 'XOF']);
    });

    test('aucun solde', () {
      final b = orderBalances(const [], 'EUR');
      expect(b.main, isNull);
      expect(b.others, isEmpty);
    });
  });

  Future<void> pump(WidgetTester tester, MoneyOverviewModel overview) =>
      tester.pumpWidget(
        MaterialApp(
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MoneySummaryCards(overview: overview, showBlocked: false),
          ),
        ),
      );

  /// Texte du montant principal (le seul dans un FittedBox).
  String mainAmount(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byType(FittedBox),
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets('devise active en grand, autres soldes dessous, zéro masqué', (
    tester,
  ) async {
    await pump(
      tester,
      const MoneyOverviewModel(wallet: wallet, activeCurrency: 'XOF'),
    );
    expect(mainAmount(tester), formatMoney(5000, 'XOF'));
    expect(find.text('+ ${formatMoney(12.5, 'EUR')}'), findsOneWidget);
    expect(find.textContaining(formatMoney(0, 'GBP')), findsNothing);
  });

  testWidgets('ancien back sans devise active : le premier solde en grand', (
    tester,
  ) async {
    await pump(tester, const MoneyOverviewModel(wallet: wallet));
    expect(mainAmount(tester), formatMoney(12.5, 'EUR'));
    expect(find.text('+ ${formatMoney(5000, 'XOF')}'), findsOneWidget);
  });

  testWidgets('autres soldes tous à zéro : aucune ligne secondaire', (
    tester,
  ) async {
    await pump(
      tester,
      const MoneyOverviewModel(
        wallet: [MoneyAmount('XOF', 5000), MoneyAmount('EUR', 0)],
        activeCurrency: 'XOF',
      ),
    );
    expect(mainAmount(tester), formatMoney(5000, 'XOF'));
    expect(find.textContaining('+ '), findsNothing);
  });

  testWidgets('aucun solde : zéro dans la devise active', (tester) async {
    await pump(tester, const MoneyOverviewModel(activeCurrency: 'XOF'));
    expect(mainAmount(tester), formatMoney(0, 'XOF'));
  });
}
