import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RatingListItem extends StatelessWidget {
  const RatingListItem({super.key, required this.item});

  final RatingItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = cs.brightness == Brightness.dark;
    final dateStr =
        DateFormat('d MMM yyyy', 'fr_FR').format(item.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: isDark
                  ? cs.surface.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.88),
              ),
              boxShadow: DonyShadow.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < item.stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: DonyColors.starGold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (item.comment != null && item.comment!.isNotEmpty) ...[
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    item.comment!,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
