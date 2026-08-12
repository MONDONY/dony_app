import 'package:dony/features/matching/presentation/widgets/marker_clustering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

LatLng _id(LatLng p) => p; // identity locator for testing with raw LatLng

void main() {
  group('cellDegForZoom', () {
    test('is monotonically non-increasing as zoom grows', () {
      double prev = double.infinity;
      for (final z in [3.0, 5.0, 7.0, 9.0, 11.0, 13.0, 16.0]) {
        final c = cellDegForZoom(z);
        expect(c, lessThanOrEqualTo(prev));
        prev = c;
      }
    });
    test('uses 3.0 deg cells below zoom 4 and 0.003 above 14', () {
      expect(cellDegForZoom(3), 3.0);
      expect(cellDegForZoom(15), 0.003);
    });
    test('boundaries use strict < (the cell shrinks AT the threshold)', () {
      // Each pair maps the exact boundary value to the SMALLER bucket.
      expect(cellDegForZoom(4.0), 1.0);
      expect(cellDegForZoom(6.0), 0.3);
      expect(cellDegForZoom(8.0), 0.1);
      expect(cellDegForZoom(10.0), 0.03);
      expect(cellDegForZoom(12.0), 0.01);
      expect(cellDegForZoom(14.0), 0.003);
    });
  });

  group('gridCluster', () {
    test('returns empty for empty input', () {
      expect(gridCluster<LatLng>(const [], 10, _id), isEmpty);
    });
    test('groups points in the same cell, separates far ones', () {
      const paris = LatLng(48.8566, 2.3522);
      const parisClose = LatLng(48.85665, 2.35225); // ~7 m — within kSameSpot (1e-4)
      const dakar = LatLng(14.6928, -17.4467);
      final clusters = gridCluster<LatLng>(
          const [paris, parisClose, dakar], 12, _id);
      expect(clusters.length, 2); // paris+parisClose merged, dakar alone
      final big = clusters.firstWhere((c) => c.isMultiple);
      expect(big.count, 2);
      expect(big.isSameSpot, isTrue); // within ~10-15 m
    });
    test('marks a cluster as not same-spot when points are ~km apart but in one cell', () {
      // At low zoom the cell is large (3 deg); two points 0.5 deg apart share a cell.
      const a = LatLng(48.0, 2.0);
      const b = LatLng(48.4, 2.4); // ~50 km
      final clusters = gridCluster<LatLng>(const [a, b], 3, _id);
      expect(clusters.length, 1);
      expect(clusters.first.isSameSpot, isFalse);
    });
  });

  group('mergeSameSpotSingletons', () {
    test('merges two singleton clusters at the same physical spot', () {
      const a = LatLng(48.8566, 2.3522);
      const b = LatLng(48.85665, 2.35225); // < 1e-4 deg apart
      final singles = [
        MarkerCluster<LatLng>([a], a, isSameSpot: true),
        MarkerCluster<LatLng>([b], b, isSameSpot: true),
      ];
      final merged = mergeSameSpotSingletons<LatLng>(singles, _id);
      expect(merged.length, 1);
      expect(merged.first.count, 2);
      expect(merged.first.isSameSpot, isTrue);
    });
    test('keeps distant singletons separate and passes multi clusters through', () {
      const a = LatLng(48.8566, 2.3522);
      const b = LatLng(45.0, 4.0); // far
      final multi = MarkerCluster<LatLng>([a, b], a, isSameSpot: false);
      final singles = [
        multi,
        MarkerCluster<LatLng>([a], a, isSameSpot: true),
        MarkerCluster<LatLng>([b], b, isSameSpot: true),
      ];
      final merged = mergeSameSpotSingletons<LatLng>(singles, _id);
      expect(merged.length, 3); // nothing merged
    });
    test('early-returns unchanged with fewer than 2 singletons', () {
      const a = LatLng(48.8566, 2.3522);
      const b = LatLng(45.0, 4.0);
      final multi = MarkerCluster<LatLng>([a, b], a, isSameSpot: false);
      final lone = MarkerCluster<LatLng>([a], a, isSameSpot: true);
      final merged = mergeSameSpotSingletons<LatLng>([multi, lone], _id);
      expect(merged.length, 2); // multi passes through, lone singleton untouched
      expect(merged, containsAll(<MarkerCluster<LatLng>>[multi, lone]));
    });
  });
}
