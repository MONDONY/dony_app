import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/traveler_bids_page.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidRepository extends Mock implements BidRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'a1',
  senderId: 's1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TravelerBidsPage _page(
  List<BidModel> bids, {
  int page = 0,
  bool isLast = true,
}) => TravelerBidsPage(content: bids, page: page, isLast: isLast);

void main() {
  late _MockBidRepository repository;
  late _MockAnalyticsService analytics;

  setUp(() {
    repository = _MockBidRepository();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  TravelerBidsBloc bloc() => TravelerBidsBloc(repository, analytics);

  /// Stub par numéro de page : le chargement initial parcourt toutes les
  /// pages jusqu'à `isLast`, le stub doit donc répondre page par page.
  void stubPages(Map<int, TravelerBidsPage> pages) {
    when(
      () => repository.getTravelerBids(
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((inv) async {
      final p = inv.namedArguments[#page] as int? ?? 0;
      return pages[p]!;
    });
  }

  void stub(TravelerBidsPage result) => stubPages({result.page: result});

  group('chargement', () {
    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'émet loading puis loaded avec les bids reçus',
      build: () {
        stub(_page([_bid('b1', 'PENDING'), _bid('b2', 'ACCEPTED')]));
        return bloc();
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
      'cumule toutes les pages au chargement initial (compteurs justes)',
      build: () {
        stubPages({
          0: _page([_bid('b1', 'PENDING')], isLast: false),
          1: _page([_bid('b2', 'ACCEPTED')], page: 1),
        });
        return bloc();
      },
      act: (b) => b.add(const TravelerBidsRequested()),
      expect: () => [
        isA<TravelerBidsLoading>(),
        isA<TravelerBidsLoaded>()
            .having((s) => s.bids.length, 'bids cumulés', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.pendingCount, 'pendingCount', 1),
      ],
      verify: (_) {
        verify(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).called(2);
      },
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'émet error si le réseau échoue',
      build: () {
        when(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).thenThrow(Exception('network'));
        return bloc();
      },
      act: (b) => b.add(const TravelerBidsRequested()),
      expect: () => [isA<TravelerBidsLoading>(), isA<TravelerBidsError>()],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'ne recharge pas si déjà chargé et force absent',
      build: () {
        stub(_page([_bid('b1', 'PENDING')]));
        return bloc();
      },
      act: (b) async {
        b.add(const TravelerBidsRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const TravelerBidsRequested());
      },
      verify: (_) {
        verify(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).called(1);
      },
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'un refresh raté conserve la liste déjà affichée',
      build: bloc,
      act: (b) async {
        stub(_page([_bid('b1', 'PENDING')]));
        b.add(const TravelerBidsRequested());
        await Future<void>.delayed(Duration.zero);
        when(
          () => repository.getTravelerBids(
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
      'au-delà du garde-fou initial, le scroll charge la page suivante',
      build: () {
        // 12 pages d'une demande : le chargement initial s'arrête au
        // garde-fou (10 pages) avec hasMore, le scroll prend le relais.
        stubPages({
          for (var p = 0; p < 12; p++)
            p: _page([_bid('b$p', 'PENDING')], page: p, isLast: p == 11),
        });
        return bloc();
      },
      act: (b) async {
        b.add(const TravelerBidsRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const TravelerBidsNextPageRequested());
      },
      expect: () => [
        isA<TravelerBidsLoading>(),
        isA<TravelerBidsLoaded>()
            .having((s) => s.bids.length, 'bids au garde-fou', 10)
            .having((s) => s.hasMore, 'hasMore', true),
        isA<TravelerBidsLoaded>().having(
          (s) => s.isLoadingMore,
          'en cours',
          true,
        ),
        isA<TravelerBidsLoaded>()
            .having((s) => s.bids.length, 'bids cumulés', 11)
            .having((s) => s.page, 'page', 10)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.isLoadingMore, 'terminé', false),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'un serveur qui renvoie toujours la même page ne boucle pas à l\'infini',
      build: () {
        // `number` figé à 0 avec `last: false` : si la boucle initiale se
        // fiait au numéro renvoyé par l'API, elle ne progresserait jamais.
        when(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).thenAnswer(
          (_) async => _page([_bid('b1', 'PENDING')], isLast: false),
        );
        return bloc();
      },
      act: (b) => b.add(const TravelerBidsRequested()),
      expect: () => [
        isA<TravelerBidsLoading>(),
        isA<TravelerBidsLoaded>()
            .having((s) => s.bids.length, 'bids au garde-fou', 10)
            .having((s) => s.hasMore, 'hasMore', true),
      ],
      verify: (_) {
        verify(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).called(10);
      },
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'aucune requête si hasMore est faux',
      build: () {
        stub(_page([_bid('b1', 'PENDING')]));
        return bloc();
      },
      act: (b) async {
        b.add(const TravelerBidsRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const TravelerBidsNextPageRequested());
      },
      verify: (_) {
        verify(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).called(1);
      },
    );
  });

  group('filtres et compteurs', () {
    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'le changement de filtre ne relance aucun appel réseau et est tracé',
      build: () {
        stub(_page([_bid('b1', 'PENDING')]));
        return bloc();
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
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).called(1);
        verify(
          () => analytics.logEvent(
            'traveler_bids_filter_applied',
            properties: {'filter': 'acceptees'},
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

  group('pull-to-refresh et chargements concurrents', () {
    test('done se termine sans erreur une fois la liste chargée', () async {
      stub(_page([_bid('b1', 'PENDING')]));
      final b = bloc();
      final done = Completer<Object?>();
      b.add(TravelerBidsRequested(force: true, done: done));

      expect(await done.future, isNull);
      expect(b.state, isA<TravelerBidsLoaded>());
      await b.close();
    });

    test(
      'refresh raté : done porte l\'erreur, la liste reste affichée',
      () async {
        stub(_page([_bid('b1', 'PENDING')]));
        final b = bloc();
        final first = Completer<Object?>();
        b.add(TravelerBidsRequested(force: true, done: first));
        await first.future;

        when(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).thenThrow(Exception('réseau'));
        final done = Completer<Object?>();
        b.add(TravelerBidsRequested(force: true, done: done));

        expect(await done.future, isNotNull);
        expect(
          b.state,
          isA<TravelerBidsLoaded>().having((s) => s.bids.length, 'bids', 1),
        );
        await b.close();
      },
    );

    test(
      'sans force sur une liste chargée : done se termine aussitôt',
      () async {
        stub(_page([_bid('b1', 'PENDING')]));
        final b = bloc();
        final first = Completer<Object?>();
        b.add(TravelerBidsRequested(force: true, done: first));
        await first.future;

        final done = Completer<Object?>();
        b.add(TravelerBidsRequested(done: done));
        expect(await done.future, isNull);
        verify(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).called(1);
        await b.close();
      },
    );

    test(
      'une réponse lente et périmée n\'écrase pas une plus récente',
      () async {
        final slow = Completer<TravelerBidsPage>();
        var calls = 0;
        when(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).thenAnswer((_) {
          calls++;
          // Premier appel : la réponse d'avant le paiement, qui arrive en
          // dernier. Second appel : la liste à jour, qui arrive tout de suite.
          if (calls == 1) return slow.future;
          return Future.value(
            _page([_bid('b1', 'PENDING'), _bid('b2', 'PAYMENT_ESCROWED')]),
          );
        });
        final b = bloc();
        final oldDone = Completer<Object?>();
        final newDone = Completer<Object?>();
        b.add(TravelerBidsRequested(force: true, done: oldDone));
        b.add(TravelerBidsRequested(force: true, done: newDone));
        await newDone.future;
        slow.complete(_page([_bid('b1', 'PENDING')]));
        expect(await oldDone.future, isNull);

        expect(
          b.state,
          isA<TravelerBidsLoaded>().having((s) => s.bids.length, 'bids', 2),
        );
        await b.close();
      },
    );
  });

  group('onglet d’ouverture (autoSelectFilter)', () {
    const open = TravelerBidsRequested(force: true, autoSelectFilter: true);
    late Completer<TravelerBidsPage> pendingResponse;

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      '« À traiter » vide : bascule sur le premier onglet non vide',
      build: () {
        stub(_page([_bid('b1', 'ACCEPTED'), _bid('b2', 'NO_SHOW')]));
        return bloc();
      },
      act: (b) => b.add(open),
      expect: () => [
        isA<TravelerBidsLoading>(),
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filter',
          TravelerBidFilter.acceptees,
        ),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'seules des demandes terminées : « Terminées »',
      build: () {
        stub(_page([_bid('b1', 'NO_SHOW')]));
        return bloc();
      },
      act: (b) => b.add(open),
      skip: 1,
      expect: () => [
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filter',
          TravelerBidFilter.terminees,
        ),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      '« À traiter » non vide : reste sur « À traiter »',
      build: () {
        stub(_page([_bid('b1', 'PENDING'), _bid('b2', 'ACCEPTED')]));
        return bloc();
      },
      act: (b) => b.add(open),
      skip: 1,
      expect: () => [
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filter',
          TravelerBidFilter.aTraiter,
        ),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'tout vide : reste sur « À traiter »',
      build: () {
        stub(_page(const []));
        return bloc();
      },
      act: (b) => b.add(open),
      skip: 1,
      expect: () => [
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filter',
          TravelerBidFilter.aTraiter,
        ),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'sans le drapeau : pas de bascule (rechargements du hub, du shell)',
      build: () {
        stub(_page([_bid('b1', 'ACCEPTED')]));
        return bloc();
      },
      act: (b) => b.add(const TravelerBidsRequested(force: true)),
      skip: 1,
      expect: () => [
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filter',
          TravelerBidFilter.aTraiter,
        ),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'onglet choisi pendant le rechargement : jamais écrasé',
      build: () {
        final response = Completer<TravelerBidsPage>();
        when(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).thenAnswer((_) => response.future);
        pendingResponse = response;
        return bloc();
      },
      seed: () => TravelerBidsLoaded(
        bids: const [],
        page: 0,
        hasMore: false,
        filter: TravelerBidFilter.aTraiter,
      ),
      act: (b) async {
        b.add(open);
        await Future<void>.delayed(Duration.zero);
        b.add(const TravelerBidsFilterChanged(TravelerBidFilter.terminees));
        await Future<void>.delayed(Duration.zero);
        pendingResponse.complete(_page([_bid('b1', 'ACCEPTED')]));
      },
      expect: () => [
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'choix de l’utilisateur',
          TravelerBidFilter.terminees,
        ),
        isA<TravelerBidsLoaded>()
            .having((s) => s.bids.length, 'bids', 1)
            .having(
              (s) => s.filter,
              'toujours le choix de l’utilisateur',
              TravelerBidFilter.terminees,
            ),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'onglet courant non vide (dernier choix gardé) : conservé',
      build: () {
        stub(_page([_bid('b1', 'PENDING'), _bid('b2', 'NO_SHOW')]));
        return bloc();
      },
      seed: () => TravelerBidsLoaded(
        bids: const [],
        page: 0,
        hasMore: false,
        filter: TravelerBidFilter.terminees,
      ),
      act: (b) => b.add(open),
      expect: () => [
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filter',
          TravelerBidFilter.terminees,
        ),
      ],
    );

    blocTest<TravelerBidsBloc, TravelerBidsState>(
      'une seule décision : le rechargement suivant ne bascule plus',
      build: () {
        var calls = 0;
        when(
          () => repository.getTravelerBids(
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).thenAnswer((_) async {
          calls++;
          return calls == 1
              ? _page([_bid('b1', 'ACCEPTED')])
              : _page([_bid('b2', 'NO_SHOW')]);
        });
        return bloc();
      },
      act: (b) async {
        b.add(open);
        await Future<void>.delayed(Duration.zero);
        b.add(const TravelerBidsRequested(force: true));
      },
      skip: 1,
      expect: () => [
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filter',
          TravelerBidFilter.acceptees,
        ),
        isA<TravelerBidsLoaded>()
            .having((s) => s.bids.single.id, 'bid', 'b2')
            .having(
              (s) => s.filter,
              'filter inchangé',
              TravelerBidFilter.acceptees,
            ),
      ],
    );

    test('doublé par un chargement plus récent : la décision suit', () async {
      final slow = Completer<TravelerBidsPage>();
      var calls = 0;
      when(
        () => repository.getTravelerBids(
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) {
        calls++;
        if (calls == 1) return slow.future;
        return Future.value(_page([_bid('b1', 'ACCEPTED')]));
      });
      final b = bloc();
      final done = Completer<Object?>();
      b
        ..add(open)
        ..add(TravelerBidsRequested(force: true, done: done));
      await done.future;
      slow.complete(_page(const []));

      expect(
        b.state,
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filter',
          TravelerBidFilter.acceptees,
        ),
      );
      await b.close();
    });

    test('échec du chargement : décision abandonnée', () async {
      var calls = 0;
      when(
        () => repository.getTravelerBids(
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('réseau');
        return _page([_bid('b1', 'ACCEPTED')]);
      });
      final b = bloc();
      final failed = Completer<Object?>();
      b.add(
        TravelerBidsRequested(
          force: true,
          autoSelectFilter: true,
          done: failed,
        ),
      );
      expect(await failed.future, isNotNull);
      final done = Completer<Object?>();
      b.add(TravelerBidsRequested(force: true, done: done));
      await done.future;

      expect(
        b.state,
        isA<TravelerBidsLoaded>().having(
          (s) => s.filter,
          'filter',
          TravelerBidFilter.aTraiter,
        ),
      );
      await b.close();
    });
  });
}
