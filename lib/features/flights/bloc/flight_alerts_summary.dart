import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:equatable/equatable.dart';

/// État de la ligne « Alertes prix vols » des Outils d'Activités, et valeur
/// de la propriété `state` de `activites_hub_flight_alerts_opened`.
enum FlightAlertsSummaryKind {
  /// Au moins une alerte active a trouvé un prix sous son seuil.
  hit('hit'),

  /// Des alertes existent, aucune n'a trouvé.
  noHit('no_hit'),

  /// Aucune alerte.
  empty('empty');

  const FlightAlertsSummaryKind(this.analyticsValue);

  final String analyticsValue;
}

/// Résumé des alertes prix pour la ligne des Outils : quel billet afficher
/// (vert, gris ou « Créer ») et quoi écrire dessous.
///
/// Les prix ne se comparent que dans une même devise : quand les alertes en
/// mélangent plusieurs, la devise retenue est celle de l'alerte la plus
/// récente concernée (la liste du back est triée de la plus récente à la
/// plus ancienne).
class FlightAlertsSummary extends Equatable {
  const FlightAlertsSummary._({
    required this.kind,
    this.hitCount = 0,
    this.activeCount = 0,
    this.best,
    this.price,
    this.currency,
  });

  factory FlightAlertsSummary.of(List<FlightAlert> alerts) {
    if (alerts.isEmpty) {
      return const FlightAlertsSummary._(kind: FlightAlertsSummaryKind.empty);
    }
    final active = alerts.where((a) => a.active).toList();
    // Une alerte en pause n'est plus vérifiée : son dernier résultat est
    // périmé, il ne compte pas comme un prix trouvé.
    final hits = active.where((a) => a.hasHit).toList();
    if (hits.isNotEmpty) {
      final best = _cheapest(hits) ?? hits.first;
      return FlightAlertsSummary._(
        kind: FlightAlertsSummaryKind.hit,
        hitCount: hits.length,
        activeCount: active.length,
        best: best,
        price: best.lastSeenPrice,
        currency: best.currency,
      );
    }
    // Un dernier prix périmé (sous le seuil alors que plus rien n'est
    // trouvé) n'est pas un « meilleur prix vu ».
    final lowest = _cheapest(
      active.where((a) => a.currentPrice != null).toList(),
    );
    return FlightAlertsSummary._(
      kind: FlightAlertsSummaryKind.noHit,
      activeCount: active.length,
      best: lowest,
      price: lowest?.lastSeenPrice,
      currency: lowest?.currency,
    );
  }

  /// Alerte au plus bas `lastSeenPrice`, parmi celles de la devise de la
  /// première alerte qui a un prix ; `null` si aucune n'a de prix connu.
  static FlightAlert? _cheapest(List<FlightAlert> alerts) {
    final priced = alerts.where((a) => a.lastSeenPrice != null).toList();
    if (priced.isEmpty) return null;
    final currency = priced.first.currency;
    final same = priced.where((a) => a.currency == currency).toList()
      ..sort((a, b) => a.lastSeenPrice!.compareTo(b.lastSeenPrice!));
    return same.first;
  }

  final FlightAlertsSummaryKind kind;

  /// Alertes actives qui ont trouvé un prix sous leur seuil.
  final int hitCount;
  final int activeCount;

  /// Alerte du billet : la moins chère de celles qui ont trouvé, sinon la
  /// moins chère des alertes actives.
  final FlightAlert? best;

  /// Prix porté par le billet, `null` = pas de billet de prix.
  final double? price;
  final String? currency;

  /// Écart avec le seuil de l'alerte du billet (positif = sous le seuil).
  double? get savings {
    final p = price;
    final b = best;
    if (p == null || b == null) return null;
    return b.maxPrice - p;
  }

  @override
  List<Object?> get props => [
    kind,
    hitCount,
    activeCount,
    best,
    price,
    currency,
  ];
}
