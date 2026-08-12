import 'dart:convert';

import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/favorites/data/favorites_migration.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockHiveService extends Mock implements HiveService {}

class _MockBox extends Mock implements Box<dynamic> {}

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

void main() {
  late _MockHiveService hive;
  late _MockBox box;
  late _MockFavoriteRepository repo;
  late FavoritesMigration migration;

  setUp(() {
    hive = _MockHiveService();
    box = _MockBox();
    repo = _MockFavoriteRepository();
    when(() => hive.userPrefs).thenReturn(box);
    migration = FavoritesMigration(hive, repo);
  });

  group('FavoritesMigration.run()', () {
    test('no-op when saved_trips key is absent', () async {
      when(() => box.get('saved_trips')).thenReturn(null);

      await migration.run();

      verifyNever(() => repo.add(any(), any()));
      verifyNever(() => box.delete(any()));
    });

    test('calls repo.add for each id and deletes the key', () async {
      when(() => box.get('saved_trips')).thenReturn([
        {'id': 'trip-1'},
        {'id': 'trip-2'},
      ]);
      when(() => repo.add('trip', any())).thenAnswer((_) async {});
      when(() => box.delete('saved_trips')).thenAnswer((_) async {});

      await migration.run();

      verify(() => repo.add('trip', 'trip-1')).called(1);
      verify(() => repo.add('trip', 'trip-2')).called(1);
      verify(() => box.delete('saved_trips')).called(1);
    });

    // Regression test for C1: SavedTripsService stored a JSON-encoded String,
    // not a bare List. The original migration did `saved as List` which threw a
    // CastError on any real user's data, silently no-oping the migration.
    test(
        'decodes JSON String stored by legacy SavedTripsService and migrates correctly',
        () async {
      // This is the exact format SavedTripsService._encode() produced:
      // jsonEncode(trips.map((a) => a.toJson()).toList())
      final stored =
          jsonEncode([{'id': 'trip-1'}, {'id': 'trip-2'}]);
      when(() => box.get('saved_trips')).thenReturn(stored);
      when(() => repo.add('trip', any())).thenAnswer((_) async {});
      when(() => box.delete('saved_trips')).thenAnswer((_) async {});

      await migration.run();

      verify(() => repo.add('trip', 'trip-1')).called(1);
      verify(() => repo.add('trip', 'trip-2')).called(1);
      verify(() => box.delete('saved_trips')).called(1);
    });

    test('swallows per-item repo.add error and still deletes the key',
        () async {
      when(() => box.get('saved_trips')).thenReturn([
        {'id': 'trip-ok'},
        {'id': 'trip-fail'},
      ]);
      when(() => repo.add('trip', 'trip-ok')).thenAnswer((_) async {});
      when(() => repo.add('trip', 'trip-fail'))
          .thenThrow(Exception('network error'));
      when(() => box.delete('saved_trips')).thenAnswer((_) async {});

      // Must not throw
      await expectLater(migration.run(), completes);

      verify(() => repo.add('trip', 'trip-ok')).called(1);
      verify(() => repo.add('trip', 'trip-fail')).called(1);
      // Key is still deleted even though one item failed
      verify(() => box.delete('saved_trips')).called(1);
    });

    test('swallows a top-level Hive error and does not throw', () async {
      when(() => box.get('saved_trips')).thenThrow(Exception('hive failure'));

      await expectLater(migration.run(), completes);

      verifyNever(() => repo.add(any(), any()));
      verifyNever(() => box.delete(any()));
    });

    test('skips entries with missing id', () async {
      when(() => box.get('saved_trips')).thenReturn([
        {'id': 'trip-valid'},
        {'other_field': 'no-id'},
        null,
      ]);
      when(() => repo.add('trip', 'trip-valid')).thenAnswer((_) async {});
      when(() => box.delete('saved_trips')).thenAnswer((_) async {});

      await migration.run();

      verify(() => repo.add('trip', 'trip-valid')).called(1);
      verifyNever(() => repo.add('trip', 'null'));
      verify(() => box.delete('saved_trips')).called(1);
    });

    test('is idempotent — second run is a no-op (key already deleted)', () async {
      // First call: key present, migration runs
      when(() => box.get('saved_trips'))
          .thenReturn([<String, dynamic>{'id': 'trip-1'}]);
      when(() => repo.add('trip', 'trip-1')).thenAnswer((_) async {});
      when(() => box.delete('saved_trips')).thenAnswer((_) async {});

      await migration.run();
      verify(() => repo.add('trip', 'trip-1')).called(1);

      // Second call: key absent
      when(() => box.get('saved_trips')).thenReturn(null);

      await migration.run();

      // repo.add not called again (total still 1)
      verifyNever(() => repo.add(any(), any()));
    });
  });
}
