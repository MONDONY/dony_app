import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_money_breakdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'breakdown_fromJson_cardPlusCash : vue voyageur, nets et espèces brutes',
    () {
      final breakdown = BidMoneyBreakdown.fromJson({
        'lines': [
          {
            'kind': 'PRINCIPAL',
            'refId': 'bid-1',
            'method': 'STRIPE',
            'amount': 54.00,
            'status': 'SECURED',
          },
          {
            'kind': 'AMENDMENT',
            'refId': 'am-1',
            'method': 'CASH',
            'amount': 23.50,
            'status': 'SECURED',
          },
        ],
        'total': 77.50,
        'onlineAmount': 54.00,
        'cashAmount': 26.80,
        'cashCommissionPaid': 3.30,
      });

      expect(breakdown.lines, hasLength(2));
      expect(breakdown.lines[0].kind, MoneyLineKind.principal);
      expect(breakdown.lines[0].method, 'STRIPE');
      expect(breakdown.lines[0].paymentMethod, BidPaymentMethod.stripe);
      expect(breakdown.lines[0].isSecured, isTrue);
      expect(breakdown.lines[1].kind, MoneyLineKind.amendment);
      expect(breakdown.lines[1].refId, 'am-1');
      expect(breakdown.lines[1].paymentMethod, BidPaymentMethod.cash);
      expect(breakdown.lines[1].amount, 23.50);
      expect(breakdown.total, 77.50);
      expect(breakdown.onlineAmount, 54.00);
      expect(breakdown.cashAmount, 26.80);
      expect(breakdown.cashCommissionPaid, 3.30);
    },
  );

  test(
    'breakdown_fromJson_sender : jamais de commission, entiers acceptés',
    () {
      final breakdown = BidMoneyBreakdown.fromJson({
        'lines': [
          {
            'kind': 'PRINCIPAL',
            'refId': 'bid-1',
            'method': 'STRIPE',
            'amount': 61,
            'status': 'SECURED',
          },
          {
            'kind': 'AMENDMENT',
            'refId': 'am-2',
            'method': 'MOBILE_MONEY',
            'amount': 12,
            'status': 'PENDING',
          },
        ],
        'total': 61,
        'onlineAmount': 61,
        'cashAmount': 0,
        'cashCommissionPaid': null,
      });

      expect(breakdown.cashCommissionPaid, isNull);
      expect(breakdown.total, 61.0);
      expect(breakdown.lines[1].isSecured, isFalse);
      expect(breakdown.lines[1].paymentMethod, BidPaymentMethod.mobileMoney);
    },
  );

  test('un type de ligne inconnu tombe sur unknown, sans planter', () {
    final breakdown = BidMoneyBreakdown.fromJson({
      'lines': [
        {
          'kind': 'REWARD',
          'refId': 'x',
          'method': 'BITCOIN',
          'amount': 1,
          'status': 'SECURED',
        },
      ],
      'total': 1,
      'onlineAmount': 1,
      'cashAmount': 0,
    });

    expect(breakdown.lines.single.kind, MoneyLineKind.unknown);
    expect(breakdown.lines.single.paymentMethod, isNull);
  });
}
