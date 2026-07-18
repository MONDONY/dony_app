import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Pill rouge « 🔥 Urgent » pour les publications dont la date clé est proche.
///
/// Couleur : `cs.error` (danger500 en light, dangerDark500 en dark — même
/// résolution brightness-aware que [MarkerUrgencyColor], via [ColorScheme]
/// puisqu'un [BuildContext] est disponible ici).
class DonyUrgentBadge extends StatelessWidget {
  const DonyUrgentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        '🔥 Urgent',
        // fontSize forcé à 12 (règle projet : fontSize < 12 interdit) —
        // labelMedium résout à 11px, aucun token DonyTypography à 12px/w500+
        // n'existe (bodySmall est 12px mais w400).
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 12,
              color: cs.error,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
