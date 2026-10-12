import 'package:equatable/equatable.dart';

/// Offre de vol prête à afficher (`FlightOfferDto` du back).
///
/// Les prix sont indicatifs (cache du partenaire) : le prix définitif est celui
/// du site partenaire, ouvert par `POST /flights/clicks`.
class FlightOffer extends Equatable {
  const FlightOffer({
    required this.originCode,
    required this.destinationCode,
    this.originAirport,
    this.destinationAirport,
    this.departureAt,
    this.returnAt,
    required this.price,
    required this.currency,
    this.airlineCode,
    this.airlineName,
    this.flightNumber,
    this.transfers,
    this.returnTransfers,
    this.durationMinutes,
    this.gate,
    required this.offerPath,
    this.logoUrl,
  });

  factory FlightOffer.fromJson(Map<String, dynamic> json) => FlightOffer(
    originCode: json['originCode'] as String? ?? '',
    destinationCode: json['destinationCode'] as String? ?? '',
    originAirport: json['originAirport'] as String?,
    destinationAirport: json['destinationAirport'] as String?,
    departureAt: _parseDate(json['departureAt']),
    returnAt: _parseDate(json['returnAt']),
    price: (json['price'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'EUR',
    airlineCode: json['airlineCode'] as String?,
    airlineName: json['airlineName'] as String?,
    flightNumber: json['flightNumber'] as String?,
    transfers: (json['transfers'] as num?)?.toInt(),
    returnTransfers: (json['returnTransfers'] as num?)?.toInt(),
    durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    gate: json['gate'] as String?,
    offerPath: json['offerPath'] as String? ?? '',
    logoUrl: json['logoUrl'] as String?,
  );

  final String originCode;
  final String destinationCode;

  /// Aéroport précis (CDG, ORY…) quand le partenaire le donne, sinon `null` :
  /// l'affichage retombe alors sur le code de la ville.
  final String? originAirport;
  final String? destinationAirport;

  /// Date et heure locales de départ (fuseau de l'aéroport, tel que reçu).
  final DateTime? departureAt;
  final DateTime? returnAt;
  final double price;
  final String currency;
  final String? airlineCode;
  final String? airlineName;
  final String? flightNumber;

  /// Nombre d'escales à l'aller (0 = direct), `null` si inconnu.
  final int? transfers;
  final int? returnTransfers;

  /// Durée totale de l'aller, escales comprises.
  final int? durationMinutes;

  /// Site vendeur de référence (Kiwi.com, Aviasales…) : sert au filtre
  /// « Sites de réservation ».
  final String? gate;

  /// Chemin de l'offre chez le partenaire, renvoyé tel quel à
  /// `POST /flights/clicks`.
  final String offerPath;
  final String? logoUrl;

  bool get isRoundTrip => returnAt != null;

  bool get isDirect => transfers == 0;

  /// Code affiché en grand sur le billet : l'aéroport s'il est connu.
  String get departureCode => originAirport ?? originCode;
  String get arrivalCode => destinationAirport ?? destinationCode;

  /// « 2026-12-04T11:30:00+01:00 » : on garde l'heure locale de l'aéroport
  /// telle qu'écrite, sans conversion vers le fuseau du téléphone.
  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.length < 10) return null;
    final local = raw.length >= 19
        ? raw.substring(0, 19)
        : raw.substring(0, 10);
    return DateTime.tryParse(local);
  }

  @override
  List<Object?> get props => [
    originCode,
    destinationCode,
    originAirport,
    destinationAirport,
    departureAt,
    returnAt,
    price,
    currency,
    airlineCode,
    airlineName,
    flightNumber,
    transfers,
    returnTransfers,
    durationMinutes,
    gate,
    offerPath,
    logoUrl,
  ];
}
