import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ListTile stylisé dony — paramètres, infos, actions.
///
/// Usage :
/// ```dart
/// DonyListTile(
///   icon: Icons.notifications_outlined,
///   label: 'Notifications',
///   subtitle: 'Gérer vos préférences',
///   trailing: Switch(...),
///   onTap: () => context.push('/settings/notifications'),
/// )
/// ```
class DonyListTile extends StatelessWidget {
  const DonyListTile({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconAsset,
    this.iconColor,
    this.iconBgColor,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.enabled = true,
    this.destructive = false,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;

  /// Nom d'un SVG Lucide dans `assets/icons/` (sans extension). Alternative
  /// à [icon] pour utiliser une icône moderne via [DonyIcon].
  final String? iconAsset;
  final Color? iconColor;
  final Color? iconBgColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final labelColor = destructive
        ? cs.error
        : enabled
            ? cs.onSurface
            : cs.onSurfaceVariant;

    final effectiveIconColor = destructive
        ? cs.error
        : iconColor ?? cs.primary;

    final effectiveIconBg = destructive
        ? cs.errorContainer
        : iconBgColor ?? cs.primaryContainer;

    return Column(
      children: [
        InkWell(
          onTap: (enabled && onTap != null)
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.xs,
              vertical: DonySpacing.sm + 2,
            ),
            child: Row(
              children: [
                if (icon != null || iconAsset != null) ...[
                  DonyIconContainer(
                    icon: icon,
                    iconAsset: iconAsset,
                    backgroundColor: effectiveIconBg,
                    iconColor: effectiveIconColor,
                    borderRadius: DonyRadius.sm,
                  ),
                  const SizedBox(width: DonySpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: tt.bodyMedium?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: DonySpacing.xxs),
                        Text(
                          subtitle!,
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                trailing ??
                    (onTap != null
                        ? Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          )
                        : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: DonySpacing.lg + DonySpacing.icon),
      ],
    );
  }
}

/// Groupe de DonyListTile dans une carte.
class DonyListSection extends StatelessWidget {
  const DonyListSection({
    super.key,
    required this.tiles,
    this.title,
  });

  final List<DonyListTile> tiles;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: DonySpacing.xs,
              bottom: DonySpacing.sm,
            ),
            child: Text(
              title!.toUpperCase(),
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
        DonyCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < tiles.length; i++)
                DonyListTile(
                  label: tiles[i].label,
                  subtitle: tiles[i].subtitle,
                  icon: tiles[i].icon,
                  iconAsset: tiles[i].iconAsset,
                  iconColor: tiles[i].iconColor,
                  iconBgColor: tiles[i].iconBgColor,
                  trailing: tiles[i].trailing,
                  onTap: tiles[i].onTap,
                  showDivider: i < tiles.length - 1,
                  enabled: tiles[i].enabled,
                  destructive: tiles[i].destructive,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
