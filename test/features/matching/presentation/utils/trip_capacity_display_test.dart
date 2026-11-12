import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _trip({
  TransportMode? mode = TransportMode.car,
  String capacityUnit = 'KG_EXACT',
  double availableKg = 1200,
  double totalKg = 1500,
  ItemSize? size,
  double? maxParcelKg,
  DateTime? arrival,
}) => AnnouncementModel(
  id: 'a1',
  travelerId: 't1',
  departureCity: 'Paris',
  arrivalCity: 'Bamako',
  departureDate: DateTime(2026, 11, 14, 18),
  arrivalDate: arrival,
  availableKg: availableKg,
  totalKg: totalKg,
  capacityUnit: capacityUnit,
  pricePerKg: 5,
  status: 'ACTIVE',
  transportMode: mode,
  maxItemSize: size,
  maxParcelWeightKg: maxParcelKg,
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
);

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('tripCapacityLine', () {
    test('route avec taille : tonnes groupées puis taille (fr et en)', () {
      final a = _trip(size: ItemSize.l);
      expect(
        tripCapacityLine(fr, a),
        '${fr.listingKgAvailableLabel('1 200')}, jusqu\'à taille L',
      );
      expect(
        tripCapacityLine(en, a),
        '${en.listingKgAvailableLabel('1,200')}, up to size L',
      );
    });

    test('route sans taille (ancien trajet) : kilos seuls, groupés', () {
      expect(
        tripCapacityLine(fr, _trip()),
        fr.listingKgAvailableLabel('1 200'),
      );
      expect(
        tripCapacityLine(en, _trip()),
        en.listingKgAvailableLabel('1,200'),
      );
    });

    test('kilo libre avec taille, puis sans', () {
      final free = _trip(capacityUnit: 'KG_FREE', size: ItemSize.xl);
      expect(tripCapacityLine(fr, free), 'Kilos libres, jusqu\'à taille XL');
      expect(tripCapacityLine(en, free), 'Free kilos, up to size XL');
      expect(
        tripCapacityLine(fr, _trip(capacityUnit: 'KG_FREE')),
        fr.tripKgFree,
      );
    });

    test('avion : strictement inchangé, même si une taille traîne', () {
      final plane = _trip(
        mode: TransportMode.plane,
        availableKg: 23,
        totalKg: 30,
        size: ItemSize.m,
      );
      expect(tripCapacityLine(fr, plane), fr.listingKgAvailableLabel('23'));
      final noMode = _trip(
        mode: null,
        availableKg: 23,
        totalKg: 30,
        size: ItemSize.m,
      );
      expect(tripCapacityLine(fr, noMode), fr.listingKgAvailableLabel('23'));
      expect(tripShownItemSize(plane), isNull);
    });

    test('valises : le détail ajoute les kilos, la taille suit', () {
      final a = _trip(
        capacityUnit: 'SUITCASE_23KG',
        totalKg: 46,
        availableKg: 40,
        size: ItemSize.m,
      );
      expect(
        tripCapacityLine(fr, a),
        '${fr.listingSuitcaseCapacityLabel(2, 23)}, jusqu\'à taille M',
      );
      expect(
        tripCapacityLine(fr, a, detailed: true),
        '${fr.listingSuitcaseCapacityLabel(2, 23)} · ${fr.listingKgAvailableLabel('40')}, jusqu\'à taille M',
      );
    });

    test('999 999 kg groupés', () {
      final a = _trip(availableKg: 999999, totalKg: 999999);
      expect(tripCapacityLine(en, a), en.listingKgAvailableLabel('999,999'));
    });
  });

  group('tripMaxParcelLine', () {
    test('route : « 20 kg max par colis » / « 20 kg max per parcel »', () {
      final a = _trip(maxParcelKg: 20);
      expect(
        tripMaxParcelLine(fr, a),
        '${formatWeightKg(fr, 20)} max par colis',
      );
      expect(
        tripMaxParcelLine(en, a),
        '${formatWeightKg(en, 20)} max per parcel',
      );
    });

    test('absent, nul ou avion : rien', () {
      expect(tripMaxParcelLine(fr, _trip()), isNull);
      expect(tripMaxParcelLine(fr, _trip(maxParcelKg: 0)), isNull);
      expect(
        tripMaxParcelLine(
          fr,
          _trip(mode: TransportMode.plane, maxParcelKg: 20),
        ),
        isNull,
      );
    });
  });

  group('tripRoadDays', () {
    test('route à arrivée datée : jours entiers, heures ignorées', () {
      expect(tripRoadDays(_trip(arrival: DateTime(2026, 11, 19, 6))), 5);
      expect(
        tripRoadDays(
          _trip(mode: TransportMode.bus, arrival: DateTime(2026, 11, 15)),
        ),
        1,
      );
      expect(fr.tripRoadDuration(1), '1 jour de route');
      expect(fr.tripRoadDuration(5), '5 jours de route');
      expect(en.tripRoadDuration(1), '1 day on the road');
      expect(en.tripRoadDuration(5), '5 days on the road');
    });

    test('dates calendaires : UTC et changement d\'heure ne décalent rien', () {
      // Arrivée servie en UTC tard le soir, départ en heure locale.
      expect(
        tripRoadDays(_trip(arrival: DateTime.utc(2026, 11, 19, 23, 30))),
        5,
      );
      // Fin de l'heure d'été (25 oct. 2026) : 7 jours calendaires, pas 6,96.
      final dst = AnnouncementModel(
        id: 'a2',
        travelerId: 't1',
        departureCity: 'Paris',
        arrivalCity: 'Bamako',
        departureDate: DateTime(2026, 10, 24, 23),
        arrivalDate: DateTime(2026, 10, 31, 1),
        availableKg: 10,
        totalKg: 10,
        status: 'ACTIVE',
        transportMode: TransportMode.car,
        createdAt: DateTime(2026, 10),
        updatedAt: DateTime(2026, 10),
      );
      expect(tripRoadDays(dst), 7);
    });

    test('sans arrivée, même jour, bateau, avion : rien', () {
      expect(tripRoadDays(_trip()), isNull);
      expect(tripRoadDays(_trip(arrival: DateTime(2026, 11, 14, 23))), isNull);
      expect(
        tripRoadDays(
          _trip(mode: TransportMode.boat, arrival: DateTime(2026, 11, 20)),
        ),
        isNull,
      );
      expect(
        tripRoadDays(
          _trip(mode: TransportMode.plane, arrival: DateTime(2026, 11, 20)),
        ),
        isNull,
      );
    });
  });

  test('parcelWeightWithSize : « 25 kg · taille L » ou le poids seul', () {
    expect(parcelWeightWithSize(fr, '25 kg', ItemSize.l), '25 kg · taille L');
    expect(parcelWeightWithSize(en, '25 kg', ItemSize.l), '25 kg · size L');
    expect(parcelWeightWithSize(fr, '25 kg', null), '25 kg');
  });
}
