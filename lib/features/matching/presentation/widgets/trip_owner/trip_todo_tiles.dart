import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';

/// Gestes qui attendent le voyageur sur l'écran de son trajet, dans la
/// section « À traiter » : les demandes à traiter (carte de réponse directe)
/// puis une ligne par autre geste ([TripTodoRow], chacune ouvrant son sheet
/// `openTripTodoSheet`).
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
/// unique de la tuile « À traiter » [TripTodoTile.requests] (carte de
/// réponse directe) et du sheet des demandes (`tripActivityShown`), absents
/// tous deux d'un trajet terminé.
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

/// Les demandes du trajet ont-elles leur place sur l'écran (sheet des
/// demandes, ouvert par « Voir les N demandes ») ? Toujours pour un trajet publié ou complet, même sans
/// demande (PROD-1N : une entrée absente ou éteinte laissait croire à une
/// panne) ; pour un trajet parti, seulement s'il reste des demandes à
/// traiter ([tripPendingRequestCount] de [bids]) : le back les expire au
/// départ et refuse tout nouveau colis. Jamais pour un trajet terminé (le
/// back y refuse toute acceptation), un brouillon, un trajet annulé, retiré
/// par l'équipe ou d'un statut inconnu.
bool tripRequestsShown(AnnouncementModel trip, List<BidModel>? bids) =>
    switch (tripRequestsPhaseFor(trip.status)) {
      TripRequestsPhase.open || TripRequestsPhase.full => true,
      TripRequestsPhase.departed => tripPendingRequestCount(trip, bids) > 0,
      TripRequestsPhase.ended || null => false,
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

/// Le suivi du trajet a-t-il un sens pour son statut [status] (« Je pars »,
/// consentement au suivi proposé à l'ouverture de l'écran) ? Oui pour un
/// trajet publié, complet ou en cours ; jamais pour un brouillon, un trajet
/// annulé, terminé, retiré par l'équipe ou d'un statut inconnu de l'app.
bool tripTrackingStatusOpen(String status) => _departStatuses.contains(status);

/// Statuts où la carte peut encore être ajoutée au trajet : sur un trajet
/// terminé ou annulé, l'encart « espèces seules » n'a plus d'objet.
const _cardStatuses = {'DRAFT', 'ACTIVE', 'FULL'};

/// Colis « en vol » qui verrouillent la modification du trajet, même
/// ensemble que le back (`BidStatus.IN_FLIGHT` : `ACCEPTED` et `EN_ROUTE`).
/// `AnnouncementService.updateAnnouncement` répond 409
/// `modification-impossible` dès qu'un colis du trajet est dans l'un d'eux,
/// quel que soit le statut du trajet. Une demande en attente (`PENDING`,
/// `PAYMENT_ESCROWED`), un paiement attendu (`AWAITING_PAYMENT`), un colis
/// livré ou clôturé ne bloquent rien.
const _editLockingBidStatuses = {
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
};

/// Le back accepterait-il une modification de [trip] ? Non dès qu'un colis
/// est en vol ([_editLockingBidStatuses]), et l'app répond non dès qu'une de
/// ses sources en montre un : les colis chargés par l'écran ([bids], `null`
/// tant que la liste n'a pas répondu) et les compteurs du détail.
/// `confirmedParcelCount` compte `ACCEPTED`, `HANDED_OVER`, `IN_TRANSIT` et
/// `COMPLETED`, `parcelsSummary` les colis `HANDED_OVER`, `IN_TRANSIT` et
/// `ARRIVED` : à eux deux ils couvrent tout colis en vol, liste chargée ou
/// non. Un colis livré compté par `confirmedParcelCount` ne bloque pas le
/// back, mais un trajet qui en a un est déjà parti (statut hors des tuiles
/// qui s'en servent).
bool tripEditAcceptedByBack(AnnouncementModel trip, List<BidModel>? bids) =>
    !(bids?.any((b) => _editLockingBidStatuses.contains(b.status)) ?? false) &&
    trip.confirmedParcelCount == 0 &&
    trip.parcelsSummary == null;

/// Nombre de demandes à traiter du trajet : les colis chargés par l'écran
/// quand la liste a répondu ([bids] non nul), sinon le compteur servi par
/// `GET /announcements/my` (`pendingBidCount`).
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

/// Tuiles « À traiter » de [trip], dans l'ordre de la section. Fonction pure :
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
/// `trackingActive`), limitée aux statuts ACTIVE, FULL et IN_PROGRESS
/// ([tripTrackingStatusOpen]). Un back antérieur au champ `trackingActive`
/// du détail le sert à `false` : la tuile n'apparaît pas, rien ne casse.
///
/// « carte » (ajouter la carte au trajet, ou activer les paiements par
/// carte pour l'y ajouter ensuite) passe par l'édition du trajet : la tuile
/// n'existe que si le back accepterait cette modification. Règle exacte :
/// - statut DRAFT, ACTIVE ou FULL (sur un trajet parti, terminé ou annulé,
///   l'encart « espèces seules » n'a plus d'objet) ;
/// - trajet en espèces seules dans une devise qui permet la carte, et
///   paiement par carte ouvert dans le pays du voyageur ;
/// - aucun colis en vol ([tripEditAcceptedByBack] : `ACCEPTED`,
///   `HANDED_OVER`, `IN_TRANSIT`, `ARRIVED`), sans quoi
///   `AnnouncementService.updateAnnouncement` refuse la modification (409
///   `modification-impossible`). Des demandes en attente seules ne bloquent
///   pas. Un trajet complet a presque toujours un colis accepté : la tuile
///   n'y apparaît alors pas.
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
    if (tripTrackingStatusOpen(trip.status) &&
        summary != null &&
        summary.count > 0 &&
        trip.trackingActive &&
        !departed)
      TripTodoTile.depart,
    if (_cardStatuses.contains(trip.status) &&
        _cashOnlyWithCardPossible(trip) &&
        stripe.connectAvailableInCountry &&
        tripEditAcceptedByBack(trip, bids))
      TripTodoTile.card,
  ];
}

