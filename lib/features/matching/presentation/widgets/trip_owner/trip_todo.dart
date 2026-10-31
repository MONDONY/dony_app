import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_transport_section.dart';
import 'package:dony/features/matching/presentation/widgets/rating_pending_pill.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';

// « À traiter » complet de l'écran du trajet vu par son voyageur (phase 1,
// app seule) : tout ce qui se calcule depuis le trajet (`AnnouncementModel`)
// et ses colis (`BidModel`) déjà chargés par l'écran. Chaque règle reprend
// celle de la fiche colis ou du pied de l'écran, sans la réécrire.

/// Urgence d'une action « À traiter » (décision du 31/10) : la file montre
/// les urgentes d'abord.
enum TripTodoUrgency {
  /// Argent, pénalité ou expiration automatique proche.
  urgent,

  /// Geste attendu, sans perte immédiate.
  important,
}

/// Types d'action « À traiter » de l'écran du trajet, dans l'ordre fixe de la
/// file (à urgence et échéance égales).
///
/// Le nom sert de valeur `tile` à `bid_detail_todo_tile_shown` (`role:
/// trip_owner`, [tripTodoItemShown]) : ne pas le renommer sans migrer
/// PostHog.
enum TripTodoKind {
  /// Demandes à accepter ou refuser (#1).
  requests(TripTodoUrgency.urgent, perParcel: false),

  /// Confirmer sa présence au dépôt (#7).
  presence(TripTodoUrgency.urgent, perParcel: true),

  /// Récupérer le colis : scan de départ (#8).
  scan(TripTodoUrgency.urgent, perParcel: true),

  /// Modification proposée, ou sa commission à finaliser (#11, #12).
  amendment(TripTodoUrgency.urgent, perParcel: true),

  /// Frais de service d'un supplément à valider (#10).
  supplement(TripTodoUrgency.urgent, perParcel: true),

  /// Signaler l'absence de l'expéditeur (#16).
  senderAbsence(TripTodoUrgency.urgent, perParcel: true),

  /// Rendre un colis après annulation (#28).
  returnParcel(TripTodoUrgency.urgent, perParcel: true),

  /// « Je pars » (#37).
  depart(TripTodoUrgency.important, perParcel: false),

  /// « Arrivé à destination » (#38).
  arrive(TripTodoUrgency.important, perParcel: false),

  /// Valider la remise au destinataire (#25).
  deliver(TripTodoUrgency.important, perParcel: true),

  /// Prévenir les destinataires (#24).
  notify(TripTodoUrgency.important, perParcel: false),

  /// Destinataire refusé : en demander un autre (#21).
  recipientDeclined(TripTodoUrgency.important, perParcel: true),

  /// Renseigner les instructions de retrait (#39).
  instructions(TripTodoUrgency.important, perParcel: false),

  /// Noter l'expéditeur (#30).
  rate(TripTodoUrgency.important, perParcel: true),

  /// Publier le brouillon (#32).
  publish(TripTodoUrgency.important, perParcel: false),

  /// Ajouter la carte au trajet, ou activer les paiements par carte (#34).
  addCard(TripTodoUrgency.important, perParcel: false);

  const TripTodoKind(this.urgency, {required this.perParcel});

  final TripTodoUrgency urgency;

  /// Action sur des colis (un sheet qui liste les colis concernés, ouvrant
  /// chacun sa fiche) plutôt qu'un geste du trajet. Seules ces actions
  /// marquent la ligne Colis ([tripTodoParcelIds]).
  final bool perParcel;
}

/// Une action « À traiter » de l'écran du trajet : un type, et pour une
/// action sur des colis, les colis concernés.
class TripTodoItem {
  const TripTodoItem({
    required this.kind,
    required this.count,
    this.bidIds = const [],
    this.dueAt,
    this.dueAtByBid = const {},
  });

  final TripTodoKind kind;

  /// Actions comptées dans la pastille « À traiter · N » : une par demande
  /// ou par colis concerné, une pour un geste du trajet.
  final int count;

  /// Colis concernés, échéance la plus proche d'abord (sans échéance à la
  /// fin, dans l'ordre de la liste). Les demandes pour [TripTodoKind.requests],
  /// les colis à prévenir pour [TripTodoKind.notify] ; vide pour les autres
  /// gestes du trajet.
  final List<String> bidIds;

