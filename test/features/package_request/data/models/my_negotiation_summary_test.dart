import 'package:dony/features/package_request/data/models/my_negotiation_summary.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({Object? myNegotiation = _absent}) => {
  'id': 'pr-1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'desiredDate': '2026-08-15T00:00:00.000Z',
  'dateToleranceDays': 2,
  'weightKg': 5.0,
  'parcelSize': 'MEDIUM',
  'sender': {
    'id': 'sender-1',
    'displayName': 'Fatou Diallo',
    'averageRating': 4.8,
    'totalRatings': 12,
    'kycVerified': true,
  },
  if (myNegotiation != _absent) 'myNegotiation': myNegotiation,
};

const Object _absent = Object();

void main() {
  group('MyNegotiationSummary (FLUTTER-NZ)', () {
    test('champ absent (ancien back ou pas de négociation) → null', () {
      final item = PackageRequestSearchItem.fromJson(_json());
      expect(item.myNegotiation, isNull);
    });

    test('champ null → null', () {
      final item = PackageRequestSearchItem.fromJson(
        _json(myNegotiation: null),
      );
      expect(item.myNegotiation, isNull);
    });

    test('négociation à mon tour → lue telle quelle', () {
      final item = PackageRequestSearchItem.fromJson(
        _json(
          myNegotiation: {'threadId': 'th-1', 'status': 'OPEN', 'myTurn': true},
        ),
      );
      expect(
        item.myNegotiation,
        const MyNegotiationSummary(
          threadId: 'th-1',
          status: 'OPEN',
          myTurn: true,
        ),
      );
    });

    test('myTurn absent → faux (proposition en attente)', () {
      final summary = MyNegotiationSummary.tryFromJson({
        'threadId': 'th-2',
        'status': 'AWAITING_PAYMENT',
      });
      expect(summary?.myTurn, isFalse);
      expect(summary?.status, 'AWAITING_PAYMENT');
    });

    test('payload mal formé → null, la carte reste sans puce', () {
      expect(MyNegotiationSummary.tryFromJson('oops'), isNull);
      expect(MyNegotiationSummary.tryFromJson({'myTurn': true}), isNull);
      expect(MyNegotiationSummary.tryFromJson({'threadId': ''}), isNull);
    });
  });
}
