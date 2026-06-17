import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal valid JSON for BidModel (non-nullable required fields only).
final _minimalBidJson = {
  'id': 'bid-001',
  'announcementId': 'ann-001',
  'senderId': 'sender-001',
  'status': 'PENDING',
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-01T00:00:00.000Z',
};

void main() {
  group('BidPhoto', () {
    test('round-trips JSON', () {
      final p = BidPhoto.fromJson({'id': 'abc', 'url': 'https://signed/1'});
      expect(p.id, 'abc');
      expect(p.url, 'https://signed/1');
      expect(p.toJson(), {'id': 'abc', 'url': 'https://signed/1'});
    });

    test('const constructor sets fields', () {
      const p = BidPhoto(id: 'x', url: 'https://s3/x');
      expect(p.id, 'x');
      expect(p.url, 'https://s3/x');
    });
  });

  group('BidModel.photos', () {
    test('parses photos list from JSON', () {
      final json = {
        ..._minimalBidJson,
        'photos': [
          {'id': 'p1', 'url': 'https://signed/1'},
          {'id': 'p2', 'url': 'https://signed/2'},
        ],
      };
      final bid = BidModel.fromJson(json);
      expect(bid.photos.length, 2);
      expect(bid.photos.first.id, 'p1');
      expect(bid.photos.first.url, 'https://signed/1');
      expect(bid.photos.last.id, 'p2');
    });

    test('defaults to empty list when photos key is absent', () {
      final bid = BidModel.fromJson(_minimalBidJson);
      expect(bid.photos, isEmpty);
    });

    test('defaults to empty list when photos is null in JSON', () {
      final json = {..._minimalBidJson, 'photos': null};
      final bid = BidModel.fromJson(json);
      expect(bid.photos, isEmpty);
    });

    test('constructor defaults photos to const []', () {
      final bid = BidModel(
        id: 'bid-x',
        announcementId: 'ann-x',
        senderId: 'sender-x',
        status: 'PENDING',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(bid.photos, isEmpty);
    });

    test('constructor accepts explicit photos list', () {
      const photo = BidPhoto(id: 'p1', url: 'https://signed/1');
      final bid = BidModel(
        id: 'bid-x',
        announcementId: 'ann-x',
        senderId: 'sender-x',
        status: 'PENDING',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        photos: const [photo],
      );
      expect(bid.photos.length, 1);
      expect(bid.photos.first.url, 'https://signed/1');
    });
  });
}
