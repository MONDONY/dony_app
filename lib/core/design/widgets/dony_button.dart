import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DonyButtonVariant { primary, secondary, ghost, destructive }

class DonyButton extends StatefulWidget {
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
  State<DonyButton> createState() => _DonyButtonState();
}

class _DonyButtonState extends State<DonyButton> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _pressed = true);
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _handleTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final spinnerColor = switch (widget.variant) {
      DonyButtonVariant.primary     => DonyColors.white,
      DonyButtonVariant.destructive => DonyColors.white,
      DonyButtonVariant.secondary   => DonyColors.ink900,
      DonyButtonVariant.ghost       => DonyColors.primary,
    };

    final child = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
          )
        : Row(
            mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 18), const SizedBox(width: DonySpacing.xs)],
              Text(widget.label),
              if (widget.iconRight != null) ...[const SizedBox(width: DonySpacing.xs), Icon(widget.iconRight, size: 18)],
            ],
          );

    final minSize = widget.fullWidth ? const Size.fromHeight(52) : const Size(120, 52);
    const contentPadding = EdgeInsets.symmetric(horizontal: 16);

    final button = switch (widget.variant) {
      DonyButtonVariant.primary => FilledButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: FilledButton.styleFrom(
            minimumSize: minSize,
            padding: contentPadding,
          ),
          child: child,
        ),
      DonyButtonVariant.secondary => OutlinedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: minSize,
            padding: contentPadding,
          ),
          child: child,
        ),
      DonyButtonVariant.ghost => TextButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: TextButton.styleFrom(
            minimumSize: minSize,
            padding: contentPadding,
          ),
          child: child,
        ),
      DonyButtonVariant.destructive => FilledButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: DonyColors.error,
            minimumSize: minSize,
            padding: contentPadding,
          ),
          child: child,
        ),
    };

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: button,
      ),
    );
  }
}
