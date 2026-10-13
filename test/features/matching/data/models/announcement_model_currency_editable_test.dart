import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({Object? currencyEditable = _absent}) => {
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
  if (currencyEditable != _absent) 'currencyEditable': currencyEditable,
};

const Object _absent = Object();

void main() {
  group('currencyEditable (FLUTTER-KV)', () {
    test('absent (back antérieur, non-propriétaire) → null', () {
      expect(AnnouncementModel.fromJson(_json()).currencyEditable, isNull);
    });

    test('true / false lus tels quels', () {
      expect(
        AnnouncementModel.fromJson(
          _json(currencyEditable: true),
        ).currencyEditable,
        isTrue,
      );
      expect(
        AnnouncementModel.fromJson(
          _json(currencyEditable: false),
        ).currencyEditable,
        isFalse,
      );
    });

    test('aller-retour JSON', () {
      final a = AnnouncementModel.fromJson(_json(currencyEditable: true));
      expect(a.toJson()['currencyEditable'], isTrue);
    });
  });
}
