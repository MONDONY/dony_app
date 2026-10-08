import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid(String status, {String announcementId = 'ann-1'}) => BidModel(
  id: 'bid-$status',
  announcementId: announcementId,
  senderId: 'sender-1',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('MyActiveBidsLookup.activeBidsByAnnouncement', () {
    test('ARRIVED compte comme colis en cours sur le trajet', () {
      final bid = _bid('ARRIVED');
      final state = BidListLoaded([bid]);
      expect(state.activeBidsByAnnouncement()['ann-1'], bid);
    });

    test('IN_TRANSIT et COMPLETED restent comptés', () {
      expect(
        BidListLoaded([_bid('IN_TRANSIT')]).activeBidsByAnnouncement(),
        isNotEmpty,
      );
      expect(
        BidListLoaded([_bid('COMPLETED')]).activeBidsByAnnouncement(),
        isNotEmpty,
      );
    });

    test('REJECTED / CANCELLED / NO_SHOW exclus', () {
      for (final status in ['REJECTED', 'CANCELLED', 'NO_SHOW']) {
        expect(
          BidListLoaded([_bid(status)]).activeBidsByAnnouncement(),
          isEmpty,
          reason: '$status ne doit pas bloquer un nouveau colis',
        );
      }
    });

    test('état hors BidListLoaded → map vide', () {
      expect(BidInitial().activeBidsByAnnouncement(), isEmpty);
    });
  });

  group('existingTripBidsByAnnouncement (FLUTTER-GC)', () {
    test('une offre ouverte marque le trajet', () {
      final offer = _bid('NEGOTIATING');
      final state = BidListLoaded(const [], openNegotiations: [offer]);
      expect(state.existingTripBidsByAnnouncement()['ann-1'], offer);
      expect(state.activeBidsByAnnouncement(), isEmpty);
    });

    test('le colis en cours prime sur l’offre du même trajet', () {
      final parcel = _bid('ACCEPTED');
      final state = BidListLoaded(
        [parcel],
        openNegotiations: [_bid('NEGOTIATING')],
      );
      expect(state.existingTripBidsByAnnouncement()['ann-1'], parcel);
    });

    test('état hors BidListLoaded → map vide', () {
      expect(BidInitial().existingTripBidsByAnnouncement(), isEmpty);
    });

    test('route : fil de négociation pour une offre, billet sinon', () {
      expect(
        existingTripBidRoute(_bid('NEGOTIATING')),
        '/bids/bid-NEGOTIATING/negotiation',
      );
      expect(existingTripBidRoute(_bid('PENDING')), '/bids/bid-PENDING');
    });
  });
}
