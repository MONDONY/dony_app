// Règles d'arrivée de l'écran du trajet : colis à bord
// (`tripHasParcelsOnBoard`, scan Transit facultatif), « Arrivé à destination »
// seulement sur un trajet parti (`tripCanMarkArrived`, IN_PROGRESS) et colis
// à restituer à l'annulation (`tripHandedOverParcelCount`).
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_owner_harness.dart';

void main() {
  group('tripHasParcelsOnBoard', () {
    test('tous IN_TRANSIT : oui', () {
      expect(tripHasParcelsOnBoard([ownerBid('b1', 'IN_TRANSIT')]), isTrue);
    });
    test('tous ARRIVED : non (arrivée déjà marquée)', () {
      expect(tripHasParcelsOnBoard([ownerBid('b1', 'ARRIVED')]), isFalse);
    });
    test('ARRIVED restant + COMPLETED : non', () {
      expect(
        tripHasParcelsOnBoard([
          ownerBid('b1', 'ARRIVED'),
          ownerBid('b2', 'COMPLETED'),
        ]),
        isFalse,
      );
    });
    // Un colis pas encore parti bloquait tout le trajet, et avec lui la saisie
    // des instructions de retrait (yadony-back #334 : seuls les colis en
    // transit passent en ARRIVED).
    test('un colis encore HANDED_OVER + un IN_TRANSIT : oui', () {
      expect(
        tripHasParcelsOnBoard([
          ownerBid('b1', 'HANDED_OVER'),
          ownerBid('b2', 'IN_TRANSIT'),
        ]),
        isTrue,
      );
    });
    test('ARRIVED + un colis resté ACCEPTED : non', () {
      expect(
        tripHasParcelsOnBoard([
          ownerBid('b1', 'ARRIVED'),
          ownerBid('b2', 'ACCEPTED'),
        ]),
        isFalse,
      );
    });
    test('ARRIVED + un colis passé en transit plus tard : oui', () {
      expect(
        tripHasParcelsOnBoard([
          ownerBid('b1', 'ARRIVED'),
          ownerBid('b2', 'IN_TRANSIT'),
        ]),
        isTrue,
      );
    });
    test('colis récupéré sans transit + un ACCEPTED : oui (transit '
        'facultatif, yadony-back #336)', () {
      expect(
        tripHasParcelsOnBoard([
          ownerBid('b1', 'HANDED_OVER'),
          ownerBid('b2', 'ACCEPTED'),
        ]),
        isTrue,
      );
    });
    test('aucun colis récupéré ni arrivé : non', () {
      expect(tripHasParcelsOnBoard([ownerBid('b1', 'ACCEPTED')]), isFalse);
    });
    test('aucun colis actif : non', () {
      expect(tripHasParcelsOnBoard([ownerBid('b1', 'COMPLETED')]), isFalse);
      expect(tripHasParcelsOnBoard(const []), isFalse);
    });
  });

  // Recette du propriétaire : « Arrivé à destination » s'affichait pendant
  // l'étape de remise (colis HANDED_OVER, trajet pas encore parti). Seul un
  // trajet IN_PROGRESS le propose.
  group('tripCanMarkArrived', () {
    final onBoard = <String, List<String>>{
      'HANDED_OVER': ['HANDED_OVER'],
      'IN_TRANSIT': ['IN_TRANSIT'],
      'HANDED_OVER + ACCEPTED': ['HANDED_OVER', 'ACCEPTED'],
      'ARRIVED + IN_TRANSIT': ['ARRIVED', 'IN_TRANSIT'],
    };
    for (final MapEntry(key: label, value: statuses) in onBoard.entries) {
      final bids = [for (final (i, s) in statuses.indexed) ownerBid('b$i', s)];
      test('IN_PROGRESS + $label : oui', () {
        expect(tripCanMarkArrived('IN_PROGRESS', bids), isTrue);
      });
      for (final status in kTripStatuses.where((s) => s != 'IN_PROGRESS')) {
        test('$status + $label : non (trajet pas parti ou soldé)', () {
          expect(tripCanMarkArrived(status, bids), isFalse);
        });
      }
    }
    test('IN_PROGRESS sans colis à bord : non', () {
      for (final s in ['ACCEPTED', 'ARRIVED', 'COMPLETED']) {
        expect(
          tripCanMarkArrived('IN_PROGRESS', [ownerBid('b1', s)]),
          isFalse,
          reason: s,
        );
      }
      expect(tripCanMarkArrived('IN_PROGRESS', const []), isFalse);
    });
  });

  group('tripHandedOverParcelCount', () {
    test('compte les colis remis, en transit et arrivés', () {
      expect(
        tripHandedOverParcelCount([
          ownerBid('b1', 'HANDED_OVER'),
          ownerBid('b2', 'IN_TRANSIT'),
          ownerBid('b3', 'ARRIVED'),
          ownerBid('b4', 'ACCEPTED'),
          ownerBid('b5', 'PENDING'),
          ownerBid('b6', 'COMPLETED'),
          ownerBid('b7', 'CANCELLED'),
        ]),
        3,
      );
    });

    test('aucun colis remis, liste vide ou pas chargée : 0', () {
      expect(tripHandedOverParcelCount([ownerBid('b1', 'ACCEPTED')]), 0);
      expect(tripHandedOverParcelCount(const []), 0);
      expect(tripHandedOverParcelCount(null), 0);
    });
  });
}
