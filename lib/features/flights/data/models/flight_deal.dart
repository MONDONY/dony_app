import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:equatable/equatable.dart';

/// Bon plan : l'offre la moins chère d'un trajet et son écart à la médiane des
/// prix observés. Affiché « −[discountPercent] % vs prix habituel », jamais
/// comme une réduction accordée par Yadony.
class FlightDeal extends Equatable {
  const FlightDeal({
    required this.offer,
    required this.medianPrice,
    required this.discountPercent,
  });

  factory FlightDeal.fromJson(Map<String, dynamic> json) => FlightDeal(
    offer: FlightOffer.fromJson(json['offer'] as Map<String, dynamic>),
    medianPrice: (json['medianPrice'] as num?)?.toDouble() ?? 0,
    discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
  );

  final FlightOffer offer;
  final double medianPrice;
  final int discountPercent;

  @override
  List<Object?> get props => [offer, medianPrice, discountPercent];
}

/// Réponse de `GET /flights/deals`.
class FlightDeals extends Equatable {
  const FlightDeals({
    required this.currency,
    required this.personalized,
    required this.deals,
  });

  factory FlightDeals.fromJson(Map<String, dynamic> json) => FlightDeals(
    currency: json['currency'] as String? ?? 'EUR',
    personalized: json['personalized'] as bool? ?? false,
    deals: (json['deals'] as List<dynamic>? ?? const [])
        .map((e) => FlightDeal.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String currency;

  /// `true` : trajets tirés des corridors de l'utilisateur ; `false` : liste
  /// des axes de la diaspora par défaut.
  final bool personalized;
  final List<FlightDeal> deals;

  @override
  List<Object?> get props => [currency, personalized, deals];
}
