import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_balances_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const balances = [
    WalletCurrencyBalanceModel(
      currency: 'EUR',
      balance: 40,
      active: true,
      estimatedInActive: 40,
    ),
    WalletCurrencyBalanceModel(
      currency: 'XOF',
      balance: 6559.57,
      active: false,
      estimatedInActive: 10,
    ),
    WalletCurrencyBalanceModel(currency: 'USD', balance: 5, active: false),
    WalletCurrencyBalanceModel(
      currency: 'CAD',
      balance: 0,
      active: false,
      estimatedInActive: 0,
    ),
  ];

  group('walletTotalInCurrency', () {
    test('total de 50 EUR exprimé en XOF au taux déduit', () {
      final v = walletTotalInCurrency(
        targetCurrency: 'xof',
        estimatedTotal: 50,
        balances: balances,
      );
      expect(v, closeTo(50 * 6559.57 / 10, 0.001));
    });

    test('la devise courante garde son total', () {
      expect(
        walletTotalInCurrency(
          targetCurrency: 'EUR',
          estimatedTotal: 50,
          balances: balances,
        ),
        closeTo(50, 0.001),
      );
    });

    test(
      'null sans total, sans équivalent, à solde nul ou devise inconnue',
      () {
        for (final target in ['XOF', 'USD', 'CAD', 'GBP']) {
          expect(
            walletTotalInCurrency(
              targetCurrency: target,
              estimatedTotal: target == 'XOF' ? null : 50,
              balances: balances,
            ),
            isNull,
            reason: target,
          );
        }
      },
    );
  });

  group('WalletTransactionModel : origine d\'une ligne convertie', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
      'type': 'COMMISSION_DEDUCTED',
      'amount': -0.69,
      'balanceAfter': 1,
      'createdAt': '2026-10-28T10:00:00Z',
      ...extra,
    };

    test('lit la devise (majuscules) et le montant d\'origine', () {
      final tx = WalletTransactionModel.fromJson(
        json({'sourceCurrency': 'xof', 'sourceAmount': 450}),
      );
      expect(tx.sourceCurrency, 'XOF');
      expect(tx.sourceAmount, 450);
      expect(tx.hasSource, isTrue);
    });

    test('absente ou mal formée : aucune origine', () {
      expect(WalletTransactionModel.fromJson(json({})).hasSource, isFalse);
      expect(
        WalletTransactionModel.fromJson(
          json({'sourceCurrency': 3, 'sourceAmount': 450}),
        ).hasSource,
        isFalse,
      );
    });
  });
}
