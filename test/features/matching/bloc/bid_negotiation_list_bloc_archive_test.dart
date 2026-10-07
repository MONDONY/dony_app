import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:dony/features/package_request/data/models/nego_archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BidNegotiationRepository {}

BidNegotiationSummary _summary(
  String bidId, {
  String status = 'REJECTED',
  bool archived = false,
}) => BidNegotiationSummary(
  bidId: bidId,
  announcementId: 'ann',
  status: status,
  archived: archived,
);

/// Archiver / désarchiver / supprimer une discussion de prix de trajet
/// terminée (FLUTTER-EJ, yadony-back #423).
void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  BidNegotiationListState loaded(
    List<BidNegotiationSummary> summaries, {
    List<BidNegotiationSummary> archived = const [],
    BidNegotiationListStatus archivedStatus = BidNegotiationListStatus.initial,
  }) => BidNegotiationListState(
    status: BidNegotiationListStatus.loaded,
    summaries: summaries,
    archivedSummaries: archived,
    archivedStatus: archivedStatus,
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    'la liste courante écarte un fil archivé',
    build: () {
      when(() => repo.myNegotiations()).thenAnswer(
        (_) async => [
          _summary('a', status: 'NEGOTIATING'),
          _summary('b', archived: true),
        ],
      );
      return BidNegotiationListBloc(repo);
    },
    act: (b) => b.add(const BidNegotiationListFetchRequested()),
    skip: 1,
    expect: () => [
      isA<BidNegotiationListState>().having(
        (s) => s.summaries.map((x) => x.bidId),
        'ids',
        ['a'],
      ),
    ],
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    'Archivées : charge archived=true et ne garde que les fils archivés',
    build: () {
      when(
        () => repo.myNegotiations(archived: true),
      ).thenAnswer((_) async => [_summary('a'), _summary('z', archived: true)]);
      return BidNegotiationListBloc(repo);
    },
    act: (b) => b.add(const BidNegotiationListArchivedFetchRequested()),
    expect: () => [
      isA<BidNegotiationListState>().having(
        (s) => s.archivedStatus,
        'archivedStatus',
        BidNegotiationListStatus.loading,
      ),
      isA<BidNegotiationListState>()
          .having(
            (s) => s.archivedStatus,
            'archivedStatus',
            BidNegotiationListStatus.loaded,
          )
          .having((s) => s.archivedSummaries.map((x) => x.bidId), 'ids', ['z']),
    ],
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    'Archivées : erreur',
    build: () {
      when(
        () => repo.myNegotiations(archived: true),
      ).thenThrow(const OfflineException());
      return BidNegotiationListBloc(repo);
    },
    act: (b) => b.add(const BidNegotiationListArchivedFetchRequested()),
    skip: 1,
    expect: () => [
      isA<BidNegotiationListState>().having(
        (s) => s.archivedStatus,
        'archivedStatus',
        BidNegotiationListStatus.error,
      ),
    ],
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    'archiver : retrait optimiste, success, rechargement',
    build: () {
      when(() => repo.archive('a')).thenAnswer((_) async {});
      when(() => repo.myNegotiations()).thenAnswer((_) async => []);
      return BidNegotiationListBloc(repo);
    },
    seed: () => loaded([_summary('a')]),
    act: (b) => b.add(
      const BidNegotiationArchiveActionRequested(
        'a',
        NegoArchiveAction.archive,
        fromDetail: true,
      ),
    ),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<BidNegotiationListState>().having(
        (s) => s.summaries,
        'optimiste',
        isEmpty,
      ),
      isA<BidNegotiationListState>()
          .having(
            (s) => s.lastAction?.outcome,
            'outcome',
            NegoArchiveOutcome.success,
          )
          .having((s) => s.lastAction?.fromDetail, 'fromDetail', isTrue),
    ],
    verify: (_) {
      verify(() => repo.archive('a')).called(1);
      verify(() => repo.myNegotiations()).called(1);
    },
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    '409 : stillOpen, rechargement',
    build: () {
      when(() => repo.archive('a')).thenThrow(
        const ConflictException('x', code: kNegotiationStillOpenCode),
      );
      when(
        () => repo.myNegotiations(),
      ).thenAnswer((_) async => [_summary('a', status: 'NEGOTIATING')]);
      return BidNegotiationListBloc(repo);
    },
    seed: () => loaded([_summary('a')]),
    act: (b) => b.add(
      const BidNegotiationArchiveActionRequested(
        'a',
        NegoArchiveAction.archive,
      ),
    ),
    wait: const Duration(milliseconds: 50),
    verify: (b) {
      expect(b.state.lastAction?.outcome, NegoArchiveOutcome.stillOpen);
      expect(b.state.summaries.map((x) => x.bidId), ['a']);
    },
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    '404 métier : gone, la tuile reste retirée',
    build: () {
      when(
        () => repo.delete('a'),
      ).thenThrow(const NotFoundException(apiCode: 'negotiation-not-found'));
      when(() => repo.myNegotiations()).thenAnswer((_) async => []);
      return BidNegotiationListBloc(repo);
    },
    seed: () => loaded([_summary('a')]),
    act: (b) => b.add(
      const BidNegotiationArchiveActionRequested('a', NegoArchiveAction.delete),
    ),
    wait: const Duration(milliseconds: 50),
    verify: (b) {
      expect(b.state.lastAction?.outcome, NegoArchiveOutcome.gone);
      expect(b.state.summaries, isEmpty);
    },
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    '405 (backend ancien) : retour arrière, aucun rechargement',
    build: () {
      when(
        () => repo.delete('a'),
      ).thenThrow(const NetworkException('x', code: '405'));
      return BidNegotiationListBloc(repo);
    },
    seed: () => loaded([_summary('a')]),
    act: (b) => b.add(
      const BidNegotiationArchiveActionRequested('a', NegoArchiveAction.delete),
    ),
    wait: const Duration(milliseconds: 50),
    verify: (b) {
      expect(b.state.lastAction?.outcome, NegoArchiveOutcome.unsupported);
      expect(b.state.summaries.map((x) => x.bidId), ['a']);
      verifyNever(() => repo.myNegotiations());
    },
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    'échec réseau : retour arrière',
    build: () {
      when(() => repo.archive('a')).thenThrow(const OfflineException());
      when(
        () => repo.myNegotiations(),
      ).thenAnswer((_) async => [_summary('a')]);
      return BidNegotiationListBloc(repo);
    },
    seed: () => loaded([_summary('a')]),
    act: (b) => b.add(
      const BidNegotiationArchiveActionRequested(
        'a',
        NegoArchiveAction.archive,
      ),
    ),
    wait: const Duration(milliseconds: 50),
    verify: (b) {
      expect(b.state.lastAction?.outcome, NegoArchiveOutcome.failed);
      expect(b.state.lastAction?.error, isA<OfflineException>());
      expect(b.state.summaries.map((x) => x.bidId), ['a']);
    },
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    'désarchiver : retire de « Archivées » et recharge les deux listes',
    build: () {
      when(() => repo.unarchive('z')).thenAnswer((_) async {});
      when(() => repo.myNegotiations()).thenAnswer((_) async => []);
      when(
        () => repo.myNegotiations(archived: true),
      ).thenAnswer((_) async => []);
      return BidNegotiationListBloc(repo);
    },
    seed: () => loaded(
      const [],
      archived: [_summary('z', archived: true)],
      archivedStatus: BidNegotiationListStatus.loaded,
    ),
    act: (b) => b.add(
      const BidNegotiationArchiveActionRequested(
        'z',
        NegoArchiveAction.unarchive,
      ),
    ),
    wait: const Duration(milliseconds: 50),
    verify: (b) {
      verify(() => repo.unarchive('z')).called(1);
      verify(() => repo.myNegotiations(archived: true)).called(1);
      expect(b.state.archivedSummaries, isEmpty);
    },
  );

  test('les actions partent l\'une après l\'autre', () async {
    final order = <String>[];
    when(() => repo.archive('a')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      order.add('archive');
    });
    when(() => repo.unarchive('a')).thenAnswer((_) async {
      order.add('unarchive');
    });
    when(() => repo.myNegotiations()).thenAnswer((_) async => []);
    final bloc = BidNegotiationListBloc(repo)
      ..add(
        const BidNegotiationArchiveActionRequested(
          'a',
          NegoArchiveAction.archive,
        ),
      )
      ..add(
        const BidNegotiationArchiveActionRequested(
          'a',
          NegoArchiveAction.unarchive,
        ),
      );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(order, ['archive', 'unarchive']);
    await bloc.close();
  });

  test('événement : props', () {
    expect(
      const BidNegotiationArchiveActionRequested(
        'a',
        NegoArchiveAction.delete,
      ).props,
      ['a', NegoArchiveAction.delete, false],
    );
  });
}
