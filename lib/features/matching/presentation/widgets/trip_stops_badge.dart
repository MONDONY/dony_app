import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Libellé court des escales pour un badge ou une ligne de détail
/// (FLUTTER-GE).
String tripStopsBadgeLabel(AppLocalizations l, TripStops stops) =>
    switch (stops) {
      TripStops.direct => l.tripStopsBadgeDirect,
      TripStops.one => l.tripStopsBadgeOne,
      TripStops.twoOrMore => l.tripStopsBadgeTwoOrMore,
    };

/// Badge « Vol direct / 1 escale / 2 escales et + » des cartes de trajet.
///
/// Rien n'est affiché quand le voyageur n'a pas renseigné les escales : un
/// trajet sans information ne doit pas avoir l'air d'un vol direct.
class TripStopsBadge extends StatelessWidget {
  const TripStopsBadge({super.key, required this.stops});

  final TripStops? stops;

  @override
  Widget build(BuildContext context) {
    final value = stops;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final direct = value == TripStops.direct;
    final fg = direct ? cs.primary : cs.onSurfaceVariant;
    return Container(
      key: const Key('trip-stops-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: direct ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('plane', size: 11, color: fg),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            tripStopsBadgeLabel(context.l10n, value),
            style: tt.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
