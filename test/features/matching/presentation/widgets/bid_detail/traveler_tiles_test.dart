import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tiles.dart';
import 'package:flutter_test/flutter_test.dart';

const _handover = AddressData(
  label: '22 Rue du Séminaire, 94550 Chevilly-Larue, France',
  lat: 48.7667,
  lng: 2.3508,
);
const _delivery = AddressData(
  label: 'ACI 2000, Bamako, Mali',
  lat: 12.6362,
  lng: -8.0121,
);

BidModel _bid(
  String status, {
  AddressData? handoverAddress,
  AddressData? deliveryAddress,
  String? handoverLocation,
  String? arrivalInstructions,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  handoverAddress: handoverAddress,
  deliveryAddress: deliveryAddress,
  handoverLocation: handoverLocation,
  arrivalInstructions: arrivalInstructions,
);

/// Statuts où le colis est encore dans la course : « Lieux » a un sens.
const _openStatuses = [
  'PENDING',
  'PAYMENT_ESCROWED',
  'AWAITING_PAYMENT',
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'DELIVERED',
  'COMPLETED',
];

/// Statuts clos : plus de lieu à montrer, même si les adresses sont connues.
const _closedStatuses = [
  'CANCELLED',
  'REJECTED',
  'NO_SHOW',
  'EXPIRED',
  'PARCEL_REFUSED',
];

void main() {
  group('travelerTilesFor : statut ouvert', () {
    for (final status in _openStatuses) {
      test('$status avec les deux adresses → [lieux, colis, details]', () {
        final bid = _bid(
          status,
          handoverAddress: _handover,
          deliveryAddress: _delivery,
        );
        expect(travelerTilesFor(bid), [
          TravelerTile.lieux,
          TravelerTile.colis,
          TravelerTile.details,
        ]);
      });

      test('$status sans aucune adresse → [colis, details]', () {
        expect(travelerTilesFor(_bid(status)), [
          TravelerTile.colis,
          TravelerTile.details,
        ]);
      });
    }
  });

  group('travelerTilesFor : statut clos', () {
    for (final status in _closedStatuses) {
      test('$status avec adresses → [colis, details]', () {
        final bid = _bid(
          status,
          handoverAddress: _handover,
          deliveryAddress: _delivery,
          arrivalInstructions: 'Sonner deux fois',
        );
        expect(travelerTilesFor(bid), [
          TravelerTile.colis,
          TravelerTile.details,
        ]);
      });

      test('$status sans adresse → [colis, details]', () {
        expect(travelerTilesFor(_bid(status)), [
          TravelerTile.colis,
          TravelerTile.details,
        ]);
      });
    }
  });

  group('travelerTilesFor : ce qui fait exister « Lieux »', () {
    test('seule l\'adresse de dépôt', () {
      expect(
        travelerTilesFor(_bid('ACCEPTED', handoverAddress: _handover)),
        contains(TravelerTile.lieux),
      );
    });

    test('seule l\'adresse de récupération', () {
      expect(
        travelerTilesFor(_bid('IN_TRANSIT', deliveryAddress: _delivery)),
        contains(TravelerTile.lieux),
      );
    });

    test('seul le texte du lieu de dépôt (ancien colis sans adresse)', () {
      expect(
        travelerTilesFor(_bid('ACCEPTED', handoverLocation: 'Gare de Lyon')),
        contains(TravelerTile.lieux),
      );
    });

    test('seules les consignes de retrait', () {
      expect(
        travelerTilesFor(
          _bid('ARRIVED', arrivalInstructions: 'Appelez à votre arrivée'),
        ),
        contains(TravelerTile.lieux),
      );
    });

    test('texte et consignes vides ou blancs → pas de « Lieux »', () {
      expect(
        travelerTilesFor(
          _bid('ACCEPTED', handoverLocation: '  ', arrivalInstructions: ' '),
        ),
        [TravelerTile.colis, TravelerTile.details],
      );
      expect(
        travelerTilesFor(
          _bid('ACCEPTED', handoverLocation: '', arrivalInstructions: ''),
        ),
        [TravelerTile.colis, TravelerTile.details],
      );
    });

    test('squelette (statut vide, rien de chargé) → [colis, details]', () {
      expect(travelerTilesFor(BidModel.skeleton('bid-001')), [
        TravelerTile.colis,
        TravelerTile.details,
      ]);
    });
  });

  test('ACCEPTED puis EXPIRED : « Lieux » disparaît avec le statut clos', () {
    final accepted = _bid('ACCEPTED', handoverAddress: _handover);
    final expired = _bid('EXPIRED', handoverAddress: _handover);
    expect(travelerTilesFor(accepted), contains(TravelerTile.lieux));
    expect(travelerTilesFor(expired), isNot(contains(TravelerTile.lieux)));
  });
}
