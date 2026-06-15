import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// En-tête de section avec titre et action optionnelle.
///
/// Usage :
/// ```dart
/// DonySectionHeader(
///   title: 'Trajets récents',
///   actionLabel: 'Voir tout',
///   onAction: () => context.push('/trips'),
/// )
/// ```
class DonySectionHeader extends StatelessWidget {
  const DonySectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment:
            subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.headlineSmall),
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
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: DonySpacing.xs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xxs),
                  DonyIcon('arrow-right', size: 14, color: cs.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
