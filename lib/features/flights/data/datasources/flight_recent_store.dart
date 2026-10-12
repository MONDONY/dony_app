import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';

/// Historique des recherches de billets, gardé sur le téléphone seulement :
/// [maxEntries] au plus, la plus récente en tête, une entrée par trajet et
/// dates.
abstract class FlightRecentStore {
  static const maxEntries = 5;

  List<FlightRecentSearch> read();

  Future<void> write(List<FlightRecentSearch> entries);

  /// Place [entry] en tête, sans doublon, tronqué à [maxEntries] ; rend la
  /// nouvelle liste.
  Future<List<FlightRecentSearch>> add(FlightRecentSearch entry) async {
    final next = [
      entry,
      ...read().where((e) => e.dedupKey != entry.dedupKey),
    ].take(maxEntries).toList(growable: false);
    await write(next);
    return next;
  }

  Future<void> clear() => write(const []);
}

/// Historique persisté dans la boîte Hive des préférences
/// (`HiveService.kFlightRecentSearches`).
class HiveFlightRecentStore extends FlightRecentStore {
  HiveFlightRecentStore(this._hive);

  final HiveService _hive;

  @override
  List<FlightRecentSearch> read() {
    try {
      final raw = _hive.userPrefs.get(HiveService.kFlightRecentSearches);
      if (raw is! List) return const [];
      return raw
          .map(FlightRecentSearch.tryParse)
          .whereType<FlightRecentSearch>()
          .toList(growable: false);
    } catch (_) {
      // Boîte fermée ou contenu corrompu : l'historique est un confort.
      return const [];
    }
  }

  @override
  Future<void> write(List<FlightRecentSearch> entries) async {
    try {
      await _hive.userPrefs.put(
        HiveService.kFlightRecentSearches,
        entries.map((e) => e.toJson()).toList(),
      );
    } catch (_) {
      // Écriture impossible : la recherche elle-même n'en dépend pas.
    }
  }
}

/// Historique en mémoire, perdu à la fermeture de l'onglet : repli des tests
/// et des écrans construits sans stockage.
class MemoryFlightRecentStore extends FlightRecentStore {
  MemoryFlightRecentStore([List<FlightRecentSearch> initial = const []])
    : _entries = [...initial];

  List<FlightRecentSearch> _entries;

  @override
  List<FlightRecentSearch> read() => List.unmodifiable(_entries);

  @override
  Future<void> write(List<FlightRecentSearch> entries) async =>
      _entries = [...entries];
}
