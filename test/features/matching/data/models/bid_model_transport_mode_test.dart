import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _bid([Map<String, dynamic> extra = const {}]) => {
  'id': 'bid1',
  'announcementId': 'ann1',
  'senderId': 'sender1',
  'weightKg': 5.0,
  'status': 'PENDING',
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
  ...extra,
};

void main() {
  group('BidModel.transportMode', () {
    test('BOAT est lu comme bateau', () {
      final b = BidModel.fromJson(_bid({'transportMode': 'BOAT'}));
      expect(b.transportMode, TransportMode.boat);
    });

    test('champ absent : null (le repli est décidé par l\'écran)', () {
      expect(BidModel.fromJson(_bid()).transportMode, isNull);
    });

    test('valeur inconnue : null, sans planter', () {
      final b = BidModel.fromJson(_bid({'transportMode': 'ROCKET'}));
      expect(b.transportMode, isNull);
    });

    test('aller-retour JSON : le mode est conservé', () {
      final b = BidModel.fromJson(_bid({'transportMode': 'CAR'}));
      expect(BidModel.fromJson(b.toJson()).transportMode, TransportMode.car);
    });
  });

  group('BidModel : paiement au dépôt', () {
    test('depositedAt lu en date, nul sans la clé (back antérieur)', () {
      final b = BidModel.fromJson(
        _bid({
          'payoutTrigger': 'DEPOSIT',
          'depositedAt': '2026-11-26T14:10:00Z',
        }),
      );
      expect(b.depositedAt, DateTime.utc(2026, 11, 26, 14, 10));
      expect(BidModel.fromJson(_bid()).depositedAt, isNull);
      expect(BidModel.fromJson(b.toJson()).depositedAt, b.depositedAt);
    });

    test(
      'isPaidOutAtDeposit : dépôt + carte ou mobile money + colis déposé',
      () {
        BidModel bid({
          String status = 'HANDED_OVER',
          String method = 'STRIPE',
          String trigger = 'DEPOSIT',
        }) => BidModel.fromJson(
          _bid({
            'status': status,
            'paymentMethod': method,
            'payoutTrigger': trigger,
          }),
        );

        expect(bid().isPaidOutAtDeposit, isTrue);
        expect(bid(method: 'MOBILE_MONEY').isPaidOutAtDeposit, isTrue);
        expect(bid(status: 'IN_TRANSIT').isPaidOutAtDeposit, isTrue);
        // Avant le dépôt : le colis est encore remboursable.
        expect(bid(status: 'ACCEPTED').isPaidOutAtDeposit, isFalse);
        // Espèces : aucun paiement de la plateforme versé.
        expect(bid(method: 'CASH').isPaidOutAtDeposit, isFalse);
        // Paiement à la livraison (avion, route) : jamais.
        expect(bid(trigger: 'DELIVERY').isPaidOutAtDeposit, isFalse);
        expect(bid(status: 'CANCELLED').isPaidOutAtDeposit, isFalse);
      },
    );
  });
}
