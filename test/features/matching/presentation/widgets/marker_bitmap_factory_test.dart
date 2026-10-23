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

    test(
      'null rating produces different cache slot from a real rating',
      () async {
        final novice = await MarkerBitmapFactory.pin(
          mode: TransportMode.plane,
          side: MarkerSide.pickup,
        );
        final rated = await MarkerBitmapFactory.pin(
          mode: TransportMode.plane,
          side: MarkerSide.pickup,
          rating: 5.0,
        );
        expect(identical(novice, rated), isFalse);
      },
    );

    // ─── Mode/side discrimination + sweep ──────────────────────────────────

    test(
      'produces a BitmapDescriptor for every (mode, side) combination',
      () async {
        for (final mode in TransportMode.values) {
          for (final side in MarkerSide.values) {
            final desc = await MarkerBitmapFactory.pin(
              mode: mode,
              side: side,
              rating: 4.5,
            );
            expect(
              desc,
              isA<BitmapDescriptor>(),
              reason: 'failed for $mode / $side',
            );
          }
        }
      },
    );

    test(
      'different modes produce different bitmaps for same side+rating',
      () async {
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
      },
    );
  });

  group('MarkerBitmapFactory.pricePill brightness', () {
    test('light vs dark produce different bitmaps', () async {
      final light = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
      );
      final dark = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        brightness: Brightness.dark,
      );
      expect(identical(light, dark), isFalse);
    });

    test('same brightness hits the cache', () async {
      final a = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        brightness: Brightness.dark,
      );
      final b = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        brightness: Brightness.dark,
      );
      expect(identical(a, b), isTrue);
    });

    test('la mention « + frais de service » change la pastille', () async {
      final plain = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
      );
      final withFee = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        feeSuffix: '+ frais de service',
      );
      final withFeeAgain = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        feeSuffix: '+ frais de service',
      );
      expect(identical(plain, withFee), isFalse);
      expect(identical(withFee, withFeeAgain), isTrue);
    });

    test('la pile de pastilles porte aussi la mention', () async {
      final plain = await MarkerBitmapFactory.stackedPricePill(
        pricePerKg: 12,
        count: 3,
        gridLabel: 'Par article',
      );
      final withFee = await MarkerBitmapFactory.stackedPricePill(
        pricePerKg: 12,
        count: 3,
        gridLabel: 'Par article',
        feeSuffix: '+ frais de service',
      );
      expect(identical(plain, withFee), isFalse);
    });

    test('selected vs not produce different bitmaps', () async {
      final plain = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
      );
      final selected = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        isSelected: true,
      );
      expect(identical(plain, selected), isFalse);
    });

    test(
      'different currencies produce different bitmaps, not always EUR',
      () async {
        final eur = await MarkerBitmapFactory.pricePill(
          pricePerKg: 12,
          gridLabel: 'Par article',
          currencyCode: 'EUR',
        );
        final cad = await MarkerBitmapFactory.pricePill(
          pricePerKg: 12,
          gridLabel: 'Par article',
          currencyCode: 'CAD',
        );
        expect(identical(eur, cad), isFalse);
      },
    );

    test('same currency hits the cache', () async {
      final a = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        currencyCode: 'CAD',
      );
      final b = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        currencyCode: 'CAD',
      );
      expect(identical(a, b), isTrue);
    });

    test(
      'different grid labels produce different bitmaps in grid mode (pricePerKg <= 0)',
      () async {
        final fr = await MarkerBitmapFactory.pricePill(
          pricePerKg: 0,
          gridLabel: 'Par article',
        );
        final en = await MarkerBitmapFactory.pricePill(
          pricePerKg: 0,
          gridLabel: 'Per item',
        );
        expect(identical(fr, en), isFalse);
      },
    );
  });

  group('MarkerBitmapFactory.stackedPricePill brightness', () {
    test('light vs dark produce different stacked bitmaps', () async {
      final light = await MarkerBitmapFactory.stackedPricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        count: 3,
      );
      final dark = await MarkerBitmapFactory.stackedPricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        count: 3,
        brightness: Brightness.dark,
      );
      expect(identical(light, dark), isFalse);
    });

    test('same brightness hits the stacked cache', () async {
      final a = await MarkerBitmapFactory.stackedPricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        count: 3,
        brightness: Brightness.dark,
      );
      final b = await MarkerBitmapFactory.stackedPricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        count: 3,
        brightness: Brightness.dark,
      );
      expect(identical(a, b), isTrue);
    });

    test('different currencies produce different stacked bitmaps', () async {
      final eur = await MarkerBitmapFactory.stackedPricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        count: 3,
        currencyCode: 'EUR',
      );
      final cad = await MarkerBitmapFactory.stackedPricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        count: 3,
        currencyCode: 'CAD',
      );
      expect(identical(eur, cad), isFalse);
    });

    test(
      'different grid labels produce different stacked bitmaps in grid mode (pricePerKg <= 0)',
      () async {
        final fr = await MarkerBitmapFactory.stackedPricePill(
          pricePerKg: 0,
          gridLabel: 'Par article',
          count: 3,
        );
        final en = await MarkerBitmapFactory.stackedPricePill(
          pricePerKg: 0,
          gridLabel: 'Per item',
          count: 3,
        );
        expect(identical(fr, en), isFalse);
      },
    );
  });

  group('MarkerBitmapFactory.pricePill : drapeau, sélection, son trajet', () {
    test('le drapeau d\'arrivée remplace le point d\'urgence', () async {
      final sansDrapeau = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
      );
      final avecDrapeau = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        flagEmoji: '🇲🇱',
      );
      final autreDrapeau = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        flagEmoji: '🇨🇮',
      );
      final memeDrapeau = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12,
        gridLabel: 'Par article',
        flagEmoji: '🇲🇱',
      );
      expect(identical(sansDrapeau, avecDrapeau), isFalse);
      expect(identical(avecDrapeau, autreDrapeau), isFalse);
      expect(identical(avecDrapeau, memeDrapeau), isTrue);
    });

    test(
      'trajet sélectionné et son propre trajet : pastilles distinctes',
      () async {
        final normal = await MarkerBitmapFactory.pricePill(
          pricePerKg: 12,
          gridLabel: 'Par article',
          flagEmoji: '🇲🇱',
        );
        final selectionne = await MarkerBitmapFactory.pricePill(
          pricePerKg: 12,
          gridLabel: 'Par article',
          flagEmoji: '🇲🇱',
          isSelected: true,
        );
        final sien = await MarkerBitmapFactory.pricePill(
          pricePerKg: 12,
          gridLabel: 'Par article',
          flagEmoji: '🇲🇱',
          isOwn: true,
        );
        final sienSelectionne = await MarkerBitmapFactory.pricePill(
          pricePerKg: 12,
          gridLabel: 'Par article',
          flagEmoji: '🇲🇱',
          isOwn: true,
          isSelected: true,
        );
        expect(identical(normal, selectionne), isFalse);
        expect(identical(normal, sien), isFalse);
        expect(identical(selectionne, sien), isFalse);
        // La sélection l'emporte : bleu nuit, même pour son propre trajet.
        expect(sienSelectionne, isA<BitmapDescriptor>());
      },
    );

    test('prix « Grille » sélectionné avec drapeau', () async {
      final desc = await MarkerBitmapFactory.pricePill(
        pricePerKg: 0,
        gridLabel: 'Par article',
        flagEmoji: '🇸🇳',
        isSelected: true,
        brightness: Brightness.dark,
      );
      expect(desc, isA<BitmapDescriptor>());
    });
  });
}
