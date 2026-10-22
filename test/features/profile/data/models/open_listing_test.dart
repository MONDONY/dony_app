import 'package:dony/features/profile/data/models/open_listing.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> tripJson() => {
  'id': 'a1',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Bamako',
  'departureDate': DateTime(2026, 10, 27).toIso8601String(),
  'availableKg': 23.0,
  'totalKg': 23.0,
  'pricePerKg': 1.07,
  'status': 'ACTIVE',
  'createdAt': DateTime(2026, 10, 20).toIso8601String(),
  'updatedAt': DateTime(2026, 10, 20).toIso8601String(),
};

Map<String, dynamic> requestJson() => {
  'id': 'pr-1',
  'departureCity': 'Lyon',
  'arrivalCity': 'Bamako',
  'desiredDate': '2026-11-12T00:00:00.000Z',
  'dateToleranceDays': 2,
  'weightKg': 3.0,
  'parcelSize': 'SMALL',
  'contentCategory': 'VETEMENTS',
  'targetPriceEur': 25.0,
  'sender': {
    'id': 's1',
    'displayName': 'Aboubakar D.',
    'averageRating': 4.8,
    'totalRatings': 9,
    'kycVerified': true,
  },
};

void main() {
  group('OpenListing.fromJson', () {
    test('TRIP : lit le trajet et la date de publication', () {
      final item = OpenListing.fromJson({
        'kind': 'TRIP',
        'publishedAt': '2026-10-20T09:00:00',
        'trip': tripJson(),
        'request': null,
      });

      expect(item, isA<OpenTripListing>());
      final trip = item! as OpenTripListing;
      expect(trip.announcement.id, 'a1');
      expect(trip.announcement.arrivalCity, 'Bamako');
      expect(trip.publishedAt, DateTime.utc(2026, 10, 20, 9));
    });

    test('REQUEST : lit la demande d\'envoi', () {
      final item = OpenListing.fromJson({
        'kind': 'REQUEST',
        'publishedAt': '2026-10-21T18:00:00',
        'trip': null,
        'request': requestJson(),
      });

      expect(item, isA<OpenRequestListing>());
      final request = item! as OpenRequestListing;
      expect(request.item.id, 'pr-1');
      expect(request.item.departureCity, 'Lyon');
      expect(request.publishedAt, DateTime.utc(2026, 10, 21, 18));
    });

    test('la date sans fuseau est lue en UTC, pas en heure locale', () {
      final item = OpenListing.fromJson({
        'kind': 'TRIP',
        'publishedAt': '2026-10-20T09:00:00',
        'trip': tripJson(),
      })!;
      expect(item.publishedAt.isUtc, isTrue);
    });

    test(
      'une date déjà suffixée par Z ou un décalage est gardée telle quelle',
      () {
        final z = OpenListing.fromJson({
          'kind': 'TRIP',
          'publishedAt': '2026-10-20T09:00:00Z',
          'trip': tripJson(),
        })!;
        final offset = OpenListing.fromJson({
          'kind': 'TRIP',
          'publishedAt': '2026-10-20T11:00:00+02:00',
          'trip': tripJson(),
        })!;
        expect(z.publishedAt, DateTime.utc(2026, 10, 20, 9));
        expect(offset.publishedAt, DateTime.utc(2026, 10, 20, 9));
      },
    );

    test('un kind inconnu (back plus récent) est ignoré', () {
      expect(
        OpenListing.fromJson({
          'kind': 'BUNDLE',
          'publishedAt': '2026-10-20T09:00:00',
        }),
        isNull,
      );
    });
  });
}
