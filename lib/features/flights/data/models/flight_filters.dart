import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:equatable/equatable.dart';

/// Ordre d'affichage des résultats.
enum FlightSort { cheapest, fastest, fewestStops }

/// Limite d'escales à l'aller.
enum FlightStops { any, direct, oneMax }

/// Filtres de la feuille « Filtres », appliqués dans l'app sur les offres déjà
/// reçues (50 au plus) : aucun appel réseau supplémentaire.
class FlightFilters extends Equatable {
  const FlightFilters({
    this.sort = FlightSort.cheapest,
    this.stops = FlightStops.any,
    this.airlines = const {},
    this.gates = const {},
    this.minPrice,
    this.maxPrice,
  });

  final FlightSort sort;
  final FlightStops stops;

  /// Codes IATA des compagnies retenues ; vide = toutes.
  final Set<String> airlines;

  /// Sites de réservation retenus ; vide = tous.
  final Set<String> gates;
  final double? minPrice;
  final double? maxPrice;

  /// Vrai si au moins un filtre restreint la liste (le tri n'en est pas un).
  bool get isFiltering =>
      stops != FlightStops.any ||
      airlines.isNotEmpty ||
      gates.isNotEmpty ||
      minPrice != null ||
      maxPrice != null;

  bool accepts(FlightOffer o) {
    final transfers = o.transfers;
    switch (stops) {
      case FlightStops.any:
        break;
      case FlightStops.direct:
        if (transfers != 0) return false;
      case FlightStops.oneMax:
        if (transfers == null || transfers > 1) return false;
    }
    if (airlines.isNotEmpty && !airlines.contains(o.airlineCode)) return false;
    if (gates.isNotEmpty && !gates.contains(o.gate)) return false;
    if (minPrice != null && o.price < minPrice!) return false;
    if (maxPrice != null && o.price > maxPrice!) return false;
    return true;
  }

  /// Offres retenues, dans l'ordre du tri. Une durée ou un nombre d'escales
  /// inconnu passe en fin de liste plutôt que d'être pris pour zéro.
  List<FlightOffer> apply(List<FlightOffer> offers) {
    final kept = offers.where(accepts).toList();
    int byPrice(FlightOffer a, FlightOffer b) => a.price.compareTo(b.price);
    switch (sort) {
      case FlightSort.cheapest:
        kept.sort(byPrice);
      case FlightSort.fastest:
        kept.sort((a, b) {
          final c = (a.durationMinutes ?? 1 << 30).compareTo(
            b.durationMinutes ?? 1 << 30,
          );
          return c != 0 ? c : byPrice(a, b);
        });
      case FlightSort.fewestStops:
        kept.sort((a, b) {
          final c = (a.transfers ?? 99).compareTo(b.transfers ?? 99);
          return c != 0 ? c : byPrice(a, b);
        });
    }
    return kept;
  }

  FlightFilters copyWith({
    FlightSort? sort,
    FlightStops? stops,
    Set<String>? airlines,
    Set<String>? gates,
    double? minPrice,
    double? maxPrice,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) => FlightFilters(
    sort: sort ?? this.sort,
    stops: stops ?? this.stops,
    airlines: airlines ?? this.airlines,
    gates: gates ?? this.gates,
    minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
    maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
  );

  @override
  List<Object?> get props => [sort, stops, airlines, gates, minPrice, maxPrice];
}

/// Choix proposés par la feuille de filtres, calculés sur les offres reçues :
/// chaque compagnie et chaque site avec son prix le plus bas.
class FlightFacets extends Equatable {
  const FlightFacets({
    required this.airlines,
    required this.gates,
    this.minPrice,
    this.maxPrice,
  });

  factory FlightFacets.of(List<FlightOffer> offers) {
    final airlines = <String, FlightAirlineFacet>{};
    final gates = <String, double>{};
    double? min;
    double? max;
    for (final o in offers) {
      min = min == null || o.price < min ? o.price : min;
      max = max == null || o.price > max ? o.price : max;
      final code = o.airlineCode;
      if (code != null && code.isNotEmpty) {
        final known = airlines[code];
        if (known == null || o.price < known.minPrice) {
          airlines[code] = FlightAirlineFacet(
            code: code,
            name: o.airlineName ?? code,
            logoUrl: o.logoUrl,
            minPrice: o.price,
          );
        }
      }
      final gate = o.gate;
      if (gate != null && gate.isNotEmpty) {
        gates[gate] = gates[gate] == null || o.price < gates[gate]!
            ? o.price
            : gates[gate]!;
      }
    }
    final sortedAirlines = airlines.values.toList()
      ..sort((a, b) => a.minPrice.compareTo(b.minPrice));
    final sortedGates = gates.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return FlightFacets(
      airlines: sortedAirlines,
      gates: [
        for (final e in sortedGates)
          FlightGateFacet(name: e.key, minPrice: e.value),
      ],
      minPrice: min,
      maxPrice: max,
    );
  }

  final List<FlightAirlineFacet> airlines;
  final List<FlightGateFacet> gates;
  final double? minPrice;
  final double? maxPrice;

  @override
  List<Object?> get props => [airlines, gates, minPrice, maxPrice];
}

class FlightAirlineFacet extends Equatable {
  const FlightAirlineFacet({
    required this.code,
    required this.name,
    this.logoUrl,
    required this.minPrice,
  });

  final String code;
  final String name;
  final String? logoUrl;
  final double minPrice;

  @override
  List<Object?> get props => [code, name, logoUrl, minPrice];
}

class FlightGateFacet extends Equatable {
  const FlightGateFacet({required this.name, required this.minPrice});

  final String name;
  final double minPrice;

  @override
  List<Object?> get props => [name, minPrice];
}
