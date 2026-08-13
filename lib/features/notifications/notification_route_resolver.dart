// Résout la route GoRouter correspondant à un type + payload de notification —
// utilisé à la fois par le tap sur push (foreground/background/terminated) et
// par le tap dans la boîte de réception in-app, pour garantir que les deux
// atterrissent toujours au même endroit pour la même notification.
//
// Les IDs sont validés comme UUID avant d'être intégrés à une route, pour
// empêcher tout path traversal via un payload FCM ou un enregistrement
// notification forgé.

final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
bool _isUuid(String? v) => v != null && _uuidRegex.hasMatch(v);

/// Onglets du shell principal — atteints via `context.go` (remplace la pile)
/// plutôt que `context.push` (empile), pour rester cohérent avec la bottom nav.
const notificationShellTabs = {
  '/home',
  '/announcements',
  '/tracking',
  '/messages',
  '/profile',
};

/// `true` si [route] doit être atteinte via `context.go` plutôt que
/// `context.push`, d'après [notificationShellTabs].
bool isShellTabRoute(String route) => notificationShellTabs.contains(route);

String? resolveNotificationRoute(String? type, Map<String, dynamic> data) {
  String? field(String key) => data[key] as String?;

  final bidId = field('bidId');
  final announcementId = field('announcementId');
  final requestId = field('requestId');
  final threadId = field('threadId');
  final cancellationId = field('cancellationId');
  final packageRequestId = field('packageRequestId');
  final conversationId = field('conversationId');

  return switch (type) {
    'BID_CREATED' when _isUuid(announcementId) =>
      '/announcements/$announcementId/bids',

    'BID_ACCEPTED' when _isUuid(bidId) => '/bids/$bidId',
    'DELIVERY_CONFIRMED' when _isUuid(bidId) => '/bids/$bidId',
    'PAYMENT_RELEASED' when _isUuid(bidId) => '/bids/$bidId',
    'DISPUTE_OPENED' when _isUuid(bidId) => '/bids/$bidId',
    'PARCEL_REFUSED' when _isUuid(bidId) => '/bids/$bidId',
    'BID_EXPIRED' when _isUuid(bidId) => '/bids/$bidId',
    'CONFIRMATION_CODE_READY' when _isUuid(bidId) => '/bids/$bidId',
    'DELIVERY_NOSHOW_REPORTED' when _isUuid(bidId) => '/bids/$bidId',
    'MM_PAYMENT_PENDING' when _isUuid(bidId) => '/bids/$bidId',

    // Offre refusée → alternatives rematch si le back en a trouvé
    'BID_REJECTED' when _isUuid(cancellationId) =>
      '/cancellations/$cancellationId/rematch',
    'BID_REJECTED' when _isUuid(bidId) => '/bids/$bidId',

    // Trajet annulé → rematch si dispo, sinon le bid concerné, sinon (pur
    // remboursement, aucun id) l'historique des envois
    'TRIP_CANCELLED' when _isUuid(cancellationId) =>
      '/cancellations/$cancellationId/rematch',
    'TRIP_CANCELLED' when _isUuid(bidId) => '/bids/$bidId',
    'TRIP_CANCELLED' => '/profile/shipments/history',

    // Négociation — les deux parties naviguent vers le thread
    'negotiation_started' when _isUuid(threadId) => '/negotiations/$threadId',
    'negotiation_counter' when _isUuid(threadId) => '/negotiations/$threadId',
    'negotiation_awaiting_trip' when _isUuid(threadId) =>
      '/negotiations/$threadId',
    'negotiation_awaiting_payment' when _isUuid(threadId) =>
      '/negotiations/$threadId',
    'negotiation_expired' when _isUuid(threadId) => '/negotiations/$threadId',
    'negotiation' when _isUuid(threadId) => '/negotiations/$threadId',
    'request_accepted' when _isUuid(threadId) => '/negotiations/$threadId',

    // Demande expirée avant toute négociation → pas de thread, retour à la demande
    'request_expired' when _isUuid(packageRequestId) =>
      '/package-requests/$packageRequestId',

    // Voyageur invité à répondre à une demande → même écran que PACKAGE_MATCH
    'TRAVELER_INVITE' when _isUuid(requestId) =>
      '/package-requests/$requestId/public',

    // Voyageur abonné → détail de l'annonce publiée
    'TRAVELER_NEW_ANNOUNCEMENT' when _isUuid(announcementId) =>
      '/traveler/$announcementId',
    // Expéditeur → détail du trajet qui matche son alerte
    'CORRIDOR_ALERT' when _isUuid(announcementId) =>
      '/traveler/$announcementId',
    // Voyageur → détail du colis qui matche un de ses trajets
    'PACKAGE_MATCH' when _isUuid(requestId) =>
      '/package-requests/$requestId/public',

    // Voyageur → rappel sur son propre trajet en cours
    'TRIP_IN_PROGRESS' when _isUuid(announcementId) =>
      '/announcements/$announcementId/trip',

    // Nouveau message → conversation précise ; repli sur la liste si l'id manque
    'NEW_MESSAGE' when _isUuid(conversationId) =>
      '/conversations/$conversationId',
    'NEW_MESSAGE' => '/messages',

    // Automatisations voyageur — même cible que la notif métier équivalente :
    // une alerte de capacité parle d'un trajet à moi, une offre de dernière
    // minute d'une offre reçue. Sans ces trois lignes, le tap ne menait nulle
    // part et la notification restait un cul-de-sac dans la boîte de réception.
    'automation_capacity_free' when _isUuid(announcementId) =>
      '/announcements/$announcementId/trip',
    'automation_last_minute' when _isUuid(bidId) => '/bids/$bidId',
    // Expéditeur fidèle → détail du trajet publié, comme CORRIDOR_ALERT
    'automation_loyal_sender' when _isUuid(announcementId) =>
      '/traveler/$announcementId',

    'ACCOUNT_SUSPENDED' => '/account/disabled',
    'CARD_EXPIRING' => '/payments/commission-method',

    // PROMO et types inconnus : aucune cible connue, reste sur l'inbox
    _ => null,
  };
}
