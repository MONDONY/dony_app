import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_icon_container.dart';
import 'package:flutter/material.dart';

enum DonyEmptyStateType { empty, error, loading }

/// État vide / erreur / chargement standardisé.
/// Conforme HIG : icône + titre + description + CTA optionnel.
class DonyEmptyState extends StatelessWidget {
  const DonyEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.type = DonyEmptyStateType.empty,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final DonyEmptyStateType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (type == DonyEmptyStateType.loading) {
      return Center(
        child: Padding(
          padding: padding ?? const EdgeInsets.all(DonySpacing.huge),
          child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
        ),
      );
    }

    final (bg, ic, defaultIcon) = switch (type) {
      DonyEmptyStateType.empty => (DonyColors.green50, DonyColors.green400, Icons.inbox_outlined),
      DonyEmptyStateType.error => (DonyColors.errorLight, DonyColors.error, Icons.error_outline_rounded),
      DonyEmptyStateType.loading => (DonyColors.green50, DonyColors.green400, Icons.sync_rounded),
    };

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(DonySpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIconContainer(
              icon: icon ?? defaultIcon,
              size: DonyIconContainerSize.xl,
              backgroundColor: bg,
              iconColor: ic,
            ),
            const SizedBox(height: DonySpacing.xl),
            Text(
              title,
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                description!,
                style: tt.bodyMedium?.copyWith(color: DonyColors.grey400),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DonySpacing.xl),
              DonyButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: type == DonyEmptyStateType.error
                    ? DonyButtonVariant.primary
                    : DonyButtonVariant.secondary,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
