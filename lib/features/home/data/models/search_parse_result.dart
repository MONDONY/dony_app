import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';

/// Le mode tel que le backend le nomme.
///
/// Flutter dit `parcels`, le backend dit `PACKAGES` : le mapping est écrit ici,
/// une fois, plutôt que déduit d'un `name.toUpperCase()` qui produirait `PARCELS`
/// et ferait échouer la désérialisation côté serveur.
String wireModeOf(SearchMode mode) =>
    mode == SearchMode.trips ? 'TRIPS' : 'PACKAGES';

enum UnresolvedKind {
  priceVague,
  dateVague,
  cityUnknown,
  cityAmbiguous;

  /// Renvoie null pour une valeur inconnue : un backend plus récent ne doit
  /// jamais faire planter une version d'app plus ancienne.
  static UnresolvedKind? fromWire(String? wire) => switch (wire) {
    'PRICE_VAGUE' => UnresolvedKind.priceVague,
    'DATE_VAGUE' => UnresolvedKind.dateVague,
    'CITY_UNKNOWN' => UnresolvedKind.cityUnknown,
    'CITY_AMBIGUOUS' => UnresolvedKind.cityAmbiguous,
    _ => null,
  };
}

class RecognizedField {
  const RecognizedField({required this.field, required this.value});

  final String field;
  final String value;

  factory RecognizedField.fromJson(Map<String, dynamic> json) =>
      RecognizedField(
        field: json['field'] as String? ?? '',
        value: '${json['value'] ?? ''}',
      );
}

class UnresolvedItem {
  const UnresolvedItem({
    required this.kind,
    required this.phrase,
    required this.options,
  });

  final UnresolvedKind kind;
  final String phrase;
  final List<String> options;
}

class SearchParseResult {
  const SearchParseResult({
    required this.filters,
    required this.recognized,
    required this.unresolved,
  });

  /// Les valeurs brutes renvoyées par le serveur, champs absents compris.
  final Map<String, dynamic> filters;
  final List<RecognizedField> recognized;
  final List<UnresolvedItem> unresolved;

  factory SearchParseResult.fromJson(Map<String, dynamic> json) {
    final rawUnresolved = (json['unresolved'] as List?) ?? const [];
    return SearchParseResult(
      filters: Map<String, dynamic>.from((json['filters'] as Map?) ?? const {}),
      recognized: ((json['recognized'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(RecognizedField.fromJson)
          .toList(),
      unresolved: rawUnresolved
          .cast<Map<String, dynamic>>()
          .map((e) {
            final kind = UnresolvedKind.fromWire(e['kind'] as String?);
            if (kind == null) return null;
            return UnresolvedItem(
              kind: kind,
              phrase: e['phrase'] as String? ?? '',
              options: ((e['options'] as List?) ?? const []).cast<String>(),
            );
          })
          .whereType<UnresolvedItem>()
          .toList(),
    );
  }

  /// Pose les filtres compris par-dessus ceux déjà réglés au doigt.
  ///
  /// Un champ absent de la réponse n'écrase rien : l'utilisateur qui a réglé
  /// « Kilo Pro » puis dicte une ville doit garder son Kilo Pro.
  HomeSearchFilters applyTo(HomeSearchFilters base) {
    var out = base;

    final arrival = filters['arrivalCity'] as String?;
    if (arrival != null) out = out.copyWith(arrivalCity: arrival);

    final departure = filters['departureCity'] as String?;
    if (departure != null) out = out.copyWith(departureCity: departure);

    // `HomeSearchFilters` ne porte qu'une seule date (`customDate`), jamais
    // de plage : la borne haute `departureDateTo` est donc ignorée
    // volontairement, limitation du modèle existant, hors périmètre de ce
    // correctif. `datePreset` DOIT passer à `custom` en même temps que
    // `customDate` : `dateFrom`/`dateTo` ne lisent `customDate` qu'en mode
    // `custom`, sinon la date posée ici n'a silencieusement aucun effet sur
    // la recherche alors que le récapitulatif l'affiche comme appliquée.
    final from = _date(filters['departureDateFrom']);
    if (from != null) {
      out = out.copyWith(datePreset: DonyDatePreset.custom, customDate: from);
    }

    final price = _number(filters['maxPricePerKg']);
    if (price != null) out = out.copyWith(maxPricePerKg: price);

    final minKg = _number(filters['minAvailableKg']);
    if (minKg != null) out = out.copyWith(weightMin: minKg);

    // `maxWeight` est le champ COLIS (capacité maximale recherchée pour une
    // demande de colis, mode PACKAGES) : à ne pas confondre avec `weightMax`,
    // champ TRAJETS lu par `toAnnouncementQuery().maxAvailableKg`. Voir la
    // note sur [HomeSearchFilters.weightMin].
    final maxKg = _number(filters['maxWeight']);
    if (maxKg != null) out = out.copyWith(maxWeight: maxKg);

    if (filters['urgent'] == true) out = out.copyWith(urgentOnly: true);

    if (filters['kiloProOnly'] == true) out = out.copyWith(kiloProOnly: true);

    if (filters['kycVerifiedOnly'] == true) {
      out = out.copyWith(kycVerifiedOnly: true);
    }

    final minRating = _number(filters['minRating']);
    if (minRating != null) out = out.copyWith(minRating: minRating);

    if (filters['weekendOnly'] == true) out = out.copyWith(weekendOnly: true);

    // Déjà le `label` du catalogue de contenu côté serveur, assignable tel
    // quel — pas de conversion à faire, contrairement à `transportMode`.
    final contentType = filters['contentType'] as String?;
    if (contentType != null) out = out.copyWith(contentType: contentType);

    // Réutilise la conversion existante de `transport_mode.dart` (même
    // contrat que `UnresolvedKind.fromWire` : `null` sur une valeur inconnue,
    // jamais de crash) plutôt que d'en écrire une nouvelle ici.
    final transportMode = transportModeFromWire(
      filters['transportMode'] as String?,
    );
    if (transportMode != null) out = out.copyWith(transportMode: transportMode);

    return out;
  }

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  static double? _number(Object? raw) => switch (raw) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };
}
