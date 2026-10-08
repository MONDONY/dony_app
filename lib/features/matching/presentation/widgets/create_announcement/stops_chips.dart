import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// « Escales (facultatif) : Direct / 1 escale / 2 escales ou plus »
/// (FLUTTER-GE), proposé pour un trajet en avion.
///
/// Facultatif : un second toucher sur l'option choisie la retire et le trajet
/// redevient « non renseigné ».
class StopsChips extends StatelessWidget {
  const StopsChips({super.key, required this.notifier});

  final ValueNotifier<TripStops?> notifier;

  static String optionLabel(AppLocalizations l, TripStops stops) =>
      switch (stops) {
        TripStops.direct => l.tripStopsDirect,
        TripStops.one => l.tripStopsOne,
        TripStops.twoOrMore => l.tripStopsTwoOrMore,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<TripStops?>(
      valueListenable: notifier,
      builder: (context, selected, _) => Column(
        key: const Key('stops-chips'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.tripStopsLabel,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.xs,
            children: [
              for (final stops in TripStops.values)
                ChoiceChip(
                  key: Key('stops-${stops.name}'),
                  label: Text(optionLabel(l, stops)),
                  selected: selected == stops,
                  onSelected: (_) =>
                      notifier.value = selected == stops ? null : stops,
                ),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            l.tripStopsHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
