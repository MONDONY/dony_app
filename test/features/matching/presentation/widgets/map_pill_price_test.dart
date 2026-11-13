import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/map_pill_price.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _trip(
  String id, {
  TransportMode? mode,
  double? pricePerKg,
  double? pricePerM3,
  double? pricePerM3Display,
  String currency = 'EUR',
}) => AnnouncementModel(
  id: id,
  travelerId: 't1',
  departureCity: 'Le Havre',
  arrivalCity: 'Abidjan',
  departureDate: DateTime(2026, 12, 2),
  availableKg: 0,
  totalKg: 0,
  pricePerKg: pricePerKg,
  pricePerM3: pricePerM3,
  pricePerM3Display: pricePerM3Display,
  transportMode: mode,
  currency: currency,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
);

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('singlePillPrice', () {
    test('trajet au m³ : prix au m³, jamais « Par article »', () {
      final pill = singlePillPrice(
        fr,
        _trip(
          'boat',
          mode: TransportMode.boat,
          pricePerM3: 540,
          pricePerM3Display: 600,
        ),
      );
      expect(pill.priceLabel, isNotNull);
      expect(pill.priceLabel, endsWith('/m³'));
      expect(pill.priceLabel, contains('540'));
      expect(pill.pricePerKg, 540);
      expect(pill.priceLabel, isNot(fr.listingPriceGridShort));
    });

    test('invité (net masqué) : le prix affiché au m³', () {
      final pill = singlePillPrice(
        en,
        _trip('boat', mode: TransportMode.boat, pricePerM3Display: 600),
      );
      expect(pill.priceLabel, contains('600'));
      expect(pill.priceLabel, endsWith('/m³'));
    });

    test('trajet au kilo : prix au kilo, sans libellé formé', () {
      final pill = singlePillPrice(
        fr,
        _trip('plane', mode: TransportMode.plane, pricePerKg: 12),
      );
      expect(pill.priceLabel, isNull);
      expect(pill.pricePerKg, 12);
    });

    test('bateau au kilo : pas de prix au m³', () {
      final pill = singlePillPrice(
        fr,
        _trip('boat-kg', mode: TransportMode.boat, pricePerKg: 4),
      );
      expect(pill.priceLabel, isNull);
      expect(pill.pricePerKg, 4);
    });
  });

  group('stackedPillPrice', () {
    test('pile sans prix au kilo : le moins cher au m³', () {
      final pill = stackedPillPrice(fr, [
        _trip('a', mode: TransportMode.boat, pricePerM3: 700),
        _trip('b', mode: TransportMode.boat, pricePerM3: 450, currency: 'XOF'),
      ]);
      expect(pill.priceLabel, endsWith('/m³'));
      expect(pill.pricePerKg, 450);
      expect(pill.currency, 'XOF');
    });

    test('pile mêlée : le prix au kilo l\'emporte', () {
      final pill = stackedPillPrice(fr, [
        _trip('boat', mode: TransportMode.boat, pricePerM3: 450),
        _trip('plane', mode: TransportMode.plane, pricePerKg: 12),
      ]);
      expect(pill.priceLabel, isNull);
      expect(pill.pricePerKg, 12);
    });

    test('aucun prix : sentinelle rendue « Par article »', () {
      final pill = stackedPillPrice(fr, [
        _trip('a', mode: TransportMode.plane),
        _trip('b', mode: TransportMode.car),
      ]);
      expect(pill.priceLabel, isNull);
      expect(pill.pricePerKg, 0);
    });
  });
}
