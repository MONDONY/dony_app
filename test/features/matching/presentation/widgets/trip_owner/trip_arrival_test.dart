// Colis à restituer à l'annulation du trajet (`tripHandedOverParcelCount`).
// Les cas de `tripArrivalCtaFor` sont dans `trip_owner_detail_screen_test`.
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_owner_harness.dart';

void main() {
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
