class ProStatsModel {
  final double monthlyRevenue;
  final double totalRevenue;
  final int monthlyTrips;
  final int monthlyParcelsDelivered;
  final double acceptanceRate;
  final double averageRating;
  final List<DestinationStatModel> topDestinations;

  const ProStatsModel({
    required this.monthlyRevenue,
    required this.totalRevenue,
    required this.monthlyTrips,
    required this.monthlyParcelsDelivered,
    required this.acceptanceRate,
    required this.averageRating,
    required this.topDestinations,
  });

  factory ProStatsModel.fromJson(Map<String, dynamic> json) {
    return ProStatsModel(
      monthlyRevenue: (json['monthlyRevenue'] as num).toDouble(),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      monthlyTrips: (json['monthlyTrips'] as num).toInt(),
      monthlyParcelsDelivered: (json['monthlyParcelsDelivered'] as num).toInt(),
      acceptanceRate: (json['acceptanceRate'] as num).toDouble(),
      averageRating: (json['averageRating'] as num).toDouble(),
      topDestinations: (json['topDestinations'] as List<dynamic>)
          .map((e) => DestinationStatModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DestinationStatModel {
  final String from;
  final String to;
  final int count;

  const DestinationStatModel({
    required this.from,
    required this.to,
    required this.count,
  });

  factory DestinationStatModel.fromJson(Map<String, dynamic> json) {
    return DestinationStatModel(
      from: json['from'] as String,
      to: json['to'] as String,
      count: (json['count'] as num).toInt(),
    );
  }
}
