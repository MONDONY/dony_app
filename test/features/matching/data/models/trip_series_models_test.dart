import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_series_result.dart';
import 'package:dony/features/matching/data/models/trip_template_from_announcement.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _trip({
  DateTime? handoverDeadline,
  DateTime? arrivalDate,
  String? departureTime = '10:30:00',
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
  TransportMode? mode = TransportMode.plane,
  double totalKg = 23.4,
  ItemSize? maxItemSize,
  double? maxParcelWeightKg,
}) => AnnouncementModel(
  id: 'a1',
  travelerId: 't1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureCountryCode: 'FR',
  arrivalCountryCode: 'SN',
  departureDate: DateTime(2026, 11, 20),
  departureTime: departureTime,
  arrivalTime: '18:00',
  arrivalDate: arrivalDate,
  handoverDeadline: handoverDeadline,
  pickupAddress: const AddressData(label: 'Orly', lat: 48.7, lng: 2.4),
  deliveryAddress: const AddressData(label: 'Dakar', lat: 14.7, lng: -17.4),
  availableKg: 10,
  totalKg: totalKg,
  pricePerKg: 8,
  transportMode: mode,
  status: 'ACTIVE',
  acceptedContentTypes: const ['CLOTHES'],
  refusedTypes: const ['FOOD'],
  description: 'note',
  acceptedPaymentMethods: methods,
  capacityUnit: 'SUITCASE_23KG',
  currency: 'XOF',
  negotiable: true,
  maxItemSize: maxItemSize,
  maxParcelWeightKg: maxParcelWeightKg,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  group('TripSeriesResult', () {
    test('lit les trajets créés et les dates refusées', () {
      final result = TripSeriesResult.fromJson(const {
        'seriesId': 's1',
        'created': [
          {
            'id': 'c1',
            'travelerId': 't1',
            'departureCity': 'Paris',
            'arrivalCity': 'Dakar',
            'departureDate': '2026-11-27',
            'availableKg': 23,
            'totalKg': 23,
            'status': 'DRAFT',
            'seriesId': 's1',
            'createdAt': '2026-10-01T00:00:00Z',
            'updatedAt': '2026-10-01T00:00:00Z',
          },
        ],
        'failed': [
          {'date': '2026-12-04', 'code': 'draft-limit-reached', 'detail': 'x'},
          {'date': '2026-12-11'},
        ],
      });

      expect(result.seriesId, 's1');
      expect(result.created.single.id, 'c1');
      expect(result.created.single.seriesId, 's1');
      expect(result.failed, [
        TripSeriesFailure(
          date: DateTime(2026, 12, 4),
          code: 'draft-limit-reached',
        ),
        TripSeriesFailure(
          date: DateTime(2026, 12, 11),
          code: 'series-copy-failed',
        ),
      ]);
      expect(result.props.first, 's1');
    });

    test('listes absentes : vides', () {
      final result = TripSeriesResult.fromJson(const {'seriesId': 's1'});
      expect(result.created, isEmpty);
      expect(result.failed, isEmpty);
    });

    test('wireDate : yyyy-MM-dd sans fuseau', () {
      expect(TripSeriesResult.wireDate(DateTime(2026, 3, 7, 23)), '2026-03-07');
    });
  });

  group('tripTemplateFromAnnouncement', () {
    test('le mode du trajet est repris tel quel, jamais forcé en avion', () {
      for (final (mode, wire) in [
        (TransportMode.boat, 'BOAT'),
        (TransportMode.car, 'CAR'),
        (TransportMode.bus, 'BUS'),
        (TransportMode.train, 'TRAIN'),
        (TransportMode.plane, 'PLANE'),
      ]) {
        final t = tripTemplateFromAnnouncement(
          _trip(mode: mode),
          label: 'Modèle',
        );
        expect(t.transportMode, wire);
      }
    });

    test('mode absent (anciennes données) : avion', () {
      final t = tripTemplateFromAnnouncement(
        _trip(mode: null),
        label: 'Modèle',
      );
      expect(t.transportMode, 'PLANE');
    });

    test('reprend le trajet sans ses dates', () {
      final t = tripTemplateFromAnnouncement(
        _trip(
          handoverDeadline: DateTime(2026, 11, 18, 20),
          arrivalDate: DateTime(2026, 11, 21),
          methods: const {BidPaymentMethod.stripe, BidPaymentMethod.cash},
        ),
        label: 'Mon trajet',
      );

      expect(t.id, '');
      expect(t.label, 'Mon trajet');
      expect(t.departureCity, 'Paris');
      expect(t.arrivalCity, 'Dakar');
      expect(t.departureLat, 48.7);
      expect(t.arrivalLng, -17.4);
      expect(t.transportMode, 'PLANE');
      expect(t.availableKg, 23);
      expect(t.pricePerKg, 8);
      expect(t.acceptedCategories, ['CLOTHES']);
      expect(t.refusedTypes, ['FOOD']);
      expect(t.departureTime, '10:30');
      expect(t.arrivalTime, '18:00');
      expect(t.handoverLeadDays, 2);
      expect(t.arrivalDayOffset, 1);
      expect(t.currency, 'XOF');
      expect(t.negotiable, isTrue);
      expect(t.cashAccepted, isTrue);
      expect(t.acceptedPaymentMethods, ['STRIPE', 'CASH']);
      expect(t.departureCountryCode, 'FR');
      expect(t.arrivalCountryCode, 'SN');
      expect(t.description, 'note');
    });

    test('valeurs absentes ou hors bornes : replis du back', () {
      final t = tripTemplateFromAnnouncement(
        _trip(
          handoverDeadline: DateTime(2026, 11),
          arrivalDate: DateTime(2026, 12, 20),
          departureTime: null,
          mode: null,
          totalKg: 0,
        ),
        label: 'x',
      );

      expect(t.handoverLeadDays, 7);
      expect(t.arrivalDayOffset, 3);
      expect(t.departureTime, isNull);
      expect(t.transportMode, 'PLANE');
      expect(t.availableKg, 1);
      expect(t.cashAccepted, isFalse);
    });

    test('route arrivée à J+10 : décalage 10, jamais tronqué à 3', () {
      final t = tripTemplateFromAnnouncement(
        _trip(mode: TransportMode.car, arrivalDate: DateTime(2026, 11, 30)),
        label: 'x',
      );
      expect(t.arrivalDayOffset, 10);
    });

    test('route : décalage borné à 14, bus compris', () {
      for (final mode in [TransportMode.car, TransportMode.bus]) {
        final t = tripTemplateFromAnnouncement(
          _trip(mode: mode, arrivalDate: DateTime(2026, 12, 20)),
          label: 'x',
        );
        expect(t.arrivalDayOffset, 14, reason: '$mode');
      }
    });

    test('bateau : décalage jusqu\'à 120', () {
      final t = tripTemplateFromAnnouncement(
        _trip(mode: TransportMode.boat, arrivalDate: DateTime(2027, 1, 20)),
        label: 'x',
      );
      expect(t.arrivalDayOffset, 61);
      final far = tripTemplateFromAnnouncement(
        _trip(mode: TransportMode.boat, arrivalDate: DateTime(2027, 6)),
        label: 'x',
      );
      expect(far.arrivalDayOffset, 120);
    });

    test('avion à J+5 (ancienne donnée) : ramené à 3', () {
      final t = tripTemplateFromAnnouncement(
        _trip(arrivalDate: DateTime(2026, 11, 25)),
        label: 'x',
      );
      expect(t.arrivalDayOffset, 3);
    });

    test('trajet route de 1 200 kg : capacité recopiée telle quelle', () {
      final t = tripTemplateFromAnnouncement(
        _trip(mode: TransportMode.car, totalKg: 1200),
        label: 'x',
      );
      expect(t.availableKg, 1200);
    });

    test('capacité bornée par le mode : 999 en avion, 999 999 en bateau', () {
      expect(
        tripTemplateFromAnnouncement(
          _trip(totalKg: 5000),
          label: 'x',
        ).availableKg,
        999,
      );
      expect(
        tripTemplateFromAnnouncement(
          _trip(mode: TransportMode.boat, totalKg: 2000000),
          label: 'x',
        ).availableKg,
        999999,
      );
    });

    test('recopie la taille et le poids max par colis', () {
      final t = tripTemplateFromAnnouncement(
        _trip(
          mode: TransportMode.car,
          maxItemSize: ItemSize.l,
          maxParcelWeightKg: 20.5,
        ),
        label: 'x',
      );
      expect(t.maxItemSize, ItemSize.l);
      expect(t.maxParcelWeightKg, 20.5);
    });

    test('trajet sans taille ni poids max : modèle sans eux', () {
      final t = tripTemplateFromAnnouncement(_trip(), label: 'x');
      expect(t.maxItemSize, isNull);
      expect(t.maxParcelWeightKg, isNull);
      expect(t.toJson().containsKey('maxItemSize'), isFalse);
    });

    test(
      'sans date limite ni arrivée : pas de délai, arrivée le jour même',
      () {
        final t = tripTemplateFromAnnouncement(_trip(), label: 'x');
        expect(t.handoverLeadDays, isNull);
        expect(t.arrivalDayOffset, 0);
      },
    );
  });
}
