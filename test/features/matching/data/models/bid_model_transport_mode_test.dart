import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

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
  group('BidModel.transportMode', () {
    test('BOAT est lu comme bateau', () {
      final b = BidModel.fromJson(_bid({'transportMode': 'BOAT'}));
      expect(b.transportMode, TransportMode.boat);
    });

    test('champ absent : null (le repli est décidé par l\'écran)', () {
      expect(BidModel.fromJson(_bid()).transportMode, isNull);
    });

    test('valeur inconnue : null, sans planter', () {
      final b = BidModel.fromJson(_bid({'transportMode': 'ROCKET'}));
      expect(b.transportMode, isNull);
    });

    test('aller-retour JSON : le mode est conservé', () {
      final b = BidModel.fromJson(_bid({'transportMode': 'CAR'}));
      expect(BidModel.fromJson(b.toJson()).transportMode, TransportMode.car);
    });
  });
}
