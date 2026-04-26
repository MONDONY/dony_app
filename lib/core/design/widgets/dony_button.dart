import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum DonyButtonVariant { primary, secondary, ghost, destructive }

class DonyButton extends StatelessWidget {
  const DonyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DonyButtonVariant.primary,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DonyButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = isLoading
        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : (icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: DonySpacing.sm),
                  Text(label),
                ],
              )
            : Text(label));

    final content = SizedBox(width: double.infinity, child: _button(cs, child));
    return content;
  }

  Widget _button(ColorScheme cs, Widget child) {
    switch (variant) {
      case DonyButtonVariant.primary:
        return FilledButton(onPressed: onPressed, child: child);
      case DonyButtonVariant.secondary:
        return OutlinedButton(onPressed: onPressed, child: child);
      case DonyButtonVariant.ghost:
        return TextButton(onPressed: onPressed, child: child);
      case DonyButtonVariant.destructive:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          child: child,
        );
    }
  }
}
