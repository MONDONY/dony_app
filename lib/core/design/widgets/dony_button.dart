import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/shadow_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DonyButtonVariant { primary, secondary, ghost, destructive, success }

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
    if (widget.onPressed == null || widget.isLoading) {
      return;
    }
    setState(() => _pressed = true);
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _handleTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    final content = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _spinnerColor(cs),
            ),
          )
        : Row(
            mainAxisSize:
                widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const SizedBox(width: DonySpacing.xs),
              ],
              // En pleine largeur la Row est bornée : on rend le label
              // « shrink-safe » (FittedBox scaleDown) pour qu'un libellé long
              // ou un textScaleFactor élevé ne provoque jamais d'overflow
              // horizontal. En largeur intrinsèque (fullWidth=false) la Row
              // est non bornée → on garde un Text simple (Flexible y crasherait).
              if (widget.fullWidth)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(widget.label, maxLines: 1),
                  ),
                )
              else
                Text(widget.label),
              if (widget.iconRight != null) ...[
                const SizedBox(width: DonySpacing.xs),
                Icon(widget.iconRight, size: 18),
              ],
            ],
          );

    final minSize = widget.fullWidth
        ? const Size.fromHeight(52)
        : const Size(120, 52);
    const padding = EdgeInsets.symmetric(horizontal: DonySpacing.base);

    final button = switch (widget.variant) {
      DonyButtonVariant.primary => _GlowButton(
          colors: isLight
              ? [const Color(0xFF3B8AFF), DonyColors.blue500, DonyColors.blue700]
              : [const Color(0xFF6699FF), DonyColors.blueDark500, DonyColors.blueDark700],
          shadows: isLight ? DonyShadow.brand : DonyShadow.brandDark,
          foreground: DonyColors.textOnBrand,
          pressed: _pressed,
          fullWidth: widget.fullWidth,
          onPressed: widget.isLoading ? null : widget.onPressed,
          child: content,
        ),
      DonyButtonVariant.success => _GlowButton(
          colors: isLight
              ? [const Color(0xFF1AA574), DonyColors.success500]
              : [DonyColors.successDark500, const Color(0xFF22B882)],
          shadows: isLight ? DonyShadow.success : DonyShadow.successDark,
          foreground: DonyColors.textOnBrand,
          pressed: _pressed,
          fullWidth: widget.fullWidth,
          onPressed: widget.isLoading ? null : widget.onPressed,
          child: content,
        ),
      DonyButtonVariant.destructive => _GlowButton(
          colors: isLight
              ? [const Color(0xFFFF5252), DonyColors.danger500]
              : [DonyColors.dangerDark500, const Color(0xFFB02020)],
          shadows: isLight ? DonyShadow.danger : DonyShadow.dangerDark,
          foreground: DonyColors.textOnBrand,
          pressed: _pressed,
          fullWidth: widget.fullWidth,
          onPressed: widget.isLoading ? null : widget.onPressed,
          child: content,
        ),
      DonyButtonVariant.secondary => OutlinedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.primary,
            minimumSize: minSize,
            padding: padding,
            side: BorderSide(color: cs.primary, width: 1.5),
          ),
          child: content,
        ),
      DonyButtonVariant.ghost => TextButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurfaceVariant,
            minimumSize: minSize,
            padding: padding,
          ),
          child: content,
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

  Color _spinnerColor(ColorScheme cs) => switch (widget.variant) {
        DonyButtonVariant.primary     => DonyColors.textOnBrand,
        DonyButtonVariant.success     => DonyColors.textOnBrand,
        DonyButtonVariant.destructive => DonyColors.textOnBrand,
        DonyButtonVariant.secondary   => cs.primary,
        DonyButtonVariant.ghost       => cs.onSurfaceVariant,
      };
}

/// Bouton avec dégradé + ombre colorée (glow).
/// Utilisé pour primary, success, destructive.
class _GlowButton extends StatelessWidget {
  const _GlowButton({
    required this.colors,
    required this.shadows,
    required this.foreground,
    required this.pressed,
    required this.fullWidth,
    required this.onPressed,
    required this.child,
  });

  final List<Color> colors;
  final List<BoxShadow> shadows;
  final Color foreground;
  final bool pressed;
  final bool fullWidth;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DonyRadius.lg);
    final isDisabled = onPressed == null;

    final gradientColors = isDisabled
        ? colors.map((c) => c.withValues(alpha: 0.5)).toList()
        : pressed
            ? colors
                .map((c) => Color.lerp(c, Colors.black, 0.08)!)
                .toList()
            : colors;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 52,
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        boxShadow: (isDisabled || pressed) ? [] : shadows,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: DonySpacing.base),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: foreground,
                  ),
              child: IconTheme(
                data: IconThemeData(color: foreground, size: 18),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
