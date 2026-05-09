import 'package:dony/core/design/tokens/color_tokens.dart'; // DonyStatusColors extension
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_icon_container.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum DonyEmptyStateType { empty, error, loading }

class DonyEmptyState extends StatelessWidget {
  const DonyEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.mascotte,
    this.type = DonyEmptyStateType.empty,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final DonyMascotteType? mascotte;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
              const SizedBox(height: DonySpacing.lg),
              Text(
                'Chargement en cours...',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final (bg, ic, defaultIcon) = switch (type) {
      DonyEmptyStateType.empty => (
          cs.primaryContainer,
          cs.primary,
          Icons.inbox_outlined,
        ),
      DonyEmptyStateType.error => (
          cs.errorLight,
          cs.error,
          Icons.wifi_off_rounded,
        ),
      _ => throw StateError('DonyEmptyState: type loading handled by early return'),
    };

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(DonySpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            (mascotte != null
                    ? DonyMascotte(type: mascotte!, size: DonyMascotteSize.lg)
                    : DonyIconContainer(
                        icon: icon ?? defaultIcon,
                        size: DonyIconContainerSize.xl,
                        backgroundColor: bg,
                        iconColor: ic,
                      ))
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                .scaleXY(begin: 0.82, duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: DonySpacing.xl),
            Text(
              title,
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ).animate(delay: 80.ms).fadeIn(duration: 300.ms).slideY(begin: 0.05),
            if (description != null) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                description!,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ).animate(delay: 140.ms).fadeIn(duration: 300.ms),
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
              ).animate(delay: 200.ms).fadeIn(duration: 300.ms).slideY(begin: 0.05),
            ],
          ],
        ),
      ),
    );
  }
}
