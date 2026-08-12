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

    // Le numéro n'est plus un repli : il n'a jamais figuré dans TravelerProfileDto côté
    // serveur, et l'afficher comme nom contredisait « Masquer mon numéro ». Depuis la
    // migration V183 le serveur renvoie toujours un displayName (username à défaut de prénom).
    test('ignore le numéro quand displayName est null', () {
      const p = TravelerProfile(
        id: 't2',
        phoneNumber: '+33612345678',
        kiloPro: false,
      );
      expect(p.resolvedName, 'Voyageur');
    });

    test('ignore le numéro quand displayName est vide', () {
      const p = TravelerProfile(
        id: 't3',
        displayName: '',
        phoneNumber: '+33699999999',
        kiloPro: false,
      );
      expect(p.resolvedName, 'Voyageur');
    });

    test('affiche le username renvoyé comme displayName', () {
      const p = TravelerProfile(
        id: 't6',
        displayName: 'user1785153600',
        kiloPro: false,
      );
      expect(p.resolvedName, 'user1785153600');
    });

    test(
      'returns "Voyageur" when both displayName and phoneNumber are null',
      () {
        const p = TravelerProfile(id: 't4', kiloPro: false);
        expect(p.resolvedName, 'Voyageur');
      },
    );

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

    test('ignore le numéro quand displayName est null', () {
      const p = TravelerProfile(
        id: 't3',
        phoneNumber: '+33612345678',
        kiloPro: false,
      );
      expect(p.resolvedInitials, '?');
    });

    test('returns "?" when both are null', () {
      const p = TravelerProfile(id: 't4', kiloPro: false);
      expect(p.resolvedInitials, '?');
    });

    test(
      'returns "?" when displayName empty and phoneNumber has no digits',
      () {
        const p = TravelerProfile(
          id: 't5',
          displayName: '',
          phoneNumber: '+++',
          kiloPro: false,
        );
        expect(p.resolvedInitials, '?');
      },
    );

    test('initiale du username quand il tient lieu de displayName', () {
      const p = TravelerProfile(
        id: 't7',
        displayName: 'user1785153600',
        kiloPro: false,
      );
      expect(p.resolvedInitials, 'U');
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

    test('parses avatarUrl when present', () {
      final json = {
        'id': 'tp-100',
        'kiloPro': false,
        'avatarUrl': 'https://cdn.dony.app/avatars/tp-100.jpg',
      };
      final p = TravelerProfile.fromJson(json);
      expect(p.avatarUrl, 'https://cdn.dony.app/avatars/tp-100.jpg');
    });

    test('avatarUrl is null when absent', () {
      final json = {'id': 'tp-101', 'kiloPro': false};
      final p = TravelerProfile.fromJson(json);
      expect(p.avatarUrl, isNull);
    });

    test('toJson includes avatarUrl', () {
      final json = {
        'id': 'tp-102',
        'kiloPro': false,
        'avatarUrl': 'https://cdn.dony.app/avatars/tp-102.jpg',
      };
      final p = TravelerProfile.fromJson(json);
      expect(
        p.toJson()['avatarUrl'],
        'https://cdn.dony.app/avatars/tp-102.jpg',
      );
    });
  });
}
