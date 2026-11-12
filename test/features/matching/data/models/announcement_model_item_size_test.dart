import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _announcement([Map<String, dynamic> extra = const {}]) => {
  'id': 'a1',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2026-10-13',
  'availableKg': 10,
  'totalKg': 20,
  'pricePerKg': 5,
  'status': 'ACTIVE',
  'createdAt': '2026-10-01T10:00:00',
  'updatedAt': '2026-10-01T10:00:00',
  ...extra,
};

Map<String, dynamic> _bid([Map<String, dynamic> extra = const {}]) => {
  'id': 'bid1',
  'announcementId': 'ann1',
  'senderId': 'sender1',
  'weightKg': 5.0,
  'status': 'PENDING',
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
  ...extra,
};

void main() {
  group('AnnouncementModel : taille et poids max par colis', () {
    test('back antérieur (clés absentes) : null, sans exception', () {
      final a = AnnouncementModel.fromJson(_announcement());
      expect(a.maxItemSize, isNull);
      expect(a.maxParcelWeightKg, isNull);
    });

    test('taille L et poids max entier JSON 20 : lus', () {
      final a = AnnouncementModel.fromJson(
        _announcement({'maxItemSize': 'L', 'maxParcelWeightKg': 20}),
      );
      expect(a.maxItemSize, ItemSize.l);
      expect(a.maxParcelWeightKg, 20.0);
    });

    test('clés présentes à null : null', () {
      final a = AnnouncementModel.fromJson(
        _announcement({'maxItemSize': null, 'maxParcelWeightKg': null}),
      );
      expect(a.maxItemSize, isNull);
      expect(a.maxParcelWeightKg, isNull);
    });

    test('taille inconnue, minuscule ou NONE : null', () {
      for (final raw in ['XXL', 'l', 'NONE', '', 3]) {
        expect(
          AnnouncementModel.fromJson(
            _announcement({'maxItemSize': raw}),
          ).maxItemSize,
          isNull,
          reason: '$raw',
        );
      }
    });

    test('poids max à 999 999,99 : sans perte de décimale', () {
      final a = AnnouncementModel.fromJson(
        _announcement({'maxParcelWeightKg': 999999.99}),
      );
      expect(a.maxParcelWeightKg, 999999.99);
    });

    test('trajet route de 1 200 kg (entier JSON) lu en double', () {
      final a = AnnouncementModel.fromJson(
        _announcement({'availableKg': 1200, 'totalKg': 1200}),
      );
      expect(a.availableKg, 1200.0);
      expect(a.totalKg, 1200.0);
    });

    test('aller-retour JSON : taille et poids max conservés', () {
      final a = AnnouncementModel.fromJson(
        _announcement({'maxItemSize': 'XL', 'maxParcelWeightKg': 12.5}),
      );
      final json = a.toJson();
      expect(json['maxItemSize'], 'XL');
      final back = AnnouncementModel.fromJson(json);
      expect(back.maxItemSize, ItemSize.xl);
      expect(back.maxParcelWeightKg, 12.5);
    });

    test('sans taille, toJson la sérialise à null', () {
      final json = AnnouncementModel.fromJson(_announcement()).toJson();
      expect(json['maxItemSize'], isNull);
    });
  });

  group('BidModel.itemSize', () {
    test('champ absent : null', () {
      expect(BidModel.fromJson(_bid()).itemSize, isNull);
    });

    test('M lu', () {
      expect(BidModel.fromJson(_bid({'itemSize': 'M'})).itemSize, ItemSize.m);
    });

    test('valeur inconnue : null, sans exception', () {
      expect(BidModel.fromJson(_bid({'itemSize': 'XXL'})).itemSize, isNull);
    });

    test('aller-retour JSON', () {
      final b = BidModel.fromJson(_bid({'itemSize': 'S'}));
      expect(BidModel.fromJson(b.toJson()).itemSize, ItemSize.s);
    });
  });
}
