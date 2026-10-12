import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:equatable/equatable.dart';

/// Réponse de `GET /flights/search` : offres triées par prix croissant.
class FlightSearchResult extends Equatable {
  const FlightSearchResult({
    required this.originCode,
    required this.destinationCode,
    required this.roundTrip,
    required this.currency,
    required this.offers,
    this.searchPath,
  });

  factory FlightSearchResult.fromJson(Map<String, dynamic> json) =>
      FlightSearchResult(
        originCode: json['originCode'] as String? ?? '',
        destinationCode: json['destinationCode'] as String? ?? '',
        roundTrip: json['roundTrip'] as bool? ?? false,
        currency: json['currency'] as String? ?? 'EUR',
        offers: (json['offers'] as List<dynamic>? ?? const [])
            .map((e) => FlightOffer.fromJson(e as Map<String, dynamic>))
            .toList(),
        searchPath: _path(json['searchPath']),
      );

  /// Un chemin vide ou qui ne ressemble pas à une recherche du partenaire est
  /// ignoré : le back le refuserait au clic.
  static String? _path(Object? raw) =>
      raw is String && raw.startsWith('/search/') ? raw : null;

  final String originCode;
  final String destinationCode;
  final bool roundTrip;
  final String currency;
  final List<FlightOffer> offers;

  /// Recherche Aviasales du trajet (« Voir toutes les compagnies »), à
  /// envoyer comme `offerPath` à `POST /flights/clicks` ; `null` sur un back
  /// qui ne la renvoie pas, ou sans jour de départ utilisable.
  final String? searchPath;

  @override
  List<Object?> get props => [
    originCode,
    destinationCode,
    roundTrip,
    currency,
    offers,
    searchPath,
  ];
}
