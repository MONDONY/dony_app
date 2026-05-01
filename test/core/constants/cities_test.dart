import 'package:dony/core/constants/cities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('CityConstants', () {
    group('findById', () {
      test('returns city for known id', () {
        final city = CityConstants.findById('paris');
        expect(city, isNotNull);
        expect(city!.displayName, 'Paris');
        expect(city.type, CityType.departure);
      });

      test('returns null for unknown id', () {
        expect(CityConstants.findById('bordeaux'), isNull);
      });

      test('returns city for all 7 known ids', () {
        for (final id in ['paris', 'lyon', 'marseille', 'dakar', 'abidjan', 'bamako', 'douala']) {
          expect(CityConstants.findById(id), isNotNull, reason: '$id should be found');
        }
      });
    });

    group('departures / arrivals', () {
      test('departures contains exactly Paris, Lyon, Marseille', () {
        final ids = CityConstants.departures.map((c) => c.id).toSet();
        expect(ids, {'paris', 'lyon', 'marseille'});
      });

      test('arrivals contains exactly Dakar, Abidjan, Bamako, Douala', () {
        final ids = CityConstants.arrivals.map((c) => c.id).toSet();
        expect(ids, {'dakar', 'abidjan', 'bamako', 'douala'});
      });
    });

    group('findNearest', () {
      test('returns Paris for position very close to Paris center', () {
        final city = CityConstants.findNearest(const LatLng(48.87, 2.35));
        expect(city?.id, 'paris');
      });

      test('returns Lyon for position near Lyon', () {
        final city = CityConstants.findNearest(const LatLng(45.75, 4.85));
        expect(city?.id, 'lyon');
      });

      test('returns null for Bordeaux (>50 km from any departure city)', () {
        final city = CityConstants.findNearest(const LatLng(44.84, -0.58));
        expect(city, isNull);
      });

      test('returns null for Dakar (arrival city, not departure)', () {
        final city = CityConstants.findNearest(const LatLng(14.72, -17.47));
        expect(city, isNull);
      });

      test('respects custom maxDistanceKm', () {
        const pos = LatLng(49.09, 2.35);
        expect(CityConstants.findNearest(pos, maxDistanceKm: 20), isNull);
        expect(CityConstants.findNearest(pos, maxDistanceKm: 50), isNotNull);
      });
    });
  });
}