/// Lignes « À traiter » rendues sous la carte de réponse directe
/// (`TripTodoRows`), chacune ouvrant son sheet (`openTripTodoSheet`) : les
/// tuiles [tile] autres que [TripTodoTile.requests], que porte la carte de
/// réponse directe (`TripDirectRequestCard`) et le sheet d'activité des
/// demandes.
///
/// Le nom est celui de la tuile : valeur `tile` des mesures et nom du sheet
/// (`trip-owner/todo-<nom>`), à ne pas renommer sans migrer PostHog.
enum TripTodoRow {
  /// « Je pars » ([TripTodoTile.depart]).
  depart(TripTodoTile.depart),

  /// Ajouter la carte au trajet ([TripTodoTile.card]).
  card(TripTodoTile.card);

  const TripTodoRow(this.tile);

  /// Tuile « À traiter » dont la ligne vient.
  final TripTodoTile tile;
}

/// Lignes de [tiles] ([tripTodoTilesFor]), dans l'ordre de la section.
List<TripTodoRow> tripTodoRowsOf(List<TripTodoTile> tiles) => [
  for (final row in TripTodoRow.values)
    if (tiles.contains(row.tile)) row,
];

/// Icône de la ligne (`assets/icons/<nom>.svg`).
String tripTodoIcon(TripTodoRow row) => switch (row) {
  TripTodoRow.depart => 'plane',
  TripTodoRow.card => 'credit-card',
};

/// Titre de la ligne et de son sheet. [cardReady] : compte de paiement prêt
/// ([tripCardPaymentsReady]), qui change le geste de la ligne
/// [TripTodoRow.card].
String tripTodoTitle(
  AppLocalizations l,
  TripTodoRow row, {
  required bool cardReady,
}) => switch (row) {
  TripTodoRow.depart => l.tripDepartButton,
  TripTodoRow.card =>
    cardReady
        ? l.listingEnableCardOnTripButton
        : l.listingActivateCardPaymentsButton,
};

/// Résumé de la ligne : ce qui est attendu, en une ou deux lignes.
String tripTodoSummary(
  AppLocalizations l,
  TripTodoRow row, {
  required bool cardReady,
}) => switch (row) {
  TripTodoRow.depart => l.tripTodoDepartSummary,
  TripTodoRow.card =>
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
