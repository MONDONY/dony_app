import 'package:dony/features/payments/wallet/data/models/wallet_eligible_topup_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletEligibleTopupModel.fromJson', () {
    test('parses all fields', () {
      final model = WalletEligibleTopupModel.fromJson({
        'id': 'tx-1',
        'amount': 30.00,
        'paymentRef': 'pi_111',
        'createdAt': '2026-08-20T10:00:00',
      });

      expect(model.id, 'tx-1');
      expect(model.amount, 30.00);
      expect(model.paymentRef, 'pi_111');
      expect(model.createdAt, DateTime.parse('2026-08-20T10:00:00'));
    });

    test('paymentRef nullable', () {
      final model = WalletEligibleTopupModel.fromJson({
        'id': 'tx-2',
        'amount': 20.00,
        'paymentRef': null,
        'createdAt': '2026-08-20T10:00:00',
      });

      expect(model.paymentRef, isNull);
    });
  });
}
