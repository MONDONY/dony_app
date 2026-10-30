// Règles d'arrivée de l'écran du trajet : « Arrivé à destination »
// (`tripCanMarkArrived`, scan Transit facultatif) et colis à restituer à
// l'annulation (`tripHandedOverParcelCount`).
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_owner_harness.dart';

void main() {
  group('tripCanMarkArrived', () {
    test('tous IN_TRANSIT : oui', () {
      expect(tripCanMarkArrived([ownerBid('b1', 'IN_TRANSIT')]), isTrue);
    });
    test('tous ARRIVED : non (arrivée déjà marquée)', () {
      expect(tripCanMarkArrived([ownerBid('b1', 'ARRIVED')]), isFalse);
    });
    test('ARRIVED restant + COMPLETED : non', () {
      expect(
        tripCanMarkArrived([
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
        tripCanMarkArrived([
          ownerBid('b1', 'HANDED_OVER'),
          ownerBid('b2', 'IN_TRANSIT'),
        ]),
        isTrue,
      );
    });
    test('ARRIVED + un colis resté ACCEPTED : non', () {
      expect(
        tripCanMarkArrived([
          ownerBid('b1', 'ARRIVED'),
          ownerBid('b2', 'ACCEPTED'),
        ]),
        isFalse,
      );
    });
    test('ARRIVED + un colis passé en transit plus tard : oui', () {
      expect(
        tripCanMarkArrived([
          ownerBid('b1', 'ARRIVED'),
          ownerBid('b2', 'IN_TRANSIT'),
        ]),
        isTrue,
      );
    });
    test('colis récupéré sans transit + un ACCEPTED : oui (transit '
        'facultatif, yadony-back #336)', () {
      expect(
        tripCanMarkArrived([
          ownerBid('b1', 'HANDED_OVER'),
          ownerBid('b2', 'ACCEPTED'),
        ]),
        isTrue,
      );
    });
    test('aucun colis récupéré ni arrivé : non', () {
      expect(tripCanMarkArrived([ownerBid('b1', 'ACCEPTED')]), isFalse);
    });
    test('aucun colis actif : non', () {
      expect(tripCanMarkArrived([ownerBid('b1', 'COMPLETED')]), isFalse);
      expect(tripCanMarkArrived(const []), isFalse);
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
