import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _minimalBid() => {
  'id': 'bid1',
  'announcementId': 'ann1',
  'senderId': 'sender1',
  'weightKg': 5.0,
  'status': 'PENDING',
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
};

void main() {
  group('BidModel.arrivalInstructions', () {
    test('fromJson parses arrivalInstructions', () {
      final json = _minimalBid()
        ..['arrivalInstructions'] = 'Métro Châtelet, sortie 3';
      final model = BidModel.fromJson(json);
      expect(model.arrivalInstructions, 'Métro Châtelet, sortie 3');
    });

    test('arrivalInstructions absent → null', () {
      final model = BidModel.fromJson(_minimalBid());
      expect(model.arrivalInstructions, isNull);
    });

    test('round-trips arrivalInstructions through toJson', () {
      final json = _minimalBid()
        ..['arrivalInstructions'] = 'Métro Châtelet, sortie 3';
      final out = BidModel.fromJson(json).toJson();
      expect(out['arrivalInstructions'], 'Métro Châtelet, sortie 3');
    });
  });
}
