import 'package:dony/core/design/accessibility_scope.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/shadow_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DonyButtonVariant { primary, secondary, ghost, destructive, success, accent }

class DonyButton extends StatefulWidget {
  const DonyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DonyButtonVariant.primary,
    this.icon,
    this.iconRight,
    this.iconAsset,
    this.iconRightAsset,
    this.isLoading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final DonyButtonVariant variant;
  final IconData? icon;
  final IconData? iconRight;

  /// Nom d'un SVG Lucide dans `assets/icons/` (sans extension), alternative à
  /// [icon] / [iconRight]. Teinté automatiquement par la couleur du variant.
  final String? iconAsset;
  final String? iconRightAsset;
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
              ] else if (widget.iconAsset != null) ...[
                // Builder : lit l'IconTheme du variant (foreground) pour teinter
                // le SVG comme un Icon Material l'aurait été.
                Builder(
                  builder: (ctx) => DonyIcon(
                    widget.iconAsset!,
                    size: 18,
                    color: IconTheme.of(ctx).color,
                  ),
                ),
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
              ] else if (widget.iconRightAsset != null) ...[
                const SizedBox(width: DonySpacing.xs),
                Builder(
                  builder: (ctx) => DonyIcon(
                    widget.iconRightAsset!,
                    size: 18,
                    color: IconTheme.of(ctx).color,
                  ),
                ),
              ],
            ],
          );

    final minSize = widget.fullWidth
        ? const Size.fromHeight(52)
        : const Size(120, 52);
    const padding = EdgeInsets.symmetric(horizontal: DonySpacing.base);

    // Le haut contraste remplace le dégradé par un aplat mesuré. Sans cette
    // bascule, le bouton garderait ses couleurs normales alors que tout le
    // reste de l'écran a basculé, et son libellé descendrait à 2.6:1.
    final hc = context.a11y.highContrast;
    final onBrand = _onBrand(hc: hc, isLight: isLight);

    final button = switch (widget.variant) {
      DonyButtonVariant.primary => _GlowButton(
          colors: hc
              ? _flat(cs.primary)
              : isLight
                  ? [const Color(0xFF1F6BF5), DonyColors.blue500, DonyColors.blue700]
                  : [const Color(0xFF6699FF), DonyColors.blueDark500, DonyColors.blueDark700],
          shadows: isLight ? DonyShadow.brand : DonyShadow.brandDark,
          foreground: onBrand,
          pressed: _pressed,
          fullWidth: widget.fullWidth,
          onPressed: widget.isLoading ? null : widget.onPressed,
          child: content,
        ),
      DonyButtonVariant.success => _GlowButton(
          colors: hc
              ? _flat(isLight ? DonyColors.successHc : DonyColors.successHcDark)
              : isLight
                  ? [const Color(0xFF0F8058), DonyColors.success700]
                  : [DonyColors.successDark500, const Color(0xFF22B882)],
          shadows: isLight ? DonyShadow.success : DonyShadow.successDark,
          foreground: onBrand,
          pressed: _pressed,
          fullWidth: widget.fullWidth,
          onPressed: widget.isLoading ? null : widget.onPressed,
          child: content,
        ),
      DonyButtonVariant.destructive => _GlowButton(
          colors: hc
              ? _flat(isLight ? DonyColors.dangerHc : DonyColors.dangerHcDark)
              : isLight
                  ? [DonyColors.danger500, DonyColors.danger700]
                  : [DonyColors.dangerDark500, const Color(0xFFD9453D)],
          shadows: isLight ? DonyShadow.danger : DonyShadow.dangerDark,
          foreground: onBrand,
          pressed: _pressed,
          fullWidth: widget.fullWidth,
          onPressed: widget.isLoading ? null : widget.onPressed,
          child: content,
        ),
      DonyButtonVariant.accent => _GlowButton(
          colors: hc
              ? _flat(isLight ? DonyColors.accentHc : DonyColors.accentHcDark)
              : isLight
                  ? [DonyColors.terra600, DonyColors.terra700]
                  : [DonyColors.terraDark500, const Color(0xFFD9743F)],
          shadows: DonyShadow.accent, // pas de variante sombre du glow accent
          foreground: onBrand,
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

  Color _spinnerColor(ColorScheme cs) {
    final onBrand = _onBrand(
      hc: context.a11y.highContrast,
      isLight: cs.brightness == Brightness.light,
    );
    return switch (widget.variant) {
      DonyButtonVariant.primary     => onBrand,
      DonyButtonVariant.success     => onBrand,
      DonyButtonVariant.destructive => onBrand,
      DonyButtonVariant.accent      => onBrand,
      DonyButtonVariant.secondary   => cs.primary,
      DonyButtonVariant.ghost       => cs.onSurfaceVariant,
    };
  }
}

/// Aplat uniforme : `_GlowButton` attend toujours un dégradé, deux fois la même
/// couleur donne une surface unie sans dupliquer sa logique de rendu.
List<Color> _flat(Color c) => [c, c];

/// Couleur du libellé posé sur un aplat de marque.
///
/// En haut contraste sombre les aplats sont clairs, donc le blanc n'y tient
/// pas. Ailleurs, le blanc reste correct sur les fonds sombres saturés.
/// Couleur du libellé posé sur un aplat de marque.
///
/// En thème sombre les aplats restent vifs, pour rester distincts du fond
/// (1.4.11, 3:1). Un libellé blanc n'y tiendrait pas : aucune couleur unique
/// ne satisfait à la fois « blanc lisible dessus » et « distinct du fond
/// sombre », les deux tirant en sens inverse. C'est donc le libellé qui
/// s'assombrit, comme le fait Material 3.
Color _onBrand({required bool hc, required bool isLight}) =>
    isLight ? DonyColors.textOnBrand : DonyColors.onBrandHcDark;

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
