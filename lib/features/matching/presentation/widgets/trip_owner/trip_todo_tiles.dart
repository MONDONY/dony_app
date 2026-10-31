import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';

/// Gestes du trajet calculés ici et repris par « À traiter »
/// (`tripTodoFor`, types `depart` et `addCard`).
enum TripTodoTile {
  /// « Je pars » : des colis sont remis, la fenêtre de suivi est ouverte et
  /// le départ n'a pas encore été confirmé depuis cet appareil.
  depart,

  /// Trajet en espèces seules alors que la carte est possible : ajouter la
  /// carte à ce trajet (compte de paiement prêt, FLUTTER-DH) ou activer les
  /// paiements par carte.
  card,
}

/// Place des demandes des expéditeurs selon le statut du trajet. Source
/// unique de l'action « À traiter » des demandes (`tripTodoFor`, carte de
/// réponse directe) et du sheet des demandes (`tripActivityShown`), absents
/// tous deux d'un trajet terminé.
enum TripRequestsPhase {
  /// ACTIVE : le trajet reçoit des demandes.
  open,

  /// FULL : plus de nouvelle demande ; celles déjà reçues se traitent
  /// encore.
  full,

  /// IN_PROGRESS : le trajet est parti. Le back expire les demandes en
  /// attente au départ et refuse toute acceptation (`BidService`) : il n'en
  /// reste qu'en cas de retard de cette expiration, et elles ne sont plus une
  /// action « À traiter » (`tripTodoFor`) ; le sheet des demandes les montre
  /// encore ([tripRequestsShown]).
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

/// Gestes « Je pars » et « carte » de [trip] ([TripTodoTile]), repris par
/// « À traiter » (`tripTodoFor`). Fonction pure.
///
/// - [bids] : colis du trajet chargés par l'écran (`BidListLoaded`), `null`
///   tant que la liste n'a pas répondu.
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
