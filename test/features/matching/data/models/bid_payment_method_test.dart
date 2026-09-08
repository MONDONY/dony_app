import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// JSON minimal valide pour un [BidModel], copié de la fixture
/// `_minimalBid` de `bid_model_cash_test.dart`.
Map<String, dynamic> _minimalBid({String? paymentMethod}) => {
  'id': 'bid1',
  'announcementId': 'ann1',
  'senderId': 'sender1',
  'weightKg': 5.0,
  'status': 'PENDING',
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
  'paymentMethod': ?paymentMethod,
};

/// JSON minimal valide pour un [AnnouncementModel], copié de la fixture
/// `_minimalAnnouncement` de `announcement_model_cash_test.dart`.
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
  test('MOBILE_MONEY est une valeur de BidPaymentMethod', () {
    expect(BidPaymentMethod.mobileMoney.apiValue, 'MOBILE_MONEY');
    expect(
      BidPaymentMethodApi.fromApi('MOBILE_MONEY'),
      BidPaymentMethod.mobileMoney,
    );
  });

  test('fromApi rend null pour une valeur inconnue ou nulle', () {
    expect(BidPaymentMethodApi.fromApi('BITCOIN'), isNull);
    expect(BidPaymentMethodApi.fromApi(null), isNull);
  });

  test('acceptedPaymentMethodsFromJson ignore les valeurs inconnues', () {
    expect(
      acceptedPaymentMethodsFromJson(['CASH', 'BITCOIN', 'MOBILE_MONEY']),
      {BidPaymentMethod.cash, BidPaymentMethod.mobileMoney},
    );
    expect(acceptedPaymentMethodsFromJson(null), {BidPaymentMethod.stripe});
  });

  test('BidModel.fromJson replie une méthode inconnue sur stripe', () {
    final b = BidModel.fromJson(_minimalBid(paymentMethod: 'BITCOIN'));
    expect(b.paymentMethod, BidPaymentMethod.stripe);
  });

  test(
    'AnnouncementModel.fromJson ignore une méthode de paiement inconnue '
    'dans acceptedPaymentMethods',
    () {
      final a = AnnouncementModel.fromJson(
        _minimalAnnouncement(methods: ['STRIPE', 'BITCOIN']),
      );
      expect(a.acceptedPaymentMethods, {BidPaymentMethod.stripe});
    },
  );
}
