import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_fixtures.dart';

void main() {
  group('TripLegChain', () {
    final first = TripLegOrigin(
      city: 'Abidjan',
      countryCode: 'CI',
      arrivalDay: DateTime(2026, 11, 10),
      address: kAbidjan,
    );

    test("l'étape 2 part de l'arrivée du premier trajet", () {
      expect(TripLegChain.originOf(first, [doualaLeg()], 0), first);
    });

    test("l'étape 3 part de l'arrivée de l'étape 2", () {
      final o = TripLegChain.originOf(first, [doualaLeg(), doualaLeg()], 1);
      expect(o.city, 'Douala');
      expect(o.countryCode, 'CM');
      expect(o.arrivalDay, DateTime(2026, 11, 14));
      expect(o.address, kDouala);
    });

    test('date avant l\'arrivée précédente : invalide, même jour : valide', () {
      expect(
        TripLegChain.departsTooEarly(
          first,
          doualaLeg(date: DateTime(2026, 11, 9)),
        ),
        isTrue,
      );
      expect(
        TripLegChain.departsTooEarly(
          first,
          doualaLeg(date: DateTime(2026, 11, 10)),
        ),
        isFalse,
      );
    });

    test('invalidIndexes repère les étapes devenues incohérentes', () {
      final legs = [
        doualaLeg(date: DateTime(2026, 11, 14)),
        doualaLeg(date: DateTime(2026, 11, 12)),
      ];
      expect(TripLegChain.invalidIndexes(first, legs), {1});
    });

    test('sameCity ignore casse, espaces et accents', () {
      expect(TripLegChain.sameCity('  Yaoundé ', 'yaounde'), isTrue);
      expect(TripLegChain.sameCity('Lomé', 'Lome'), isTrue);
      expect(TripLegChain.sameCity('Paris', 'Dakar'), isFalse);
      expect(TripLegChain.sameCity(null, 'Dakar'), isFalse);
      expect(TripLegChain.sameCity('Dakar', null), isFalse);
    });
  });

  group('TripLegDraft', () {
    test('departureAt combine jour et heure', () {
      expect(doualaLeg().departureAt, DateTime(2026, 11, 14, 9, 30));
    });

    test('égalité de valeur', () {
      expect(doualaLeg(), doualaLeg());
      expect(doualaLeg(), isNot(doualaLeg(price: 7)));
    });
  });

  group('TripLegsInfo', () {
    final json = {
      'tripGroupId': 'g1',
      'legCount': 3,
      'legs': [
        {
          'id': 'a',
          'legIndex': 1,
          'departureCity': 'Paris',
          'arrivalCity': 'Abidjan',
          'departureCountryCode': 'FR',
          'arrivalCountryCode': 'CI',
          'departureDate': '2026-11-10',
          'arrivalDate': '2026-11-11',
          'status': 'ACTIVE',
        },
        {
          'id': 'b',
          'legIndex': 2,
          'departureCity': 'Abidjan',
          'arrivalCity': 'Douala',
          'departureDate': '2026-11-14',
          'status': 'FULL',
        },
        {
          'id': 'c',
          'legIndex': 3,
          'departureCity': 'Douala',
          'arrivalCity': 'Paris',
          'departureDate': '2026-11-20',
          'status': 'CANCELLED',
        },
      ],
    };

    test('fromJson lit le groupe, le total et les étapes', () {
      final info = TripLegsInfo.fromJson(json);
      expect(info.isTrip, isTrue);
      expect(info.legCount, 3);
      expect(info.legs.first.arrivalDate, DateTime(2026, 11, 11));
      expect(info.legs[1].arrivalDate, isNull);
      expect(info.legOf('b')!.legIndex, 2);
      expect(info.legOf('zz'), isNull);
    });

    test('openLegsAfter garde les étapes suivantes encore ouvertes', () {
      final info = TripLegsInfo.fromJson(json);
      expect(info.openLegsAfter('a').map((l) => l.id), ['b']);
      expect(info.openLegsAfter('c'), isEmpty);
      expect(info.openLegsAfter('inconnue'), isEmpty);
    });

    test('trajet isolé : rien à montrer', () {
      final info = TripLegsInfo.fromJson(const {'legCount': 0, 'legs': []});
      expect(info.isTrip, isFalse);
      expect(TripLegsInfo.none.isTrip, isFalse);
    });

    test('valeurs par défaut tolérantes', () {
      final leg = TripLegSummary.fromJson(const {
        'id': 'x',
        'departureDate': '2026-11-10',
      });
      expect(leg.legIndex, 0);
      expect(leg.status, 'ACTIVE');
      expect(leg.isOpen, isTrue);
      expect(leg.departureCity, '');
    });
  });

  group('AnnouncementPayload', () {
    test('toJson reprend le contrat de POST /announcements', () {
      final json = AnnouncementPayload(
        departureCity: 'Paris',
        arrivalCity: 'Abidjan',
        departureCountryCode: 'FR',
        departureDate: DateTime(2026, 11, 10),
        departureTime: '10:00',
        pickupAddress: kParis,
        deliveryAddress: kAbidjan,
        availableKg: 20,
        pricePerKg: 8,
        transportMode: TransportMode.plane,
        description: 'Note',
        handoverDeadline: DateTime.utc(2026, 11, 9, 10),
        saveAsDraft: true,
        currency: 'EUR',
      ).toJson();
      expect(json['departureDate'], '2026-11-10');
      expect(json['departureCountryCode'], 'FR');
      expect(json.containsKey('arrivalCountryCode'), isFalse);
      expect(json['transportMode'], 'PLANE');
      expect(json['description'], 'Note');
      expect(json['saveAsDraft'], isTrue);
      expect(json['handoverDeadline'], '2026-11-09T10:00:00.000Z');
      expect(json['pickupAddress'], kParis.toJson());
    });

    test('ni description vide ni brouillon superflu', () {
      final json = AnnouncementPayload(
        departureCity: 'Paris',
        arrivalCity: 'Abidjan',
        departureDate: DateTime(2026, 11, 10),
        pickupAddress: kParis,
        deliveryAddress: kAbidjan,
        availableKg: 20,
        pricePerKg: 8,
        transportMode: TransportMode.car,
        description: '',
        handoverDeadline: DateTime.utc(2026, 11, 9),
      ).toJson();
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('saveAsDraft'), isFalse);
      expect(json.containsKey('currency'), isFalse);
    });
  });

  group('AnnouncementModel (FLUTTER-4D)', () {
    final base = {
      'id': 'a',
      'travelerId': 't',
      'departureCity': 'Paris',
      'arrivalCity': 'Abidjan',
      'departureDate': '2026-11-10',
      'availableKg': 10,
      'totalKg': 10,
      'status': 'ACTIVE',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    };

    test('lit le groupe et le rang de l\'étape', () {
      final m = AnnouncementModel.fromJson({
        ...base,
        'tripGroupId': 'g1',
        'tripLegIndex': 1,
        'tripLegCount': 2,
      });
      expect(m.isTripLeg, isTrue);
      expect(m.tripLegIndex, 1);
      expect(m.tripLegCount, 2);
      expect(m.toJson()['tripGroupId'], 'g1');
    });

    test('ancien backend : trajet isolé', () {
      final m = AnnouncementModel.fromJson(base);
      expect(m.isTripLeg, isFalse);
      expect(m.tripLegIndex, isNull);
    });
  });
}
