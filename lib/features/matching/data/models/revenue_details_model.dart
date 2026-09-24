/// Rail d'une ligne de revenu, tel que le backend le nomme
/// (`CARD`, `MOBILE_MONEY`, `CASH`). Une valeur inconnue ne casse jamais le
/// parsing : un rail ajouté côté serveur s'affiche « Paiement » en attendant.
enum RevenueRail {
  card,
  mobileMoney,
  cash,
  unknown;

  static RevenueRail fromApi(String? value) => switch (value) {
    'CARD' => card,
    'MOBILE_MONEY' => mobileMoney,
    'CASH' => cash,
    _ => unknown,
  };
}

/// Une livraison payée, dans la devise de son groupe. [date] est la date de
/// départ du trajet, ou celle du paiement quand aucun trajet n'est lié.
class RevenueItemModel {
  final String? tripId;
  final String departureCity;
  final String arrivalCity;
  final DateTime date;
  final double? weightKg;
  final RevenueRail rail;
  final double amount;

  const RevenueItemModel({
    this.tripId,
    required this.departureCity,
    required this.arrivalCity,
    required this.date,
    this.weightKg,
    required this.rail,
    required this.amount,
  });

  factory RevenueItemModel.fromJson(Map<String, dynamic> json) =>
      RevenueItemModel(
        tripId: json['tripId'] as String?,
        departureCity: json['departureCity'] as String? ?? '',
        arrivalCity: json['arrivalCity'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        rail: RevenueRail.fromApi(json['rail'] as String?),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );
}

/// Les livraisons d'une devise et leur sous-total, dans cette devise.
class RevenueGroupModel {
  final String currency;
  final double total;
  final int deliveries;
  final List<RevenueItemModel> items;

  const RevenueGroupModel({
    required this.currency,
    required this.total,
    required this.deliveries,
    required this.items,
  });

  factory RevenueGroupModel.fromJson(Map<String, dynamic> json) =>
      RevenueGroupModel(
        currency: json['currency'] as String? ?? 'EUR',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        deliveries: (json['deliveries'] as num?)?.toInt() ?? 0,
        items: [
          for (final item in (json['items'] as List<dynamic>? ?? const []))
            RevenueItemModel.fromJson(item as Map<String, dynamic>),
        ],
      );
}

/// Feuille « Revenus » : chaque livraison dans la devise de son paiement,
/// regroupée par devise. Aucune conversion ici, c'est tout l'objet.
class RevenueDetailsModel {
  final String period;
  final int deliveries;
  final List<RevenueGroupModel> groups;

  const RevenueDetailsModel({
    required this.period,
    required this.deliveries,
    required this.groups,
  });

  factory RevenueDetailsModel.fromJson(Map<String, dynamic> json) =>
      RevenueDetailsModel(
        period: json['period'] as String? ?? '',
        deliveries: (json['deliveries'] as num?)?.toInt() ?? 0,
        groups: [
          for (final group in (json['groups'] as List<dynamic>? ?? const []))
            RevenueGroupModel.fromJson(group as Map<String, dynamic>),
        ],
      );
}
