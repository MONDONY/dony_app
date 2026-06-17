import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Éléments de « chrome » partagés entre la liste des demandes (« Acceptées »)
// et l'écran « À traiter » : état d'erreur, bandeau d'offres masquées, fond du
// swipe-to-delete.
// ─────────────────────────────────────────────────────────────────────────────

/// État d'erreur avec bouton « Réessayer ».
class BidListErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const BidListErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('circle-alert', size: 48, color: cs.outlineVariant),
            const SizedBox(height: DonySpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.base),
            DonyButton(
              label: 'Réessayer',
              onPressed: onRetry,
              variant: DonyButtonVariant.secondary,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau « n offre(s) masquée(s) » (filtre prix minimum actif) + « Voir tout ».
class HiddenBidsBanner extends StatelessWidget {
  const HiddenBidsBanner({
    super.key,
    required this.count,
    required this.onShowAll,
  });
  final int count;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Row(
        children: [
          DonyIcon('list-filter', size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Expanded(
            child: Text(
              '$count offre${count > 1 ? 's' : ''} masquée${count > 1 ? 's' : ''} (prix minimum actif)',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: onShowAll, child: const Text('Voir tout')),
        ],
      ),
    );
  }
}

/// Fond rouge affiché derrière une carte lors du swipe-to-delete.
class DismissBackground extends StatelessWidget {
  const DismissBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: DonySpacing.xl),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DonyIcon('trash-2', color: DonyColors.neutral0, size: 28),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Supprimer',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: DonyColors.neutral0),
          ),
        ],
      ),
    );
  }
}
