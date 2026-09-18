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

    test('parses refundableAmount and nonRefundableAmount per currency', () {
      final wallet = WalletModel.fromJson({
        'balance': 40.00,
        'currency': 'EUR',
        'transactions': [],
        'balances': [
          {
            'currency': 'EUR',
            'balance': 40.00,
            'active': true,
            'refundEligible': true,
            'refundableAmount': 35.00,
            'nonRefundableAmount': 5.00,
          },
        ],
      });

      expect(wallet.balances[0].refundableAmount, 35.00);
      expect(wallet.balances[0].nonRefundableAmount, 5.00);
      expect(wallet.activeBalance?.currency, 'EUR');
    });

    test('refundableAmount stays null on the old contract', () {
      final wallet = WalletModel.fromJson({
        'balance': 40.00,
        'currency': 'EUR',
        'transactions': [],
        'balances': [
          {'currency': 'EUR', 'balance': 40.00, 'active': true},
        ],
      });

      expect(wallet.balances[0].refundableAmount, isNull);
      expect(wallet.balances[0].nonRefundableAmount, isNull);
    });

    test('parses refundFeeAmount and refundNetAmount per currency', () {
      final wallet = WalletModel.fromJson({
        'balance': 40.00,
        'currency': 'EUR',
        'transactions': [],
        'balances': [
          {
            'currency': 'EUR',
            'balance': 40.00,
            'active': true,
            'refundEligible': true,
            'refundableAmount': 35.00,
            'nonRefundableAmount': 5.00,
            'refundFeeAmount': 2.00,
            'refundNetAmount': 33.00,
          },
        ],
      });

      expect(wallet.balances[0].refundFeeAmount, 2.00);
      expect(wallet.balances[0].refundNetAmount, 33.00);
    });

    test('refundFeeAmount et refundNetAmount restent null sur l\'ancien '
        'contrat', () {
      final wallet = WalletModel.fromJson({
        'balance': 40.00,
        'currency': 'EUR',
        'transactions': [],
        'balances': [
          {'currency': 'EUR', 'balance': 40.00, 'active': true},
        ],
      });

      expect(wallet.balances[0].refundFeeAmount, isNull);
      expect(wallet.balances[0].refundNetAmount, isNull);
    });

    test('parses provider and msisdnMasked on a transaction', () {
      final wallet = WalletModel.fromJson({
        'balance': 5000.0,
        'currency': 'XOF',
        'transactions': [
          {
            'type': 'TOPUP',
            'amount': 5000.0,
            'balanceAfter': 5000.0,
            'createdAt': '2026-09-15T10:00:00.000Z',
            'provider': 'ORANGE_CIV',
            'msisdnMasked': '+225 •• •• 56 78',
          },
        ],
      });

      expect(wallet.transactions[0].provider, 'ORANGE_CIV');
      expect(wallet.transactions[0].msisdnMasked, '+225 •• •• 56 78');
    });

    test('provider et msisdnMasked restent null sur une transaction sans '
        'ces champs', () {
      final wallet = WalletModel.fromJson({
        'balance': 40.00,
        'currency': 'EUR',
        'transactions': [
          {
            'type': 'TOPUP',
            'amount': 40.00,
            'balanceAfter': 40.00,
            'createdAt': '2026-09-15T10:00:00.000Z',
          },
        ],
      });

      expect(wallet.transactions[0].provider, isNull);
      expect(wallet.transactions[0].msisdnMasked, isNull);
    });

    test('activeBalance is null when no currency is active', () {
      final wallet = WalletModel.fromJson({
        'balance': 0,
        'currency': 'EUR',
        'transactions': [],
        'balances': [
          {'currency': 'CAD', 'balance': 15.00, 'active': false},
        ],
      });

      expect(wallet.activeBalance, isNull);
    });
  });
}
