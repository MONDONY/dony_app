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
    this.arrivalAt,
    this.returnArrivalAt,
    this.outboundDurationMinutes,
    this.returnDurationMinutes,
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
    transfers: _int(json['transfers']),
    returnTransfers: _int(json['returnTransfers']),
    durationMinutes: _int(json['durationMinutes']),
    gate: _text(json['gate']),
    offerPath: json['offerPath'] as String? ?? '',
    logoUrl: json['logoUrl'] as String?,
    arrivalAt: _parseDate(json['arrivalAt']),
    returnArrivalAt: _parseDate(json['returnArrivalAt']),
    outboundDurationMinutes: _int(json['outboundDurationMinutes']),
    returnDurationMinutes: _int(json['returnDurationMinutes']),
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

  /// Durée totale du voyage, escales comprises : l'aller seul en aller
  /// simple, aller + retour en aller-retour (champ `duration` du partenaire).
  final int? durationMinutes;

  /// Site vendeur de référence (Kiwi.com, Aviasales…) : sert au filtre
  /// « Sites de réservation ».
  final String? gate;

  /// Chemin de l'offre chez le partenaire, renvoyé tel quel à
  /// `POST /flights/clicks`.
  final String offerPath;
  final String? logoUrl;

  /// Arrivée de l'aller, à l'heure locale de l'aéroport d'arrivée ; `null`
  /// sur un back qui ne la calcule pas encore, ou quand le fuseau manque.
  final DateTime? arrivalAt;

  /// Arrivée du retour, à l'heure locale de l'aéroport de départ du voyage.
  final DateTime? returnArrivalAt;

  /// Durée de l'aller seul et du retour seul (back récent, sinon `null`).
  final int? outboundDurationMinutes;
  final int? returnDurationMinutes;

  /// Durée affichée sur la ligne de l'aller. Un ancien back ne donne que la
  /// durée totale : juste pour un aller simple, fausse pour un aller-retour
  /// (elle additionne les deux trajets), où elle reste donc masquée.
  int? get outboundMinutes {
    if (outboundDurationMinutes != null) return outboundDurationMinutes;
    if (!isRoundTrip) return durationMinutes;
    // Aller-retour : `durationMinutes` est le total, l'aller s'en déduit
    // seulement si la durée du retour est connue.
    final total = durationMinutes;
    final back = returnDurationMinutes;
    if (total == null || back == null || total <= back) return null;
    return total - back;
  }

  /// Jours de décalage de l'arrivée de l'aller (« +1 » : lendemain).
  int get arrivalDayOffset => dayOffset(departureAt, arrivalAt);

  /// Jours de décalage de l'arrivée du retour.
  int get returnArrivalDayOffset => dayOffset(returnAt, returnArrivalAt);

  /// Écart en jours calendaires entre deux heures locales (0 si inconnu ou
  /// négatif : un fuseau mal renseigné ne doit pas afficher « -1 »).
  static int dayOffset(DateTime? from, DateTime? to) {
    if (from == null || to == null) return 0;
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    final days = b.difference(a).inDays;
    return days > 0 ? days : 0;
  }

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

  /// Entier tolérant : un nombre, ou une chaîne de chiffres.
  static int? _int(Object? raw) => switch (raw) {
    final num n => n.toInt(),
    final String s => int.tryParse(s.trim()),
    _ => null,
  };

  static String? _text(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

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
    arrivalAt,
    returnArrivalAt,
    outboundDurationMinutes,
    returnDurationMinutes,
  ];
}
