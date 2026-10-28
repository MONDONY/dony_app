/// Récapitulatif des colis portés, servi au seul voyageur par
/// `GET /announcements/{id}` (colis remis, en transit ou arrivés).
class TripParcelsSummary {
  const TripParcelsSummary({
    required this.count,
    required this.totalKg,
    required this.netAmount,
    required this.currency,
  });

  final int count;
  final double totalKg;

  /// Net estimé du voyageur ; les colis en espèces comptent pour 0.
  final double netAmount;
  final String currency;

  factory TripParcelsSummary.fromJson(Map<String, dynamic> json) =>
      TripParcelsSummary(
        count: (json['count'] as num?)?.toInt() ?? 0,
        totalKg: (json['totalKg'] as num?)?.toDouble() ?? 0,
        netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'EUR',
      );

  static TripParcelsSummary? fromJsonOrNull(Object? json) =>
      json is Map<String, dynamic> ? TripParcelsSummary.fromJson(json) : null;

  Map<String, dynamic> toJson() => {
    'count': count,
    'totalKg': totalKg,
    'netAmount': netAmount,
    'currency': currency,
  };
}
