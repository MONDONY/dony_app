import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
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
  if (TripRescheduleCard.needsReply(bid)) SenderTodoTile.reschedule,
  if (PrevenirDestinataire.showsDeclined(bid)) SenderTodoTile.recipient,
];

/// Titre de la tuile et de son sheet, repris de la carte.
String senderTodoTitle(AppLocalizations l, SenderTodoTile tile) =>
    switch (tile) {
      SenderTodoTile.reschedule => l.bidRescheduleTitle,
      SenderTodoTile.recipient => l.recipientDeclinedSenderTitle,
    };

/// Résumé de la tuile : ce qui est attendu, en une ou deux lignes.
String senderTodoSummary(
  AppLocalizations l,
  BidModel bid,
  SenderTodoTile tile,
) => switch (tile) {
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

/// Mesure d'affichage de la tuile [tile] pour [bid], dédoublonnée par le
/// statut du colis.
///
/// Point d'extension : une tuile dont la carte émettait un `*_viewed` à son
/// montage (modification, supplément) rend ici cet événement, avec
/// `surface: tile` et le statut de la demande, au lieu de
/// `bid_detail_todo_tile_shown`.
TodoTileShown senderTodoShown(SenderTodoTile tile, BidModel bid) =>
    TodoTileShown(AnalyticsEvents.bidDetailTodoTileShown, {
      'tile': tile.name,
      'role': 'sender',
      'status': bid.status,
    }, status: bid.status);
