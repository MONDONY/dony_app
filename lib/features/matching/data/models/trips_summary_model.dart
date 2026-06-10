class TripsSummaryModel {
  final int activeTrips;
  final double kgSoldThisMonth;
  final double revenueThisMonth;

  const TripsSummaryModel({
    required this.activeTrips,
    required this.kgSoldThisMonth,
    required this.revenueThisMonth,
  });

  factory TripsSummaryModel.fromJson(Map<String, dynamic> json) =>
      TripsSummaryModel(
        activeTrips: (json['activeTrips'] as num?)?.toInt() ?? 0,
        kgSoldThisMonth: (json['kgSoldThisMonth'] as num?)?.toDouble() ?? 0,
        revenueThisMonth: (json['revenueThisMonth'] as num?)?.toDouble() ?? 0,
      );
}
