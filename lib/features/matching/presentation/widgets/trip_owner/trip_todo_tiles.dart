import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';

/// Gestes qui attendent le voyageur sur l'écran de son trajet et prennent la
/// forme d'une tuile dans la section « À traiter ». Chaque tuile ouvre un
/// bottom sheet (`openTripTodoSheet`).
///
/// Le nom sert de valeur `tile` aux mesures (`bid_detail_tile_opened`,
/// `bid_detail_todo_tile_shown`, `role: trip_owner`) : ne pas le renommer
/// sans migrer PostHog.
enum TripTodoTile {
  /// Au moins une demande en attente de réponse (`PENDING` ou
  /// `PAYMENT_ESCROWED`, [isPendingBid]) sur un trajet encore ouvert.
  requests,

  /// « Je pars » : des colis sont remis, la fenêtre de suivi est ouverte et
  /// le départ n'a pas encore été confirmé depuis cet appareil.
  depart,

  /// Trajet en espèces seules alors que la carte est possible : ajouter la
  /// carte à ce trajet (compte de paiement prêt, FLUTTER-DH) ou activer les
  /// paiements par carte.
  card,
}

/// Place des demandes des expéditeurs selon le statut du trajet. Source
/// unique de la tuile « À traiter » [TripTodoTile.requests] et de la carte
/// « Demandes » du corps (`TripRequestsCard`).
enum TripRequestsPhase {
  /// ACTIVE : le trajet reçoit des demandes.
  open,

  /// FULL : plus de nouvelle demande ; celles déjà reçues se traitent
  /// encore.
  full,

  /// IN_PROGRESS : le trajet est parti. Le back expire les demandes en
  /// attente au départ et refuse tout nouveau colis : il n'en reste qu'en
  /// cas de retard de cette expiration, et elles se traitent encore.
  departed,

  /// COMPLETED : terminé, le back n'accepte plus aucune demande.
  ended,
}

/// [TripRequestsPhase] du statut [status] ; `null` pour un brouillon (pas
/// encore visible des expéditeurs), un trajet annulé, retiré par l'équipe ou
/// un statut inconnu de l'app : aucune demande à y montrer.
TripRequestsPhase? tripRequestsPhaseFor(String status) => switch (status) {
  'ACTIVE' => TripRequestsPhase.open,
  'FULL' => TripRequestsPhase.full,
  'IN_PROGRESS' => TripRequestsPhase.departed,
  'COMPLETED' => TripRequestsPhase.ended,
  _ => null,
};

/// Une demande en attente peut-elle encore recevoir une réponse ? Oui tant
/// que le trajet n'est pas terminé, annulé ou retiré (le back refuse alors
/// toute acceptation).
bool _requestsAnswerable(String status) =>
    switch (tripRequestsPhaseFor(status)) {
      TripRequestsPhase.open ||
      TripRequestsPhase.full ||
      TripRequestsPhase.departed => true,
      TripRequestsPhase.ended || null => false,
    };

/// Statuts où « Je pars » a un sens : trajet publié, complet ou en cours.
/// Jamais sur un trajet annulé (ses colis remis suivent la procédure de
/// retour), terminé, brouillon ou retiré, même si le back sert la fenêtre de
/// suivi ouverte (`trackingActive` ne dépend pas du statut).
const _departStatuses = {'ACTIVE', 'FULL', 'IN_PROGRESS'};

/// Statuts où la carte peut encore être ajoutée au trajet : sur un trajet
/// terminé ou annulé, l'encart « espèces seules » n'a plus d'objet.
const _cardStatuses = {'DRAFT', 'ACTIVE', 'FULL'};

/// Nombre de demandes à traiter du trajet : les colis chargés par l'écran
/// quand la liste a répondu ([bids] non nul), sinon le compteur servi par
/// `GET /announcements/my` (`pendingBidCount`), comme la grille d'actions.
int tripPendingRequestCount(AnnouncementModel trip, List<BidModel>? bids) =>
    bids != null ? bids.where(isPendingBid).length : trip.pendingBidCount;

/// Le nombre de demandes à traiter est-il connu ? Oui quand la liste des
/// colis a répondu, ou quand le compteur servi par `GET /announcements/my`
/// en annonce. Sinon (liste en chargement, en erreur ou jamais chargée,
/// trajet ouvert sans la liste des trajets : le détail ne sert pas
/// `pendingBidCount`, qui vaut alors 0), un 0 ne prouve rien : ne jamais
/// affirmer « aucune demande ».
bool tripPendingRequestCountKnown(
  AnnouncementModel trip,
  List<BidModel>? bids,
) => bids != null || trip.pendingBidCount > 0;

/// Le compte de paiement par carte du voyageur est-il prêt (inscription
/// Stripe Connect terminée) ? Tant que le statut n'est pas chargé : non.
bool tripCardPaymentsReady(StripeAccountState stripe) =>
    stripe is StripeAccountReady && stripe.accountStatus.isComplete;

