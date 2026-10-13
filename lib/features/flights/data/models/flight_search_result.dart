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
    this.similarOffers = const [],
    this.similarStayMinDays,
    this.similarStayMaxDays,
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
        similarOffers: _offers(json['similarOffers']),
        similarStayMinDays: _days(json['similarStayMinDays']),
        similarStayMaxDays: _days(json['similarStayMaxDays']),
      );

  /// Liste d'offres tolérante : absente, nulle ou d'un autre type = vide ;
  /// les éléments qui ne sont pas des objets sont ignorés.
  static List<FlightOffer> _offers(Object? raw) => raw is List
      ? raw.whereType<Map<String, dynamic>>().map(FlightOffer.fromJson).toList()
      : const [];

  /// Durée de séjour tolérante : un entier positif (ou sa chaîne), sinon
  /// `null`.
  static int? _days(Object? raw) {
    final n = switch (raw) {
      final num v => v.toInt(),
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    return n != null && n > 0 ? n : null;
  }

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

  /// Allers-retours du même trajet, à d'autres dates (mois voisins), dont la
  /// durée de séjour est proche de celle demandée : au plus 10, triés par
  /// prix, jamais déjà présents dans [offers]. Absent (ancien back) = vide.
  /// Ni les onglets de tri ni les filtres ne s'y appliquent.
  final List<FlightOffer> similarOffers;

  /// Plage de durée de séjour, en jours, retenue par le back pour
  /// [similarOffers] ; `null` quand il ne la donne pas.
  final int? similarStayMinDays;
  final int? similarStayMaxDays;

  /// Plage de durée de séjour à afficher : celle du back, sinon celle des
  /// offres reçues ; `null` sans aucune durée connue.
  ({int min, int max})? get similarStayRange {
    final min = similarStayMinDays;
    final max = similarStayMaxDays;
    if (min != null && max != null && min <= max) return (min: min, max: max);
    final stays = similarOffers
        .map((o) => o.stayDays)
        .whereType<int>()
        .toList();
    if (stays.isEmpty) return null;
    stays.sort();
    return (min: stays.first, max: stays.last);
  }

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
    similarOffers,
    similarStayMinDays,
    similarStayMaxDays,
  ];
}
