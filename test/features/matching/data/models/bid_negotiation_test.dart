import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fil servi par le back à commission par paliers (yadony-back, commission
/// par grille) : grille figée du bid, réductions figées servies au seul
/// voyageur.
Map<String, dynamic> _json({
  String role = 'TRAVELER',
  Object? commissionGridId = 'g-thread',
  Object? commissionRate,
  Object? commissionOverrideRate,
  Object? commissionVoucherFactor,
}) => {
  'bidId': 'bid-1',
  'announcementId': 'ann-1',
  'status': 'NEGOTIATING',
  'role': role,
  'proposedGrossEur': 51.0,
  'commissionGridId': ?commissionGridId,
  'commissionRate': ?commissionRate,
  'commissionOverrideRate': ?commissionOverrideRate,
  'commissionVoucherFactor': ?commissionVoucherFactor,
};

void main() {
  group('BidNegotiation : grille et réductions figées', () {
    test('lit commissionGridId, commissionOverrideRate, '
        'commissionVoucherFactor', () {
      final t = BidNegotiation.fromJson(
        _json(
          commissionRate: 0.12,
          commissionOverrideRate: 0.04,
          commissionVoucherFactor: 0.5,
        ),
      );
      expect(t.commissionGridId, 'g-thread');
      expect(t.commissionOverrideRate, 0.04);
      expect(t.commissionVoucherFactor, 0.5);
    });

    test('ancien back : les trois champs sont nuls', () {
      final t = BidNegotiation.fromJson(_json(commissionGridId: null));
      expect(t.commissionGridId, isNull);
      expect(t.commissionOverrideRate, isNull);
      expect(t.commissionVoucherFactor, isNull);
    });

    test('counterInNet vrai pour un voyageur sur un fil à grille sans '
        'commissionRate', () {
      final t = BidNegotiation.fromJson(_json());
      expect(t.commissionRate, isNull);
      expect(t.counterInNet, isTrue);
    });

    test('expéditeur sur un fil à grille : saisie brute', () {
      final t = BidNegotiation.fromJson(_json(role: 'SENDER'));
      expect(t.counterInNet, isFalse);
    });

    test('voyageur sans grille ni taux : saisie brute', () {
      final t = BidNegotiation.fromJson(_json(commissionGridId: null));
      expect(t.counterInNet, isFalse);
    });
  });
}
