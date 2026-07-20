import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/traveler_bids_page.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidRepository extends Mock implements BidRepository {}

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'a1',
  senderId: 's1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

TravelerBidsPage _page(
  List<BidModel> bids, {
  int page = 0,
  bool isLast = true,
  int? total,
}) => TravelerBidsPage(
  content: bids,
  totalElements: total ?? bids.length,
  page: page,
  isLast: isLast,
);

void main() {
  late _MockBidRepository repository;

  setUp(() => repository = _MockBidRepository());

  void stub(TravelerBidsPage result) {
    when(
      () => repository.getTravelerBids(
        status: any(named: 'status'),
        tripId: any(named: 'tripId'),
        q: any(named: 'q'),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((_) async => result);
  }

  group('chargement', () {
    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'émet loading puis loaded avec les bids reçus',
      build: () {
        stub(_page([_bid('b1', 'PENDING'), _bid('b2', 'ACCEPTED')]));
        return TravelerBidsBloc(repository);
      },
      act: (b) => b.add(const TravelerBidsRequested()),
      expect: () => [
        isA<TravelerBidsLoading>(),
        isA<TravelerBidsLoaded>()
            .having((s) => s.bids.length, 'bids', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having(
              (s) => s.filter,
              'filtre par défaut',
              TravelerBidFilter.aTraiter,
            ),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'émet error si le réseau échoue',
      build: () {
        when(
          () => repository.getTravelerBids(
            status: any(named: 'status'),
            tripId: any(named: 'tripId'),
            q: any(named: 'q'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).thenThrow(Exception('network'));
        return TravelerBidsBloc(repository);
      },
      act: (b) => b.add(const TravelerBidsRequested()),
      expect: () => [isA<TravelerBidsLoading>(), isA<TravelerBidsError>()],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'ne recharge pas si déjà chargé et force absent',
      build: () {
        stub(_page([_bid('b1', 'PENDING')]));
        return TravelerBidsBloc(repository);
      },
      act: (b) async {
        b.add(const TravelerBidsRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const TravelerBidsRequested());
      },
      verify: (_) {
        verify(
          () => repository.getTravelerBids(
            status: any(named: 'status'),
            tripId: any(named: 'tripId'),
            q: any(named: 'q'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).called(1);
      },
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'un refresh raté conserve la liste déjà affichée',
      build: () => TravelerBidsBloc(repository),
      act: (b) async {
        stub(_page([_bid('b1', 'PENDING')]));
        b.add(const TravelerBidsRequested());
        await Future<void>.delayed(Duration.zero);
        when(
          () => repository.getTravelerBids(
            status: any(named: 'status'),
            tripId: any(named: 'tripId'),
            q: any(named: 'q'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).thenThrow(Exception('network'));
        b.add(const TravelerBidsRequested(force: true));
      },
      // L'échec ne produit aucun nouvel état : le bloc ré-émet l'état courant,
      // que bloc ignore par égalité. C'est le comportement voulu — la liste
      // reste à l'écran et aucune vue d'erreur ne s'affiche par-dessus.
      expect: () => [
        isA<TravelerBidsLoading>(),
        isA<TravelerBidsLoaded>().having((s) => s.bids.length, 'bids', 1),
      ],
      verify: (b) {
        expect(b.state, isA<TravelerBidsLoaded>());
        expect((b.state as TravelerBidsLoaded).bids.length, 1);
      },
    );
  });

  group('pagination', () {
    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'la page suivante est ajoutée à la liste courante',
      build: () => TravelerBidsBloc(repository),
      act: (b) async {
        stub(_page([_bid('b1', 'PENDING')], isLast: false, total: 2));
        b.add(const TravelerBidsRequested());
        await Future<void>.delayed(Duration.zero);
        stub(_page([_bid('b2', 'ACCEPTED')], page: 1, total: 2));
        b.add(const TravelerBidsNextPageRequested());
      },
      expect: () => [
        isA<TravelerBidsLoading>(),
        isA<TravelerBidsLoaded>().having((s) => s.hasMore, 'hasMore', true),
        isA<TravelerBidsLoaded>().having(
          (s) => s.isLoadingMore,
          'en cours',
          true,
        ),
        isA<TravelerBidsLoaded>()
            .having((s) => s.bids.length, 'bids cumulés', 2)
            .having((s) => s.page, 'page', 1)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.isLoadingMore, 'terminé', false),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'aucune requête si hasMore est faux',
      build: () {
        stub(_page([_bid('b1', 'PENDING')]));
        return TravelerBidsBloc(repository);
      },
      act: (b) async {
        b.add(const TravelerBidsRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const TravelerBidsNextPageRequested());
      },
      verify: (_) {
        verify(
          () => repository.getTravelerBids(
            status: any(named: 'status'),
            tripId: any(named: 'tripId'),
            q: any(named: 'q'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).called(1);
      },
    );
  });

  group('filtres et compteurs', () {
    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'le changement de filtre ne relance aucun appel réseau',
      build: () {
        stub(_page([_bid('b1', 'PENDING')]));
        return TravelerBidsBloc(repository);
      },
      act: (b) async {
        b.add(const TravelerBidsRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const TravelerBidsFilterChanged(TravelerBidFilter.acceptees));
      },
      expect: () => [
        isA<TravelerBidsLoading>(),
        isA<TravelerBidsLoaded>(),
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filtre',
          TravelerBidFilter.acceptees,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.getTravelerBids(
            status: any(named: 'status'),
            tripId: any(named: 'tripId'),
            q: any(named: 'q'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).called(1);
      },
    );

    test('pendingCount ne compte que PENDING et PAYMENT_ESCROWED', () {
      final state = TravelerBidsLoaded(
        bids: [
          _bid('b1', 'PENDING'),
          _bid('b2', 'PAYMENT_ESCROWED'),
          _bid('b3', 'ACCEPTED'),
          _bid('b4', 'COMPLETED'),
        ],
        page: 0,
        hasMore: false,
        filter: TravelerBidFilter.aTraiter,
      );

      expect(state.pendingCount, 2);
    });

    test('visibleBids applique le filtre courant', () {
      final bids = [
        _bid('b1', 'PENDING'),
        _bid('b2', 'ACCEPTED'),
        _bid('b3', 'IN_TRANSIT'),
        _bid('b4', 'NO_SHOW'),
      ];
      final base = TravelerBidsLoaded(
        bids: bids,
        page: 0,
        hasMore: false,
        filter: TravelerBidFilter.aTraiter,
      );

      expect(base.visibleBids.map((b) => b.id), ['b1']);
      expect(
        base
            .copyWith(filter: TravelerBidFilter.acceptees)
            .visibleBids
            .map((b) => b.id),
        ['b2', 'b3'],
      );
      expect(
        base
            .copyWith(filter: TravelerBidFilter.terminees)
            .visibleBids
            .map((b) => b.id),
        ['b4'],
      );
    });

    test(
      'countFor donne le compte par filtre sans changer le filtre actif',
      () {
        final state = TravelerBidsLoaded(
          bids: [
            _bid('b1', 'PENDING'),
            _bid('b2', 'ACCEPTED'),
            _bid('b3', 'CANCELLED'),
          ],
          page: 0,
          hasMore: false,
          filter: TravelerBidFilter.aTraiter,
        );

        expect(state.countFor(TravelerBidFilter.aTraiter), 1);
        expect(state.countFor(TravelerBidFilter.acceptees), 1);
        expect(state.countFor(TravelerBidFilter.terminees), 1);
        expect(state.filter, TravelerBidFilter.aTraiter);
      },
    );
  });
}
