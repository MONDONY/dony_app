import 'package:flutter_test/flutter_test.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';

void main() {
  test('parses ACCEPTED status', () {
    final r = AcceptanceResponse.fromJson({'status': 'ACCEPTED'});
    expect(r.status, AcceptanceStatus.accepted);
    expect(r.clientSecret, isNull);
    expect(r.paymentIntentId, isNull);
    expect(r.error, isNull);
  });

  test('parses REQUIRES_3DS with clientSecret', () {
    final r = AcceptanceResponse.fromJson({
      'status': 'REQUIRES_3DS',
      'clientSecret': 'pi_xxx_secret',
      'paymentIntentId': 'pi_xxx',
    });
    expect(r.status, AcceptanceStatus.requires3ds);
    expect(r.clientSecret, 'pi_xxx_secret');
    expect(r.paymentIntentId, 'pi_xxx');
  });

  test('parses FAILED with error', () {
    final r = AcceptanceResponse.fromJson({
      'status': 'FAILED',
      'error': 'Carte refusée',
    });
    expect(r.status, AcceptanceStatus.failed);
    expect(r.error, 'Carte refusée');
  });

  test('parses INSUFFICIENT_WALLET with balance details', () {
    final r = AcceptanceResponse.fromJson({
      'status': 'INSUFFICIENT_WALLET',
      'availableBalance': 3.5,
      'requiredCommission': 12.0,
      'hasCard': true,
    });
    expect(r.status, AcceptanceStatus.insufficientWallet);
    expect(r.availableBalance, 3.5);
    expect(r.requiredCommission, 12.0);
    expect(r.hasCard, isTrue);
  });

  test('INSUFFICIENT_WALLET tolerates integer numeric fields', () {
    final r = AcceptanceResponse.fromJson({
      'status': 'INSUFFICIENT_WALLET',
      'availableBalance': 0,
      'requiredCommission': 12,
      'hasCard': false,
    });
    expect(r.availableBalance, 0.0);
    expect(r.requiredCommission, 12.0);
    expect(r.hasCard, isFalse);
  });

  test('unknown status defaults to failed', () {
    final r = AcceptanceResponse.fromJson({'status': 'UNKNOWN'});
    expect(r.status, AcceptanceStatus.failed);
  });

  test('missing status defaults to failed', () {
    final r = AcceptanceResponse.fromJson({});
    expect(r.status, AcceptanceStatus.failed);
  });

  test('ConfirmResponse.fromJson parses accepted true', () {
    final r = ConfirmResponse.fromJson({'accepted': true});
    expect(r.accepted, isTrue);
    expect(r.error, isNull);
  });

  test('ConfirmResponse.fromJson parses accepted false with error', () {
    final r = ConfirmResponse.fromJson({'accepted': false, 'error': '3DS échoué'});
    expect(r.accepted, isFalse);
    expect(r.error, '3DS échoué');
  });
}
