import 'package:dony/features/matching/data/models/mobile_money_payment_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileMoneyPaymentModel', () {
    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'payment-uuid-1',
          'status': 'PENDING',
          'amount': 50.0,
          'currency': 'XOF',
          'paymentLink': 'https://wave.test/pay?ref=abc',
          'expiresAt': '2026-05-27T20:00:00.000',
          'failureReason': null,
        };

        final model = MobileMoneyPaymentModel.fromJson(json);

        expect(model.id, 'payment-uuid-1');
        expect(model.status, 'PENDING');
        expect(model.amount, 50.0);
        expect(model.currency, 'XOF');
        expect(model.paymentLink, 'https://wave.test/pay?ref=abc');
        expect(model.expiresAt, isNotNull);
        expect(model.failureReason, isNull);
      });

      test('parses amount as int (integer in JSON)', () {
        final json = {
          'id': 'payment-uuid-2',
          'status': 'COMPLETED',
          'amount': 75,
          'currency': 'XOF',
        };

        final model = MobileMoneyPaymentModel.fromJson(json);

        expect(model.amount, 75.0);
        expect(model.amount, isA<double>());
      });

      test('defaults currency to XOF when absent', () {
        final json = {
          'id': 'payment-uuid-3',
          'status': 'PENDING',
          'amount': 50.0,
        };

        final model = MobileMoneyPaymentModel.fromJson(json);

        expect(model.currency, 'XOF');
      });

      test('paymentLink is null when absent', () {
        final json = {
          'id': 'payment-uuid-4',
          'status': 'FAILED',
          'amount': 50.0,
          'currency': 'XOF',
        };

        final model = MobileMoneyPaymentModel.fromJson(json);

        expect(model.paymentLink, isNull);
      });

      test('expiresAt is null when absent', () {
        final json = {
          'id': 'payment-uuid-5',
          'status': 'PENDING',
          'amount': 50.0,
          'currency': 'XOF',
        };

        final model = MobileMoneyPaymentModel.fromJson(json);

        expect(model.expiresAt, isNull);
      });

      test('failureReason is populated when present', () {
        final json = {
          'id': 'payment-uuid-6',
          'status': 'FAILED',
          'amount': 50.0,
          'currency': 'XOF',
          'failureReason': 'Solde insuffisant',
        };

        final model = MobileMoneyPaymentModel.fromJson(json);

        expect(model.failureReason, 'Solde insuffisant');
      });

      test('COMPLETED status parsed correctly', () {
        final json = {
          'id': 'payment-uuid-7',
          'status': 'COMPLETED',
          'amount': 100.0,
          'currency': 'XOF',
        };

        final model = MobileMoneyPaymentModel.fromJson(json);

        expect(model.status, 'COMPLETED');
      });

      test('EXPIRED status parsed correctly', () {
        final json = {
          'id': 'payment-uuid-8',
          'status': 'EXPIRED',
          'amount': 50.0,
          'currency': 'XOF',
        };

        final model = MobileMoneyPaymentModel.fromJson(json);

        expect(model.status, 'EXPIRED');
      });
    });

    group('Equatable props', () {
      test('two models with same data are equal', () {
        const m1 = MobileMoneyPaymentModel(
          id: 'id-1',
          status: 'PENDING',
          amount: 50.0,
          currency: 'XOF',
        );
        const m2 = MobileMoneyPaymentModel(
          id: 'id-1',
          status: 'PENDING',
          amount: 50.0,
          currency: 'XOF',
        );

        expect(m1, equals(m2));
        expect(m1.props, equals(m2.props));
      });

      test('two models with different ids are not equal', () {
        const m1 = MobileMoneyPaymentModel(
          id: 'id-1',
          status: 'PENDING',
          amount: 50.0,
          currency: 'XOF',
        );
        const m2 = MobileMoneyPaymentModel(
          id: 'id-2',
          status: 'PENDING',
          amount: 50.0,
          currency: 'XOF',
        );

        expect(m1, isNot(equals(m2)));
      });

      test('props list contains all fields', () {
        const model = MobileMoneyPaymentModel(
          id: 'id-1',
          status: 'PENDING',
          amount: 50.0,
          currency: 'XOF',
          paymentLink: 'https://wave.test/pay',
          failureReason: null,
        );

        expect(model.props.length, 7);
      });
    });
  });
}
