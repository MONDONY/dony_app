import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> baseAnnouncementJson() => {
    'id': 'a1',
    'travelerId': 't1',
    'departureCity': 'Paris',
    'arrivalCity': 'Dakar',
    'departureDate': '2026-06-01T00:00:00.000Z',
    'availableKg': 10.0,
    'totalKg': 10.0,
    'pricePerKg': 5.0,
    'status': 'ACTIVE',
    'createdAt': '2026-05-02T00:00:00.000Z',
    'updatedAt': '2026-05-02T00:00:00.000Z',
  };

  group('AnnouncementModel.transportMode', () {
    test('deserializes "PLANE" -> TransportMode.plane', () {
      final json = baseAnnouncementJson()..['transportMode'] = 'PLANE';
      final model = AnnouncementModel.fromJson(json);
      expect(model.transportMode, TransportMode.plane);
    });

    test('deserializes each known value', () {
      const wireToEnum = {
        'PLANE': TransportMode.plane,
        'CAR': TransportMode.car,
        'TRAIN': TransportMode.train,
        'BUS': TransportMode.bus,
        'BOAT': TransportMode.boat,
        'OTHER': TransportMode.other,
      };
      for (final entry in wireToEnum.entries) {
        final json = baseAnnouncementJson()..['transportMode'] = entry.key;
        final model = AnnouncementModel.fromJson(json);
        expect(model.transportMode, entry.value);
      }
    });

    test('deserializes missing transportMode as null', () {
      final json = baseAnnouncementJson();
      final model = AnnouncementModel.fromJson(json);
      expect(model.transportMode, isNull);
    });

    test('deserializes unknown transportMode as null', () {
      final json = baseAnnouncementJson()..['transportMode'] = 'BIKE';
      final model = AnnouncementModel.fromJson(json);
      expect(model.transportMode, isNull);
    });

    test('serializes TransportMode.plane -> "PLANE"', () {
      final model = AnnouncementModel(
        id: 'a1',
        travelerId: 't1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime.parse('2026-06-01'),
        availableKg: 10.0,
        totalKg: 10.0,
        pricePerKg: 5.0,
        status: 'ACTIVE',
        createdAt: DateTime.parse('2026-05-02'),
        updatedAt: DateTime.parse('2026-05-02'),
        transportMode: TransportMode.plane,
      );
      final json = model.toJson();
      expect(json['transportMode'], 'PLANE');
    });

    test('serializes null transportMode -> null in JSON', () {
      final model = AnnouncementModel(
        id: 'a1',
        travelerId: 't1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime.parse('2026-06-01'),
        availableKg: 10.0,
        totalKg: 10.0,
        pricePerKg: 5.0,
        status: 'ACTIVE',
        createdAt: DateTime.parse('2026-05-02'),
        updatedAt: DateTime.parse('2026-05-02'),
      );
      final json = model.toJson();
      expect(json['transportMode'], isNull);
    });
  });

  group('AnnouncementGridItemModel', () {
    test('constructs correctly', () {
      const item = AnnouncementGridItemModel(
        id: 'item-1',
        label: 'Valise cabine',
        unitPriceNet: 10.0,
        unitPriceDisplay: 11.2,
      );

      expect(item.id, 'item-1');
      expect(item.label, 'Valise cabine');
      expect(item.unitPriceNet, 10.0);
      expect(item.unitPriceDisplay, 11.2);
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'item-2',
        'label': 'Téléphone',
        'unitPriceNet': 20.0,
        'unitPriceDisplay': 22.4,
      };
      final item = AnnouncementGridItemModel.fromJson(json);

      expect(item.id, 'item-2');
      expect(item.label, 'Téléphone');
      expect(item.unitPriceNet, 20.0);
      expect(item.unitPriceDisplay, 22.4);
    });

    test('fromJson handles integer price values', () {
      final json = {
        'id': 'item-3',
        'label': 'Ordinateur',
        'unitPriceNet': 50,
        'unitPriceDisplay': 56,
      };
      final item = AnnouncementGridItemModel.fromJson(json);

      expect(item.unitPriceNet, 50.0);
      expect(item.unitPriceDisplay, 56.0);
    });

    test('toJson serializes correctly', () {
      const item = AnnouncementGridItemModel(
        id: 'item-4',
        label: 'Chaussures',
        unitPriceNet: 15.0,
        unitPriceDisplay: 16.8,
      );
      final json = item.toJson();

      expect(json['id'], 'item-4');
      expect(json['label'], 'Chaussures');
      expect(json['unitPriceNet'], 15.0);
      expect(json['unitPriceDisplay'], 16.8);
    });

    test('round-trips through JSON', () {
      const original = AnnouncementGridItemModel(
        id: 'item-round',
        label: 'Sacoche',
        unitPriceNet: 8.0,
        unitPriceDisplay: 9.0,
      );
      final json = original.toJson();
      final restored = AnnouncementGridItemModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.label, original.label);
      expect(restored.unitPriceNet, original.unitPriceNet);
      expect(restored.unitPriceDisplay, original.unitPriceDisplay);
    });
  });

  group('AnnouncementModel with priceGridItems', () {
    test('deserializes priceGridItems from JSON', () {
      final json = baseAnnouncementJson()
        ..['pricingMode'] = 'MIXED'
        ..['priceGridItems'] = [
          {
            'id': 'item-1',
            'label': 'Valise cabine',
            'unitPriceNet': 10.0,
            'unitPriceDisplay': 11.2,
          }
        ];

      final model = AnnouncementModel.fromJson(json);
      expect(model.priceGridItems, hasLength(1));
      expect(model.priceGridItems.first.id, 'item-1');
      expect(model.priceGridItems.first.label, 'Valise cabine');
    });

    test('priceGridItems defaults to empty list when null in JSON', () {
      final json = baseAnnouncementJson();
      final model = AnnouncementModel.fromJson(json);
      expect(model.priceGridItems, isEmpty);
    });

    test('priceGridItems serializes back to JSON', () {
      final model = AnnouncementModel(
        id: 'a1',
        travelerId: 't1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime.parse('2026-06-01'),
        availableKg: 10.0,
        totalKg: 10.0,
        pricePerKg: 5.0,
        status: 'ACTIVE',
        createdAt: DateTime.parse('2026-05-02'),
        updatedAt: DateTime.parse('2026-05-02'),
        pricingMode: 'MIXED',
        priceGridItems: const [
          AnnouncementGridItemModel(
            id: 'item-1',
            label: 'Valise',
            unitPriceNet: 10.0,
            unitPriceDisplay: 11.2,
          ),
        ],
      );

      final json = model.toJson();
      expect(json['priceGridItems'], isNotNull);
      expect((json['priceGridItems'] as List), hasLength(1));
    });
  });
}
