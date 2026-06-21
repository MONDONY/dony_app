import 'dart:convert';

import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';

/// One-shot migration: pushes locally-saved trips (Hive key `saved_trips`)
/// to the server, then deletes the Hive key so the migration never runs again.
///
/// Best-effort: every error is swallowed. Local favorites are a legacy bonus —
/// losing them is acceptable, crashing is not.
///
/// The legacy `SavedTripsService` stored the value as a JSON-encoded String
/// (via `jsonEncode(trips.map((a) => a.toJson()).toList())`), so each stored
/// value is a `String`, NOT a bare `List`. This migration handles both forms
/// for safety.
class FavoritesMigration {
  final HiveService _hive;
  final FavoriteRepository _repo;

  FavoritesMigration(this._hive, this._repo);

  static const _key = 'saved_trips';

  Future<void> run() async {
    try {
      final box = _hive.userPrefs;
      final raw = box.get(_key);
      if (raw == null) {
        return;
      }

      // The legacy service stored a JSON-encoded String. Decode it to a List.
      // Accept a bare List too, for forward-compatibility with any hypothetical
      // future format change.
      final List<dynamic> list;
      if (raw is String) {
        list = jsonDecode(raw) as List<dynamic>;
      } else {
        list = raw as List<dynamic>;
      }

      final ids = <String>{};
      for (final entry in list) {
        final id = (entry is Map ? entry['id'] : null)?.toString();
        if (id != null && id.isNotEmpty) {
          ids.add(id);
        }
      }

      for (final id in ids) {
        try {
          await _repo.add('trip', id);
        } catch (_) {
          // swallow per-item errors — one failure must not block the rest
        }
      }

      await box.delete(_key);
    } catch (_) {
      // swallow top-level errors — migration is best-effort
    }
  }
}
