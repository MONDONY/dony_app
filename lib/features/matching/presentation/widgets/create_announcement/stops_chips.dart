import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// « Escales (facultatif) : Direct / 1 escale / 2 escales ou plus »
/// (FLUTTER-GE), proposé pour un trajet en avion.
///
/// Facultatif : un second toucher sur l'option choisie la retire et le trajet
/// redevient « non renseigné ».
///
/// [segmented] : bascule segmentée aux libellés courts, sur une seule ligne
/// quelle que soit la largeur (feuille d'une étape, FLUTTER-HN) ; sinon des
/// puces (formulaire du premier trajet).
class StopsChips extends StatelessWidget {
  const StopsChips({super.key, required this.notifier, this.segmented = false});

  final ValueNotifier<TripStops?> notifier;
  final bool segmented;

  /// Libellé court d'une option, pour la bascule segmentée : « 2 escales ou
  /// plus » ne tient pas dans un tiers de 320 dp.
  static String shortLabel(AppLocalizations l, TripStops stops) =>
      switch (stops) {
        TripStops.direct => l.tripStopsDirect,
        TripStops.one => l.tripStopsOne,
        TripStops.twoOrMore => l.tripStopsTwoOrMoreShort,
      };

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
          if (segmented)
            DonySegmentedControl<TripStops?>(
              key: const Key('stops-segmented'),
              selected: selected,
              // Second toucher sur l'option choisie : retour à « non
              // renseigné », comme les puces.
              onSelect: (stops) =>
                  notifier.value = selected == stops ? null : stops,
              segments: [
                for (final stops in TripStops.values)
                  DonySegment<TripStops?>(
                    key: Key('stops-${stops.name}'),
                    value: stops,
                    label: shortLabel(l, stops),
                  ),
              ],
            )
          else
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
