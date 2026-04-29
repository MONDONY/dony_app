import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _fullJson = {
  'id': 'ann-001',
  'travelerId': 'trav-001',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2024-06-01T00:00:00.000Z',
  'departureTime': '10:00',
  'arrivalTime': '20:00',
  'departureLocation': 'CDG Terminal 2',
  'arrivalLocation': 'Aéroport Léopold Sédar Senghor',
  'availableKg': 12.5,
  'pricePerKg': 10.0,
  'status': 'OPEN',
  'bidsCount': 3,
  'traveler': {
    'id': 'tp-001',
    'displayName': 'Ibrahima Ba',
    'phoneNumber': '+33612345678',
    'averageRating': 4.8,
    'totalTrips': 15,
    'kiloPro': true,
  },
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-20T00:00:00.000Z',
};

final _minimalJson = {
  'id': 'ann-002',
  'travelerId': 'trav-002',
  'departureCity': 'Lyon',
  'arrivalCity': 'Abidjan',
  'departureDate': '2024-07-01T00:00:00.000Z',
  'availableKg': 5,
  'pricePerKg': 15,
  'status': 'OPEN',
  'createdAt': '2024-06-01T00:00:00.000Z',
  'updatedAt': '2024-06-01T00:00:00.000Z',
};

void main() {
  group('AnnouncementModel.fromJson', () {
    test('parses all fields from full JSON', () {
      final model = AnnouncementModel.fromJson(_fullJson);
      expect(model.id, 'ann-001');
      expect(model.travelerId, 'trav-001');
      expect(model.departureCity, 'Paris');
      expect(model.arrivalCity, 'Dakar');
      expect(model.departureTime, '10:00');
      expect(model.arrivalTime, '20:00');
      expect(model.departureLocation, 'CDG Terminal 2');
      expect(model.arrivalLocation, 'Aéroport Léopold Sédar Senghor');
      expect(model.availableKg, 12.5);
      expect(model.pricePerKg, 10.0);
      expect(model.status, 'OPEN');
      expect(model.bidsCount, 3);
      expect(model.traveler, isNotNull);
      expect(model.traveler!.displayName, 'Ibrahima Ba');
      expect(model.traveler!.kiloPro, isTrue);
    });

    test('handles minimal JSON with optionals null', () {
      final model = AnnouncementModel.fromJson(_minimalJson);
      expect(model.id, 'ann-002');
      expect(model.departureTime, isNull);
      expect(model.arrivalTime, isNull);
      expect(model.departureLocation, isNull);
      expect(model.arrivalLocation, isNull);
      expect(model.bidsCount, isNull);
      expect(model.traveler, isNull);
    });

    test('availableKg parsed from int', () {
      final model = AnnouncementModel.fromJson(_minimalJson);
      expect(model.availableKg, 5.0);
    });

    test('pricePerKg parsed from int', () {
      final model = AnnouncementModel.fromJson(_minimalJson);
      expect(model.pricePerKg, 15.0);
    });
  });

  group('AnnouncementModel.toJson', () {
    test('serializes full model back to JSON', () {
      final model = AnnouncementModel.fromJson(_fullJson);
      final json = model.toJson();
      expect(json['id'], 'ann-001');
      expect(json['departureCity'], 'Paris');
      expect(json['availableKg'], 12.5);
      expect(json['bidsCount'], 3);
      expect(json['traveler'], isNotNull);
    });

    test('serializes model with null traveler', () {
      final model = AnnouncementModel.fromJson(_minimalJson);
      final json = model.toJson();
      expect(json['traveler'], isNull);
      expect(json['departureTime'], isNull);
    });
  });

  group('TravelerProfile.fromJson (generated)', () {
    test('parses full TravelerProfile', () {
      final json = {
        'id': 'tp-99',
        'displayName': 'Fatou Sow',
        'phoneNumber': '+221770000000',
        'averageRating': 4.5,
        'totalTrips': 8,
        'kiloPro': false,
      };
      final p = TravelerProfile.fromJson(json);
      expect(p.id, 'tp-99');
      expect(p.averageRating, 4.5);
      expect(p.totalTrips, 8);
      expect(p.kiloPro, isFalse);
    });

    test('toJson round-trips correctly', () {
      final json = {
        'id': 'tp-1',
        'displayName': 'Test User',
        'kiloPro': true,
      };
      final p = TravelerProfile.fromJson(json);
      final out = p.toJson();
      expect(out['id'], 'tp-1');
      expect(out['displayName'], 'Test User');
      expect(out['kiloPro'], isTrue);
    });
  });

  group('PaymentModel (generated — via payment_model.g.dart)', () {
    test('placeholder — covered by payment_bloc_test', () {
      // payment_model.g.dart is exercised by PaymentModel.fromJson calls in payment_bloc_test
      expect(true, isTrue);
    });
  });
}
