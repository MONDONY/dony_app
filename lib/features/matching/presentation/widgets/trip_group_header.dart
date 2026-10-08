import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// En-tête d'un voyage à plusieurs étapes dans « Mes trajets » (FLUTTER-4D).
class TripGroupHeader extends StatelessWidget {
  const TripGroupHeader({super.key, required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        left: DonySpacing.xs,
        bottom: DonySpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.alt_route_rounded, size: 18, color: cs.primary),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              context.l10n.tripGroupHeader(route),
              style: tt.labelLarge?.copyWith(color: cs.primary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille « Étape 1/2 » posée sur la carte d'une étape (FLUTTER-4D).
class TripLegBadge extends StatelessWidget {
  const TripLegBadge({super.key, required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Text(
        context.l10n.tripLegBadge(index, count),
        style: tt.labelSmall?.copyWith(
          color: cs.onPrimaryContainer,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
