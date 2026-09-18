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

    test(
      'la devise de chaque ligne vient du back, pas du portefeuille actif',
      () {
        final wallet = WalletModel.fromJson({
          'balance': 1.33,
          'currency': 'EUR',
          'transactions': [
            {
              'type': 'TOP_UP',
              'amount': 10000.0,
              'currency': 'xof',
              'balanceAfter': 10000.0,
              'paymentRef': 'pawapay:11111111-1111-1111-1111-111111111111',
              'createdAt': '2026-09-18T12:26:00.000Z',
            },
            {
              'type': 'REFUND',
              'amount': 1.33,
              'balanceAfter': 1.33,
              'createdAt': '2026-09-18T14:34:00.000Z',
            },
          ],
        });

        expect(wallet.transactions[0].currency, 'XOF');
        expect(wallet.transactions[1].currency, isNull);
      },
    );

    test('isMobileMoneyTopup est vrai pour un paymentRef préfixé pawapay:', () {
      final wallet = WalletModel.fromJson({
        'balance': 5000.0,
        'currency': 'XOF',
        'transactions': [
          {
            'type': 'TOPUP',
            'amount': 5000.0,
            'balanceAfter': 5000.0,
            'paymentRef': 'pawapay:11111111-1111-1111-1111-111111111111',
            'createdAt': '2026-09-15T10:00:00.000Z',
          },
        ],
      });

      expect(wallet.transactions[0].isMobileMoneyTopup, isTrue);
    });

    test('isMobileMoneyTopup est faux pour un paymentRef Stripe (pi_...)', () {
      final wallet = WalletModel.fromJson({
        'balance': 40.00,
        'currency': 'EUR',
        'transactions': [
          {
            'type': 'TOPUP',
            'amount': 40.00,
            'balanceAfter': 40.00,
            'paymentRef': 'pi_123',
            'createdAt': '2026-09-15T10:00:00.000Z',
          },
        ],
      });

      expect(wallet.transactions[0].isMobileMoneyTopup, isFalse);
    });

    test('isMobileMoneyTopup est faux quand paymentRef est absent', () {
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

      expect(wallet.transactions[0].isMobileMoneyTopup, isFalse);
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
