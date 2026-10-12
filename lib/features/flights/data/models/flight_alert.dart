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