  /// Échéance la plus proche quand le modèle la porte, sinon `null`.
  final DateTime? dueAt;

  /// Échéance de chaque colis de [bidIds] qui en a une.
  final Map<String, DateTime> dueAtByBid;

  TripTodoUrgency get urgency => kind.urgency;
}

/// Horloge de « À traiter » sur l'écran du trajet (section, pied, ligne
/// Colis, sheets) : `DateTime.now` en production ; seuls les tests la
/// remplacent (et la remettent dans leur `tearDown`).
DateTime Function() tripTodoNow = DateTime.now;

/// D'où s'ouvre le geste d'une action « À traiter » de l'écran du trajet :
/// valeur `source` de `bid_detail_tile_opened` (son `name`). Ne pas renommer
/// sans migrer PostHog.
enum TripTodoSource {
  /// Bouton de la grosse carte « Prochaine action » (ou lien « Voir les N
  /// demandes » de la carte de réponse directe).
  card,

  /// Ligne de la file sous la grosse carte, ou du sheet « toute la liste ».
  list,

  /// Bouton principal du pied collant, qui suit l'action la plus urgente.
  footer,
}

/// Délai entre la date limite de dépôt et la déclaration automatique du
/// voyageur absent (back `NoShowScheduler`, date limite + 1 h) : échéance de
/// la récupération et du signalement de l'absence de l'expéditeur.
const tripTravelerNoShowGrace = Duration(hours: 1);

/// Le back accepte-t-il encore une demande sur [trip] à [now] ? Trajet
/// publié ou complet (sur IN_PROGRESS il refuse toute acceptation,
/// `BidService`), et date limite de dépôt du trajet pas encore atteinte
/// (`HandoverDeadlineRules` : les demandes y expirent, l'acceptation est
/// refusée).
bool _requestsAcceptable(AnnouncementModel trip, DateTime now) {
  final phase = tripRequestsPhaseFor(trip.status);
  if (phase != TripRequestsPhase.open && phase != TripRequestsPhase.full) {
    return false;
  }
  final deadline = trip.handoverDeadline;
  return deadline == null || now.isBefore(deadline);
}

/// Une demande à traiter par le voyageur ([isPendingBid]), hors carte pas
/// encore payée par l'expéditeur ([BidModel.isAwaitingSenderCardPayment] :
/// « Accepter » répondrait 409).
bool _isAnswerableRequest(BidModel bid) =>
    isPendingBid(bid) && !bid.isAwaitingSenderCardPayment;

/// La livraison du colis peut être confirmée à [now] : étape de remise du
/// pied de la fiche colis ([TravelerStickyBar.hasDeliveryStep]) et trajet
/// parti ([DeliveryWindow] ; départ inconnu : ouvert, le serveur tranche).
bool _canDeliver(BidModel bid, DateTime now) =>
    TravelerStickyBar.hasDeliveryStep(bid) &&
    (DeliveryWindow.fromBid(bid)?.isOpenAt(now) ?? true);

/// Item [kind] des colis de [bids] qui vérifient [when], ou `null` s'il n'y
/// en a aucun. [dueOf] : échéance d'un colis.
TripTodoItem? _collect(
  TripTodoKind kind,
  List<BidModel> bids, {
  required bool Function(BidModel) when,
  DateTime? Function(BidModel)? dueOf,
}) {
  final concerned = bids.where(when).toList();
  if (concerned.isEmpty) return null;
  final due = <String, DateTime>{
    for (final b in concerned) b.id: ?dueOf?.call(b),
  };
  final order = [for (var i = 0; i < concerned.length; i++) i]
    ..sort((a, b) {
      final da = due[concerned[a].id];
      final db = due[concerned[b].id];
      if (da != null && db != null && da != db) return da.compareTo(db);
      if (da != null && db == null) return -1;
      if (da == null && db != null) return 1;
      return a.compareTo(b);
    });
  final ids = [for (final i in order) concerned[i].id];
  return TripTodoItem(
    kind: kind,
    count: ids.length,
    bidIds: ids,
    // Colis à échéance en tête : la première est la plus proche.
    dueAt: due[ids.first],
    dueAtByBid: due,
  );
}

