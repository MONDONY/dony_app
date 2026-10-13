import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Alerte prix (`FlightAlertResponse` du back) : prévenir quand le prix le
/// plus bas trouvé dans la période passe sous [maxPrice].
class FlightAlert extends Equatable {
  const FlightAlert({
    required this.id,
    required this.originCode,
    required this.destinationCode,
    this.originLabel,
    this.destinationLabel,
    this.departureFrom,
    this.departureTo,
    this.returnFrom,
    this.returnTo,
    required this.directOnly,
    required this.maxPrice,
    required this.currency,
    required this.active,
    this.lastSeenPrice,
    this.lastCheckedAt,
    this.matchCount,
    this.matchAirlineCodes = const [],
  });

  factory FlightAlert.fromJson(Map<String, dynamic> json) => FlightAlert(
    id: json['id'] as String,
    originCode: json['originCode'] as String? ?? '',
    destinationCode: json['destinationCode'] as String? ?? '',
    originLabel: json['originLabel'] as String?,
    destinationLabel: json['destinationLabel'] as String?,
    departureFrom: _date(json['departureFrom']),
    departureTo: _date(json['departureTo']),
    returnFrom: _date(json['returnFrom']),
    returnTo: _date(json['returnTo']),
    directOnly: json['directOnly'] as bool? ?? false,
    maxPrice: (json['maxPrice'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'EUR',
    active: json['active'] as bool? ?? true,
    lastSeenPrice: (json['lastSeenPrice'] as num?)?.toDouble(),
    lastCheckedAt: json['lastCheckedAt'] is String
        ? DateTime.tryParse(json['lastCheckedAt'] as String)
        : null,
    matchCount: (json['matchCount'] as num?)?.toInt(),
    matchAirlineCodes: [
      for (final code
          in json['matchAirlineCodes'] as List<dynamic>? ?? const [])
        if (code is String && code.trim().isNotEmpty) code.trim(),
    ].take(3).toList(),
  );

  final String id;
  final String originCode;
  final String destinationCode;
  final String? originLabel;
  final String? destinationLabel;

  /// Période de départ (bornes incluses), `null` = toutes les dates à venir.
  final DateTime? departureFrom;
  final DateTime? departureTo;

  /// Période de retour, `null` = aller simple.
  final DateTime? returnFrom;
  final DateTime? returnTo;
  final bool directOnly;
  final double maxPrice;
  final String currency;
  final bool active;

  /// Prix le plus bas vu à la dernière vérification, `null` avant la première.
  final double? lastSeenPrice;
  final DateTime? lastCheckedAt;

  /// Vols de la dernière vérification au prix inférieur ou égal au seuil ;
  /// `null` avant la première vérification, ou sur un back qui ne le
  /// renvoie pas encore.
  final int? matchCount;

  /// Jusqu'à trois codes IATA de ces vols, du moins cher au plus cher ; vide
  /// quand rien n'est sous le seuil ou sur un ancien back.
  final List<String> matchAirlineCodes;

  /// Un prix est passé sous le seuil à la dernière vérification. Sans
  /// [matchCount] (ancien back), le dernier prix vu en décide.
  bool get hasHit {
    final count = matchCount;
    if (count != null) return count > 0;
    final seen = lastSeenPrice;
    return seen != null && seen <= maxPrice;
  }

  /// Dernier prix vu encore crédible comme « meilleur prix du moment ». Le
  /// back ne remet pas `lastSeenPrice` à zéro quand une vérification ne
  /// trouve plus rien : un prix sous le seuil avec `matchCount == 0` est
  /// périmé et n'est pas montré.
  double? get currentPrice {
    final seen = lastSeenPrice;
    if (seen == null) return null;
    if (matchCount == 0 && seen <= maxPrice) return null;
    return seen;
  }

  /// L'alerte a déjà été vérifiée au moins une fois.
  bool get checked => lastCheckedAt != null || lastSeenPrice != null;

  /// Chemin de recherche Aviasales du trajet, construit comme le back
  /// (`FlightQuery.searchPath`) sur le premier jour encore à venir de la
  /// période : `/search/{ORIG}{JJMM}{DEST}[{JJMM retour}]1`. Sert de repli
  /// quand `GET /me/flight-alerts/{id}/offers` n'existe pas encore (ancien
  /// back) ; `null` sans période de départ ou si elle est passée.
  String? aviasalesSearchPath(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    DateTime? firstDay(DateTime? from, DateTime? to) {
      if (from == null) return null;
      final start = from.isBefore(day) ? day : from;
      if (to != null && start.isAfter(to)) return null;
      return start;
    }

    final out = firstDay(departureFrom, departureTo);
    if (out == null || originCode.isEmpty || destinationCode.isEmpty) {
      return null;
    }
    DateTime? back;
    if (isRoundTrip) {
      back = firstDay(returnFrom, returnTo);
      if (back == null || back.isBefore(out)) return null;
    }
    return searchPathFor(originCode, destinationCode, out, back: back);
  }

  /// `/search/{ORIG}{JJMM}{DEST}[{JJMM retour}]1` (1 = un adulte), le format
  /// du back (`FlightQuery.searchPath`).
  static String searchPathFor(
    String origin,
    String destination,
    DateTime out, {
    DateTime? back,
  }) {
    String ddmm(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}';
    return '/search/$origin${ddmm(out)}$destination'
        '${back == null ? '' : ddmm(back)}1';
  }

  bool get isRoundTrip => returnFrom != null;

  String get originDisplay => originLabel ?? originCode;
  String get destinationDisplay => destinationLabel ?? destinationCode;

  FlightAlert copyWith({bool? active}) => FlightAlert(
    id: id,
    originCode: originCode,
    destinationCode: destinationCode,
    originLabel: originLabel,
    destinationLabel: destinationLabel,
    departureFrom: departureFrom,
    departureTo: departureTo,
    returnFrom: returnFrom,
    returnTo: returnTo,
    directOnly: directOnly,
    maxPrice: maxPrice,
    currency: currency,
    active: active ?? this.active,
    lastSeenPrice: lastSeenPrice,
    lastCheckedAt: lastCheckedAt,
    matchCount: matchCount,
    matchAirlineCodes: matchAirlineCodes,
  );

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  @override
  List<Object?> get props => [
    id,
    originCode,
    destinationCode,
    originLabel,
    destinationLabel,
    departureFrom,
    departureTo,
    returnFrom,
    returnTo,
    directOnly,
    maxPrice,
    currency,
    active,
    lastSeenPrice,
    lastCheckedAt,
    matchCount,
    matchAirlineCodes,
  ];
}

/// Création d'une alerte (`POST /me/flight-alerts`). Les périodes sont au
/// plus de 31 jours, bornes incluses ; le back reste la source de vérité.
class FlightAlertDraft extends Equatable {
  const FlightAlertDraft({
    required this.originCode,
    required this.destinationCode,
    this.originLabel,
    this.destinationLabel,
    this.departureFrom,
    this.departureTo,
    this.returnFrom,
    this.returnTo,
    this.directOnly = false,
    required this.maxPrice,
    this.currency,
  });

  /// Durée maximale d'une période (bornes comprises), alignée sur le back.
  static const maxPeriodDays = 31;

  final String originCode;
  final String destinationCode;
  final String? originLabel;
  final String? destinationLabel;
  final DateTime? departureFrom;
  final DateTime? departureTo;
  final DateTime? returnFrom;
  final DateTime? returnTo;
  final bool directOnly;
  final double maxPrice;
  final String? currency;

  static final _day = DateFormat('yyyy-MM-dd');

  Map<String, dynamic> toJson() => {
    'originCode': originCode,
    'destinationCode': destinationCode,
    'originLabel': ?originLabel,
    'destinationLabel': ?destinationLabel,
    if (departureFrom != null) 'departureFrom': _day.format(departureFrom!),
    if (departureTo != null) 'departureTo': _day.format(departureTo!),
    if (returnFrom != null) 'returnFrom': _day.format(returnFrom!),
    if (returnTo != null) 'returnTo': _day.format(returnTo!),
    'directOnly': directOnly,
    'maxPrice': maxPrice,
    'currency': ?currency,
  };

  @override
  List<Object?> get props => [
    originCode,
    destinationCode,
    originLabel,
    destinationLabel,
    departureFrom,
    departureTo,
    returnFrom,
    returnTo,
    directOnly,
    maxPrice,
    currency,
  ];
}
