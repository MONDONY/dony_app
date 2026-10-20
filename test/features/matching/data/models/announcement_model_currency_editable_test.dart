import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  Object? currencyEditable = _absent,
  Object? departureTimezone = _absent,
  Object? handoverDeadline = _absent,
}) => {
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
  if (departureTimezone != _absent) 'departureTimezone': departureTimezone,
  if (handoverDeadline != _absent) 'handoverDeadline': handoverDeadline,
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

  group('departureTimezone (PROD-1R)', () {
    test('absent (back antérieur à #627) → null', () {
      expect(AnnouncementModel.fromJson(_json()).departureTimezone, isNull);
    });

    test('présent → lu tel quel, aller-retour JSON', () {
      final a = AnnouncementModel.fromJson(
        _json(departureTimezone: 'Europe/Paris'),
      );
      expect(a.departureTimezone, 'Europe/Paris');
      expect(a.toJson()['departureTimezone'], 'Europe/Paris');
    });
  });

  group('isHandoverClosedAt (PROD-1R)', () {
    final now = DateTime.utc(2027, 7, 20, 18, 31);

    test('limite passée (instant UTC) → dépôt clos', () {
      final a = AnnouncementModel.fromJson(
        _json(handoverDeadline: '2027-07-20T18:30:00Z'),
      );
      expect(a.isHandoverClosedAt(now), isTrue);
    });

    test('limite à venir → dépôt ouvert', () {
      final a = AnnouncementModel.fromJson(
        _json(handoverDeadline: '2027-07-20T18:32:00Z'),
      );
      expect(a.isHandoverClosedAt(now), isFalse);
    });

    test('sans limite (ancienne annonce) → jamais clos', () {
      expect(
        AnnouncementModel.fromJson(_json()).isHandoverClosedAt(now),
        isFalse,
      );
      expect(AnnouncementModel.fromJson(_json()).isHandoverClosed, isFalse);
    });
  });
}
