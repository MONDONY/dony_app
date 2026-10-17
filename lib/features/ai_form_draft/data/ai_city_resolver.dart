import 'package:dony/features/ai_form_draft/data/ai_text_fold.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/city_repository.dart';

/// Ville dite à l'IA → ville du catalogue, par la même recherche que le
/// formulaire (`GET /cities/search`). Seul un nom égal (sans casse ni
/// accents) est accepté : une suggestion approchante remplirait une autre
/// ville en silence.
class AiCityResolver {
  AiCityResolver(this._cities);

  final CityRepository _cities;

  Future<CityModel?> resolve(String name, {String? countryCode}) async {
    final query = name.trim();
    if (query.length < 2) return null;
    final List<CityModel> results;
    try {
      results = await _cities.searchCities(query);
    } on Object {
      return null;
    }
    final target = foldForMatch(query);
    final matches = [
      for (final city in results)
        if (foldForMatch(city.name) == target) city,
    ];
    if (matches.isEmpty) return null;
    if (countryCode != null) {
      for (final city in matches) {
        if (city.countryCode == countryCode) return city;
      }
    }
    return matches.first;
  }

  /// Remplace dans [draft] la ville (et son code pays) par celle du
  /// catalogue. Faux si une ville était donnée mais n'existe pas : les clés
  /// sont alors vidées. Vrai si aucune ville n'était donnée.
  Future<bool> resolveInto(
    Map<String, Object?> draft, {
    required String cityKey,
    String? countryKey,
  }) async {
    final name = draft[cityKey];
    if (name is! String || name.trim().isEmpty) {
      draft[cityKey] = null;
      return true;
    }
    final country = countryKey == null ? null : draft[countryKey];
    final city = await resolve(
      name,
      countryCode: country is String ? country : null,
    );
    draft[cityKey] = city?.name;
    if (countryKey != null) draft[countryKey] = city?.countryCode;
    return city != null;
  }
}
