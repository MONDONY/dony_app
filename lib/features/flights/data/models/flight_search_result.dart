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
    this.nearbyDates = false,
    this.nearbyDaysWindow = defaultNearbyDaysWindow,
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
        nearbyDates: json['nearbyDates'] == true,
        nearbyDaysWindow: _window(json['nearbyDaysWindow']),
      );

  /// Écart des dates proches quand le back ne le précise pas.
  static const defaultNearbyDaysWindow = 3;

  /// Écart en jours tolérant : un entier positif (ou sa chaîne), sinon la
  /// valeur par défaut.
  static int _window(Object? raw) {
    final n = switch (raw) {
      final num v => v.toInt(),
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    return n != null && n > 0 ? n : defaultNearbyDaysWindow;
  }

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

  /// Aucune offre aux jours demandés : le back renvoie à la place des vols à
  /// [nearbyDaysWindow] jours près. Absent (ancien back, champ non nul
  /// omis) = faux.
  final bool nearbyDates;

  /// Écart maximal, en jours, des dates proches (3 par défaut).
  final int nearbyDaysWindow;

  @override
  List<Object?> get props => [
    originCode,
    destinationCode,
    roundTrip,
    currency,
    offers,
    searchPath,
    nearbyDates,
    nearbyDaysWindow,
  ];
}