/// File « À traiter » de [trip] pour son voyageur, TRIÉE : urgentes d'abord,
/// puis à urgence égale l'échéance la plus proche (connue avant inconnue),
/// puis l'ordre fixe de [TripTodoKind]. Fonction pure : ni bloc ni horloge
/// globale, [now] fait foi.
///
/// - [bids] : colis du trajet chargés par l'écran (`BidListLoaded`), `null`
///   tant que la liste n'a pas répondu : seules restent les actions qui n'en
///   dépendent pas (« Je pars », « Publier », « Ajouter la carte ») ; aucune
///   demande n'est déduite de `pendingBidCount` (qui compte aussi les cartes
///   non payées et les expéditeurs bloqués).
/// - [isOwner] faux : aucune action.
/// - [departed] : « Je pars » déjà confirmé depuis cet appareil.
/// - [stripe] : compte de paiement par carte (« Ajouter la carte »).
///
/// Règles (numéros de l'inventaire du 31/10) :
/// - #1 [TripTodoKind.requests] : [isPendingBid] sans carte non payée, trajet
///   ACTIVE ou FULL avant sa date limite de dépôt ; échéance non servie par
///   le back, donc `null` ;
/// - #7 [TripTodoKind.presence] : [TravelerStickyBar.awaitsPresence] ;
///   échéance `handoverDeadline` du colis ;
/// - #8 [TripTodoKind.scan] : [TravelerStickyBar.canScanHandover] ;
///   échéance `handoverDeadline` + [tripTravelerNoShowGrace] ;
/// - #11, #12 [TripTodoKind.amendment] : [AmendmentTravelerCard.needsReply] ;
///   échéance `expiresAt` de la modification ouverte ;
/// - #10 [TripTodoKind.supplement] : [SupplementTravelerCard.needsReply] ;
///   échéance `expiresAt` du supplément ;
/// - #16 [TripTodoKind.senderAbsence] :
///   [TravelerHeroCard.canReportSenderNoShow] ; échéance `handoverDeadline`
///   + [tripTravelerNoShowGrace] ;
/// - #28 [TripTodoKind.returnParcel] : [BidModel.isAwaitingReturn], colis
///   annulés compris ; échéance `returnDeadline` ;
/// - #37 [TripTodoKind.depart], #34 [TripTodoKind.addCard] : règles de
///   [tripTodoTilesFor] ;
/// - #38 [TripTodoKind.arrive] : [tripCanMarkArrived] ;
/// - #25 [TripTodoKind.deliver] : étape de remise et trajet parti
///   ([DeliveryWindow]) ;
/// - #24 [TripTodoKind.notify] : arrivée marquée et destinataires à prévenir
///   ([tripRecipientsToNotifyDue]), colis de [recipientsToNotify] ;
/// - #21 [TripTodoKind.recipientDeclined] :
///   [TravelerTransportSection.recipientNeedsReplacement] ;
/// - #39 [TripTodoKind.instructions] : trajet ACTIVE, FULL ou IN_PROGRESS
///   arrivé ([tripHasArrivedParcel]) et instructions de retrait vides ;
/// - #30 [TripTodoKind.rate] : [bidAwaitsRating] côté voyageur ;
/// - #32 [TripTodoKind.publish] : brouillon.
List<TripTodoItem> tripTodoFor({
  required AnnouncementModel trip,
  required List<BidModel>? bids,
  required bool isOwner,
  required DateTime now,
  required bool departed,
  required StripeAccountState stripe,
}) {
  if (!isOwner) return const [];
  final tiles = tripTodoTilesFor(
    trip: trip,
    bids: bids,
    isOwner: true,
    departed: departed,
    stripe: stripe,
  );
  DateTime? afterGrace(BidModel b) =>
      b.handoverDeadline?.add(tripTravelerNoShowGrace);
  final items = <TripTodoItem>[
    if (bids != null) ...[
      if (_requestsAcceptable(trip, now))
        ?_collect(TripTodoKind.requests, bids, when: _isAnswerableRequest),
      ?_collect(
        TripTodoKind.presence,
        bids,
        when: (b) => TravelerStickyBar.awaitsPresence(b, now: now),
        dueOf: (b) => b.handoverDeadline,
      ),
      ?_collect(
        TripTodoKind.scan,
        bids,
        when: (b) => TravelerStickyBar.canScanHandover(b, now: now),
        dueOf: afterGrace,
      ),
      ?_collect(
        TripTodoKind.amendment,
        bids,
        when: AmendmentTravelerCard.needsReply,
        dueOf: (b) => openAmendmentOf(b)?.expiresAt,
      ),
      ?_collect(
        TripTodoKind.supplement,
        bids,
        when: SupplementTravelerCard.needsReply,
        dueOf: (b) => b.supplement?.expiresAt,
      ),
      ?_collect(
        TripTodoKind.senderAbsence,
        bids,
        when: (b) => TravelerHeroCard.canReportSenderNoShow(b, now: now),
        dueOf: afterGrace,
      ),
      ?_collect(
        TripTodoKind.returnParcel,
        bids,
        when: (b) => b.isAwaitingReturn,
        dueOf: (b) => b.returnDeadline,
      ),
      if (tripCanMarkArrived(trip.status, bids))
        const TripTodoItem(kind: TripTodoKind.arrive, count: 1),
      ?_collect(TripTodoKind.deliver, bids, when: (b) => _canDeliver(b, now)),
      if (tripRecipientsToNotifyDue(trip.status, bids))
        TripTodoItem(
          kind: TripTodoKind.notify,
          count: 1,
          bidIds: [for (final b in recipientsToNotify(bids)) b.id],
        ),
      ?_collect(
        TripTodoKind.recipientDeclined,
        bids,
        when: (b) =>
            TravelerTransportSection.recipientNeedsReplacement(b, now: now),
      ),
      if (tripTrackingStatusOpen(trip.status) &&
          tripHasArrivedParcel(bids) &&
          (trip.arrivalInstructions?.trim() ?? '').isEmpty)
        const TripTodoItem(kind: TripTodoKind.instructions, count: 1),
      ?_collect(
        TripTodoKind.rate,
        bids,
        when: (b) => bidAwaitsRating(b, asSender: false),
      ),
    ],
    if (tiles.contains(TripTodoTile.depart))
      const TripTodoItem(kind: TripTodoKind.depart, count: 1),
    if (trip.status == 'DRAFT')
      const TripTodoItem(kind: TripTodoKind.publish, count: 1),
    if (tiles.contains(TripTodoTile.card))
      const TripTodoItem(kind: TripTodoKind.addCard, count: 1),
  ];
  return items..sort(_compare);
}

