import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
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
      final item = PackageRequestSearchItem.fromJson(
        _baseJson(negotiable: false),
      );
      expect(item.negotiable, isFalse);
    });

    test('parses negotiable=true', () {
      final item = PackageRequestSearchItem.fromJson(
        _baseJson(negotiable: true),
      );
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
        categories: const ['Vêtements'],
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
      final firm = PackageRequestSearchItem.fromJson(
        _baseJson(negotiable: false),
      );
      final negotiable = PackageRequestSearchItem.fromJson(
        _baseJson(negotiable: true),
      );
      expect(firm, isNot(equals(negotiable)));
    });

    test('parses acceptedPaymentMethods from JSON', () {
      final json = _baseJson()..['acceptedPaymentMethods'] = ['STRIPE', 'CASH'];
      final item = PackageRequestSearchItem.fromJson(json);
      expect(item.acceptedPaymentMethods, {
        PaymentMethod.stripe,
        PaymentMethod.cash,
      });
    });

    test('acceptedPaymentMethods defaults to empty when absent', () {
      final item = PackageRequestSearchItem.fromJson(_baseJson());
      expect(item.acceptedPaymentMethods, isEmpty);
    });
  });

  group('SenderPublicProfile avatarUrl', () {
    test('parses avatarUrl when present', () {
      final json = _baseJson();
      (json['sender'] as Map<String, dynamic>)['avatarUrl'] =
          'https://cdn.dony.app/avatars/sender-1.jpg';
      final item = PackageRequestSearchItem.fromJson(json);
      expect(
        item.sender.avatarUrl,
        'https://cdn.dony.app/avatars/sender-1.jpg',
      );
    });

    test('avatarUrl is null when absent', () {
      final item = PackageRequestSearchItem.fromJson(_baseJson());
      expect(item.sender.avatarUrl, isNull);
    });

    test('avatarUrl participates in equality (props)', () {
      final json1 = _baseJson();
      final json2 = _baseJson();
      (json2['sender'] as Map<String, dynamic>)['avatarUrl'] =
          'https://cdn.dony.app/avatars/sender-1.jpg';
      final item1 = PackageRequestSearchItem.fromJson(json1);
      final item2 = PackageRequestSearchItem.fromJson(json2);
      expect(item1.sender, isNot(equals(item2.sender)));
    });
  });

  group('PackageRequestSearchItem urgent', () {
    test('urgent depuis le JSON prime sur le calcul local (true)', () {
      final json = _baseJson()
        ..['desiredDate'] = DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
        ..['urgent'] = true;
      final item = PackageRequestSearchItem.fromJson(json);
      expect(item.isUrgent, isTrue);
    });

    test('urgent depuis le JSON prime sur le calcul local (false)', () {
      final json = _baseJson()
        ..['desiredDate'] = DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
        ..['urgent'] = false;
      final item = PackageRequestSearchItem.fromJson(json);
      expect(item.isUrgent, isFalse);
    });

    test('urgent absent → repli sur la date (proche → urgent)', () {
      final json = _baseJson()
        ..['desiredDate'] = DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String();
      final item = PackageRequestSearchItem.fromJson(json);
      expect(item.urgent, isNull);
      expect(item.isUrgent, isTrue);
    });

    test('urgent absent → repli sur la date (lointaine → pas urgent)', () {
      final json = _baseJson()
        ..['desiredDate'] = DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String();
      final item = PackageRequestSearchItem.fromJson(json);
      expect(item.urgent, isNull);
      expect(item.isUrgent, isFalse);
    });

    test('isUrgent match isUrgentDate quand urgent absent', () {
      final desiredDate = DateTime.now().add(const Duration(days: 2));
      final json = _baseJson()..['desiredDate'] = desiredDate.toIso8601String();
      final item = PackageRequestSearchItem.fromJson(json);
      expect(item.isUrgent, isUrgentDate(item.desiredDate));
    });

    test('urgent participates in equality (props)', () {
      final withUrgent = PackageRequestSearchItem.fromJson(
        _baseJson()..['urgent'] = true,
      );
      final withoutUrgent = PackageRequestSearchItem.fromJson(_baseJson());
      expect(withUrgent, isNot(equals(withoutUrgent)));
    });
  });

  // ─── Champs de match (filtre « Pour mes trajets ») ─────────────────────────
  group('PackageRequestSearchItem.grossPriceEur (brut pour un invité)', () {
    test('grossPriceEur est lu quand le serveur le fournit', () {
      final json = _baseJson()..['grossPriceEur'] = 60.0;

      final item = PackageRequestSearchItem.fromJson(json);

      expect(item.grossPriceEur, 60.0);
    });

    test('grossPriceEur absent : nul, aucune exception', () {
      final json = _baseJson();

      final item = PackageRequestSearchItem.fromJson(json);

      expect(item.grossPriceEur, isNull);
    });

    test('parses an integer grossPriceEur as a double', () {
      final json = _baseJson()..['grossPriceEur'] = 60;

      final item = PackageRequestSearchItem.fromJson(json);

      expect(item.grossPriceEur, 60.0);
    });

    test('grossPriceEur participates in equality (props)', () {
      final avec = PackageRequestSearchItem.fromJson(
        _baseJson()..['grossPriceEur'] = 60.0,
      );
      final sans = PackageRequestSearchItem.fromJson(_baseJson());
      expect(avec, isNot(equals(sans)));
    });
  });

  group('matchingMyTrips', () {
    test('fromJson lit les trois champs de match', () {
      final item = PackageRequestSearchItem.fromJson({
        ..._baseJson(),
        'matchScore': 94,
        'matchedTripId': 'b1f0-trip',
        'matchedTripDepartureDate': '2026-08-12',
      });

      expect(item.matchScore, 94);
      expect(item.matchedTripId, 'b1f0-trip');
      expect(item.matchedTripDepartureDate, DateTime(2026, 8, 12));
    });

    test('les trois champs sont nuls quand le serveur ne les renvoie pas', () {
      final item = PackageRequestSearchItem.fromJson(_baseJson());

      expect(item.matchScore, isNull);
      expect(item.matchedTripId, isNull);
      expect(item.matchedTripDepartureDate, isNull);
    });

    test('matchScore participe à l\'égalité (props)', () {
      final avec = PackageRequestSearchItem.fromJson(
        _baseJson()..['matchScore'] = 94,
      );
      final sans = PackageRequestSearchItem.fromJson(_baseJson());
      expect(avec, isNot(equals(sans)));
    });

    test('matchedTripId participe à l\'égalité (props)', () {
      final avec = PackageRequestSearchItem.fromJson(
        _baseJson()..['matchedTripId'] = 'trip-9',
      );
      final sans = PackageRequestSearchItem.fromJson(_baseJson());
      expect(avec, isNot(equals(sans)));
    });

    test('matchedTripDepartureDate participe à l\'égalité (props)', () {
      final avec = PackageRequestSearchItem.fromJson(
        _baseJson()..['matchedTripDepartureDate'] = '2026-08-12',
      );
      final sans = PackageRequestSearchItem.fromJson(_baseJson());
      expect(avec, isNot(equals(sans)));
    });
  });
}
