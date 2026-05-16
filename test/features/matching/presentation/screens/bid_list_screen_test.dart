import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid(String status, {String? rejectionReason}) => BidModel(
      id: 'b-$status',
      announcementId: 'a-1',
      senderId: 's-1',
      weightKg: 1,
      status: status,
      rejectionReason: rejectionReason,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

void main() {
  group('isAcceptedTabBid (fonctions de filtrage onglet Acceptées)', () {
    test('inclut tout le cycle post-acceptation (dont HANDED_OVER et DELIVERED)', () {
      final bids = [
        _bid('ACCEPTED'),
        _bid('HANDED_OVER'),
        _bid('IN_TRANSIT'),
        _bid('COMPLETED'),
        _bid('NO_SHOW'),
        _bid('PARCEL_REFUSED'),
        _bid('CANCELLED'),
      ];
      final result = bids.where(isAcceptedTabBid).toList();
      expect(result.map((b) => b.status).toSet(), {
        'ACCEPTED',
        'HANDED_OVER',
        'IN_TRANSIT',
        'COMPLETED',
        'NO_SHOW',
        'PARCEL_REFUSED',
        'CANCELLED',
      });
    });

    test('exclut PENDING et REJECTED', () {
      final bids = [
        _bid('PENDING'),
        _bid('REJECTED'),
      ];
      final result = bids.where(isAcceptedTabBid).toList();
      expect(result, isEmpty);
    });

    test('exclut CANCELLED auto-annulé (TRAVELER_NO_RESPONSE)', () {
      final autoCancelled = _bid('CANCELLED', rejectionReason: 'TRAVELER_NO_RESPONSE');
      expect(isAcceptedTabBid(autoCancelled), isFalse);
    });

    test('inclut CANCELLED avec une autre raison (voyageur accepta puis annula)', () {
      final regularCancelled = _bid('CANCELLED', rejectionReason: 'TRAVELER_CANCELLED');
      expect(isAcceptedTabBid(regularCancelled), isTrue);
    });
  });

  group('isActiveBid / isClosedBid', () {
    test('isActiveBid retourne true pour les statuts actifs', () {
      for (final s in kActiveBidStatuses) {
        expect(isActiveBid(_bid(s)), isTrue, reason: 'should be active: $s');
      }
    });

    test('isClosedBid retourne true pour les statuts clôturés', () {
      for (final s in kClosedBidStatuses) {
        expect(isClosedBid(_bid(s)), isTrue, reason: 'should be closed: $s');
      }
    });

    test('isClosedBid retourne false pour CANCELLED auto-annulé', () {
      final autoCancelled = _bid('CANCELLED', rejectionReason: 'TRAVELER_NO_RESPONSE');
      expect(isClosedBid(autoCancelled), isFalse);
    });
  });
}
