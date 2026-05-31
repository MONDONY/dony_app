import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MarkerBitmapFactory.clearCache();
  });

  group('MarkerBitmapFactory.clusterBadge', () {
    test('returns non-null BitmapDescriptor for count=3', () async {
      final desc = await MarkerBitmapFactory.clusterBadge(3);
      expect(desc, isA<BitmapDescriptor>());
    });

    test('handles big counts (99+)', () async {
      final desc = await MarkerBitmapFactory.clusterBadge(150);
      expect(desc, isA<BitmapDescriptor>());
    });
  });

  group('MarkerBitmapFactory.pin', () {
    test('returns BitmapDescriptor for plane pickup with rating', () async {
      final desc = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: 4.7,
      );
      expect(desc, isA<BitmapDescriptor>());
    });

    test('returns identical BitmapDescriptor on cache hit', () async {
      final a = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: 4.7,
      );
      final b = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: 4.7,
      );
      expect(identical(a, b), isTrue);
    });

    // ─── Rating bucket behavior ────────────────────────────────────────────

    test('rounds rating to one decimal — 4.71 reuses 4.7 bitmap', () async {
      final a = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: 4.7,
      );
      final b = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: 4.71,
      );
      expect(identical(a, b), isTrue);
    });

    test('different rating buckets produce different bitmaps', () async {
      final a = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: 4.5,
      );
      final b = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: 4.7,
      );
      expect(identical(a, b), isFalse);
    });

    // ─── Null handling ─────────────────────────────────────────────────────

    test('handles null mode without crashing', () async {
      final desc = await MarkerBitmapFactory.pin(
        mode: null,
        side: MarkerSide.pickup,
        rating: 4.7,
      );
      expect(desc, isA<BitmapDescriptor>());
    });

    test('null rating produces different cache slot from a real rating', () async {
      final novice = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: null,
      );
      final rated = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: 5.0,
      );
      expect(identical(novice, rated), isFalse);
    });

    // ─── Mode/side discrimination + sweep ──────────────────────────────────

    test('produces a BitmapDescriptor for every (mode, side) combination', () async {
      for (final mode in TransportMode.values) {
        for (final side in MarkerSide.values) {
          final desc = await MarkerBitmapFactory.pin(
            mode: mode,
            side: side,
            rating: 4.5,
          );
          expect(desc, isA<BitmapDescriptor>(),
              reason: 'failed for $mode / $side');
        }
      }
    });

    test('different modes produce different bitmaps for same side+rating', () async {
      final plane = await MarkerBitmapFactory.pin(
        mode: TransportMode.plane,
        side: MarkerSide.pickup,
        rating: 4.7,
      );
      final car = await MarkerBitmapFactory.pin(
        mode: TransportMode.car,
        side: MarkerSide.pickup,
        rating: 4.7,
      );
      expect(identical(plane, car), isFalse);
    });
  });

  group('MarkerBitmapFactory.pricePill brightness', () {
    test('light vs dark produce different bitmaps', () async {
      final light = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, brightness: Brightness.light);
      final dark = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, brightness: Brightness.dark);
      expect(identical(light, dark), isFalse);
    });

    test('same brightness hits the cache', () async {
      final a = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, brightness: Brightness.dark);
      final b = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, brightness: Brightness.dark);
      expect(identical(a, b), isTrue);
    });

    test('selected vs not produce different bitmaps', () async {
      final plain = await MarkerBitmapFactory.pricePill(pricePerKg: 12);
      final selected = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, isSelected: true);
      expect(identical(plain, selected), isFalse);
    });
  });
}
