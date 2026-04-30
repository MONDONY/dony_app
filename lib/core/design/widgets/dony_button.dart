import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';

enum DonyButtonVariant { primary, secondary, ghost, destructive }

class DonyButton extends StatelessWidget {
  const DonyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DonyButtonVariant.primary,
    this.icon,
    this.iconRight,
    this.isLoading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final DonyButtonVariant variant;
  final IconData? icon;
  final IconData? iconRight;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final spinnerColor = switch (variant) {
      DonyButtonVariant.primary     => DonyColors.white,
      DonyButtonVariant.destructive => DonyColors.white,
      DonyButtonVariant.secondary   => DonyColors.ink900,
      DonyButtonVariant.ghost       => DonyColors.primary,
    };

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: DonySpacing.xs)],
              Text(label),
              if (iconRight != null) ...[const SizedBox(width: DonySpacing.xs), Icon(iconRight, size: 18)],
            ],
          );

    final minSize = fullWidth ? const Size.fromHeight(52) : const Size(120, 52);

    return switch (variant) {
      DonyButtonVariant.primary => FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(minimumSize: minSize),
          child: child,
        ),
      DonyButtonVariant.secondary => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(minimumSize: minSize),
          child: child,
        ),
      DonyButtonVariant.ghost => TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(minimumSize: minSize),
          child: child,
        ),
      DonyButtonVariant.destructive => FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: DonyColors.error,
            minimumSize: minSize,
          ),
          child: child,
        ),
    };
  }
}
