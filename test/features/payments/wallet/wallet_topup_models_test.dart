import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletTopupModel.fromJson', () {
    test('parses all fields, authorizationUrl présent (Wave)', () {
      final model = WalletTopupModel.fromJson({
        'topupId': 't-1',
        'currency': 'XOF',
        'provider': 'WAVE_SEN',
        'providerLabel': 'Wave',
        'msisdnMasked': '+221 •• •• 12 34',
        'authorizationUrl': 'https://pay.wave.com/xyz',
      });

      expect(model.topupId, 't-1');
      expect(model.currency, 'XOF');
      expect(model.provider, 'WAVE_SEN');
      expect(model.providerLabel, 'Wave');
      expect(model.msisdnMasked, '+221 •• •• 12 34');
      expect(model.authorizationUrl, 'https://pay.wave.com/xyz');
    });

    test('authorizationUrl absent (Orange Money) : reste null', () {
      final model = WalletTopupModel.fromJson({
        'topupId': 't-2',
        'currency': 'XOF',
        'provider': 'ORANGE_CIV',
        'providerLabel': 'Orange Money',
        'msisdnMasked': '+225 •• •• 56 78',
      });

      expect(model.authorizationUrl, isNull);
    });
  });

  group('WalletTopupStatusModel.fromJson', () {
    Map<String, dynamic> baseJson({String status = 'PENDING'}) => {
      'topupId': 't-1',
      'status': status,
      'amount': 5000.0,
      'currency': 'XOF',
      'provider': 'ORANGE_CIV',
      'providerLabel': 'Orange Money',
      'msisdnMasked': '+225 •• •• 56 78',
    };

    test('parses all fields when present', () {
      final model = WalletTopupStatusModel.fromJson({
        ...baseJson(status: 'CONFIRMED'),
        'authorizationUrl': 'https://pay.wave.com/xyz',
        'failureReason': null,
        'walletBalance': 15000.0,
      });

      expect(model.topupId, 't-1');
      expect(model.status, 'CONFIRMED');
      expect(model.amount, 5000.0);
      expect(model.currency, 'XOF');
      expect(model.provider, 'ORANGE_CIV');
      expect(model.providerLabel, 'Orange Money');
      expect(model.msisdnMasked, '+225 •• •• 56 78');
      expect(model.authorizationUrl, 'https://pay.wave.com/xyz');
      expect(model.walletBalance, 15000.0);
    });

    test('champs optionnels absents restent null', () {
      final model = WalletTopupStatusModel.fromJson(baseJson());

      expect(model.authorizationUrl, isNull);
      expect(model.failureReason, isNull);
      expect(model.walletBalance, isNull);
    });

    test('failureReason renseigné sur FAILED', () {
      final model = WalletTopupStatusModel.fromJson({
        ...baseJson(status: 'FAILED'),
        'failureReason': 'INSUFFICIENT_BALANCE',
      });

      expect(model.failureReason, 'INSUFFICIENT_BALANCE');
    });
  });
}
