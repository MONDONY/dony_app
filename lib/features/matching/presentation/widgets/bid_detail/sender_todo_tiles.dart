import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Demandes qui attendent une réponse de l'expéditeur et prennent la forme
/// d'une tuile dans la section « À traiter » de la fiche colis. Chaque tuile
/// ouvre un bottom sheet (`openSenderTodoSheet`).
///
/// Le nom sert de valeur `tile` aux mesures (`bid_detail_tile_opened`,
/// `bid_detail_todo_tile_shown`) : ne pas le renommer sans migrer PostHog.
enum SenderTodoTile {
  /// Modification du colis où l'expéditeur a un geste à faire
  /// ([AmendmentSenderCard.needsReply]) : l'annuler (proposée, autorisation
  /// carte en attente) ou la payer (mobile money). En commission chez le
  /// voyageur, la carte reste une information.
  amendment,

  /// Trajet reporté, décision ouverte ([TripRescheduleCard.needsReply]).
  reschedule,

  /// Destinataire à remplacer ([PrevenirDestinataire.showsDeclined]).
  recipient,
}

/// Tuiles « À traiter » de [bid], dans l'ordre de la grille. Fonction pure :
/// le corps la rappelle à chaque rafraîchissement du colis, et le sheet
/// ouvert s'en sert pour se fermer quand sa tuile n'a plus lieu d'être.
///
/// Les conditions sont celles qui rangeaient jusqu'ici la carte sous
/// « À traiter » ; hors de ces cas, la carte reste une information du corps
/// (report déjà décidé) ou n'existe pas.
List<SenderTodoTile> senderTodoTilesFor(BidModel bid) => [
  if (AmendmentSenderCard.needsReply(bid)) SenderTodoTile.amendment,
  if (TripRescheduleCard.needsReply(bid)) SenderTodoTile.reschedule,
  if (PrevenirDestinataire.showsDeclined(bid)) SenderTodoTile.recipient,
];

/// Titre de la tuile et de son sheet, repris de la carte.
String senderTodoTitle(AppLocalizations l, SenderTodoTile tile) =>
    switch (tile) {
      // « Modification du colis » : le titre de la carte est en capitales.
      SenderTodoTile.amendment => l.amendmentPaymentContextLabel,
      SenderTodoTile.reschedule => l.bidRescheduleTitle,
      SenderTodoTile.recipient => l.recipientDeclinedSenderTitle,
    };

/// Pastille de la tuile. Modification : l'état de la demande, puisque c'est
/// le voyageur qui répond (« En attente », seul geste : annuler) ou que le
/// paiement est attendu (« Paiement attendu »). Autres tuiles : « Réponse
/// attendue ».
String senderTodoBadge(AppLocalizations l, BidModel bid, SenderTodoTile tile) =>
    switch (tile) {
      SenderTodoTile.amendment =>
        AmendmentSenderCard.openRequest(bid)?.status ==
                BidAmendmentStatus.paymentPending
            ? l.senderTodoAmendmentBadgePaymentDue
            : l.senderTodoAmendmentBadgePending,
      SenderTodoTile.reschedule ||
      SenderTodoTile.recipient => l.todoTileBadgeReplyNeeded,
    };

/// Résumé de la tuile : ce qui est attendu, en une ou deux lignes.
String senderTodoSummary(
  AppLocalizations l,
  BidModel bid,
  SenderTodoTile tile,
) => switch (tile) {
  SenderTodoTile.amendment => _amendmentSummary(l, bid),
  SenderTodoTile.reschedule => switch (bid.reschedule?.decisionDeadline) {
    // Envoyée en UTC (yadony-back #627) : heure de l'appareil, comme la carte.
    final deadline? => l.senderTodoRescheduleSummary(
      DateFormat.MMMd(l.localeName).add_Hm().format(deadline.toLocal()),
    ),
    null => l.senderTodoRescheduleChoice,
  },
  SenderTodoTile.recipient =>
    bid.recipientReplacementRequestedAt != null
        ? l.senderTodoRecipientRequested
        : l.senderTodoRecipientSummary,
};

/// Kilos ajoutés et montant brut de la demande ouverte ; le montant seul
/// quand elle n'ajoute que des articles.
String _amendmentSummary(AppLocalizations l, BidModel bid) {
  final a = AmendmentSenderCard.openRequest(bid);
  if (a == null) return '';
  final amount = formatSupplementAmount(a.grossAmount, a.currency);
  return a.addedWeightKg > 0
      ? l.senderTodoAmendmentSummary(formatWeightKg(l, a.addedWeightKg), amount)
      : l.senderTodoAmendmentAmount(amount);
}

/// Mesure d'affichage de la tuile [tile] pour [bid], dédoublonnée par le
/// statut du colis. Une tuile dont la carte émettait un `*_viewed` à son
/// montage a en plus sa mesure de carte ([senderTodoViewed]).
///
/// La clé de dédoublonnage précise la demande quand le statut du colis ne
/// suffit pas : l'identifiant de la modification ouverte (une demande B
/// créée après l'annulation de A est remesurée), l'identifiant du report (un nouveau report sur un colis au
/// même statut est remesuré), une empreinte du destinataire refusé (le modèle
/// n'a pas d'horodatage du refus : un même destinataire qui refuse deux fois
/// au même statut n'est mesuré qu'une fois). Jamais le nom ni le numéro en
/// clair : la clé reste en mémoire, hors des propriétés.
TodoTileShown senderTodoShown(SenderTodoTile tile, BidModel bid) =>
    TodoTileShown(
      AnalyticsEvents.bidDetailTodoTileShown,
      tile: tile.name,
      properties: () => {
        'tile': tile.name,
        'role': 'sender',
        'status': bid.status,
      },
      status: switch (tile) {
        SenderTodoTile.amendment =>
          '${bid.status}|${AmendmentSenderCard.openRequest(bid)?.id}',
        SenderTodoTile.reschedule => '${bid.status}|${bid.reschedule?.id}',
        SenderTodoTile.recipient =>
          '${bid.status}|'
              '${Object.hash(bid.recipientName, bid.recipientPhone)}',
      },
    );

/// Mesure de la carte reprise par la tuile [tile], émise à l'affichage de la
/// tuile en plus de [senderTodoShown] : la carte n'est plus montée tant que la
/// demande attend une réponse, et son sheet ne la réémet pas à chaque
/// ouverture. `null` pour une tuile dont la carte n'avait pas de mesure.
///
/// Modification : `bid_amendment_viewed` avec `surface: tile`, une fois par
/// demande et par statut de la demande.
TodoTileShown? senderTodoViewed(SenderTodoTile tile, BidModel bid) {
  if (tile != SenderTodoTile.amendment) return null;
  final a = AmendmentSenderCard.openRequest(bid);
  if (a == null) return null;
  return TodoTileShown(
    AnalyticsEvents.bidAmendmentViewed,
    tile: tile.name,
    properties: () => {
      'role': 'sender',
      'status': a.status.wire,
      'surface': 'tile',
    },
    status: '${a.id}|${a.status.wire}',
  );
}
