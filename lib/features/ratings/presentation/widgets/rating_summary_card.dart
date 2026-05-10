import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class RatingSummaryCard extends StatelessWidget {
  const RatingSummaryCard({
    super.key,
    required this.averageRating,
    required this.ratingCount,
    required this.distribution,
  });

  final double averageRating;
  final int ratingCount;
  final Map<int, int> distribution;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = cs.brightness == Brightness.dark;
    final total = distribution.values.fold(0, (a, b) => a + b);

    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surface.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.88),
            ),
            boxShadow: DonyShadow.card,
          ),
          child: Row(
            children: [
              // ── Note globale ────────────────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < averageRating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 14,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    '$ratingCount avis',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(width: DonySpacing.base),
              // ── Distribution ────────────────────────────────────────────
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final star = 5 - i;
                    final count = distribution[star] ?? 0;
                    final ratio = total == 0 ? 0.0 : count / total;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('$star', style: tt.bodySmall),
                          const SizedBox(width: DonySpacing.xs),
                          const Icon(
                            Icons.star_rounded,
                            size: 10,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor:
                                    cs.outline.withValues(alpha: 0.2),
                                color: cs.primary,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '$count',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