/// Trajet en espèces seules dont la devise permet la carte : même condition
/// que l'encart « espèces seules » du corps du trajet.
bool _cashOnlyWithCardPossible(AnnouncementModel trip) =>
    trip.acceptedPaymentMethods.length == 1 &&
    trip.acceptedPaymentMethods.contains(BidPaymentMethod.cash) &&
    SupportedCurrency.fromCodeOrDefault(trip.currency).isStripeEligible;

/// Tuiles « À traiter » de [trip], dans l'ordre de la grille. Fonction pure :
/// l'écran la rappelle à chaque rechargement, et le sheet ouvert s'en sert
/// pour se fermer quand sa tuile n'a plus lieu d'être.
///
/// - [bids] : colis du trajet chargés par l'écran (`BidListLoaded`), `null`
///   tant que la liste n'a pas répondu ([tripPendingRequestCount]).
/// - [isOwner] : la personne connectée est le voyageur du trajet ; sinon
///   aucune tuile.
/// - [departed] : « Je pars » déjà confirmé depuis cet appareil (drapeau
///   Hive lu par `TripDepartCubit`).
/// - [stripe] : statut du compte de paiement par carte (`StripeAccountBloc`).
///
/// « Je pars » reprend la règle de l'ancien bouton de l'écran (colis remis
/// servis par le détail, `parcelsSummary`, et fenêtre de suivi ouverte,
/// `trackingActive`), limitée aux statuts ACTIVE, FULL et IN_PROGRESS. Le
/// détail ne sert pas encore `trackingActive` (piège n°1 de l'inventaire) :
/// la tuile apparaîtra quand le back le fera.
List<TripTodoTile> tripTodoTilesFor({
  required AnnouncementModel trip,
  required List<BidModel>? bids,
  required bool isOwner,
  required bool departed,
  required StripeAccountState stripe,
}) {
  if (!isOwner) return const [];
  final summary = trip.parcelsSummary;
  return [
    if (_requestsAnswerable(trip.status) &&
        tripPendingRequestCount(trip, bids) > 0)
      TripTodoTile.requests,
    if (_departStatuses.contains(trip.status) &&
        summary != null &&
        summary.count > 0 &&
        trip.trackingActive &&
        !departed)
      TripTodoTile.depart,
    if (_cardStatuses.contains(trip.status) &&
        _cashOnlyWithCardPossible(trip) &&
        stripe.connectAvailableInCountry)
      TripTodoTile.card,
  ];
}

/// Icône de la tuile (`assets/icons/<nom>.svg`).
String tripTodoIcon(TripTodoTile tile) => switch (tile) {
  TripTodoTile.requests => 'package',
  TripTodoTile.depart => 'plane',
  TripTodoTile.card => 'credit-card',
};

/// Titre de la tuile et de son sheet. [cardReady] : compte de paiement prêt
/// ([tripCardPaymentsReady]), qui change le geste de la tuile [TripTodoTile.card].
String tripTodoTitle(
  AppLocalizations l,
  TripTodoTile tile, {
  required bool cardReady,
}) => switch (tile) {
  TripTodoTile.requests => l.tripTodoRequestsTitle,
  TripTodoTile.depart => l.tripDepartButton,
  TripTodoTile.card =>
    cardReady
        ? l.listingEnableCardOnTripButton
        : l.listingActivateCardPaymentsButton,
};

/// Résumé de la tuile : ce qui est attendu, en une ou deux lignes.
/// [pendingCount] : [tripPendingRequestCount].
String tripTodoSummary(
  AppLocalizations l,
  TripTodoTile tile, {
  required int pendingCount,
  required bool cardReady,
}) => switch (tile) {
  TripTodoTile.requests => l.tripTodoRequestsSummary(pendingCount),
  TripTodoTile.depart => l.tripTodoDepartSummary,
  TripTodoTile.card =>
    cardReady ? l.tripTodoCardReadySummary : l.tripTodoCardActivateSummary,
};

/// Mesure d'affichage de la tuile [tile] de [trip]
/// (`bid_detail_todo_tile_shown`, `role: trip_owner`), à émettre par
/// `TodoTileViewLog.logAll` avec l'identifiant du trajet. Dédoublonnée par
/// le statut du trajet, et pour la tuile [TripTodoTile.requests] seulement
/// par le nombre de demandes à traiter : une nouvelle demande remesure cette
/// tuile, jamais « Je pars » ni « carte » ; un simple rechargement ne
/// remesure rien.
TodoTileShown tripTodoShown(
  TripTodoTile tile,
  AnnouncementModel trip, {
  required int pendingCount,
}) => TodoTileShown(
  AnalyticsEvents.bidDetailTodoTileShown,
  tile: tile.name,
  properties: () => {
    'tile': tile.name,
    'role': 'trip_owner',
    'status': trip.status,
  },
  status: tile == TripTodoTile.requests
      ? '${trip.status}|$pendingCount'
      : trip.status,
);
