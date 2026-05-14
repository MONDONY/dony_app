import 'package:dony/core/design/tokens/animation_tokens.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Types de mascotte disponibles — 8 expressions alignées sur les assets.
enum DonyMascotteType {
  joyeux,
  confiant,
  securise,
  tenantColis,
  donneColis,
  enCourse,
  assis,
  scan;

  String get assetPath => switch (this) {
        joyeux      => 'assets/mascotte/joyeux.png',
        confiant    => 'assets/mascotte/confiant.png',
        securise    => 'assets/mascotte/sécurisé.png',
        tenantColis => 'assets/mascotte/tenant_le_colis.png',
        donneColis  => 'assets/mascotte/donne_un_colis.png',
        enCourse    => 'assets/mascotte/en_course.png',
        assis       => 'assets/mascotte/assis.png',
        scan        => 'assets/mascotte/Scan.png',
      };

  String get semanticLabel => switch (this) {
        joyeux      => 'Mascotte joyeuse',
        confiant    => 'Mascotte confiante',
        securise    => 'Colis sécurisé',
        tenantColis => 'Mascotte tenant un colis',
        donneColis  => 'Mascotte donnant un colis',
        enCourse    => 'Colis en transit',
        assis       => 'Mascotte assise',
        scan        => 'Mascotte scannant',
      };
}

enum DonyMascotteSize {
  sm(64),
  md(96),
  lg(160),
  xl(240);

  const DonyMascotteSize(this.dimension);
  final double dimension;
}

/// Widget statique — rendu direct de l'image sans animation.
/// Préférer [DonyMascotteAnimated] pour tout nouvel usage.
/// Ne jamais utiliser `Image.asset('assets/mascotte/...')` directement.
class DonyMascotte extends StatelessWidget {
  const DonyMascotte({
    super.key,
    required this.type,
    this.size = DonyMascotteSize.md,
    this.customDimension,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  final DonyMascotteType type;
  final DonyMascotteSize size;

  /// Override de la taille standard. Prend le pas sur [size] si non null.
  final double? customDimension;

  final BoxFit fit;

  /// Applique un ClipRRect si non null.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final dim = customDimension ?? size.dimension;
    final image = Image.asset(
      type.assetPath,
      width: dim,
      height: dim,
      fit: fit,
      semanticLabel: type.semanticLabel,
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

/// Wrapper animé autour de [DonyMascotte] avec presets flutter_animate par type.
///
/// Chaque type a une animation d'entrée distincte (< 500 ms, easeOutCubic).
/// `scan` utilise un pulse répété pendant toute la durée du scan.
///
/// ```dart
/// // Entrée standard
/// DonyMascotteAnimated(type: DonyMascotteType.joyeux, size: DonyMascotteSize.lg)
///
/// // Succès avec halo ambient
/// DonyMascotteAnimated(type: DonyMascotteType.securise, withGlow: true)
/// ```
class DonyMascotteAnimated extends StatelessWidget {
  const DonyMascotteAnimated({
    super.key,
    required this.type,
    this.size = DonyMascotteSize.md,
    this.customDimension,
    this.fit = BoxFit.contain,
    this.withGlow = false,
  });

  final DonyMascotteType type;
  final DonyMascotteSize size;
  final double? customDimension;
  final BoxFit fit;

  /// Halo radial ambient derrière la mascotte — réservé aux écrans success/KYC.
  final bool withGlow;

  @override
  Widget build(BuildContext context) {
    final dim = customDimension ?? size.dimension;
    final cs = Theme.of(context).colorScheme;

    Widget mascot = DonyMascotte(
      type: type,
      size: size,
      customDimension: customDimension,
      fit: fit,
    );

    mascot = _animate(mascot);

    if (!withGlow) {
      return mascot;
    }

    final glowColor = cs.brightness == Brightness.light
        ? DonyColors.primary.withValues(alpha: 0.15)
        : DonyColors.blueDark500.withValues(alpha: 0.20);

    return SizedBox(
      width: dim * 1.4,
      height: dim * 1.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: dim * 1.4,
            height: dim * 1.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [glowColor, Colors.transparent],
              ),
            ),
          ),
          mascot,
        ],
      ),
    );
  }

  Widget _animate(Widget child) => switch (type) {
        DonyMascotteType.joyeux => child
            .animate()
            .fadeIn(duration: 400.ms)
            .scaleXY(
              begin: 0.85,
              duration: 500.ms,
              curve: Curves.easeOutBack,
            ),
        DonyMascotteType.confiant => child
            .animate()
            .fadeIn(duration: 250.ms)
            .slideY(
              begin: 0.06,
              duration: 350.ms,
              curve: DonyCurve.enter,
            )
            .shimmer(duration: 600.ms, delay: 300.ms),
        DonyMascotteType.securise => child
            .animate()
            .fadeIn(duration: 300.ms)
            .scaleXY(
              begin: 0.88,
              duration: 480.ms,
              curve: Curves.easeOutBack,
            ),
        DonyMascotteType.tenantColis => child
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(
              begin: 0.08,
              duration: 420.ms,
              curve: DonyCurve.enter,
            ),
        DonyMascotteType.donneColis => child
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(
              begin: -0.06,
              duration: 400.ms,
              curve: DonyCurve.enter,
            ),
        DonyMascotteType.enCourse => child
            .animate()
            .fadeIn(duration: 250.ms)
            .slideX(
              begin: -0.1,
              duration: 400.ms,
              curve: DonyCurve.enter,
            ),
        DonyMascotteType.assis => child
            .animate()
            .fadeIn(duration: 450.ms, curve: DonyCurve.enter)
            .scaleXY(
              begin: 0.92,
              duration: 450.ms,
              curve: DonyCurve.enter,
            ),
        DonyMascotteType.scan => child
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(
              begin: 0.97,
              end: 1.03,
              duration: 900.ms,
              curve: Curves.easeInOut,
            ),
      };
}

/// Halo ambient — utilisé indépendamment autour d'un widget quelconque.
///
/// ```dart
/// DonyGlowWrap(child: DonyMascotteAnimated(type: .securise))
/// ```
class DonyGlowWrap extends StatelessWidget {
  const DonyGlowWrap({
    super.key,
    required this.child,
    this.radius = DonySpacing.huge,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glowColor = cs.brightness == Brightness.light
        ? DonyColors.primary.withValues(alpha: 0.14)
        : DonyColors.blueDark500.withValues(alpha: 0.20);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [glowColor, Colors.transparent],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
