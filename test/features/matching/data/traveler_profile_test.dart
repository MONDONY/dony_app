import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TravelerProfile.resolvedName', () {
    test('returns displayName when set', () {
      const p = TravelerProfile(
        id: 't1',
        displayName: 'Ibrahima Diallo',
        kiloPro: false,
      );
      expect(p.resolvedName, 'Ibrahima Diallo');
    });

    test('returns phoneNumber when displayName is null', () {
      const p = TravelerProfile(
        id: 't2',
        phoneNumber: '+33612345678',
        kiloPro: false,
      );
      expect(p.resolvedName, '+33612345678');
    });

    test('returns phoneNumber when displayName is empty string', () {
      const p = TravelerProfile(
        id: 't3',
        displayName: '',
        phoneNumber: '+33699999999',
        kiloPro: false,
      );
      expect(p.resolvedName, '+33699999999');
    });

    test('returns "Voyageur" when both displayName and phoneNumber are null', () {
      const p = TravelerProfile(id: 't4', kiloPro: false);
      expect(p.resolvedName, 'Voyageur');
    });

    test('returns "Voyageur" when both are empty strings', () {
      const p = TravelerProfile(
        id: 't5',
        displayName: '',
        phoneNumber: '',
        kiloPro: false,
      );
      expect(p.resolvedName, 'Voyageur');
    });
  });

  group('TravelerProfile.resolvedInitials', () {
    test('returns two-letter initials for full name', () {
      const p = TravelerProfile(
        id: 't1',
        displayName: 'Ibrahima Diallo',
        kiloPro: false,
      );
      expect(p.resolvedInitials, 'ID');
    });

    test('returns single letter for single-word displayName', () {
      const p = TravelerProfile(
        id: 't2',
        displayName: 'Ibrahima',
        kiloPro: false,
      );
      expect(p.resolvedInitials, 'I');
    });

    test('returns first digit of phone when displayName is null', () {
      const p = TravelerProfile(
        id: 't3',
        phoneNumber: '+33612345678',
        kiloPro: false,
      );
      expect(p.resolvedInitials, '3');
    });

    test('returns "?" when both are null', () {
      const p = TravelerProfile(id: 't4', kiloPro: false);
      expect(p.resolvedInitials, '?');
    });

    test('returns "?" when displayName empty and phoneNumber has no digits', () {
      const p = TravelerProfile(
        id: 't5',
        displayName: '',
        phoneNumber: '+++',
        kiloPro: false,
      );
      expect(p.resolvedInitials, '?');
    });

    test('initials are uppercase', () {
      const p = TravelerProfile(
        id: 't6',
        displayName: 'amina barry',
        kiloPro: false,
      );
      expect(p.resolvedInitials, 'AB');
    });
  });

  group('TravelerProfile.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'tp-99',
        'displayName': 'Fatou Sow',
        'phoneNumber': '+22177000000',
        'averageRating': 4.8,
        'totalTrips': 12,
        'kiloPro': true,
      };
      final p = TravelerProfile.fromJson(json);
      expect(p.id, 'tp-99');
      expect(p.displayName, 'Fatou Sow');
      expect(p.averageRating, 4.8);
      expect(p.totalTrips, 12);
      expect(p.kiloPro, isTrue);
    });

    test('parses with optional fields null', () {
      final json = {'id': 'tp-1', 'kiloPro': false};
      final p = TravelerProfile.fromJson(json);
      expect(p.displayName, isNull);
      expect(p.phoneNumber, isNull);
      expect(p.averageRating, isNull);
      expect(p.resolvedName, 'Voyageur');
      expect(p.resolvedInitials, '?');
    });
  });
}
