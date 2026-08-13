import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _minimalAnnouncement({List<String>? methods}) => {
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
  'acceptedPaymentMethods': ?methods,
};

void main() {
  test('announcement defaults to STRIPE only', () {
    final a = AnnouncementModel.fromJson(_minimalAnnouncement());
    expect(a.acceptedPaymentMethods, {BidPaymentMethod.stripe});
  });

  test('parses STRIPE and CASH payment methods', () {
    final a = AnnouncementModel.fromJson(
      _minimalAnnouncement(methods: ['STRIPE', 'CASH']),
    );
    expect(a.acceptedPaymentMethods, {
      BidPaymentMethod.stripe,
      BidPaymentMethod.cash,
    });
  });

  test('parses CASH only', () {
    final a = AnnouncementModel.fromJson(
      _minimalAnnouncement(methods: ['CASH']),
    );
    expect(a.acceptedPaymentMethods, {BidPaymentMethod.cash});
  });
}
