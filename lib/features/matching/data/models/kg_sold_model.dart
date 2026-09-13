/// Poids livré sur un trajet, avec le nombre de colis, sur la période.
class KgSoldTripModel {
  final String tripId;
  final String departureCity;
  final String arrivalCity;
  final DateTime date;
  final int parcels;
  final double kg;

  const KgSoldTripModel({
    required this.tripId,
    required this.departureCity,
    required this.arrivalCity,
    required this.date,
    required this.parcels,
    required this.kg,
  });

  factory KgSoldTripModel.fromJson(Map<String, dynamic> json) =>
      KgSoldTripModel(
        tripId: json['tripId'] as String? ?? '',
        departureCity: json['departureCity'] as String? ?? '',
        arrivalCity: json['arrivalCity'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        parcels: (json['parcels'] as num?)?.toInt() ?? 0,
        kg: (json['kg'] as num?)?.toDouble() ?? 0,
      );
}

/// Feuille « Kg vendus » : total de la période, puis trajet par trajet.
class KgSoldModel {
  final String period;
  final double totalKg;
  final int parcels;
  final List<KgSoldTripModel> trips;

  const KgSoldModel({
    required this.period,
    required this.totalKg,
    required this.parcels,
    required this.trips,
  });

  factory KgSoldModel.fromJson(Map<String, dynamic> json) => KgSoldModel(
    period: json['period'] as String? ?? '',
    totalKg: (json['totalKg'] as num?)?.toDouble() ?? 0,
    parcels: (json['parcels'] as num?)?.toInt() ?? 0,
    trips: [
      for (final trip in (json['trips'] as List<dynamic>? ?? const []))
        KgSoldTripModel.fromJson(trip as Map<String, dynamic>),
    ],
  );
}
