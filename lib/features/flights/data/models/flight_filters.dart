import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:equatable/equatable.dart';

/// Ordre d'affichage des résultats.
enum FlightSort { cheapest, fastest, fewestStops }

/// Limite d'escales à l'aller.
enum FlightStops { any, direct, oneMax }

/// Tranche horaire du départ de l'aller (heure locale de l'aéroport).
enum FlightDaySlot {
  night(0, 5),
  morning(5, 12),
  afternoon(12, 18),
  evening(18, 24);

  const FlightDaySlot(this.fromHour, this.toHour);

  /// Heure de début incluse, heure de fin exclue.
  final int fromHour;
  final int toHour;

  /// Tranche de [departure], `null` si l'heure est inconnue (le partenaire
  /// ne donne parfois que la date : minuit pile).
  static FlightDaySlot? of(DateTime? departure) {
    if (departure == null) return null;
    if (departure.hour == 0 && departure.minute == 0) return null;
    return values.firstWhere(
      (s) => departure.hour >= s.fromHour && departure.hour < s.toHour,
    );
  }
}

/// Onglets de tri des résultats : le moins cher, le plus rapide, et les
/// seuls vols directs triés par prix.
enum FlightResultsTab { cheapest, fastest, direct }

/// Meilleure offre d'un onglet : son prix et la durée de son aller.
class FlightTabSummary extends Equatable {
  const FlightTabSummary({required this.offer});

  final FlightOffer offer;

  double get price => offer.price;
  int? get minutes => offer.outboundMinutes ?? offer.durationMinutes;

  /// Meilleure offre de chaque onglet parmi [offers] (déjà filtrées) ;
  /// l'onglet est absent de la table quand aucune offre n'y entre.
  static Map<FlightResultsTab, FlightTabSummary> of(List<FlightOffer> offers) {
    final result = <FlightResultsTab, FlightTabSummary>{};
    for (final tab in FlightResultsTab.values) {
      final ranked = rank(offers, tab);
      if (ranked.isNotEmpty) {
        result[tab] = FlightTabSummary(offer: ranked.first);
      }
    }
    return result;
  }

  /// [offers] rangées selon [tab]. Une durée inconnue passe en fin de liste.
  static List<FlightOffer> rank(
    List<FlightOffer> offers,
    FlightResultsTab tab,
  ) {
    int byPrice(FlightOffer a, FlightOffer b) => a.price.compareTo(b.price);
    switch (tab) {
      case FlightResultsTab.cheapest:
        return [...offers]..sort(byPrice);
      case FlightResultsTab.direct:
        return offers.where((o) => o.isDirect).toList()..sort(byPrice);
      case FlightResultsTab.fastest:
        return [...offers]..sort((a, b) {
          final c = (a.durationMinutes ?? 1 << 30).compareTo(
            b.durationMinutes ?? 1 << 30,
          );
          return c != 0 ? c : byPrice(a, b);
        });
    }
  }

  @override
  List<Object?> get props => [offer];
}

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
    this.slots = const {},
  });

  final FlightSort sort;
  final FlightStops stops;

  /// Codes IATA des compagnies retenues ; vide = toutes.
  final Set<String> airlines;

  /// Sites de réservation retenus ; vide = tous.
  final Set<String> gates;
  final double? minPrice;
  final double? maxPrice;

  /// Tranches horaires de départ retenues ; vide = toutes.
  final Set<FlightDaySlot> slots;

  /// Vrai si au moins un filtre restreint la liste (le tri n'en est pas un).
  bool get isFiltering => activeCount > 0;

  /// Nombre de rubriques de filtre actives (« Filtres · 2 »).
  int get activeCount => [
    stops != FlightStops.any,
    airlines.isNotEmpty,
    gates.isNotEmpty,
    minPrice != null || maxPrice != null,
    slots.isNotEmpty,
  ].where((active) => active).length;

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
    if (slots.isNotEmpty && !slots.contains(FlightDaySlot.of(o.departureAt))) {
      return false;
    }
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
    Set<FlightDaySlot>? slots,
  }) => FlightFilters(
    sort: sort ?? this.sort,
    stops: stops ?? this.stops,
    airlines: airlines ?? this.airlines,
    gates: gates ?? this.gates,
    minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
    maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
    slots: slots ?? this.slots,
  );

  @override
  List<Object?> get props => [
    sort,
    stops,
    airlines,
    gates,
    minPrice,
    maxPrice,
    slots,
  ];
}

/// Choix proposés par la feuille de filtres, calculés sur les offres reçues :
/// chaque compagnie et chaque site avec son prix le plus bas.
class FlightFacets extends Equatable {
  const FlightFacets({
    required this.airlines,
    required this.gates,
    this.minPrice,
    this.maxPrice,
    this.slots = const {},
  });

  factory FlightFacets.of(List<FlightOffer> offers) {
    final airlines = <String, FlightAirlineFacet>{};
    final gates = <String, double>{};
    final slots = <FlightDaySlot>{};
    double? min;
    double? max;
    for (final o in offers) {
      final slot = FlightDaySlot.of(o.departureAt);
      if (slot != null) slots.add(slot);
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
      slots: slots,
    );
  }

  final List<FlightAirlineFacet> airlines;
  final List<FlightGateFacet> gates;
  final double? minPrice;
  final double? maxPrice;

  /// Tranches horaires où part au moins une offre.
  final Set<FlightDaySlot> slots;

  /// Plafonds de prix proposés en puces : trois paliers arrondis, répartis
  /// entre le prix le plus bas et le plus haut, sans doublon.
  List<double> get priceSteps {
    final low = minPrice;
    final high = maxPrice;
    if (low == null || high == null || high <= low) return const [];
    final unit = high - low >= 300 ? 50.0 : 10.0;
    final steps = <double>{};
    for (final f in const [0.25, 0.5, 0.75]) {
      final raw = low + (high - low) * f;
      final rounded = (raw / unit).ceil() * unit;
      if (rounded > low && rounded < high) steps.add(rounded);
    }
    return steps.toList()..sort();
  }

  @override
  List<Object?> get props => [airlines, gates, minPrice, maxPrice, slots];
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
