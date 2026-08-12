import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/city/data/city_model.dart';

/// Rôle du champ concerné par l'historique — départ et arrivée sont mémorisés
/// séparément, un trajet Paris → Dakar ne doit pas faire apparaître Paris
/// dans les suggestions du champ d'arrivée.
enum CityFieldRole { departure, arrival }

/// Mémorise les 3 dernières villes sélectionnées par champ (départ/arrivée),
/// affichées au focus avant toute frappe — évite un aller-retour réseau pour
/// les trajets récurrents. Persisté en Hive (`userPrefsBox`), même pattern que
/// `HiveService.kFavDestinations`.
class RecentCityStore {
  RecentCityStore(this._hive);

  final HiveService _hive;

  static const int maxEntries = 3;

  String _key(CityFieldRole role) => switch (role) {
    CityFieldRole.departure => HiveService.kRecentDepartureCities,
    CityFieldRole.arrival => HiveService.kRecentArrivalCities,
  };

  List<CityModel> read(CityFieldRole role) {
    final raw =
        _hive.userPrefs.get(_key(role), defaultValue: const <dynamic>[])
            as List;
    return raw
        .whereType<Map>()
        .map((m) => CityModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// Place [city] en tête, sans doublon (name+countryCode), tronqué à
  /// [maxEntries].
  Future<void> add(CityFieldRole role, CityModel city) async {
    final withoutDuplicate = read(
      role,
    ).where((c) => c.name != city.name || c.countryCode != city.countryCode);
    final next = [city, ...withoutDuplicate].take(maxEntries).toList();
    await _hive.userPrefs.put(_key(role), next.map((c) => c.toJson()).toList());
  }
}
