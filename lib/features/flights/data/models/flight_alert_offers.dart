import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:equatable/equatable.dart';

/// Vols trouvés par une alerte prix (`GET /me/flight-alerts/{id}/offers`) :
/// les offres de la période de l'alerte au prix inférieur ou égal à
/// [maxPrice], du moins cher au plus cher. Prix indicatifs, lus au moment
/// de l'ouverture ([checkedAt]).
class FlightAlertOffers extends Equatable {
  const FlightAlertOffers({
    required this.alertId,
    required this.originCode,
    required this.destinationCode,
    this.originLabel,
    this.destinationLabel,
    required this.roundTrip,
    required this.currency,
    required this.maxPrice,
    required this.offers,
    this.searchPath,
    this.checkedAt,
  });

  factory FlightAlertOffers.fromJson(Map<String, dynamic> json) {
    final offers = <FlightOffer>[
      for (final raw in json['offers'] as List<dynamic>? ?? const [])
        if (raw is Map<String, dynamic>) FlightOffer.fromJson(raw),
    ]..sort((a, b) => a.price.compareTo(b.price));
    final path = json['searchPath'];
    return FlightAlertOffers(
      alertId: json['alertId'] as String? ?? '',
      originCode: json['originCode'] as String? ?? '',
      destinationCode: json['destinationCode'] as String? ?? '',
      originLabel: json['originLabel'] as String?,
      destinationLabel: json['destinationLabel'] as String?,
      roundTrip: json['roundTrip'] as bool? ?? false,
      currency: json['currency'] as String? ?? 'EUR',
      maxPrice: (json['maxPrice'] as num?)?.toDouble() ?? 0,
      offers: offers,
      // Même garde que la recherche : un chemin qui ne ressemble pas à une
      // recherche du partenaire serait refusé au clic.
      searchPath: path is String && path.startsWith('/search/') ? path : null,
      checkedAt: json['checkedAt'] is String
          ? DateTime.tryParse(json['checkedAt'] as String)
          : null,
    );
  }

  final String alertId;
  final String originCode;
  final String destinationCode;
  final String? originLabel;
  final String? destinationLabel;
  final bool roundTrip;
  final String currency;
  final double maxPrice;
  final List<FlightOffer> offers;

  /// Recherche Aviasales du trajet sur le premier jour de la période,
  /// `null` sans période de départ.
  final String? searchPath;
  final DateTime? checkedAt;

  FlightOffer? get cheapest => offers.isEmpty ? null : offers.first;

  /// Même forme qu'une recherche, pour « Plus de vols sur Aviasales »
  /// ([FlightLinkCubit.openAllAirlines]).
  FlightSearchResult toSearchResult({String? fallbackSearchPath}) =>
      FlightSearchResult(
        originCode: originCode,
        destinationCode: destinationCode,
        roundTrip: roundTrip,
        currency: currency,
        offers: offers,
        searchPath: searchPath ?? fallbackSearchPath,
      );

  @override
  List<Object?> get props => [
    alertId,
    originCode,
    destinationCode,
    originLabel,
    destinationLabel,
    roundTrip,
    currency,
    maxPrice,
    offers,
    searchPath,
    checkedAt,
  ];
}
