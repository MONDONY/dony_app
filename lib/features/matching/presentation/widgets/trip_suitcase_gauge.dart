import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Jauge des valises d'un trajet : une barre par valise, remplie des kilos
/// encore libres, avec ce qui reste en dessous de chaque ligne.
class TripSuitcaseGauge extends StatelessWidget {
  const TripSuitcaseGauge({super.key, required this.capacity});

  final TripCapacity capacity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final remaining = capacity.remainingPerSuitcase;
    final labelStyle = tt.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      key: const Key('trip-suitcase-gauge'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < remaining.length; i++) ...[
          if (i > 0) const SizedBox(height: DonySpacing.sm),
          _SuitcaseRow(
            index: i + 1,
            freeKg: remaining[i],
            sizeKg: capacity.unitKg,
          ),
        ],
        const SizedBox(height: DonySpacing.sm),
        Row(
          children: [
            _LegendDot(color: cs.primary),
            const SizedBox(width: DonySpacing.xs),
            Text(l.listingSuitcaseGaugeRemaining, style: labelStyle),
            const SizedBox(width: DonySpacing.base),
            _LegendDot(color: cs.outline),
            const SizedBox(width: DonySpacing.xs),
            Text(l.listingSuitcaseGaugeReserved, style: labelStyle),
          ],
        ),
      ],
    );
  }
}

class _SuitcaseRow extends StatelessWidget {
  const _SuitcaseRow({
    required this.index,
    required this.freeKg,
    required this.sizeKg,
  });

  final int index;
  final double freeKg;
  final int sizeKg;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final isFull = freeKg <= 0;
    final fraction = (freeKg / sizeKg).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            l.listingSuitcaseShort(index),
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Semantics(
            label: l.listingSuitcaseRemaining(
              freeKg.toStringAsFixed(0),
              sizeKg,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DonyRadius.full),
              child: SizedBox(
                key: Key('trip-suitcase-track-$index'),
                height: 12,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: cs.outline)),
                    // Kilos libres en bleu, calés à gauche sur toute la
                    // hauteur de la piste. Sans `heightFactor`, le Stack
                    // passait des contraintes lâches et la barre, sans
                    // enfant, prenait 0 de haut : jauge toute grise.
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: fraction,
                        heightFactor: 1,
                        child: ColoredBox(
                          key: Key('trip-suitcase-free-$index'),
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        SizedBox(
          width: 84,
          child: Text(
            isFull
                ? l.listingSuitcaseFull
                : l.listingSuitcaseRemaining(freeKg.toStringAsFixed(0), sizeKg),
            textAlign: TextAlign.right,
            style: tt.labelMedium?.copyWith(
              color: isFull ? cs.warning : cs.onSurface,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}
