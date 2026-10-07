import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/nego_archive.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements NegotiationRepository {}

NegotiationThread _thread(
  String id, {
  NegotiationThreadStatus status = NegotiationThreadStatus.expired,
  bool archived = false,
}) => NegotiationThread(
  id: id,
  packageRequestId: 'pr-$id',
  travelerId: 'tr-1',
  travelerTravelDate: DateTime(2026, 6, 15),
  travelerAvailableKg: 10,
  status: status,
  currentPriceEur: 30,
  roundsCount: 1,
  lastActivityAt: DateTime(2026, 5, 10),
  createdAt: DateTime(2026, 5, 10),
  messages: const [],
  archived: archived,
);

/// Archiver / désarchiver / supprimer une discussion de prix terminée
/// (FLUTTER-EJ, yadony-back #423).
void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  NegotiationListState loaded(
    List<NegotiationThread> threads, {
    List<NegotiationThread> archived = const [],
    NegotiationListStatus archivedStatus = NegotiationListStatus.initial,
  }) => NegotiationListState(
    status: NegotiationListStatus.loaded,
    threads: threads,
    archivedThreads: archived,
    archivedStatus: archivedStatus,
  );

  group('chargement', () {
    blocTest<NegotiationListBloc, NegotiationListState>(
      'la liste courante écarte un fil archivé (backend qui ignorerait le '
      'filtre)',
      build: () {
        when(
          () => repo.findMine(),
        ).thenAnswer((_) async => [_thread('a'), _thread('b', archived: true)]);
        return NegotiationListBloc(repo);
      },
      act: (b) => b.add(const NegotiationListFetchRequested()),
      skip: 1,
      expect: () => [
        isA<NegotiationListState>().having(
          (s) => s.threads.map((t) => t.id),
          'ids',
          ['a'],
        ),
      ],
    );

    blocTest<NegotiationListBloc, NegotiationListState>(
      'Archivées : charge archived=true et ne garde que les fils archivés',
      build: () {
        when(() => repo.findMine(archived: true)).thenAnswer(
          // Backend ancien : renvoie la liste courante, rien d'archivé.
          (_) async => [_thread('a'), _thread('z', archived: true)],
        );
        return NegotiationListBloc(repo);
      },
      act: (b) => b.add(const NegotiationListArchivedFetchRequested()),
      expect: () => [
        isA<NegotiationListState>().having(
          (s) => s.archivedStatus,
          'archivedStatus',
          NegotiationListStatus.loading,
        ),
        isA<NegotiationListState>()
            .having(
              (s) => s.archivedStatus,
              'archivedStatus',
              NegotiationListStatus.loaded,
            )
            .having((s) => s.archivedThreads.map((t) => t.id), 'ids', ['z'])
            // Les compteurs ne lisent que `threads` : inchangés.
            .having((s) => s.activeCount, 'activeCount', 0),
      ],
    );

    blocTest<NegotiationListBloc, NegotiationListState>(
      'Archivées : une erreur passe archivedStatus en error',
      build: () {
        when(
          () => repo.findMine(archived: true),
        ).thenThrow(const OfflineException());
        return NegotiationListBloc(repo);
      },
      act: (b) => b.add(const NegotiationListArchivedFetchRequested()),
      skip: 1,
      expect: () => [
        isA<NegotiationListState>()
            .having(
              (s) => s.archivedStatus,
              'archivedStatus',
              NegotiationListStatus.error,
            )
            .having((s) => s.errorMessage, 'error', isA<OfflineException>()),
      ],
    );
  });

  group('archiver', () {
    blocTest<NegotiationListBloc, NegotiationListState>(
      'succès : retrait optimiste, résultat success, rechargement',
      build: () {
        when(() => repo.archive('a')).thenAnswer((_) async {});
        when(() => repo.findMine()).thenAnswer((_) async => [_thread('b')]);
        return NegotiationListBloc(repo);
      },
      seed: () => loaded([_thread('a'), _thread('b')]),
      act: (b) => b.add(
        const NegotiationArchiveActionRequested('a', NegoArchiveAction.archive),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<NegotiationListState>().having(
          (s) => s.threads.map((t) => t.id),
          'optimiste',
          ['b'],
        ),
        isA<NegotiationListState>()
            .having((s) => s.lastAction?.outcome, 'outcome', isSuccess)
            .having((s) => s.lastAction?.id, 'id', 'a')
            .having((s) => s.lastAction?.fromDetail, 'fromDetail', isFalse),
        // Rechargement silencieux.
        isA<NegotiationListState>().having(
          (s) => s.threads.map((t) => t.id),
          'rechargé',
          ['b'],
        ),
      ],
      verify: (_) {
        verify(() => repo.archive('a')).called(1);
        verify(() => repo.findMine()).called(1);
      },
    );

    blocTest<NegotiationListBloc, NegotiationListState>(
      '409 : stillOpen, la tuile revient au rechargement',
      build: () {
        when(() => repo.archive('a')).thenThrow(
          const ConflictException('x', code: kNegotiationStillOpenCode),
        );
        when(() => repo.findMine()).thenAnswer((_) async => [_thread('a')]);
        return NegotiationListBloc(repo);
      },
      seed: () => loaded([_thread('a')]),
      act: (b) => b.add(
        const NegotiationArchiveActionRequested('a', NegoArchiveAction.archive),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<NegotiationListState>().having((s) => s.threads, 'vide', isEmpty),
        isA<NegotiationListState>().having(
          (s) => s.lastAction?.outcome,
          'outcome',
          NegoArchiveOutcome.stillOpen,
        ),
        isA<NegotiationListState>().having(
          (s) => s.threads.map((t) => t.id),
          'rechargé',
          ['a'],
        ),
      ],
    );

    blocTest<NegotiationListBloc, NegotiationListState>(
      '403 : gone, la tuile reste retirée et la liste se recharge',
      build: () {
        when(() => repo.archive('a')).thenThrow(const ForbiddenException());
        when(() => repo.findMine()).thenAnswer((_) async => []);
        return NegotiationListBloc(repo);
      },
      seed: () => loaded([_thread('a')]),
      act: (b) => b.add(
        const NegotiationArchiveActionRequested('a', NegoArchiveAction.archive),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<NegotiationListState>().having((s) => s.threads, 'vide', isEmpty),
        isA<NegotiationListState>()
            .having(
              (s) => s.lastAction?.outcome,
              'outcome',
              NegoArchiveOutcome.gone,
            )
            .having((s) => s.threads, 'toujours vide', isEmpty),
        isA<NegotiationListState>().having(
          (s) => s.status,
          'rechargé',
          NegotiationListStatus.loaded,
        ),
      ],
      verify: (_) => verify(() => repo.findMine()).called(1),
    );

    blocTest<NegotiationListBloc, NegotiationListState>(
      '404 sans code (backend ancien) : retour arrière, aucun rechargement',
      build: () {
        when(() => repo.archive('a')).thenThrow(const NotFoundException());
        return NegotiationListBloc(repo);
      },
      seed: () => loaded([_thread('a')]),
      act: (b) => b.add(
        const NegotiationArchiveActionRequested(
          'a',
          NegoArchiveAction.archive,
          fromDetail: true,
        ),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<NegotiationListState>().having((s) => s.threads, 'vide', isEmpty),
        isA<NegotiationListState>()
            .having(
              (s) => s.lastAction?.outcome,
              'outcome',
              NegoArchiveOutcome.unsupported,
            )
            .having((s) => s.lastAction?.fromDetail, 'fromDetail', isTrue)
            .having((s) => s.threads.map((t) => t.id), 'rollback', ['a']),
      ],
      verify: (_) => verifyNever(() => repo.findMine()),
    );

    blocTest<NegotiationListBloc, NegotiationListState>(
      'échec réseau : retour arrière, erreur portée, rechargement',
      build: () {
        when(() => repo.archive('a')).thenThrow(const OfflineException());
        when(() => repo.findMine()).thenThrow(const OfflineException());
        return NegotiationListBloc(repo);
      },
      seed: () => loaded([_thread('a')]),
      act: (b) => b.add(
        const NegotiationArchiveActionRequested('a', NegoArchiveAction.archive),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<NegotiationListState>().having((s) => s.threads, 'vide', isEmpty),
        isA<NegotiationListState>()
            .having(
              (s) => s.lastAction?.outcome,
              'outcome',
              NegoArchiveOutcome.failed,
            )
            .having(
              (s) => s.lastAction?.error,
              'error',
              isA<OfflineException>(),
            )
            .having((s) => s.threads.map((t) => t.id), 'rollback', ['a']),
        isA<NegotiationListState>().having(
          (s) => s.status,
          'refresh en erreur',
          NegotiationListStatus.error,
        ),
      ],
    );
  });

  group('désarchiver', () {
    blocTest<NegotiationListBloc, NegotiationListState>(
      'retire de « Archivées », puis recharge les deux listes',
      build: () {
        when(() => repo.unarchive('z')).thenAnswer((_) async {});
        when(() => repo.findMine()).thenAnswer((_) async => [_thread('z')]);
        when(() => repo.findMine(archived: true)).thenAnswer((_) async => []);
        return NegotiationListBloc(repo);
      },
      seed: () => loaded(
        const [],
        archived: [_thread('z', archived: true)],
        archivedStatus: NegotiationListStatus.loaded,
      ),
      act: (b) => b.add(
        const NegotiationArchiveActionRequested(
          'z',
          NegoArchiveAction.unarchive,
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        verify(() => repo.unarchive('z')).called(1);
        verify(() => repo.findMine(archived: true)).called(1);
        verify(() => repo.findMine()).called(1);
        expect(b.state.archivedThreads, isEmpty);
        expect(b.state.threads.map((t) => t.id), ['z']);
        expect(b.state.lastAction?.action, NegoArchiveAction.unarchive);
      },
    );
  });

  group('supprimer', () {
    blocTest<NegotiationListBloc, NegotiationListState>(
      'succès : DELETE puis rechargement',
      build: () {
        when(() => repo.delete('a')).thenAnswer((_) async {});
        when(() => repo.findMine()).thenAnswer((_) async => []);
        return NegotiationListBloc(repo);
      },
      seed: () => loaded([_thread('a')]),
      act: (b) => b.add(
        const NegotiationArchiveActionRequested('a', NegoArchiveAction.delete),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        verify(() => repo.delete('a')).called(1);
        expect(b.state.lastAction?.action, NegoArchiveAction.delete);
        expect(b.state.lastAction?.isSuccess, isTrue);
        expect(b.state.threads, isEmpty);
      },
    );

    blocTest<NegotiationListBloc, NegotiationListState>(
      '405 (backend ancien) : retour arrière',
      build: () {
        when(
          () => repo.delete('a'),
        ).thenThrow(const NetworkException('x', code: '405'));
        return NegotiationListBloc(repo);
      },
      seed: () => loaded([_thread('a')]),
      act: (b) => b.add(
        const NegotiationArchiveActionRequested('a', NegoArchiveAction.delete),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.lastAction?.outcome, NegoArchiveOutcome.unsupported);
        expect(b.state.threads.map((t) => t.id), ['a']);
      },
    );
  });

  test(
    'les actions partent l\'une après l\'autre (Annuler après Archiver)',
    () async {
      final order = <String>[];
      when(() => repo.archive('a')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        order.add('archive');
      });
      when(() => repo.unarchive('a')).thenAnswer((_) async {
        order.add('unarchive');
      });
      when(() => repo.findMine()).thenAnswer((_) async => [_thread('a')]);
      final bloc = NegotiationListBloc(repo)
        ..add(
          const NegotiationArchiveActionRequested(
            'a',
            NegoArchiveAction.archive,
          ),
        )
        ..add(
          const NegotiationArchiveActionRequested(
            'a',
            NegoArchiveAction.unarchive,
          ),
        );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(order, ['archive', 'unarchive']);
      expect(bloc.state.lastAction?.seq, 2);
      await bloc.close();
    },
  );

  test('événements : props', () {
    expect(
      const NegotiationArchiveActionRequested('a', NegoArchiveAction.archive),
      const NegotiationArchiveActionRequested('a', NegoArchiveAction.archive),
    );
    expect(
      const NegotiationArchiveActionRequested(
        'a',
        NegoArchiveAction.archive,
      ).props,
      ['a', NegoArchiveAction.archive, false],
    );
  });
}

const isSuccess = NegoArchiveOutcome.success;
