import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum DonyBadgeType { info, success, warning, error }

class DonyBadge extends StatelessWidget {
  const DonyBadge({
    super.key,
    required this.label,
    this.type = DonyBadgeType.info,
    this.icon,
  });

  final String label;
  final DonyBadgeType type;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (type) {
      DonyBadgeType.info    => (DonyColors.infoLight,    DonyColors.info),
      DonyBadgeType.success => (DonyColors.successLight, DonyColors.success),
      DonyBadgeType.warning => (DonyColors.warningLight, DonyColors.warning),
      DonyBadgeType.error   => (DonyColors.errorLight,   DonyColors.error),
    };

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
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
