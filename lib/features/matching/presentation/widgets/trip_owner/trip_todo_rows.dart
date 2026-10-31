import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Lignes « À traiter » de [live] rendues par [TripTodoRows]
/// ([tripTodoRowsOf] : toutes les tuiles sauf les demandes, que porte la
/// carte de réponse directe `TripDirectRequestCard`).
List<TripTodoRow> tripTodoRowsFor(TripTodoLiveData live) =>
    tripTodoRowsOf(live.tiles);

/// « Autres choses à traiter » de l'écran du trajet vu par son voyageur
/// (« Je pars », « Ajouter la carte ») : une seule carte, une ligne par geste
/// ([tripTodoRowsFor]) avec son icône en pastille, son titre et son résumé
/// ([tripTodoTitle], [tripTodoSummary]), puis un chevron. Un tap appelle
/// [onOpen], qui ouvre le sheet de la tuile (`openTripTodoSheet`) avec le
/// contexte du corps.
///
/// Ne rend rien sans ligne. L'affichage de chaque ligne est mesuré
/// (`bid_detail_todo_tile_shown`, [tripTodoShown]) dans [views], le journal
/// du corps : même clé de dédoublonnage que les tuiles d'avant. Chaque ligne
/// garde la clé de sa tuile (`trip_owner-todo-<tile>`).
class TripTodoRows extends StatelessWidget {
  const TripTodoRows({
    super.key,
    required this.live,
    required this.views,
    required this.onOpen,
  });

  final TripTodoLiveData live;
  final TodoTileViewLog views;
  final ValueChanged<TripTodoRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = tripTodoRowsFor(live);
    if (rows.isEmpty) return const SizedBox.shrink();
    views.logAll(context, live.trip.id, [
      for (final row in rows)
        tripTodoShown(row.tile, live.trip, pendingCount: live.pendingCount),
    ]);
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(DonyRadius.card);
    return Material(
      key: const Key('trip-todo-rows'),
      color: cs.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, color: cs.outline),
              _TodoRow(live: live, row: row, onTap: () => onOpen(row)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.live, required this.row, required this.onTap});

  final TripTodoLiveData live;
  final TripTodoRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = tripTodoTitle(l, row, cardReady: live.cardReady);
    final summary = tripTodoSummary(l, row, cardReady: live.cardReady);
    return Semantics(
      button: true,
      label: '$title. $summary',
      excludeSemantics: true,
      child: InkWell(
        key: Key('trip_owner-todo-${row.name}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            child: Row(
              children: [
                DonyIconContainer(
                  iconAsset: tripTodoIcon(row),
                  size: DonyIconContainerSize.sm,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
