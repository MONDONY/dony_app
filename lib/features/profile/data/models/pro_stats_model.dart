/// `monthlyRevenue`/`totalRevenue` arrivent CONVERTIS dans [currency] (devise
/// active du voyageur, résolue par le serveur) : quand [isMultiCurrency] est
/// vrai, ce sont des estimations au taux courant — l'affichage doit le dire
/// (« environ »), la réalité par devise étant [totalRevenueByCurrency].
class ProStatsModel {
  final double monthlyRevenue;
  final double totalRevenue;
  final int monthlyTrips;
  final int monthlyParcelsDelivered;
  final double acceptanceRate;
  final double averageRating;
  final List<DestinationStatModel> topDestinations;
  final String? currency;
  final List<CurrencyRevenueModel> monthlyRevenueByCurrency;
  final List<CurrencyRevenueModel> totalRevenueByCurrency;

  const ProStatsModel({
    required this.monthlyRevenue,
    required this.totalRevenue,
    required this.monthlyTrips,
    required this.monthlyParcelsDelivered,
    required this.acceptanceRate,
    required this.averageRating,
    required this.topDestinations,
    this.currency,
    this.monthlyRevenueByCurrency = const [],
    this.totalRevenueByCurrency = const [],
  });

  /// Le total mêle-t-il plusieurs devises encaissées ?
  bool get isMultiCurrency => totalRevenueByCurrency.length > 1;

  factory ProStatsModel.fromJson(Map<String, dynamic> json) {
    List<CurrencyRevenueModel> breakdown(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map(
              (e) => CurrencyRevenueModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
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
      // Champs absents d'un backend pas encore déployé : repli silencieux,
      // l'écran garde alors son comportement d'avant (devise active du cache).
      currency: json['currency'] as String?,
      monthlyRevenueByCurrency: breakdown('monthlyRevenueByCurrency'),
      totalRevenueByCurrency: breakdown('totalRevenueByCurrency'),
    );
  }
}

/// Montant encaissé dans une devise, tel quel — jamais converti.
class CurrencyRevenueModel {
  final String currency;
  final double amount;

  const CurrencyRevenueModel({required this.currency, required this.amount});

  factory CurrencyRevenueModel.fromJson(Map<String, dynamic> json) {
    return CurrencyRevenueModel(
      currency: json['currency'] as String,
      amount: (json['amount'] as num).toDouble(),
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
