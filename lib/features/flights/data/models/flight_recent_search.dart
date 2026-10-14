import 'package:dony/features/flights/data/models/flight_passengers.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:equatable/equatable.dart';

/// Recherche de billets mémorisée sur le téléphone (« Vos recherches ») : le
/// trajet, ses dates, et le prix le plus bas vu au moment de la recherche.
class FlightRecentSearch extends Equatable {
  const FlightRecentSearch({
    required this.origin,
    required this.destination,
    this.departure,
    this.returnDate,
    this.roundTrip = false,
    this.directOnly = false,
    this.passengers = FlightPassengers.single,
    this.lowestPrice,
    this.currency,
    required this.searchedAt,
  });

  factory FlightRecentSearch.fromQuery(
    FlightSearchQuery query, {
    double? lowestPrice,
    String? currency,
    required DateTime at,
  }) => FlightRecentSearch(
    origin: query.origin!,
    destination: query.destination!,
    departure: query.departure,
    returnDate: query.returnDate,
    roundTrip: query.isRoundTrip,
    directOnly: query.directOnly,
    passengers: query.passengers,
    lowestPrice: lowestPrice,
    currency: currency,
    searchedAt: at,
  );

  /// Lecture tolérante d'une entrée Hive : une entrée illisible rend `null`
  /// et disparaît de la liste plutôt que de casser l'onglet.
  static FlightRecentSearch? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final origin = _place(json['origin']);
    final destination = _place(json['destination']);
    final at = DateTime.tryParse(json['searchedAt'] as String? ?? '');
    if (origin == null || destination == null || at == null) return null;
    final returnDate = _when(json['returnDate']);
    return FlightRecentSearch(
      origin: origin,
      destination: destination,
      departure: _when(json['departure']),
      returnDate: returnDate,
      roundTrip: json['roundTrip'] as bool? ?? returnDate != null,
      directOnly: json['directOnly'] as bool? ?? false,
      // Entrée d'avant le choix des passagers : un adulte.
      passengers: FlightPassengers.tryParse(json['passengers']),
      lowestPrice: (json['lowestPrice'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      searchedAt: at,
    );
  }

  final FlightPlace origin;
  final FlightPlace destination;
  final FlightWhen? departure;
  final FlightWhen? returnDate;
  final bool roundTrip;
  final bool directOnly;
  final FlightPassengers passengers;

  /// Prix le plus bas reçu, `null` si la recherche n'a rien donné.
  final double? lowestPrice;
  final String? currency;
  final DateTime searchedAt;

  /// Même trajet, mêmes dates et mêmes passagers : une seule entrée dans
  /// l'historique.
  String get dedupKey => [
    origin.code,
    destination.code,
    departure?.toQueryValue() ?? '',
    returnDate?.toQueryValue() ?? '',
    passengers.key,
  ].join('|');

  FlightSearchQuery toQuery() => FlightSearchQuery(
    origin: origin,
    destination: destination,
    departure: departure,
    returnDate: returnDate,
    directOnly: directOnly,
    passengers: passengers,
    roundTrip: roundTrip,
  );

  Map<String, dynamic> toJson() => {
    'origin': _placeJson(origin),
    'destination': _placeJson(destination),
    if (departure != null) 'departure': _whenJson(departure!),
    if (returnDate != null) 'returnDate': _whenJson(returnDate!),
    'roundTrip': roundTrip,
    'directOnly': directOnly,
    'passengers': passengers.toJson(),
    'lowestPrice': ?lowestPrice,
    'currency': ?currency,
    'searchedAt': searchedAt.toIso8601String(),
  };

  static Map<String, dynamic> _placeJson(FlightPlace p) => {
    'code': p.code,
    'name': p.name,
    'countryCode': ?p.countryCode,
    'countryName': ?p.countryName,
  };

  static FlightPlace? _place(Object? raw) {
    if (raw is! Map) return null;
    final place = FlightPlace.fromJson(Map<String, dynamic>.from(raw));
    return place.code.isEmpty ? null : place;
  }

  static Map<String, dynamic> _whenJson(FlightWhen w) => {
    'date': w.date.toIso8601String(),
    'month': w.wholeMonth,
  };

  static FlightWhen? _when(Object? raw) {
    if (raw is! Map) return null;
    final date = DateTime.tryParse(raw['date'] as String? ?? '');
    if (date == null) return null;
    return raw['month'] == true ? FlightWhen.month(date) : FlightWhen.day(date);
  }

  @override
  List<Object?> get props => [
    origin,
    destination,
    departure,
    returnDate,
    roundTrip,
    directOnly,
    passengers,
    lowestPrice,
    currency,
    searchedAt,
  ];
}
