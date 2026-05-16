import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/bid_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid(String status) => BidModel(
  id: 'b-$status',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 1,
  status: status,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

void main() {
  group('acceptedBidsFrom', () {
    test('inclut tout le cycle post-acceptation (dont HANDED_OVER et '
        'DELIVERED)', () {
      final result = acceptedBidsFrom([
        _bid('ACCEPTED'),
        _bid('HANDED_OVER'),
        _bid('IN_TRANSIT'),
        _bid('COMPLETED'),
        _bid('DELIVERED'),
      ]);
      expect(result.map((b) => b.status).toSet(), {
        'ACCEPTED',
        'HANDED_OVER',
        'IN_TRANSIT',
        'COMPLETED',
        'DELIVERED',
      });
    });

    test('exclut PENDING, REJECTED, CANCELLED', () {
      final result = acceptedBidsFrom([
        _bid('PENDING'),
        _bid('REJECTED'),
        _bid('CANCELLED'),
      ]);
      expect(result, isEmpty);
    });
  });

  group('pendingBidsFrom', () {
    test('inclut PENDING et PAYMENT_ESCROWED uniquement', () {
      final result = pendingBidsFrom([
        _bid('PENDING'),
        _bid('PAYMENT_ESCROWED'),
        _bid('ACCEPTED'),
        _bid('HANDED_OVER'),
      ]);
      expect(result.map((b) => b.status).toSet(), {
        'PENDING',
        'PAYMENT_ESCROWED',
      });
    });
  });
}
