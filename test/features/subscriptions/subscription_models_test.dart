import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TravelerAnnouncement.fromJson', () {
    Map<String, dynamic> base() => {
      'id': 'a1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'departureDate': '2026-11-02',
      'pricePerKg': 0,
      'availableKg': 20,
      'status': 'ACTIVE',
    };

    test('grille : mode et prix « dès X » lus', () {
      final a = TravelerAnnouncement.fromJson({
        ...base(),
        'pricingMode': 'MIXED',
        'minGridUnitPriceDisplay': 16.8,
      });
      expect(a.pricingMode, 'MIXED');
      expect(a.minGridUnitPriceDisplay, 16.8);
      expect(a.gridOnly, isTrue);
    });

    test('ancien back : KG par défaut, prix au kilo à 0 vaut grille', () {
      final a = TravelerAnnouncement.fromJson(base());
      expect(a.pricingMode, 'KG');
      expect(a.minGridUnitPriceDisplay, isNull);
      expect(a.gridOnly, isTrue);
      expect(
        TravelerAnnouncement.fromJson({...base(), 'pricePerKg': 8}).gridOnly,
        isFalse,
      );
    });
  });

  group('LastAnnouncement.fromJson', () {
    Map<String, dynamic> base() => {
      'announcementId': 'a1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'pricePerKg': 8,
      'publishedAt': '2026-10-14T10:00:00',
    };

    test('grille : mode et prix « dès X » lus', () {
      final last = LastAnnouncement.fromJson({
        ...base(),
        'pricePerKg': 0,
        'pricingMode': 'MIXED',
        'minGridUnitPriceDisplay': 16.8,
      });
      expect(last.gridOnly, isTrue);
      expect(last.minGridUnitPriceDisplay, 16.8);
    });

    test('ancien back : KG par défaut', () {
      final last = LastAnnouncement.fromJson(base());
      expect(last.pricingMode, 'KG');
      expect(last.gridOnly, isFalse);
    });
  });
}
