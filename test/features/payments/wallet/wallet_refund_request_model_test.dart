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

    test('parses feeAmount, netAmount, rail and destinationMasked when '
        'present', () {
      final model = WalletRefundRequestModel.fromJson({
        'id': 'r1',
        'currency': 'XOF',
        'amount': 5000.0,
        'channel': 'AUTOMATIC_PAWAPAY',
        'status': 'PROCESSING',
        'requestedAt': '2026-09-15T10:00:00',
        'feeAmount': 150.0,
        'netAmount': 4850.0,
        'rail': 'PAWAPAY',
        'destinationMasked': '+225 •• •• 56 78',
      });

      expect(model.feeAmount, 150.0);
      expect(model.netAmount, 4850.0);
      expect(model.rail, 'PAWAPAY');
      expect(model.destinationMasked, '+225 •• •• 56 78');
    });

    test('feeAmount, netAmount, rail et destinationMasked restent null sur '
        'l\'ancien contrat', () {
      final model = WalletRefundRequestModel.fromJson({
        'id': 'r1',
        'currency': 'EUR',
        'amount': 45.00,
        'channel': 'AUTOMATIC_STRIPE',
        'status': 'PROCESSING',
        'requestedAt': '2026-08-20T10:00:00',
      });

      expect(model.feeAmount, isNull);
      expect(model.netAmount, isNull);
      expect(model.rail, isNull);
      expect(model.destinationMasked, isNull);
    });
  });
}
