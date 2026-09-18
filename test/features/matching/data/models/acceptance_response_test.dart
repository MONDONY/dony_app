import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final r = ConfirmResponse.fromJson({
      'accepted': false,
      'error': '3DS échoué',
    });
    expect(r.accepted, isFalse);
    expect(r.error, '3DS échoué');
  });

  test('INSUFFICIENT_WALLET avec breakdown : parsé', () {
    final r = AcceptanceResponse.fromJson({
      'status': 'INSUFFICIENT_WALLET',
      'availableBalance': 1.33,
      'requiredCommission': 1.60,
      'hasCard': false,
      'currency': 'EUR',
      'breakdown': {
        'bidCurrency': 'XOF',
        'commission': 1050,
        'coveredByBidWallet': 600,
        'remainingBid': 450,
        'remainingInActive': 0.69,
        'activeCurrency': 'EUR',
        'activeBalance': 1.33,
      },
    });

    expect(r.status, AcceptanceStatus.insufficientWallet);
    expect(r.breakdown, isNotNull);
    expect(r.breakdown!.bidCurrency, 'XOF');
    expect(r.breakdown!.commission, 1050);
    expect(r.breakdown!.coveredByBidWallet, 600);
    expect(r.breakdown!.remainingBid, 450);
    expect(r.breakdown!.remainingInActive, 0.69);
    expect(r.breakdown!.activeCurrency, 'EUR');
    expect(r.breakdown!.activeBalance, 1.33);
  });

  test('INSUFFICIENT_WALLET sans breakdown (ancien back) : null', () {
    final r = AcceptanceResponse.fromJson({
      'status': 'INSUFFICIENT_WALLET',
      'availableBalance': 1.33,
      'requiredCommission': 1.60,
      'hasCard': true,
      'currency': 'EUR',
    });

    expect(r.breakdown, isNull);
    expect(r.hasCard, isTrue);
  });
}
