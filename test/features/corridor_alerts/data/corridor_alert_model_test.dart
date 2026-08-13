import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CorridorAlertModel.fromJson', () {
    test('parses a full payload', () {
      final json = <String, dynamic>{
        'id': 'a1',
        'departureCity': 'Paris',
        'arrivalCity': 'Bamako',
        'departureCountryCode': 'FR',
        'arrivalCountryCode': 'ML',
        'dateFrom': '2026-07-01',
        'dateTo': '2026-07-31',
        'minWeightKg': 3.5,
        'contentCategories': <String>['Vêtements', 'Documents'],
        'active': true,
        'matchCount': 4,
        'createdAt': '2026-06-20T09:00:00',
      };
      final m = CorridorAlertModel.fromJson(json);
      expect(m.id, 'a1');
      expect(m.departureCity, 'Paris');
      expect(m.arrivalCity, 'Bamako');
      expect(m.departureCountryCode, 'FR');
      expect(m.arrivalCountryCode, 'ML');
      expect(m.dateFrom, DateTime(2026, 7));
      expect(m.dateTo, DateTime(2026, 7, 31));
      expect(m.minWeightKg, 3.5);
      expect(m.contentCategories, ['Vêtements', 'Documents']);
      expect(m.active, isTrue);
      expect(m.matchCount, 4);
      expect(m.createdAt, DateTime(2026, 6, 20, 9));
    });

    test('tolerates nulls / missing optionals', () {
      final json = <String, dynamic>{
        'id': 'a2',
        'departureCity': 'Lyon',
        'arrivalCity': 'Dakar',
        'active': false,
        'createdAt': '2026-06-20T09:00:00',
      };
      final m = CorridorAlertModel.fromJson(json);
      expect(m.departureCountryCode, isNull);
      expect(m.dateFrom, isNull);
      expect(m.dateTo, isNull);
      expect(m.minWeightKg, isNull);
      expect(m.contentCategories, isEmpty);
      expect(m.active, isFalse);
      expect(m.matchCount, 0);
    });

    test('active round-trips true correctly', () {
      final m = CorridorAlertModel.fromJson(const <String, dynamic>{
        'id': 'rt-true',
        'departureCity': 'Paris',
        'arrivalCity': 'Abidjan',
        'active': true,
        'createdAt': '2026-06-20T09:00:00',
      });
      expect(m.active, isTrue);
    });

    test('active round-trips false correctly', () {
      final m = CorridorAlertModel.fromJson(const <String, dynamic>{
        'id': 'rt-false',
        'departureCity': 'Marseille',
        'arrivalCity': 'Douala',
        'active': false,
        'createdAt': '2026-06-20T09:00:00',
      });
      expect(m.active, isFalse);
    });

    test('throws when active is missing (strict parse)', () {
      final json = <String, dynamic>{
        'id': 'a-missing',
        'departureCity': 'Lyon',
        'arrivalCity': 'Dakar',
        'createdAt': '2026-06-20T09:00:00',
        // 'active' intentionally absent
      };
      expect(
        () => CorridorAlertModel.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('copyWith overrides active + matchCount', () {
      final m = CorridorAlertModel.fromJson(const <String, dynamic>{
        'id': 'a3',
        'departureCity': 'Paris',
        'arrivalCity': 'Douala',
        'active': true,
        'matchCount': 2,
        'createdAt': '2026-06-20T09:00:00',
      });
      final updated = m.copyWith(active: false, matchCount: 9);
      expect(updated.active, isFalse);
      expect(updated.matchCount, 9);
      expect(updated.id, 'a3');
    });
  });

  group('CorridorAlertDraft.toJson', () {
    test('omits null optionals, formats dates as yyyy-MM-dd', () {
      const draft = CorridorAlertDraft(
        departureCity: 'Paris',
        arrivalCity: 'Bamako',
        departureCountryCode: 'FR',
        arrivalCountryCode: 'ML',
        contentCategories: ['Documents'],
      );
      final json = draft.toJson();
      expect(json['departureCity'], 'Paris');
      expect(json['arrivalCity'], 'Bamako');
      expect(json['departureCountryCode'], 'FR');
      expect(json['arrivalCountryCode'], 'ML');
      expect(json['contentCategories'], ['Documents']);
      expect(json.containsKey('dateFrom'), isFalse);
      expect(json.containsKey('dateTo'), isFalse);
      expect(json.containsKey('minWeightKg'), isFalse);
    });

    test('serializes dates + minWeight when present', () {
      final draft = CorridorAlertDraft(
        departureCity: 'Paris',
        arrivalCity: 'Bamako',
        dateFrom: DateTime(2026, 7),
        dateTo: DateTime(2026, 7, 31),
        minWeightKg: 2.0,
      );
      final json = draft.toJson();
      expect(json['dateFrom'], '2026-07-01');
      expect(json['dateTo'], '2026-07-31');
      expect(json['minWeightKg'], 2.0);
    });
  });

  group('AlertDirection in CorridorAlertModel / CorridorAlertDraft', () {
    test('fromJson parses direction from wire string', () {
      final json = <String, dynamic>{
        'id': 'a1',
        'departureCity': 'Paris',
        'arrivalCity': 'Bamako',
        'direction': 'SENDER_WANTS_TRIPS',
        'active': true,
        'createdAt': '2026-06-20T09:00:00',
      };
      expect(
        CorridorAlertModel.fromJson(json).direction,
        AlertDirection.senderWantsTrips,
      );
    });

    test(
      'fromJson defaults direction to travelerWantsPackages when absent',
      () {
        final json = <String, dynamic>{
          'id': 'a1',
          'departureCity': 'Paris',
          'arrivalCity': 'Bamako',
          'active': true,
          'createdAt': '2026-06-20T09:00:00',
        };
        expect(
          CorridorAlertModel.fromJson(json).direction,
          AlertDirection.travelerWantsPackages,
        );
      },
    );

    test('draft.toJson includes direction wire string', () {
      const draft = CorridorAlertDraft(
        departureCity: 'Paris',
        arrivalCity: 'Bamako',
        direction: AlertDirection.senderWantsTrips,
      );
      expect(draft.toJson()['direction'], 'SENDER_WANTS_TRIPS');
    });
  });

  group('CorridorAlertModel / Draft — zone de remise', () {
    test('fromJson parses zone fields + hasPickupZone', () {
      final m = CorridorAlertModel.fromJson(const <String, dynamic>{
        'id': 'z1',
        'departureCity': 'Paris',
        'arrivalCity': 'Abidjan',
        'active': true,
        'createdAt': '2026-06-20T09:00:00',
        'direction': 'SENDER_WANTS_TRIPS',
        'centerLat': 48.8566,
        'centerLng': 2.3522,
        'radiusKm': 20,
        'centerLabel': 'Châtelet, Paris',
      });
      expect(m.centerLat, 48.8566);
      expect(m.centerLng, 2.3522);
      expect(m.radiusKm, 20);
      expect(m.centerLabel, 'Châtelet, Paris');
      expect(m.hasPickupZone, isTrue);
    });

    test('hasPickupZone false when zone absent', () {
      final m = CorridorAlertModel.fromJson(const <String, dynamic>{
        'id': 'z2',
        'departureCity': 'Lyon',
        'arrivalCity': 'Dakar',
        'active': true,
        'createdAt': '2026-06-20T09:00:00',
      });
      expect(m.hasPickupZone, isFalse);
      expect(m.radiusKm, isNull);
    });

    test('copyWith preserves zone fields', () {
      final m = CorridorAlertModel.fromJson(const <String, dynamic>{
        'id': 'z3',
        'departureCity': 'Paris',
        'arrivalCity': 'Abidjan',
        'active': true,
        'createdAt': '2026-06-20T09:00:00',
        'direction': 'SENDER_WANTS_TRIPS',
        'centerLat': 48.85,
        'centerLng': 2.35,
        'radiusKm': 30,
        'centerLabel': 'Paris',
      });
      final toggled = m.copyWith(active: false);
      expect(toggled.hasPickupZone, isTrue);
      expect(toggled.radiusKm, 30);
      expect(toggled.centerLabel, 'Paris');
    });

    test('draft.toJson includes zone when set', () {
      const draft = CorridorAlertDraft(
        departureCity: 'Paris',
        arrivalCity: 'Abidjan',
        direction: AlertDirection.senderWantsTrips,
        centerLat: 48.8566,
        centerLng: 2.3522,
        radiusKm: 20,
        centerLabel: 'Châtelet',
      );
      final json = draft.toJson();
      expect(json['centerLat'], 48.8566);
      expect(json['centerLng'], 2.3522);
      expect(json['radiusKm'], 20);
      expect(json['centerLabel'], 'Châtelet');
    });

    test('draft.toJson omits zone when absent', () {
      const draft = CorridorAlertDraft(
        departureCity: 'Lyon',
        arrivalCity: 'Dakar',
        direction: AlertDirection.senderWantsTrips,
      );
      final json = draft.toJson();
      expect(json.containsKey('centerLat'), isFalse);
      expect(json.containsKey('radiusKm'), isFalse);
      expect(json.containsKey('centerLabel'), isFalse);
    });
  });
}
