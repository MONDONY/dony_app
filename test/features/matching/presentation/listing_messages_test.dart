// Couvre les six messages ICU imposés par la tâche C1 (détail d'annonce,
// cartes et feuilles de trajet) : pour chacun, on compare le rendu du
// nouveau message (fr et en) à l'ancien calcul concaténé, pour 0, 1, 2 et 12.
//
// Seule exception délibérée : `listingRouteTrips` à 0, qui corrige un
// accord faux (« 0 trajets » → « 0 trajet »), signalée dans le corps de la
// PR — voir route_bottom_sheet.dart:110 avant migration (`!= 1`).
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('listingAcceptedParcels', () {
    // Ancien code (announcement_detail_body.dart) :
    // accepted > 1 ? 'colis acceptés' : 'colis accepté'
    String oldFr(int n) => n > 1 ? 'colis acceptés' : 'colis accepté';

    for (final n in [0, 1, 2, 12]) {
      test('fr count=$n identique à l\'ancien calcul', () {
        expect(fr.listingAcceptedParcels(n), oldFr(n));
      });
    }

    test('en count=1 singulier, sinon pluriel', () {
      expect(en.listingAcceptedParcels(1), 'parcel accepted');
      expect(en.listingAcceptedParcels(0), 'parcels accepted');
      expect(en.listingAcceptedParcels(2), 'parcels accepted');
      expect(en.listingAcceptedParcels(12), 'parcels accepted');
    });
  });

  group('listingRouteTrips', () {
    // Ancien code (route_bottom_sheet.dart) :
    // '${items.length} trajet${items.length != 1 ? 's' : ''}'
    String oldFr(int n) => '$n trajet${n != 1 ? 's' : ''}';

    test('fr count=1, 2 et 12 identiques à l\'ancien calcul', () {
      expect(fr.listingRouteTrips(1), oldFr(1));
      expect(fr.listingRouteTrips(2), oldFr(2));
      expect(fr.listingRouteTrips(12), oldFr(12));
    });

    test(
      'fr count=0 corrige l\'accord : "0 trajet" au lieu de "0 trajets"',
      () {
        expect(oldFr(0), '0 trajets'); // rendu de l'ancien code, pour mémoire
        expect(fr.listingRouteTrips(0), '0 trajet');
      },
    );

    test('en count=1 singulier, sinon pluriel', () {
      expect(en.listingRouteTrips(1), '1 trip');
      expect(en.listingRouteTrips(0), '0 trips');
      expect(en.listingRouteTrips(2), '2 trips');
      expect(en.listingRouteTrips(12), '12 trips');
    });
  });

  group('listingSameAddressTravelers', () {
    // Ancien code (same_address_announcements_sheet.dart) :
    // '${length} voyageur${length > 1 ? "s" : ""} disponible${length > 1 ? "s" : ""} à cette adresse'
    String oldFr(int n) =>
        '$n voyageur${n > 1 ? "s" : ""} disponible${n > 1 ? "s" : ""} à cette adresse';

    for (final n in [0, 1, 2, 12]) {
      test('fr count=$n identique à l\'ancien calcul', () {
        expect(fr.listingSameAddressTravelers(n), oldFr(n));
      });
    }

    test('en count=1 singulier, sinon pluriel', () {
      expect(
        en.listingSameAddressTravelers(1),
        '1 traveler available at this address',
      );
      expect(
        en.listingSameAddressTravelers(0),
        '0 travelers available at this address',
      );
      expect(
        en.listingSameAddressTravelers(2),
        '2 travelers available at this address',
      );
      expect(
        en.listingSameAddressTravelers(12),
        '12 travelers available at this address',
      );
    });
  });

  group('listingItemCount', () {
    // Ancien code (traveler_announcement_bottom_sheet.dart) :
    // '${items.length} article${items.length > 1 ? 's' : ''}'
    String oldFr(int n) => '$n article${n > 1 ? 's' : ''}';

    for (final n in [0, 1, 2, 12]) {
      test('fr count=$n identique à l\'ancien calcul', () {
        expect(fr.listingItemCount(n), oldFr(n));
      });
    }

    test('en count=1 singulier, sinon pluriel', () {
      expect(en.listingItemCount(1), '1 item');
      expect(en.listingItemCount(0), '0 items');
      expect(en.listingItemCount(2), '2 items');
      expect(en.listingItemCount(12), '12 items');
    });
  });

  group('listingTravelerTrips', () {
    // Ancien code (traveler_announcement_bottom_sheet.dart, traveler_card.dart) :
    // '· $totalTrips trajet${totalTrips > 1 ? 's' : ''}'
    String oldFr(int n) => '· $n trajet${n > 1 ? 's' : ''}';

    for (final n in [0, 1, 2, 12]) {
      test('fr count=$n identique à l\'ancien calcul', () {
        expect(fr.listingTravelerTrips(n), oldFr(n));
      });
    }

    test('en count=1 singulier, sinon pluriel', () {
      expect(en.listingTravelerTrips(1), '· 1 trip');
      expect(en.listingTravelerTrips(0), '· 0 trips');
      expect(en.listingTravelerTrips(2), '· 2 trips');
      expect(en.listingTravelerTrips(12), '· 12 trips');
    });
  });

  group('listingHandoverUntil', () {
    test('fr reprend le gabarit "Jusqu\'au {date}"', () {
      expect(fr.listingHandoverUntil('6 oct.'), "Jusqu'au 6 oct.");
    });

    test('en reprend le gabarit "Until {date}"', () {
      expect(en.listingHandoverUntil('Oct 6'), 'Until Oct 6');
    });
  });
}
