import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/l10n/l10n.dart';

/// Demandes qui attendent une réponse du voyageur et prennent la forme d'une
/// tuile dans la section « À traiter » de la fiche colis. Chaque tuile ouvre
/// un bottom sheet (`openTravelerTodoSheet`).
///
/// Le nom sert de valeur `tile` aux mesures (`bid_detail_tile_opened`,
/// `bid_detail_todo_tile_shown`) : ne pas le renommer sans migrer PostHog.
enum TravelerTodoTile {
  /// Supplément de prix d'un colis payé en espèces dont les frais de service
  /// attendent la validation du voyageur ([SupplementTravelerCard.needsReply],
  /// `COMMISSION_PENDING`).
  supplement,
}

/// Tuiles « À traiter » de [bid], dans l'ordre de la grille. Fonction pure :
/// le corps la rappelle à chaque rafraîchissement du colis, et le sheet
/// ouvert s'en sert pour se fermer quand sa tuile n'a plus lieu d'être.
///
/// Les autres états du supplément (en attente de l'expéditeur, payé, refusé,
/// expiré…) restent une carte d'information du corps.
List<TravelerTodoTile> travelerTodoTilesFor(BidModel bid) => [
  if (SupplementTravelerCard.needsReply(bid)) TravelerTodoTile.supplement,
];

/// Titre de la tuile et de son sheet, le même que celui de la carte.
String travelerTodoTitle(AppLocalizations l, TravelerTodoTile tile) =>
    switch (tile) {
      TravelerTodoTile.supplement => l.supplementCardTitle,
    };

/// Résumé de la tuile : ce qui est attendu, en une ou deux lignes.
String travelerTodoSummary(
  AppLocalizations l,
  BidModel bid,
  TravelerTodoTile tile,
) => switch (tile) {
  TravelerTodoTile.supplement => switch (bid.supplement) {
    final s? when s.commissionAmount != null => l.travelerTodoSupplementSummary(
      formatSupplementAmount(s.commissionAmount!, s.currency),
    ),
    _ => l.supplementTravelerCommissionPending,
  },
};

/// Mesure d'affichage de la tuile [tile] pour [bid]
/// (`bid_detail_todo_tile_shown`), dédoublonnée par le statut du colis et
/// l'identifiant de la demande : une nouvelle demande de supplément sur un
/// colis au même statut est remesurée.
TodoTileShown travelerTodoShown(TravelerTodoTile tile, BidModel bid) =>
    TodoTileShown(
      AnalyticsEvents.bidDetailTodoTileShown,
      tile: tile.name,
      properties: () => {
        'tile': tile.name,
        'role': 'traveler',
        'status': bid.status,
      },
      status: switch (tile) {
        TravelerTodoTile.supplement => '${bid.status}|${bid.supplement?.id}',
      },
    );

/// Mesure de la carte reprise par la tuile [tile], émise à l'affichage de la
/// tuile en plus de [travelerTodoShown] : la carte n'est pas montée tant que
/// la demande attend le voyageur, et son sheet ne la réémet pas à chaque
/// ouverture.
///
/// Supplément : `bid_supplement_viewed` avec `surface: tile`, une fois par
/// demande et par statut de la demande. `null` sans supplément.
TodoTileShown? travelerTodoViewed(TravelerTodoTile tile, BidModel bid) {
  final s = bid.supplement;
  if (s == null) return null;
  return switch (tile) {
    TravelerTodoTile.supplement => TodoTileShown(
      AnalyticsEvents.bidSupplementViewed,
      tile: tile.name,
      properties: () => {
        'role': 'traveler',
        'status': s.status.name,
        'surface': 'tile',
      },
      status: '${s.id}|${s.status.name}',
    ),
  };
}
