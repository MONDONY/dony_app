import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // FavoriteIdsState.copyWith
  // ---------------------------------------------------------------------------
  group('FavoriteIdsState.copyWith', () {
    const initial = FavoriteIdsState({'t1', 't2'}, {'r1'});

    test('creates new instance with updated tripIds', () {
      final updated = initial.copyWith(tripIds: {'t3'});

      expect(updated.tripIds, {'t3'});
      expect(updated.requestIds, {'r1'}); // unchanged
    });

    test('creates new instance with updated requestIds', () {
      final updated = initial.copyWith(requestIds: {'r2', 'r3'});

      expect(updated.tripIds, {'t1', 't2'}); // unchanged
      expect(updated.requestIds, {'r2', 'r3'});
    });

    test('returns a copy when no params provided (same values)', () {
      final copy = initial.copyWith();

      expect(copy.tripIds, initial.tripIds);
      expect(copy.requestIds, initial.requestIds);
    });

    test('can update both at once', () {
      final updated = initial.copyWith(
        tripIds: {'new-t'},
        requestIds: {'new-r'},
      );

      expect(updated.tripIds, {'new-t'});
      expect(updated.requestIds, {'new-r'});
    });
  });

  // ---------------------------------------------------------------------------
  // FavoriteIdsState.count
  // ---------------------------------------------------------------------------
  group('FavoriteIdsState.count', () {
    test('returns sum of trips and requests', () {
      const state = FavoriteIdsState({'t1', 't2', 't3'}, {'r1', 'r2'});

      expect(state.count, 5);
    });

    test('returns 0 for empty state', () {
      const state = FavoriteIdsState({}, {});

      expect(state.count, 0);
    });

    test('returns count of trips only when requests empty', () {
      const state = FavoriteIdsState({'t1'}, {});

      expect(state.count, 1);
    });

    test('returns count of requests only when trips empty', () {
      const state = FavoriteIdsState({}, {'r1', 'r2'});

      expect(state.count, 2);
    });
  });
}
