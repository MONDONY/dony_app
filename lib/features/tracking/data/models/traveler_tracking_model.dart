/// État du suivi approximatif du voyageur, vu par l'expéditeur.
enum TravelerTrackingStatus {
  notActivated,
  enRoute,
  arrived,
  stale;

  /// Valeur inconnue ou absente (back plus récent ou plus ancien) : suivi
  /// non activé, c'est l'état le plus prudent à afficher.
  static TravelerTrackingStatus fromWire(Object? value) => switch (value) {
    'EN_ROUTE' => TravelerTrackingStatus.enRoute,
    'ARRIVED' => TravelerTrackingStatus.arrived,
    'STALE' => TravelerTrackingStatus.stale,
    _ => TravelerTrackingStatus.notActivated,
  };
}

/// Une ville traversée entre le scan du colis et sa livraison.
class TravelerTrackingPoint {
  const TravelerTrackingPoint({required this.city, this.at});

  final String city;
  final DateTime? at;

  static TravelerTrackingPoint? tryParse(Object? json) {
    if (json is! Map) return null;
    final city = json['city'];
    if (city is! String || city.trim().isEmpty) return null;
    final at = json['at'];
    return TravelerTrackingPoint(
      city: city,
      at: at is String ? DateTime.tryParse(at) : null,
    );
  }

  Map<String, dynamic> toJson() => {'city': city, 'at': at?.toIso8601String()};
}

/// `travelerTracking` du détail d'un colis (`GET /bids/{id}`). Tous les champs
/// sont facultatifs : un back antérieur ne sert rien.
class TravelerTrackingModel {
  const TravelerTrackingModel({
    this.status = TravelerTrackingStatus.notActivated,
    this.lastUpdatedAt,
    this.progressPct,
    this.nearestCity,
    this.history = const [],
  });

  final TravelerTrackingStatus status;
  final DateTime? lastUpdatedAt;

  /// Avancement 0..100, `null` si inconnu.
  final int? progressPct;
  final String? nearestCity;

  /// Villes entre le scan et la livraison, la dernière est la position
  /// actuelle. Vide hors du détail du colis.
  final List<TravelerTrackingPoint> history;

  factory TravelerTrackingModel.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'];
    final lastUpdated = json['lastUpdatedAt'];
    final pct = json['progressPct'];
    final city = json['nearestCity'];
    return TravelerTrackingModel(
      status: TravelerTrackingStatus.fromWire(json['status']),
      lastUpdatedAt: lastUpdated is String
          ? DateTime.tryParse(lastUpdated)
          : null,
      progressPct: pct is num ? pct.toInt().clamp(0, 100) : null,
      nearestCity: city is String && city.isNotEmpty ? city : null,
      history: rawHistory is List
          ? rawHistory
                .map(TravelerTrackingPoint.tryParse)
                .whereType<TravelerTrackingPoint>()
                .toList()
          : const [],
    );
  }

  /// Valeur de la clé `travelerTracking` d'un JSON de colis (`null` si
  /// absente ou mal formée).
  static TravelerTrackingModel? fromJsonOrNull(Object? json) =>
      json is Map<String, dynamic>
      ? TravelerTrackingModel.fromJson(json)
      : null;

  Map<String, dynamic> toJson() => {
    'status': switch (status) {
      TravelerTrackingStatus.notActivated => 'NOT_ACTIVATED',
      TravelerTrackingStatus.enRoute => 'EN_ROUTE',
      TravelerTrackingStatus.arrived => 'ARRIVED',
      TravelerTrackingStatus.stale => 'STALE',
    },
    'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
    'progressPct': progressPct,
    'nearestCity': nearestCity,
    'history': history.map((e) => e.toJson()).toList(),
  };
}
