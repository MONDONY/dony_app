import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

enum DonyBadgeType { info, success, warning, error }

class DonyBadge extends StatelessWidget {
  const DonyBadge({
    super.key,
    required this.label,
    this.type = DonyBadgeType.info,
    this.icon,
    this.iconAsset,
  });

  final String label;
  final DonyBadgeType type;
  final IconData? icon;

  /// Nom d'un SVG Lucide dans `assets/icons/` (sans extension), alternative à
  /// [icon]. Teinté par la couleur du type de badge.
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (type) {
      DonyBadgeType.info    => (cs.infoLight,    cs.info),
      DonyBadgeType.success => (cs.successLight, cs.success),
      DonyBadgeType.warning => (cs.warningLight, cs.warning),
      DonyBadgeType.error   => (cs.errorLight,   cs.error),
    };

    // En mode étiquettes renforcées, un badge sans icône en reçoit une, tirée
    // de son type : la couleur seule ne suffit pas à distinguer un succès d'une
    // erreur pour une vision des couleurs atypique.
    final fallbackIcon = switch (type) {
      DonyBadgeType.info => Icons.info_outline,
      DonyBadgeType.success => Icons.check_circle_outline,
      DonyBadgeType.warning => Icons.warning_amber_rounded,
      DonyBadgeType.error => Icons.error_outline,
    };
    final effectiveIcon = icon ??
        (context.a11y.reinforceLabels && iconAsset == null
            ? fallbackIcon
            : null);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (effectiveIcon != null) ...[
            Icon(effectiveIcon, size: 12, color: fg),
            const SizedBox(width: 4),
          ] else if (iconAsset != null) ...[
            DonyIcon(iconAsset!, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
