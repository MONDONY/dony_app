import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletRefundRequestModel.fromJson', () {
    test('parses all fields', () {
      final model = WalletRefundRequestModel.fromJson({
        'id': 'a1b2c3',
        'currency': 'CAD',
        'amount': 45.00,
        'channel': 'AUTOMATIC_STRIPE',
        'status': 'PROCESSING',
        'requestedAt': '2026-08-20T10:00:00',
        'resolvedAt': null,
      });

      expect(model.id, 'a1b2c3');
      expect(model.currency, 'CAD');
      expect(model.amount, 45.00);
      expect(model.channel, 'AUTOMATIC_STRIPE');
      expect(model.status, 'PROCESSING');
      expect(model.resolvedAt, isNull);
    });
  });
}
