import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
