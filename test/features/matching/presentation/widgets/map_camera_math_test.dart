import 'package:dony/features/matching/presentation/widgets/map_camera_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  const paris = LatLng(48.8566, 2.3522);
  const parisNear = LatLng(48.90, 2.40); // ~6 km
  const lyon = LatLng(45.7640, 4.8357); // ~392 km
  const dakar = LatLng(14.6928, -17.4467); // ~4200 km

  group('distanceKm', () {
    test('returns ~0 for the same point', () {
      expect(distanceKm(paris, paris), lessThan(0.001));
    });
    test('Paris→Lyon is ~392 km (±15)', () {
      expect(distanceKm(paris, lyon), closeTo(392, 15));
    });
  });

  group('computeHybridBounds', () {
    test('returns null when there are no points', () {
      expect(computeHybridBounds(paris, const []), isNull);
    });

    test('keeps only nearby points (≤150 km) with the user', () {
      final b = computeHybridBounds(paris, const [parisNear, lyon]);
      expect(b, isNotNull);
      expect(b!.contains(paris), isTrue);
      expect(b.contains(parisNear), isTrue);
      expect(b.contains(lyon), isFalse); // 392 km → exclu
    });

    test('falls back to nearest points when none are within radius', () {
      final b = computeHybridBounds(paris, const [lyon, dakar]);
      expect(b, isNotNull);
      expect(b!.contains(paris), isTrue);
      expect(b.contains(lyon), isTrue);
      expect(b.contains(dakar), isTrue); // les 2 plus proches retenues
    });

    test('returns null when the only point equals the user (degenerate)', () {
      expect(computeHybridBounds(paris, const [paris]), isNull);
    });
  });

  group('boundsAround', () {
    test('cadre carré centré sur le point, sw < ne', () {
      final b = boundsAround(paris, 1000);
      expect(b.contains(paris), isTrue);
      expect(b.southwest.latitude, lessThan(b.northeast.latitude));
      expect(b.southwest.longitude, lessThan(b.northeast.longitude));
    });

    test('rayon ~1000 km : inclut Lyon (~392 km), exclut Dakar (~4200 km)', () {
      final b = boundsAround(paris, 1000);
      expect(b.contains(lyon), isTrue);
      expect(b.contains(dakar), isFalse);
    });
  });
}
