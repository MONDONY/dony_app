import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/models/favorite_ids.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements FavoriteRepository {}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  // ---------------------------------------------------------------------------
  // load()
  // ---------------------------------------------------------------------------
  group('load()', () {
    test('emits loaded state from repo.ids()', () async {
      when(() => repo.ids()).thenAnswer(
        (_) async => const FavoriteIds(
          trips: {'t1', 't2'},
          packageRequests: {'r1'},
        ),
      );
      final cubit = FavoriteIdsCubit(repo);
      await cubit.load();
      expect(cubit.state.tripIds, {'t1', 't2'});
      expect(cubit.state.requestIds, {'r1'});
      expect(cubit.count, 3);
    });

    test('keeps current state when repo.ids() throws', () async {
      when(() => repo.ids()).thenThrow(Exception('network'));
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {'t0'}, requests: {});
      await cubit.load(); // should not throw
      expect(cubit.state.tripIds, {'t0'}); // unchanged
    });
  });

  // ---------------------------------------------------------------------------
  // toggleTrip — add path
  // ---------------------------------------------------------------------------
  group('toggleTrip — add', () {
    test('ajoute en optimiste puis appelle add', () async {
      when(() => repo.add(any(), any())).thenAnswer((_) async {});
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});
      await cubit.toggleTrip('t1');
      expect(cubit.isTripFav('t1'), isTrue);
      verify(() => repo.add('trip', 't1')).called(1);
    });

    test('rollback si add échoue', () async {
      when(() => repo.add(any(), any())).thenThrow(Exception('net'));
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});
      // toggleTrip rethrows — catch it so test does not fail on the throw
      await expectLater(
        cubit.toggleTrip('t1'),
        throwsException,
      );
      expect(cubit.isTripFav('t1'), isFalse); // revenu à l'état initial
    });

    test('count augmente de 1 après ajout', () async {
      when(() => repo.add(any(), any())).thenAnswer((_) async {});
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});
      expect(cubit.count, 0);
      await cubit.toggleTrip('t1');
      expect(cubit.count, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // toggleTrip — remove path
  // ---------------------------------------------------------------------------
  group('toggleTrip — remove', () {
    test('retire un favori existant et appelle remove', () async {
      when(() => repo.remove(any(), any())).thenAnswer((_) async {});
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {'t1'}, requests: {});
      await cubit.toggleTrip('t1');
      expect(cubit.isTripFav('t1'), isFalse);
      verify(() => repo.remove('trip', 't1')).called(1);
    });

    test('rollback si remove échoue', () async {
      when(() => repo.remove(any(), any())).thenThrow(Exception('net'));
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {'t1'}, requests: {});
      await expectLater(
        cubit.toggleTrip('t1'),
        throwsException,
      );
      expect(cubit.isTripFav('t1'), isTrue); // revenu à l'état initial
    });
  });

  // ---------------------------------------------------------------------------
  // toggleRequest — add path
  // ---------------------------------------------------------------------------
  group('toggleRequest — add', () {
    test('ajoute en optimiste puis appelle add(package-request, id)', () async {
      when(() => repo.add(any(), any())).thenAnswer((_) async {});
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});
      await cubit.toggleRequest('r1');
      expect(cubit.isRequestFav('r1'), isTrue);
      verify(() => repo.add('package-request', 'r1')).called(1);
    });

    test('rollback si add échoue', () async {
      when(() => repo.add(any(), any())).thenThrow(Exception('net'));
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});
      await expectLater(
        cubit.toggleRequest('r1'),
        throwsException,
      );
      expect(cubit.isRequestFav('r1'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // toggleRequest — remove path
  // ---------------------------------------------------------------------------
  group('toggleRequest — remove', () {
    test('retire un favori existant et appelle remove(package-request, id)',
        () async {
      when(() => repo.remove(any(), any())).thenAnswer((_) async {});
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {'r1'});
      await cubit.toggleRequest('r1');
      expect(cubit.isRequestFav('r1'), isFalse);
      verify(() => repo.remove('package-request', 'r1')).called(1);
    });

    test('rollback si remove échoue', () async {
      when(() => repo.remove(any(), any())).thenThrow(Exception('net'));
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {'r1'});
      await expectLater(
        cubit.toggleRequest('r1'),
        throwsException,
      );
      expect(cubit.isRequestFav('r1'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // blocTest — state sequence
  // ---------------------------------------------------------------------------
  blocTest<FavoriteIdsCubit, FavoriteIdsState>(
    'toggleTrip émet [optimiste] quand add réussit',
    build: () {
      when(() => repo.add(any(), any())).thenAnswer((_) async {});
      return FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
    },
    act: (c) => c.toggleTrip('t1'),
    expect: () => [
      predicate<FavoriteIdsState>((s) => s.tripIds.contains('t1')),
    ],
  );

  blocTest<FavoriteIdsCubit, FavoriteIdsState>(
    'toggleTrip émet [optimiste, rollback] quand add échoue',
    build: () {
      when(() => repo.add(any(), any())).thenThrow(Exception('net'));
      return FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
    },
    act: (c) async {
      try {
        await c.toggleTrip('t1');
      } catch (_) {}
    },
    expect: () => [
      predicate<FavoriteIdsState>((s) => s.tripIds.contains('t1')), // optimiste
      predicate<FavoriteIdsState>((s) => !s.tripIds.contains('t1')), // rollback
    ],
  );
}
