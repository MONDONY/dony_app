import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  required String status,
  String? senderName,
  String? trackingNumber,
  String? rejectionReason,
}) =>
    BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      senderName: senderName,
      trackingNumber: trackingNumber,
      rejectionReason: rejectionReason,
      weightKg: 1,
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('BidListFilterCubit', () {
    test('état initial : query vide, filtre all', () {
      final cubit = BidListFilterCubit();
      expect(cubit.state, const BidListFilterState());
      expect(cubit.state.query, '');
      expect(cubit.state.filter, AcceptedStatusFilter.all);
      cubit.close();
    });

    blocTest<BidListFilterCubit, BidListFilterState>(
      'setQuery émet le nouvel état',
      build: BidListFilterCubit.new,
      act: (c) => c.setQuery('tra'),
      expect: () => const [BidListFilterState(query: 'tra')],
    );

    blocTest<BidListFilterCubit, BidListFilterState>(
      'setFilter émet le nouvel état',
      build: BidListFilterCubit.new,
      act: (c) => c.setFilter(AcceptedStatusFilter.closed),
      expect: () =>
          const [BidListFilterState(filter: AcceptedStatusFilter.closed)],
    );

    blocTest<BidListFilterCubit, BidListFilterState>(
      "reset revient à l'état initial",
      build: BidListFilterCubit.new,
      seed: () => const BidListFilterState(
          query: 'x', filter: AcceptedStatusFilter.active),
      act: (c) => c.reset(),
      expect: () => const [BidListFilterState()],
    );
  });

  group('isAcceptedTabBid', () {
    test('inclut les statuts actifs et clôturés', () {
      for (final s in [...kActiveBidStatuses, ...kClosedBidStatuses]) {
        expect(isAcceptedTabBid(_bid(status: s)), isTrue, reason: s);
      }
    });

    test('exclut PENDING / REJECTED', () {
      expect(isAcceptedTabBid(_bid(status: 'PENDING')), isFalse);
      expect(isAcceptedTabBid(_bid(status: 'REJECTED')), isFalse);
    });

    test('exclut CANCELLED auto-annulé (TRAVELER_NO_RESPONSE)', () {
      expect(
        isAcceptedTabBid(_bid(
            status: 'CANCELLED', rejectionReason: 'TRAVELER_NO_RESPONSE')),
        isFalse,
      );
    });

    test('inclut CANCELLED post-acceptation (autre motif ou nul)', () {
      expect(
        isAcceptedTabBid(
            _bid(status: 'CANCELLED', rejectionReason: 'TRIP_CANCELLED')),
        isTrue,
      );
      expect(isAcceptedTabBid(_bid(status: 'CANCELLED')), isTrue);
    });
  });

  group('isActiveBid', () {
    test('vrai pour chaque statut actif', () {
      for (final s in kActiveBidStatuses) {
        expect(isActiveBid(_bid(status: s)), isTrue, reason: s);
      }
    });
    test('faux pour les statuts clôturés', () {
      for (final s in kClosedBidStatuses) {
        expect(isActiveBid(_bid(status: s)), isFalse, reason: s);
      }
    });
  });

  group('isClosedBid', () {
    test('vrai pour chaque statut clôturé', () {
      for (final s in kClosedBidStatuses) {
        expect(isClosedBid(_bid(status: s)), isTrue, reason: s);
      }
    });
    test('faux pour les statuts actifs', () {
      for (final s in kActiveBidStatuses) {
        expect(isClosedBid(_bid(status: s)), isFalse, reason: s);
      }
    });
    test('faux pour un CANCELLED auto-annulé (TRAVELER_NO_RESPONSE)', () {
      expect(
        isClosedBid(_bid(
            status: 'CANCELLED', rejectionReason: 'TRAVELER_NO_RESPONSE')),
        isFalse,
      );
    });
  });

  group('normalizeSearch', () {
    test('minuscule + suppression des accents', () {
      expect(normalizeSearch('Moussa TRAORÉ'), 'moussa traore');
      expect(normalizeSearch('Aïcha Côté'), 'aicha cote');
    });

    test('préserve la longueur (1 char → 1 char)', () {
      const s = 'Éàçùî';
      expect(normalizeSearch(s).length, s.length);
    });
  });

  group('bidMatchesQuery', () {
    test('requête vide ou espaces → match', () {
      expect(bidMatchesQuery(_bid(status: 'ACCEPTED'), ''), isTrue);
      expect(bidMatchesQuery(_bid(status: 'ACCEPTED'), '   '), isTrue);
    });

    test('match par nom, insensible casse/accents', () {
      final b = _bid(status: 'ACCEPTED', senderName: 'Moussa Traoré');
      expect(bidMatchesQuery(b, 'TRAORE'), isTrue);
      expect(bidMatchesQuery(b, 'mou'), isTrue);
      expect(bidMatchesQuery(b, 'diallo'), isFalse);
    });

    test('match par numéro de suivi', () {
      final b = _bid(
          status: 'ACCEPTED', senderName: 'X', trackingNumber: 'DNY-4815');
      expect(bidMatchesQuery(b, 'dny-48'), isTrue);
      expect(bidMatchesQuery(b, '4815'), isTrue);
      expect(bidMatchesQuery(b, '9999'), isFalse);
    });

    test('trackingNumber nul → pas de crash, pas de match numéro', () {
      final b = _bid(status: 'ACCEPTED', senderName: 'X', trackingNumber: null);
      expect(bidMatchesQuery(b, 'dny'), isFalse);
    });
  });
}
