import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/models/supplement_commission_unfunded.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupplementCommissionUnfunded.fromError', () {
    test('lit le 422 supplement-commission-unfunded complet', () {
      const error = ValidationException(
        'd',
        code: 'supplement-commission-unfunded',
        extensions: {
          'availableBalance': 0.5,
          'requiredCommission': 1.8,
          'shortfall': 1.3,
          'hasCard': true,
          'currency': 'eur',
          'bidCurrency': 'xof',
          'breakdown': {
            'bidCurrency': 'XOF',
            'commission': 1200,
            'coveredByBidWallet': 0,
            'remainingBid': 1200,
            'remainingInActive': 1.8,
            'activeCurrency': 'EUR',
            'activeBalance': 0.5,
          },
          'alternatives': [
            {'currency': 'gbp', 'balance': 20, 'required': 1.6},
            {'currency': '', 'required': 1},
          ],
        },
      );

      final u = SupplementCommissionUnfunded.fromError(error)!;

      expect(u.availableBalance, 0.5);
      expect(u.requiredCommission, 1.8);
      expect(u.shortfall, 1.3);
      expect(u.hasCard, isTrue);
      expect(u.currency, 'EUR');
      expect(u.bidCurrency, 'XOF');
      expect(u.breakdown?.activeCurrency, 'EUR');
      expect(u.alternatives.map((a) => a.currency), ['GBP']);
      expect(u, SupplementCommissionUnfunded.fromError(error));
    });

    test('champs absents ou mal formés : valeurs neutres', () {
      const error = ValidationException(
        'd',
        code: 'supplement-commission-unfunded',
        extensions: {
          'breakdown': {'bidCurrency': 3},
          'currency': 7,
        },
      );

      final u = SupplementCommissionUnfunded.fromError(error)!;

      expect(u.availableBalance, 0);
      expect(u.shortfall, 0);
      expect(u.hasCard, isFalse);
      expect(u.currency, isNull);
      expect(u.breakdown, isNull);
      expect(u.alternatives, isEmpty);
    });

    test('sans extensions : lu quand même', () {
      const error = ValidationException(
        'd',
        code: 'supplement-commission-unfunded',
      );
      expect(SupplementCommissionUnfunded.fromError(error)?.hasCard, isFalse);
    });

    test('autre erreur : null', () {
      expect(
        SupplementCommissionUnfunded.fromError(
          const ValidationException('d', code: 'commission-method-missing'),
        ),
        isNull,
      );
      expect(
        SupplementCommissionUnfunded.fromError(
          const ConflictException('d', code: 'supplement-commission-unfunded'),
        ),
        isNull,
      );
    });
  });

  group('BidSupplement espèces', () {
    test('commissionClientSecret lu mais jamais réécrit en JSON', () {
      final s = BidSupplement.fromJson({
        'id': 'sup-1',
        'status': 'COMMISSION_PENDING',
        'rail': 'CASH',
        'grossAmount': 16.8,
        'commissionStatus': 'REQUIRES_3DS',
        'commissionClientSecret': 'pi_secret',
      });
      expect(s.needsCommissionAuth, isTrue);
      expect(s.toJson().containsKey('commissionClientSecret'), isFalse);
    });

    test('ancien back : pas de secret, pas de 3DS à présenter', () {
      final s = BidSupplement.fromJson({
        'id': 'sup-1',
        'status': 'COMMISSION_PENDING',
        'grossAmount': 16.8,
      });
      expect(s.commissionClientSecret, isNull);
      expect(s.needsCommissionAuth, isFalse);
      expect(s.isCash, isFalse);
    });

    test('états de la commission', () {
      const charged = BidSupplement(
        id: 's',
        status: BidSupplementStatus.proposed,
        rail: 'CASH',
        grossAmount: 1,
        commissionStatus: SupplementCommissionStatus.charged,
      );
      expect(charged.commissionCharged, isTrue);
      expect(charged.commissionRefunded, isFalse);
      const refunded = BidSupplement(
        id: 's',
        status: BidSupplementStatus.declined,
        grossAmount: 1,
        commissionStatus: SupplementCommissionStatus.refunded,
      );
      expect(refunded.commissionRefunded, isTrue);
    });

    test('SupplementCheckout espèces', () {
      final c = SupplementCheckout.fromJson({
        'supplement': {
          'id': 'sup-1',
          'status': 'PAID',
          'rail': 'CASH',
          'grossAmount': 16.8,
        },
        'rail': 'CASH',
        'clientSecret': null,
        'paymentMethodTypes': null,
        'amount': 16.8,
        'currency': 'EUR',
      });
      expect(c.isCash, isTrue);
      expect(c.needsPayment, isFalse);
      expect(c.isMobileMoney, isFalse);
    });
  });
}
