import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';

/// One-shot migration: pushes locally-saved trips (Hive key `saved_trips`)
/// to the server, then deletes the Hive key so the migration never runs again.
///
/// Best-effort: every error is swallowed. Local favorites are a legacy bonus —
/// losing them is acceptable, crashing is not.
class FavoritesMigration {
  final HiveService _hive;
  final FavoriteRepository _repo;

  FavoritesMigration(this._hive, this._repo);

  static const _key = 'saved_trips';

  Future<void> run() async {
    try {
      final box = _hive.userPrefs;
      final saved = box.get(_key);
      if (saved == null) {
        return;
      }

      final ids = <String>{};
      for (final raw in (saved as List)) {
        final id = (raw is Map ? raw['id'] : null)?.toString();
        if (id != null) {
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
