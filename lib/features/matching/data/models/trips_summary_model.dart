/// Statistiques d'activité de l'utilisateur sur une période.
///
/// Le backend a d'abord exposé des champs bornés au mois courant
/// (`kgSoldThisMonth`, `revenueThisMonth`), remplacés par `kgSold` / `revenue`
/// une fois le paramètre `period` déployé. Le repli sur les anciens noms est
/// fait au parsing : le reste de l'app ne voit qu'un modèle uniforme.
///
/// [tripsPublished] et [parcelsSent] restent nullables — un backend antérieur
/// ne les renvoie pas du tout, et l'UI doit pouvoir distinguer « pas de
/// donnée » d'un vrai zéro.
class TripsSummaryModel {
  final int activeTrips;
  final double kgSold;
  final double revenue;
  final int? tripsPublished;
  final int? parcelsSent;

  const TripsSummaryModel({
    required this.activeTrips,
    required this.kgSold,
    required this.revenue,
    this.tripsPublished,
    this.parcelsSent,
  });

  factory TripsSummaryModel.fromJson(Map<String, dynamic> json) =>
      TripsSummaryModel(
        activeTrips: (json['activeTrips'] as num?)?.toInt() ?? 0,
        kgSold:
            (json['kgSold'] as num?)?.toDouble() ??
            (json['kgSoldThisMonth'] as num?)?.toDouble() ??
            0,
        revenue:
            (json['revenue'] as num?)?.toDouble() ??
            (json['revenueThisMonth'] as num?)?.toDouble() ??
            0,
        tripsPublished: (json['tripsPublished'] as num?)?.toInt(),
        parcelsSent: (json['parcelsSent'] as num?)?.toInt(),
      );
}
