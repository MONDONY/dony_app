import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Pill rouge « 🔥 Urgent » pour les publications dont la date clé est proche.
class DonyUrgentBadge extends StatelessWidget {
  const DonyUrgentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: DonyColors.urgencyRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        '🔥 Urgent',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: DonyColors.urgencyRed,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
