import 'package:dony/features/favorites/data/models/favorite_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // FavoriteIds.fromJson
  // ---------------------------------------------------------------------------
  group('FavoriteIds.fromJson', () {
    test('parses trips and packageRequests from full JSON', () {
      final result = FavoriteIds.fromJson({
        'trips': ['t1', 't2'],
        'packageRequests': ['r1', 'r2', 'r3'],
      });

      expect(result.trips, containsAll(['t1', 't2']));
      expect(result.trips, hasLength(2));
      expect(result.packageRequests, containsAll(['r1', 'r2', 'r3']));
      expect(result.packageRequests, hasLength(3));
    });

    test('returns empty sets when lists are null', () {
      final result = FavoriteIds.fromJson({});

      expect(result.trips, isEmpty);
      expect(result.packageRequests, isEmpty);
    });

    test('returns empty sets when lists are explicitly null', () {
      final result = FavoriteIds.fromJson({
        'trips': null,
        'packageRequests': null,
      });

      expect(result.trips, isEmpty);
      expect(result.packageRequests, isEmpty);
    });

    test('deduplicates ids (Set semantics)', () {
      final result = FavoriteIds.fromJson({
        'trips': ['t1', 't1', 't2'],
        'packageRequests': ['r1', 'r1'],
      });

      expect(result.trips, hasLength(2));
      expect(result.packageRequests, hasLength(1));
    });

    test('converts non-String items to String', () {
      final result = FavoriteIds.fromJson({
        'trips': [42, 'abc'],
        'packageRequests': [],
      });

      expect(result.trips, containsAll(['42', 'abc']));
    });
  });

  // ---------------------------------------------------------------------------
  // FavoriteIds.empty
  // ---------------------------------------------------------------------------
  group('FavoriteIds.empty()', () {
    test('returns a FavoriteIds with empty sets', () {
      final result = FavoriteIds.empty();

      expect(result.trips, isEmpty);
      expect(result.packageRequests, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // FavoriteIdsState.copyWith
  // ---------------------------------------------------------------------------
  group('FavoriteIdsState.copyWith — direct model test', () {
    // The copyWith is tested via cubit tests indirectly.
    // Verify FavoriteIds const constructor directly for completeness.
    test('FavoriteIds const constructor preserves values', () {
      const ids = FavoriteIds(
        trips: {'trip-a', 'trip-b'},
        packageRequests: {'req-x'},
      );
      expect(ids.trips, hasLength(2));
      expect(ids.packageRequests, hasLength(1));
    });
  });
}
