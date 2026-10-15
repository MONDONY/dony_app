import 'package:dony/features/payments/wallet/data/models/wallet_topup_code_redemption_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson lit montant, devise et solde (entiers ou décimaux)', () {
    final m = WalletTopupCodeRedemptionModel.fromJson({
      'amount': 2000,
      'currency': 'XOF',
      'balance': 3500.0,
      'transactionId': 'tx-1',
    });
    expect(m.amount, 2000.0);
    expect(m.currency, 'XOF');
    expect(m.balance, 3500.0);
    expect(m.transactionId, 'tx-1');
  });
}
