import 'dart:ui';

import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Yadony Glassmorphism — 4 patterns canoniques
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// Pattern A · DonyGlassOnBrand        — glass clair sur fond brand (couleur unie)
// Pattern B · DonyGlassDarkSheet      — glass sombre immersif (sheet hero)
// Pattern C · DonyGlassCard           — glass clair flottant sur fond coloré
// Pattern D · DonyGlassDarkFloating   — glass sombre flottant sur fond coloré
//
// + DonyGlassChip, DonyGlassButton (atomes)
//
// CONTRAT LISIBILITÉ AA :
// - Patterns C/D : opacité plancher = 0.62 (assertion en dev).
// - Min font-size sur verre : 13px.
// - saturate ≈180% via backdrop pour intensifier les couleurs derrière.
// - Letter-spacing +0.2 sur les titres pour compensation visuelle.

// ─── Pattern A · DonyGlassOnBrand ──────────────────────────────────────────
//
// Existant : `profile_header.dart:294` (stats sur header brand).
// Background: white α=0.15 · Blur: 5×5 · Border: white α=0.25 · Text: white.
class DonyGlassOnBrand extends StatelessWidget {
  const DonyGlassOnBrand({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(DonyRadius.card);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.md,
              ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Pattern B · DonyGlassDarkSheet ────────────────────────────────────────
//
// Bottom sheet immersif (glass sombre plein écran ou quasi).
// Background: aplat ink-900 α=0.80-0.90 · Blur: 12×12 · Text: white.
// Couleur unie, pas de dégradé (demande du propriétaire).
class DonyGlassDarkSheet extends StatelessWidget {
  const DonyGlassDarkSheet({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.background,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  /// Aplat du fond (défaut : bleu nuit de la marque).
  final Color? background;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
        background ??
        (isDark ? const Color(0xFF1A2744) : const Color(0xFF0A2540));
    final bgAlpha = isDark ? 0.80 : 0.90;
    final borderAlpha = isDark ? 0.10 : 0.18;
    final radius = borderRadius ?? BorderRadius.circular(DonyRadius.card);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(DonySpacing.xl),
          decoration: BoxDecoration(
            color: base.withValues(alpha: bgAlpha),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
            ),
            boxShadow:
                boxShadow ??
                [
                  BoxShadow(
                    color: base.withValues(alpha: isDark ? 0.4 : 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── Pattern C · DonyGlassCard ─────────────────────────────────────────────
//
// Glass clair flottant sur fond coloré.
// Use cases : marketplace cards, listing cards, AppBar sur fond coloré.
// Background: white α=0.62 MIN · Blur: 14×14 · Border: white α=0.55 · Text: ink-900.
class DonyGlassCard extends StatelessWidget {
  const DonyGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DonySpacing.base),
    this.borderRadius,
    this.opacity = 0.62,
  }) : assert(
         opacity >= 0.62,
         'DonyGlassCard.opacity must be >= 0.62 (AA contrast contract). ' // i18n-ignore
         'Below 0.62, ink-900 text on a saturated background becomes unreadable.', // i18n-ignore
       );

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(22);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: DonyColors.ink800.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Pattern D · DonyGlassDarkFloating ─────────────────────────────────────
//
// Glass sombre flottant sur fond coloré — hero cards (prix actuel négo), FAB.
// Background: ink-900 α=0.62 MIN · Blur: 14×14 · Border: white α=0.18 · Text: white.
class DonyGlassDarkFloating extends StatelessWidget {
  const DonyGlassDarkFloating({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DonySpacing.base),
    this.borderRadius,
    this.opacity = 0.62,
    this.tint,
  }) : assert(
         opacity >= 0.62,
         'DonyGlassDarkFloating.opacity must be >= 0.62 (AA contrast contract).', // i18n-ignore
       );

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double opacity;

  /// Override the default ink-900 base — useful for status-themed hero
  /// (e.g. amber for AWAITING_TRIP, violet for AWAITING_PAYMENT).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(22);
    final base = tint ?? DonyColors.ink900;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: base.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: DonyColors.ink800.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Atomes glass — chip & button
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class DonyGlassChip extends StatelessWidget {
  const DonyGlassChip({
    super.key,
    required this.label,
    this.icon,
    this.active = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DonyRadius.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md + 1,
              vertical: DonySpacing.xs + 3,
            ),
            decoration: BoxDecoration(
              color: active
                  ? DonyColors.primary
                  : Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(DonyRadius.full),
              border: Border.all(
                color: active
                    ? DonyColors.primary
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14,
                    color: active ? Colors.white : cs.onSurface,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(
                      fontSize: 13, // never < 13 on glass
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum DonyGlassButtonVariant { primary, light }

class DonyGlassButton extends StatelessWidget {
  const DonyGlassButton({
    super.key,
    required this.label,
    this.variant = DonyGlassButtonVariant.primary,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final DonyGlassButtonVariant variant;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Si true, le bouton prend toute la largeur disponible.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPrimary = variant == DonyGlassButtonVariant.primary;
    final bgColor = isPrimary
        ? DonyColors.primary
        : Colors.white.withValues(alpha: 0.62);
    final fgColor = isPrimary ? Colors.white : cs.onSurface;
    final borderColor = isPrimary
        ? DonyColors.primary
        : Colors.white.withValues(alpha: 0.6);

    final button = ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.lg,
                vertical: DonySpacing.md + 1,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(DonyRadius.lg),
                border: Border.all(color: borderColor),
                boxShadow: isPrimary
                    ? [
                        BoxShadow(
                          color: DonyColors.primary.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fgColor),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: fgColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
