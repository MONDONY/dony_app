import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:equatable/equatable.dart';

/// Vols d'une alerte prix (`GET /me/flight-alerts/{id}/offers?scope=all`) :
/// les offres de la période de l'alerte, du moins cher au plus cher, d'abord
/// celles au prix inférieur ou égal à [maxPrice] ([below]), puis les autres
/// ([above]). Un back antérieur à `scope` ne renvoie que les premières.
/// Prix indicatifs, lus au moment de l'ouverture ([checkedAt]).
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
    int? belowCount,
  }) : _belowCount = belowCount;

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
      belowCount: (json['belowCount'] as num?)?.toInt(),
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

  /// Nombre de vols sous le seuil donné par le back, `null` s'il ne le
  /// donne pas (ancien back) : [belowCount] le recalcule.
  final int? _belowCount;

  /// Vols au prix inférieur ou égal à [maxPrice], en tête de [offers]
  /// (triées du moins cher au plus cher).
  int get belowCount =>
      (_belowCount ?? offers.where((o) => o.price <= maxPrice).length).clamp(
        0,
        offers.length,
      );

  /// Réponse d'un back qui connaît `scope=all` (il donne `belowCount`) :
  /// une liste vide y signifie qu'aucun vol n'existe pour ce trajet et ces
  /// dates, et non que les prix sont repassés au-dessus du seuil.
  bool get allScope => _belowCount != null;

  List<FlightOffer> get below => offers.sublist(0, belowCount);

  /// Vols au-dessus du seuil, vides sur un ancien back.
  List<FlightOffer> get above => offers.sublist(belowCount);

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
    _belowCount,
  ];
}
