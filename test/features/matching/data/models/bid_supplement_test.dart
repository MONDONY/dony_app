import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _supplementJson({
  String status = 'PROPOSED',
  bool withNet = true,
}) => {
  'id': 'sup-1',
  'status': status,
  'rail': 'STRIPE',
  'currency': 'EUR',
  'netAmount': withNet ? 15 : null,
  'commissionAmount': withNet ? 1.8 : null,
  'grossAmount': 16.8,
  'reasonCode': 'GRID_ITEM',
  'reasonText': 'Un téléphone',
  'gridItemLabel': 'Téléphone',
  'photoUrl': 'https://r2.test/tracking/bid-1/x.jpg?sig=1',
  'expiresAt': '2026-10-19T12:30:00Z',
  'paidAt': null,
  'commissionStatus': null,
  'blocksHandover': true,
};

Map<String, dynamic> _bidJson([Map<String, dynamic> extra = const {}]) => {
  'id': 'bid-1',
  'announcementId': 'ann-1',
  'senderId': 'sender-1',
  'status': 'ACCEPTED',
  'createdAt': '2026-10-01T10:00:00',
  'updatedAt': '2026-10-01T10:00:00',
  ...extra,
};

void main() {
  group('BidSupplement.fromJson', () {
    test('lit un supplément complet vu par le voyageur', () {
      final s = BidSupplement.fromJson(_supplementJson());

      expect(s.id, 'sup-1');
      expect(s.status, BidSupplementStatus.proposed);
      expect(s.rail, 'STRIPE');
      expect(s.netAmount, 15);
      expect(s.commissionAmount, 1.8);
      expect(s.grossAmount, 16.8);
      expect(s.reason, BidSupplementReason.gridItem);
      expect(s.gridItemLabel, 'Téléphone');
      expect(s.expiresAt, DateTime.utc(2026, 10, 19, 12, 30));
      expect(s.blocksHandover, isTrue);
    });

    test("côté expéditeur, le net et la commission sont nuls", () {
      final s = BidSupplement.fromJson(_supplementJson(withNet: false));

      expect(s.netAmount, isNull);
      expect(s.commissionAmount, isNull);
      expect(s.grossAmount, 16.8);
    });

    test('un statut ou un motif inconnu ne casse pas le parsing', () {
      final s = BidSupplement.fromJson({
        ..._supplementJson(status: 'SOMETHING_NEW'),
        'reasonCode': 'NEW_REASON',
        'blocksHandover': null,
        'currency': null,
      });

      expect(s.status, BidSupplementStatus.unknown);
      expect(s.reason, isNull);
      expect(s.blocksHandover, isFalse);
      expect(s.currency, 'EUR');
    });

    test('toJson rend les mêmes valeurs', () {
      final json = BidSupplement.fromJson(_supplementJson()).toJson();
      expect(json['status'], 'PROPOSED');
      expect(json['grossAmount'], 16.8);
    });
  });

  group('BidSupplementStatus', () {
    test('ouvert, payé, remboursé', () {
      expect(BidSupplementStatus.commissionPending.isOpen, isTrue);
      expect(BidSupplementStatus.proposed.isOpen, isTrue);
      expect(BidSupplementStatus.paymentPending.isOpen, isTrue);
      expect(BidSupplementStatus.paid.isOpen, isFalse);
      expect(BidSupplementStatus.paid.isPaid, isTrue);
      expect(BidSupplementStatus.payoutPending.isPaid, isTrue);
      expect(BidSupplementStatus.paidOut.isPaid, isTrue);
      expect(BidSupplementStatus.declined.isPaid, isFalse);
      expect(BidSupplementStatus.refundPending.isRefunded, isTrue);
      expect(BidSupplementStatus.refunded.isRefunded, isTrue);
      expect(BidSupplementStatus.expired.isRefunded, isFalse);
    });
  });

  group('BidSupplementReason', () {
    test('valeurs API et analytics', () {
      expect(
        BidSupplementReason.fromApi('EXTRA_WEIGHT'),
        BidSupplementReason.extraWeight,
      );
      expect(BidSupplementReason.fromApi('OTHER'), BidSupplementReason.other);
      expect(BidSupplementReason.fromApi(null), isNull);
      expect(BidSupplementReason.gridItem.analyticsValue, 'grid_item');
    });
  });

  group('SupplementOptions / SupplementQuote', () {
    test('lit les bornes, les suggestions et le rail', () {
      final o = SupplementOptions.fromJson({
        'currency': 'XOF',
        'minNet': 656,
        'maxNet': 196787,
        'suggestions': [
          {'kind': 'GRID_ITEM', 'label': 'Téléphone', 'unitNet': 10000},
          {'kind': 'KG', 'label': null, 'unitNet': 5000},
        ],
        'rail': 'PAWAPAY',
      });

      expect(o.currency, 'XOF');
      expect(o.minNet, 656);
      expect(o.maxNet, 196787);
      expect(o.rail, 'PAWAPAY');
      expect(o.suggestions, hasLength(2));
      expect(o.suggestions.first.isGridItem, isTrue);
      expect(o.suggestions.first.label, 'Téléphone');
      expect(o.suggestions.last.isGridItem, isFalse);
      expect(o.suggestions.last.unitNet, 5000);
    });

    test('suggestions absentes : liste vide, devise par défaut', () {
      final o = SupplementOptions.fromJson({'minNet': 1, 'maxNet': 300});
      expect(o.suggestions, isEmpty);
      expect(o.currency, 'EUR');
    });

    test('lit un devis', () {
      final q = SupplementQuote.fromJson({
        'netAmount': 20,
        'commissionAmount': 2.4,
        'grossAmount': 22.4,
        'currency': 'EUR',
      });
      expect(q.netAmount, 20);
      expect(q.commissionAmount, 2.4);
      expect(q.grossAmount, 22.4);
      expect(q.currency, 'EUR');
    });
  });

  group('BidModel', () {
    test('ancien JSON : pas de supplément, demande non autorisée', () {
      final bid = BidModel.fromJson(_bidJson());

      expect(bid.supplement, isNull);
      expect(bid.supplementRequestAllowed, isFalse);
      expect(bid.totalSenderAmountWithSupplementEur, isNull);
      expect(bid.totalNetAmountWithSupplementEur, isNull);
    });

    test('lit le supplément et les totaux avec supplément', () {
      final bid = BidModel.fromJson(
        _bidJson({
          'supplement': _supplementJson(status: 'PAID'),
          'supplementRequestAllowed': true,
          'totalSenderAmountWithSupplementEur': 56.8,
          'totalNetAmountWithSupplementEur': 50,
        }),
      );

      expect(bid.supplement?.status, BidSupplementStatus.paid);
      expect(bid.supplementRequestAllowed, isTrue);
      expect(bid.totalSenderAmountWithSupplementEur, 56.8);
      expect(bid.totalNetAmountWithSupplementEur, 50);
    });
  });
}
