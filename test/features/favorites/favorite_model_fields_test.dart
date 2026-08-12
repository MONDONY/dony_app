/// Tests for the `isFavorite` field added to existing models
/// (AnnouncementModel and PackageRequestSearchItem) as part of the favorites
/// feature. These supplement existing model tests which predate the field.
library;

import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // AnnouncementModel.isFavorite
  // ---------------------------------------------------------------------------
  group('AnnouncementModel.isFavorite', () {
    Map<String, dynamic> baseAnnouncementJson() => {
          'id': 'trip-1',
          'travelerId': 'tv1',
          'departureCity': 'Paris',
          'arrivalCity': 'Dakar',
          'departureDate':
              DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          'totalKg': 20.0,
          'availableKg': 15.0,
          'pricePerKg': 8.0,
          'pricingMode': 'KG',
          'status': 'ACTIVE',
          'pendingBidCount': 0,
          'confirmedParcelCount': 0,
          'createdAt': '2024-01-01T00:00:00Z',
          'updatedAt': '2024-01-01T00:00:00Z',
        };

    test('defaults to false when isFavorite is absent from JSON', () {
      final model = AnnouncementModel.fromJson(baseAnnouncementJson());

      expect(model.isFavorite, isFalse);
    });

    test('parses isFavorite=true from JSON', () {
      final json = baseAnnouncementJson()..['isFavorite'] = true;
      final model = AnnouncementModel.fromJson(json);

      expect(model.isFavorite, isTrue);
    });

    test('parses isFavorite=false explicitly from JSON', () {
      final json = baseAnnouncementJson()..['isFavorite'] = false;
      final model = AnnouncementModel.fromJson(json);

      expect(model.isFavorite, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // PackageRequestSearchItem.isFavorite
  // ---------------------------------------------------------------------------
  group('PackageRequestSearchItem.isFavorite', () {
    Map<String, dynamic> baseRequestJson() => {
          'id': 'req-1',
          'departureCity': 'Lyon',
          'arrivalCity': 'Abidjan',
          'desiredDate': '2025-07-01',
          'dateToleranceDays': 3,
          'weightKg': 4.0,
          'parcelSize': 'MEDIUM',
          'sender': {
            'id': 's1',
            'displayName': 'Moussa',
            'averageRating': 4.5,
            'totalRatings': 8,
            'kycVerified': true,
          },
        };

    test('defaults to false when isFavorite is absent from JSON', () {
      final item = PackageRequestSearchItem.fromJson(baseRequestJson());

      expect(item.isFavorite, isFalse);
    });

    test('parses isFavorite=true from JSON', () {
      final json = baseRequestJson()..['isFavorite'] = true;
      final item = PackageRequestSearchItem.fromJson(json);

      expect(item.isFavorite, isTrue);
    });

    test('default constructor uses false for isFavorite', () {
      final item = PackageRequestSearchItem(
        id: 'req-2',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2025, 8, 1),
        dateToleranceDays: 2,
        weightKg: 3.0,
        parcelSize: ParcelSize.small,
        sender: const SenderPublicProfile(
          id: 's2',
          displayName: 'Diallo',
          averageRating: 4.0,
          totalRatings: 5,
          kycVerified: true,
        ),
      );

      expect(item.isFavorite, isFalse);
    });

    test('isFavorite is included in Equatable props', () {
      final json = baseRequestJson();
      final a = PackageRequestSearchItem.fromJson(json..['isFavorite'] = false);
      final b = PackageRequestSearchItem.fromJson(json..['isFavorite'] = true);

      // Different isFavorite → not equal
      expect(a, isNot(equals(b)));
    });
  });
}
