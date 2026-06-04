import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _baseJson({Object? negotiable = _absent}) => {
      'id': 'pr-1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'desiredDate': '2026-08-15T00:00:00.000Z',
      'dateToleranceDays': 2,
      'weightKg': 5.0,
      'parcelSize': 'MEDIUM',
      'contentCategory': 'VETEMENTS',
      'targetPriceEur': 50.0,
      'sender': {
        'id': 'sender-1',
        'displayName': 'Fatou Diallo',
        'averageRating': 4.8,
        'totalRatings': 12,
        'kycVerified': true,
      },
      if (negotiable != _absent) 'negotiable': negotiable,
    };

const Object _absent = Object();

void main() {
  group('PackageRequestSearchItem', () {
    test('defaults negotiable to true when absent from JSON', () {
      final item = PackageRequestSearchItem.fromJson(_baseJson());
      expect(item.negotiable, isTrue);
    });

    test('parses negotiable=false', () {
      final item =
          PackageRequestSearchItem.fromJson(_baseJson(negotiable: false));
      expect(item.negotiable, isFalse);
    });

    test('parses negotiable=true', () {
      final item =
          PackageRequestSearchItem.fromJson(_baseJson(negotiable: true));
      expect(item.negotiable, isTrue);
    });

    test('constructor defaults negotiable to true', () {
      final item = PackageRequestSearchItem(
        id: 'pr-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 8, 15),
        dateToleranceDays: 2,
        weightKg: 5,
        parcelSize: ParcelSize.medium,
        contentCategory: ContentCategory.vetements,
        sender: const SenderPublicProfile(
          id: 'sender-1',
          displayName: 'Fatou Diallo',
          averageRating: 4.8,
          totalRatings: 12,
          kycVerified: true,
        ),
      );
      expect(item.negotiable, isTrue);
    });

    test('negotiable participates in equality (props)', () {
      final firm =
          PackageRequestSearchItem.fromJson(_baseJson(negotiable: false));
      final negotiable =
          PackageRequestSearchItem.fromJson(_baseJson(negotiable: true));
      expect(firm, isNot(equals(negotiable)));
    });
  });
}
