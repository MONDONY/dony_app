/// Ce qu'une push reçue application ouverte doit faire recharger.
///
/// Toutes les pushs rechargeaient le fil de notifications et les deux listes
/// de l'onglet Activités, y compris un simple message de chat, qui n'ajoute
/// rien au fil (push seule côté serveur, la messagerie a son propre compteur).
class ForegroundPushRefresh {
  const ForegroundPushRefresh({
    required this.notificationFeed,
    required this.activityIndicators,
  });

  /// Le fil et le compteur de la cloche (`NotificationsLoadRequested`).
  final bool notificationFeed;

  /// Demandes reçues et négociations actives de l'onglet Activités.
  final bool activityIndicators;

  /// [type] est le champ `type` des données de la push, `null` s'il manque :
  /// on recharge alors tout, faute de savoir.
  factory ForegroundPushRefresh.forType(String? type) => switch (type) {
    'NEW_MESSAGE' => const ForegroundPushRefresh(
      notificationFeed: false,
      activityIndicators: false,
    ),
    'SUPPORT_MESSAGE' => const ForegroundPushRefresh(
      notificationFeed: true,
      activityIndicators: false,
    ),
    _ => const ForegroundPushRefresh(
      notificationFeed: true,
      activityIndicators: true,
    ),
  };
}
