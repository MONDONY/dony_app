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
        pricePerKg: 5.0,
        status: 'ACTIVE',
        createdAt: DateTime.parse('2026-05-02'),
        updatedAt: DateTime.parse('2026-05-02'),
      );
      final json = model.toJson();
      expect(json['transportMode'], isNull);
    });
  });
}
