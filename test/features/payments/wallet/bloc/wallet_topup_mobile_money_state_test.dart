// Constructeurs appelés à l'exécution : deux instances `const` identiques
// court-circuitent la comparaison Equatable.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/value_equality.dart';

WalletTopupStatusModel _status(String status) => WalletTopupStatusModel(
  topupId: 'tp-1',
  status: status,
  amount: 5000,
  currency: 'XOF',
  provider: 'WAVE',
  providerLabel: 'Wave',
  msisdnMasked: '+221 77 *** ** 00',
);

void main() {
  test('Confirmed compare le statut du rechargement', () {
    final paid = _status('SUCCEEDED');
    expectValueEquality(() => WalletTopupMobileMoneyConfirmed(paid), [
      WalletTopupMobileMoneyConfirmed(_status('PENDING')),
    ]);
  });

  test('Confirmed distingue une recharge reprise', () {
    final paid = _status('CONFIRMED');
    expectValueEquality(
      () => WalletTopupMobileMoneyConfirmed(paid, resumed: true),
      [WalletTopupMobileMoneyConfirmed(paid)],
    );
  });

  test('Failed compare le code et le motif du back', () {
    expectValueEquality(
      () => WalletTopupMobileMoneyFailed(
        failureCode: 'insufficient-balance',
        failureReason: 'Solde insuffisant',
      ),
      [
        WalletTopupMobileMoneyFailed(failureCode: 'insufficient-balance'),
        WalletTopupMobileMoneyFailed(
          failureCode: 'other',
          failureReason: 'Solde insuffisant',
        ),
      ],
    );
  });

  test('Overdue compare la recharge', () {
    final topup = _topup('tp-1');
    expectValueEquality(() => WalletTopupMobileMoneyOverdue(topup: topup), [
      WalletTopupMobileMoneyOverdue(topup: _topup('tp-2')),
    ]);
  });

  test('Awaiting : échéance du back, sinon repli à 15 min', () {
    final startedAt = DateTime.utc(2026, 10, 19, 10);
    final server = DateTime.utc(2026, 10, 19, 10, 5);
    expect(
      WalletTopupMobileMoneyAwaiting(
        topup: _topup('tp-1', expiresAt: server),
        startedAt: startedAt,
      ).expiresAt,
      server,
    );
    expect(
      WalletTopupMobileMoneyAwaiting(
        topup: _topup('tp-1'),
        startedAt: startedAt,
      ).expiresAt,
      startedAt.add(walletTopupFallbackExpiry),
    );
  });
}

WalletTopupModel _topup(String id, {DateTime? expiresAt}) => WalletTopupModel(
  topupId: id,
  currency: 'XOF',
  provider: 'ORANGE_CIV',
  providerLabel: 'Orange Money',
  msisdnMasked: '+225 07 •• •• 56',
  expiresAt: expiresAt,
);
