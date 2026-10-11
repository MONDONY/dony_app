// Constructeurs appelés à l'exécution : deux instances `const` identiques
// court-circuitent la comparaison Equatable.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
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

  test('Failed compare la raison et le message de l’opérateur', () {
    expectValueEquality(
      () => WalletTopupMobileMoneyFailed(
        reason: WalletTopupFailureReason.refused,
        operatorMessage: 'Solde insuffisant',
      ),
      [
        WalletTopupMobileMoneyFailed(reason: WalletTopupFailureReason.refused),
        WalletTopupMobileMoneyFailed(
          reason: WalletTopupFailureReason.expired,
          operatorMessage: 'Solde insuffisant',
        ),
      ],
    );
  });
}
