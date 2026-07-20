/// Statistiques d'activité du voyageur sur une période.
///
/// Le backend a d'abord exposé des champs bornés au mois courant
/// (`kgSoldThisMonth`, `revenueThisMonth`). Les champs neutres `kgSold` et
/// `revenue` les remplacent une fois le paramètre `period` déployé. Les
/// nouveaux champs sont nullables et les getters [kgSoldForPeriod] /
/// [revenueForPeriod] retombent sur les anciens : l'app affiche les chiffres du
/// mois courant tant que le backend n'est pas à jour, au lieu de zéros.
class TripsSummaryModel {
  final int activeTrips;
  final double kgSoldThisMonth;
  final double revenueThisMonth;

  /// Kg vendus sur la période demandée. `null` si le backend ne la gère pas.
  final double? kgSold;

  /// Revenus nets sur la période demandée. `null` si non fourni.
  final double? revenue;

  /// Trajets publiés sur la période demandée. `null` si non fourni.
  final int? tripsPublished;

  /// Colis envoyés sur la période demandée. `null` si non fourni.
  final int? parcelsSent;

  /// Période effectivement appliquée par le serveur (`7d`, `30d`, `12m`).
  final String? period;

  const TripsSummaryModel({
    required this.activeTrips,
    required this.kgSoldThisMonth,
    required this.revenueThisMonth,
    this.kgSold,
    this.revenue,
    this.tripsPublished,
    this.parcelsSent,
    this.period,
  });

  double get kgSoldForPeriod => kgSold ?? kgSoldThisMonth;

  double get revenueForPeriod => revenue ?? revenueThisMonth;

  /// `true` si le serveur a renvoyé des chiffres réellement bornés à la
  /// période demandée. Sinon l'UI affiche les valeurs du mois courant.
  bool get hasPeriodData => kgSold != null || revenue != null;

  factory TripsSummaryModel.fromJson(Map<String, dynamic> json) =>
      TripsSummaryModel(
        activeTrips: (json['activeTrips'] as num?)?.toInt() ?? 0,
        kgSoldThisMonth: (json['kgSoldThisMonth'] as num?)?.toDouble() ?? 0,
        revenueThisMonth: (json['revenueThisMonth'] as num?)?.toDouble() ?? 0,
        kgSold: (json['kgSold'] as num?)?.toDouble(),
        revenue: (json['revenue'] as num?)?.toDouble(),
        tripsPublished: (json['tripsPublished'] as num?)?.toInt(),
        parcelsSent: (json['parcelsSent'] as num?)?.toInt(),
        period: json['period'] as String?,
      );
}
