import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/money/presentation/money_conditions.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Frise de libération en quatre segments Payé → Remis → Livré → Versé
/// (maquette B, FLUTTER-HV). Lue d'un seul tenant par les lecteurs d'écran :
/// « Étape 3 sur 4, Livré ».
class MoneyReleaseTimeline extends StatelessWidget {
  const MoneyReleaseTimeline({super.key, required this.segments});

  final List<TimelineSegment> segments;

  /// Dernière étape atteinte (non grise), 0 si aucune.
  int get reachedStep {
    var reached = 0;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i] != TimelineSegment.todo) reached = i + 1;
    }
    return reached;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final labels = timelineLabels(l);
    final step = reachedStep;
    final semantics = step == 0
        ? null
        : l.moneyTimelineSemantics(step, kTimelineSteps, labels[step - 1]);

    Color bar(TimelineSegment s) => switch (s) {
      TimelineSegment.done => cs.success,
      TimelineSegment.current => cs.primary,
      TimelineSegment.attention => cs.warning,
      TimelineSegment.todo => cs.outline,
    };

    Color text(TimelineSegment s) => switch (s) {
      TimelineSegment.done => cs.success,
      TimelineSegment.current => cs.onPrimaryContainer,
      TimelineSegment.attention => cs.onSurface,
      TimelineSegment.todo => cs.onSurfaceVariant,
    };

    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

    return Semantics(
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Column(
                  key: Key('money-timeline-segment-$i-${segments[i].name}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      height: 6,
                      decoration: BoxDecoration(
                        color: bar(segments[i]),
                        borderRadius: BorderRadius.circular(DonyRadius.full),
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs + 2),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle?.copyWith(color: text(segments[i])),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
