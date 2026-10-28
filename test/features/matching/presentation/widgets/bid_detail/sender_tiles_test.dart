import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tiles.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _handover = AddressData(
  label: '22 Rue du Séminaire, 94550 Chevilly-Larue, France',
  lat: 48.7667,
  lng: 2.3508,
);

BidModel _bid(
  String status, {
  String? trackingToken = 'tok-abc123',
  String? recipientAppStatus,
  AddressData? handoverAddress = _handover,
  TravelerTrackingModel? travelerTracking,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  trackingToken: trackingToken,
  recipientAppStatus: recipientAppStatus,
  handoverAddress: handoverAddress,
  travelerTracking: travelerTracking,
);

TravelerTrackingModel _tracking() => TravelerTrackingModel(
  status: TravelerTrackingStatus.enRoute,
  lastUpdatedAt: DateTime.utc(2026, 10, 28, 12),
);

void main() {
  group('senderTilesFor', () {
    test(
      'ACCEPTED with tracking token → [prevenir, lieux, colis, details]',
      () {
        expect(senderTilesFor(_bid('ACCEPTED')), [
          SenderTile.prevenir,
          SenderTile.lieux,
          SenderTile.colis,
          SenderTile.details,
        ]);
      },
    );

    test('IN_TRANSIT → [prevenir, suivi, colis, details]', () {
      expect(senderTilesFor(_bid('IN_TRANSIT')), [
        SenderTile.prevenir,
        SenderTile.suivi,
        SenderTile.colis,
        SenderTile.details,
      ]);
    });

    test('IN_TRANSIT with only the traveler tracking → suivi', () {
      final bid = _bid(
        'IN_TRANSIT',
        handoverAddress: null,
        travelerTracking: _tracking(),
      );
      expect(senderTilesFor(bid), contains(SenderTile.suivi));
    });

    test('ACCEPTED then HANDED_OVER switches lieux to suivi', () {
      final accepted = senderTilesFor(_bid('ACCEPTED'));
      final handedOver = senderTilesFor(_bid('HANDED_OVER'));
      expect(accepted, contains(SenderTile.lieux));
      expect(accepted, isNot(contains(SenderTile.suivi)));
      expect(handedOver, contains(SenderTile.suivi));
      expect(handedOver, isNot(contains(SenderTile.lieux)));
    });

    test('ACCEPTED without any address → no lieux', () {
      expect(senderTilesFor(_bid('ACCEPTED', handoverAddress: null)), [
        SenderTile.prevenir,
        SenderTile.colis,
        SenderTile.details,
      ]);
    });

    test('recipient declined and changeable → no prevenir', () {
      expect(
        senderTilesFor(_bid('IN_TRANSIT', recipientAppStatus: 'DECLINED')),
        [SenderTile.suivi, SenderTile.colis, SenderTile.details],
      );
      expect(
        senderTilesFor(_bid('ACCEPTED', recipientAppStatus: 'DECLINED')),
        isNot(contains(SenderTile.prevenir)),
      );
    });

    test('no tracking token → no prevenir', () {
      expect(
        senderTilesFor(_bid('ACCEPTED', trackingToken: null)),
        isNot(contains(SenderTile.prevenir)),
      );
    });

    test('delivered parcel → [suivi, colis, details], no prevenir', () {
      for (final status in ['COMPLETED', 'DELIVERED']) {
        expect(senderTilesFor(_bid(status)), [
          SenderTile.suivi,
          SenderTile.colis,
          SenderTile.details,
        ], reason: status);
      }
    });

    test('PENDING / AWAITING_PAYMENT → [colis, details]', () {
      for (final status in [
        'PENDING',
        'AWAITING_PAYMENT',
        'PAYMENT_ESCROWED',
      ]) {
        expect(senderTilesFor(_bid(status)), [
          SenderTile.colis,
          SenderTile.details,
        ], reason: status);
      }
    });

    test('CANCELLED → [colis, details]', () {
      for (final status in ['CANCELLED', 'REJECTED', 'EXPIRED']) {
        expect(senderTilesFor(_bid(status)), [
          SenderTile.colis,
          SenderTile.details,
        ], reason: status);
      }
    });
  });
}
