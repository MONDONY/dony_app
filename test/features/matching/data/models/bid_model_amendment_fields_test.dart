import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_money_breakdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// JSON d'un back qui ne connaît pas encore les modifications de colis.
Map<String, dynamic> _legacyJson() => {
  'id': 'bid-001',
  'announcementId': 'ann-001',
  'senderId': 'sender-001',
  'weightKg': 5.0,
  'status': 'ACCEPTED',
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-15T00:00:00.000Z',
  'supplementRequestAllowed': true,
};

void main() {
  test('bid_model_parses_without_amendment_fields', () {
    final bid = BidModel.fromJson(_legacyJson());

    expect(bid.amendments, isEmpty);
    expect(bid.amendmentAllowed, isFalse);
    expect(bid.moneyBreakdown, isNull);
    expect(bid.totalWeightKg, isNull);
    expect(bid.supplementRequestAllowed, isTrue);
  });

  test('un ancien back peut envoyer des champs nuls', () {
    final bid = BidModel.fromJson({
      ..._legacyJson(),
      'amendments': null,
      'amendmentAllowed': null,
      'moneyBreakdown': null,
      'totalWeightKg': null,
    });

    expect(bid.amendments, isEmpty);
    expect(bid.amendmentAllowed, isFalse);
    expect(bid.moneyBreakdown, isNull);
  });

  test('bid_model_parses_amendment_fields', () {
    final bid = BidModel.fromJson({
      ..._legacyJson(),
      'amendments': [
        {
          'id': 'am-1',
          'status': 'ACCEPTED',
          'rail': 'CASH',
          'grossAmount': 26.8,
          'netAmount': 23.5,
          'commissionAmount': 3.3,
        },
      ],
      'amendmentAllowed': true,
      'totalWeightKg': 7.5,
      'moneyBreakdown': {
        'lines': [
          {
            'kind': 'AMENDMENT',
            'refId': 'am-1',
            'method': 'CASH',
            'amount': 23.5,
            'status': 'SECURED',
          },
        ],
        'total': 23.5,
        'onlineAmount': 0,
        'cashAmount': 26.8,
        'cashCommissionPaid': 3.3,
      },
    });

    expect(bid.amendments.single.status, BidAmendmentStatus.accepted);
    expect(bid.amendments.single.netAmount, 23.5);
    expect(bid.amendmentAllowed, isTrue);
    expect(bid.totalWeightKg, 7.5);
    expect(bid.moneyBreakdown!.cashAmount, 26.8);
    expect(bid.moneyBreakdown!.lines.single.kind, MoneyLineKind.amendment);
  });
  group('poids affiché', () {
    BidModel bidWith({double? weightKg, double? totalWeightKg}) =>
        BidModel.fromJson({
          ..._legacyJson(),
          'weightKg': weightKg,
          'totalWeightKg': totalWeightKg,
        });

    test('displayWeightKg garde le poids du colis sur un back antérieur', () {
      final bid = bidWith(weightKg: 5);

      expect(bid.displayWeightKg, 5);
      expect(bid.acquiredAddedWeightKg, 0);
    });

    test('displayWeightKg prend le poids avec les modifications acquises', () {
      final bid = bidWith(weightKg: 5, totalWeightKg: 7.5);

      expect(bid.displayWeightKg, 7.5);
      expect(bid.acquiredAddedWeightKg, 2.5);
    });

    test('colis en grille pure : les kilos acquis comptent quand même', () {
      final bid = bidWith(totalWeightKg: 2);

      expect(bid.displayWeightKg, 2);
      expect(bid.acquiredAddedWeightKg, 2);
    });

    test('sans aucun poids, displayWeightKg est nul', () {
      final bid = bidWith();

      expect(bid.displayWeightKg, isNull);
      expect(bid.acquiredAddedWeightKg, 0);
    });
  });
}
