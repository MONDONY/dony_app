import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Same-spot threshold in degrees: 1e-4° ≈ 11 m at the equator — captures
/// same-building geocoding variations. Shared by [gridCluster] and
/// [mergeSameSpotSingletons] so their notion of "same spot" stays in sync.
const _kSameSpot = 1e-4;

/// A lightweight cluster: one or more items [T] with a centroid.
class MarkerCluster<T> {
  MarkerCluster(this.items, this.centroid, {required this.isSameSpot});

  final List<T> items;
  final LatLng centroid;

  /// True when all items are within ~10 m of each other (same building/address).
  /// Pre-computed at build time so tap handlers don't need to recheck.
  final bool isSameSpot;

  bool get isMultiple => items.length > 1;
  int get count => items.length;
}

/// Groups [points] whose lat/lng are within [cellDegForZoom]\([zoom]) of each
/// other. [locate] extracts the position of each item.
List<MarkerCluster<T>> gridCluster<T>(
  List<T> points,
  double zoom,
  LatLng Function(T) locate,
) {
  if (points.isEmpty) {
    return [];
  }
  final double cellDeg = cellDegForZoom(zoom);
  final Map<String, List<T>> grid = {};
  for (final p in points) {
    final loc = locate(p);
    final key = '${(loc.latitude / cellDeg).floor()}_${(loc.longitude / cellDeg).floor()}';
    grid.putIfAbsent(key, () => []).add(p);
  }
  return grid.values.map((pts) {
    final avgLat =
        pts.fold<double>(0, (s, p) => s + locate(p).latitude) / pts.length;
    final avgLng =
        pts.fold<double>(0, (s, p) => s + locate(p).longitude) / pts.length;

    final first = locate(pts.first);
    final isSameSpot = pts.every(
      (p) =>
          (locate(p).latitude - first.latitude).abs() < _kSameSpot &&
          (locate(p).longitude - first.longitude).abs() < _kSameSpot,
    );

    return MarkerCluster<T>(pts, LatLng(avgLat, avgLng), isSameSpot: isSameSpot);
  }).toList();
}

/// Merges singleton clusters whose single point falls within ~10 m of another
/// singleton's point (handles points straddling a grid-cell boundary).
///
/// Merging is anchored on the first singleton of each group (not transitive):
/// three co-located points that straddle the threshold may not all merge.
List<MarkerCluster<T>> mergeSameSpotSingletons<T>(
  List<MarkerCluster<T>> clusters,
  LatLng Function(T) locate,
) {
  final multi = <MarkerCluster<T>>[];
  final singles = <MarkerCluster<T>>[];

  for (final c in clusters) {
    if (c.isMultiple) {
      multi.add(c);
    } else {
      singles.add(c);
    }
  }

  if (singles.length < 2) return [...multi, ...singles];

  final used = List.filled(singles.length, false);
  final merged = <MarkerCluster<T>>[];

  for (int i = 0; i < singles.length; i++) {
    if (used[i]) continue;
    final group = [singles[i]];
    used[i] = true;
    final locI = locate(singles[i].items.first);

    for (int j = i + 1; j < singles.length; j++) {
      if (used[j]) continue;
      final locJ = locate(singles[j].items.first);
      if ((locI.latitude - locJ.latitude).abs() < _kSameSpot &&
          (locI.longitude - locJ.longitude).abs() < _kSameSpot) {
        group.add(singles[j]);
        used[j] = true;
      }
    }

    if (group.length == 1) {
      merged.add(singles[i]);
    } else {
      final allItems = group.expand((c) => c.items).toList();
      final avgLat =
          allItems.fold<double>(0, (s, p) => s + locate(p).latitude) /
              allItems.length;
      final avgLng =
          allItems.fold<double>(0, (s, p) => s + locate(p).longitude) /
              allItems.length;
      merged.add(MarkerCluster<T>(allItems, LatLng(avgLat, avgLng), isSameSpot: true));
    }
  }

  return [...multi, ...merged];
}

/// Grid cell size (degrees) per zoom level. Smaller = points stay distinct
/// sooner when zooming in.
double cellDegForZoom(double zoom) {
  if (zoom < 4) {
    return 3.0;
  }
  if (zoom < 6) {
    return 1.0;
  }
  if (zoom < 8) {
    return 0.3;
  }
  if (zoom < 10) {
    return 0.1;
  }
  if (zoom < 12) {
    return 0.03;
  }
  if (zoom < 14) {
    return 0.01;
  }
  return 0.003;
}