/// Urgence, puis échéance (connue avant inconnue, la plus proche d'abord),
/// puis ordre fixe des types.
int _compare(TripTodoItem a, TripTodoItem b) {
  final byUrgency = a.urgency.index.compareTo(b.urgency.index);
  if (byUrgency != 0) return byUrgency;
  final da = a.dueAt;
  final db = b.dueAt;
  if (da != null && db != null && da != db) return da.compareTo(db);
  if (da != null && db == null) return -1;
  if (da == null && db != null) return 1;
  return a.kind.index.compareTo(b.kind.index);
}

/// Nombre d'actions à traiter de [items] (pastille « À traiter · N » du
/// billet) : somme des [TripTodoItem.count].
int tripTodoCount(List<TripTodoItem> items) =>
    items.fold(0, (sum, item) => sum + item.count);

/// Colis distincts qui attendent un geste du voyageur (ligne Colis : « N
/// attendent ton geste ») : ceux des actions sur des colis
/// ([TripTodoKind.perParcel]). Les demandes et les gestes du trajet
/// (« Prévenir les destinataires » compris) n'en marquent aucun.
Set<String> tripTodoParcelIds(List<TripTodoItem> items) => {
  for (final item in items)
    if (item.kind.perParcel) ...item.bidIds,
};

/// Mesure d'affichage de l'action [item] de [trip]
/// (`bid_detail_todo_tile_shown`, `role: trip_owner`), à émettre par
/// `TodoTileViewLog.logAll` avec l'identifiant du trajet. Propriétés `tile`
/// (nom du type), `role`, `status` (statut du trajet) et `count` (actions
/// de ce type). Dédoublonnée par type et nombre : une action de plus du même
/// type la remesure, un simple rechargement ou un changement de statut du
/// trajet ne remesure rien.
TodoTileShown tripTodoItemShown(TripTodoItem item, AnnouncementModel trip) =>
    TodoTileShown(
      AnalyticsEvents.bidDetailTodoTileShown,
      tile: item.kind.name,
      status: '${item.count}',
      properties: () => {
        'tile': item.kind.name,
        'role': 'trip_owner',
        'status': trip.status,
        'count': item.count,
      },
    );
