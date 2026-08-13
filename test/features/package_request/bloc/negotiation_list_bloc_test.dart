import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements NegotiationRepository {}

NegotiationThread _fakeThread(
  String id, {
  String packageRequestId = 'pr-1',
  bool hasUnread = false,
}) => NegotiationThread(
  id: id,
  packageRequestId: packageRequestId,
  travelerId: 'traveler-001',
  travelerTravelDate: DateTime(2026, 8),
  travelerAvailableKg: 10,
  status: NegotiationThreadStatus.open,
  currentPriceEur: 25,
  roundsCount: 1,
  lastActivityAt: DateTime(2026, 6),
  createdAt: DateTime(2026, 6),
  messages: const [],
  hasUnread: hasUnread,
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  // ── NegotiationListFetchRequested ────────────────────────────────────────────

  blocTest<NegotiationListBloc, NegotiationListState>(
    'NegotiationListFetchRequested emits loading then loaded',
    build: () {
      when(
        () => repo.findMine(),
      ).thenAnswer((_) async => [_fakeThread('t-1'), _fakeThread('t-2')]);
      return NegotiationListBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationListFetchRequested()),
    expect: () => [
      isA<NegotiationListState>().having(
        (s) => s.status,
        'status',
        NegotiationListStatus.loading,
      ),
      isA<NegotiationListState>()
          .having((s) => s.status, 'status', NegotiationListStatus.loaded)
          .having((s) => s.threads.length, 'threads.length', 2)
          .having(
            (s) => s.fetchedAt.isAfter(DateTime(2000)),
            'fetchedAt fresh',
            true,
          ),
    ],
  );

  blocTest<NegotiationListBloc, NegotiationListState>(
    'NegotiationListFetchRequested emits error on repo failure',
    build: () {
      when(() => repo.findMine()).thenThrow(Exception('réseau indisponible'));
      return NegotiationListBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationListFetchRequested()),
    expect: () => [
      isA<NegotiationListState>().having(
        (s) => s.status,
        'status',
        NegotiationListStatus.loading,
      ),
      isA<NegotiationListState>()
          .having((s) => s.status, 'status', NegotiationListStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
  );

  // ── NegotiationListRefreshRequested ──────────────────────────────────────────

  blocTest<NegotiationListBloc, NegotiationListState>(
    'NegotiationListRefreshRequested does NOT emit loading — keeps existing threads visible',
    build: () {
      when(
        () => repo.findMine(),
      ).thenAnswer((_) async => [_fakeThread('t-new')]);
      return NegotiationListBloc(repo);
    },
    seed: () => NegotiationListState(
      status: NegotiationListStatus.loaded,
      threads: [_fakeThread('t-old')],
    ),
    act: (bloc) => bloc.add(const NegotiationListRefreshRequested()),
    expect: () => [
      // Only one emission: the loaded state — NO intermediate loading state.
      isA<NegotiationListState>()
          .having((s) => s.status, 'status', NegotiationListStatus.loaded)
          .having((s) => s.threads.length, 'threads.length', 1)
          .having((s) => s.threads.first.id, 'thread id', 't-new')
          .having(
            (s) => s.fetchedAt.isAfter(DateTime(2000)),
            'fetchedAt fresh',
            true,
          ),
    ],
    verify: (_) => verify(() => repo.findMine()).called(1),
  );

  blocTest<NegotiationListBloc, NegotiationListState>(
    'NegotiationListRefreshRequested emits error without wiping threads on failure',
    build: () {
      when(() => repo.findMine()).thenThrow(Exception('timeout'));
      return NegotiationListBloc(repo);
    },
    seed: () => NegotiationListState(
      status: NegotiationListStatus.loaded,
      threads: [_fakeThread('t-existing')],
    ),
    act: (bloc) => bloc.add(const NegotiationListRefreshRequested()),
    expect: () => [
      isA<NegotiationListState>()
          .having((s) => s.status, 'status', NegotiationListStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
  );

  // ── activeCount ──────────────────────────────────────────────────────────────

  test('activeCount counts only open/awaitingTrip/awaitingPayment threads', () {
    final state = NegotiationListState(
      status: NegotiationListStatus.loaded,
      threads: [
        _fakeThread('t1'), // open → counted
        NegotiationThread(
          id: 't2',
          packageRequestId: 'pr-1',
          travelerId: 'traveler-001',
          travelerTravelDate: DateTime(2026, 8),
          travelerAvailableKg: 10,
          status: NegotiationThreadStatus.accepted, // terminal → not counted
          currentPriceEur: 25,
          roundsCount: 1,
          lastActivityAt: DateTime(2026, 6),
          createdAt: DateTime(2026, 6),
          messages: const [],
        ),
      ],
    );
    expect(state.activeCount, 1);
  });

  // ── actionableCount ──────────────────────────────────────────────────────────

  test('actionableCount ne compte que les threads ouverts où isMyTurn', () {
    final state = NegotiationListState(
      status: NegotiationListStatus.loaded,
      threads: [
        // Ouvert, à moi de jouer → compté par actionableCount ET activeCount.
        NegotiationThread(
          id: 't1',
          packageRequestId: 'pr-1',
          travelerId: 'traveler-001',
          travelerTravelDate: DateTime(2026, 8),
          travelerAvailableKg: 10,
          status: NegotiationThreadStatus.open,
          currentPriceEur: 25,
          roundsCount: 1,
          lastActivityAt: DateTime(2026, 6),
          createdAt: DateTime(2026, 6),
          messages: const [],
          isMyTurn: true,
        ),
        // Ouvert mais on attend la partie adverse → activeCount seulement.
        NegotiationThread(
          id: 't2',
          packageRequestId: 'pr-1',
          travelerId: 'traveler-001',
          travelerTravelDate: DateTime(2026, 8),
          travelerAvailableKg: 10,
          status: NegotiationThreadStatus.open,
          currentPriceEur: 30,
          roundsCount: 1,
          lastActivityAt: DateTime(2026, 6),
          createdAt: DateTime(2026, 6),
          messages: const [],
        ),
      ],
    );

    // La carte « Discussions de prix » reste allumée pour les 2 (ouverts)…
    expect(state.activeCount, 2);
    // …mais l'onglet ne s'allume que pour celui où l'utilisateur doit jouer.
    expect(state.actionableCount, 1);
  });

  test(
    'unreadCountForRequests compte seulement les fils non lus concernés',
    () {
      final unread = _fakeThread(
        'unread',
        packageRequestId: 'mine',
        hasUnread: true,
      );
      final read = _fakeThread('read', packageRequestId: 'mine');
      final other = _fakeThread(
        'other',
        packageRequestId: 'other-request',
        hasUnread: true,
      );

      final state = NegotiationListState(threads: [unread, read, other]);

      expect(state.unreadCountForRequests({'mine'}), 1);
    },
  );
}
