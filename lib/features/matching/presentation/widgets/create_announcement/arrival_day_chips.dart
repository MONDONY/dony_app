import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// « Arrivée : le jour même / le lendemain / dans 2 jours » (FLUTTER-4E).
///
/// Partagé par la création de trajet et l'édition d'un modèle de trajet.
class ArrivalDayChips extends StatelessWidget {
  const ArrivalDayChips({super.key, required this.notifier});
  final ValueNotifier<int> notifier;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, selected, _) => Column(
        key: const Key('arrival-day-chips'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.tripPublishArrivalDayLabel,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.xs,
            children: [
              for (final offset in const [0, 1, 2])
                ChoiceChip(
                  key: Key('arrival-day-$offset'),
                  label: Text(l.tripPublishArrivalDayOption(offset)),
                  selected: selected == offset,
                  onSelected: (_) => notifier.value = offset,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
