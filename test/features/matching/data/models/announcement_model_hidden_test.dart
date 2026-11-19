import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json([Object? hidden = _absent]) => {
  'id': 'ann1',
  'travelerId': 'traveler1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2024-06-01',
  'availableKg': 10.0,
  'totalKg': 20.0,
  'pricePerKg': 15.0,
  'status': 'ACTIVE',
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
  if (hidden != _absent) 'hidden': hidden,
};

const Object _absent = Object();

void main() {
  group('hidden (trajet caché de la recherche)', () {
    test('absent (ancien back) : false', () {
      expect(AnnouncementModel.fromJson(_json()).hidden, isFalse);
    });

    test('null : false', () {
      expect(AnnouncementModel.fromJson(_json(null)).hidden, isFalse);
    });

    test('true et false lus tels quels', () {
      expect(AnnouncementModel.fromJson(_json(true)).hidden, isTrue);
      expect(AnnouncementModel.fromJson(_json(false)).hidden, isFalse);
    });

    test('aller-retour JSON', () {
      final a = AnnouncementModel.fromJson(_json(true));
      expect(a.toJson()['hidden'], isTrue);
      expect(AnnouncementModel.fromJson(a.toJson()).hidden, isTrue);
    });
  });
}
