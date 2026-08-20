import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletModel.fromJson', () {
    test('parses balances with active flag per currency', () {
      final wallet = WalletModel.fromJson({
        'balance': 47.50,
        'currency': 'EUR',
        'transactions': [],
        'balances': [
          {'currency': 'EUR', 'balance': 47.50, 'active': true},
          {'currency': 'CAD', 'balance': 15.00, 'active': false},
        ],
      });

      expect(wallet.balances, hasLength(2));
      expect(wallet.balances[0].currency, 'EUR');
      expect(wallet.balances[0].active, isTrue);
      expect(wallet.balances[1].currency, 'CAD');
      expect(wallet.balances[1].balance, 15.00);
      expect(wallet.balances[1].active, isFalse);
    });

    test('defaults to empty balances when field is absent', () {
      final wallet = WalletModel.fromJson({
        'balance': 0,
        'currency': 'EUR',
        'transactions': [],
      });

      expect(wallet.balances, isEmpty);
    });

    test('parses refundEligible flag', () {
      final wallet = WalletModel.fromJson({
        'balance': 40.00,
        'currency': 'EUR',
        'transactions': [],
        'refundEligible': true,
      });

      expect(wallet.refundEligible, isTrue);
    });

    test('defaults refundEligible to false when absent', () {
      final wallet = WalletModel.fromJson({
        'balance': 0,
        'currency': 'EUR',
        'transactions': [],
      });

      expect(wallet.refundEligible, isFalse);
    });
  });
}
