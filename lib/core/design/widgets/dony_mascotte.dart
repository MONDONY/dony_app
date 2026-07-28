import 'package:dony/core/design/tokens/animation_tokens.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Côté de décodage des PNG, en pixels.
///
/// La plus grande taille de rendu réellement employée est [DonyMascotteSize.lg]
/// (160 pt) ; 480 px la couvre jusqu'à un ratio de 3. Volontairement constant
/// plutôt que dérivé de la taille demandée : `ResizeImage` est clé par
/// dimension cible, donc un calcul par taille ferait vivre plusieurs copies
/// décodées du même fichier dans l'`ImageCache`.
const int _kDecodeSize = 480;

/// Types de mascotte disponibles — 11 situations alignées sur les assets.
enum DonyMascotteType {
  joyeux,
  bienvenue,
  confiant,
  securise,
  succes,
  enCourse,
  assis,
  aucunResultat,
  attente,
  erreur,
  erreurLegere;

  String get assetPath => switch (this) {
        joyeux        => 'assets/mascotte/hello.png',
        bienvenue     => 'assets/mascotte/welcome.png',
        confiant      => 'assets/mascotte/travel.png',
        securise      => 'assets/mascotte/success.png',
        succes        => 'assets/mascotte/success_celebration.png',
        enCourse      => 'assets/mascotte/travel.png',
        assis         => 'assets/mascotte/search.png',
        aucunResultat => 'assets/mascotte/no_result.png',
        attente       => 'assets/mascotte/waiting.png',
        erreur        => 'assets/mascotte/error.png',
        erreurLegere  => 'assets/mascotte/error_light.png',
      };

  String get semanticLabel => switch (this) {
        joyeux        => 'Mascotte qui salue',
        bienvenue     => 'Mascotte accueillante, bras ouverts',
        confiant      => 'Mascotte prête à partir en voyage',
        securise      => 'Mascotte brandissant un badge de validation',
        succes        => 'Mascotte célébrant une réussite',
        enCourse      => 'Colis en transit',
        assis         => 'Mascotte curieuse, une loupe à la main',
        aucunResultat => 'Mascotte perplexe devant une carte, aucun résultat',
        attente       => 'Mascotte patientant devant une horloge',
        erreur        => 'Mascotte inquiète, une erreur est survenue',
        erreurLegere  => 'Mascotte signalant un souci mineur',
      };

  /// Vrai pour les types dont l'animation tourne tant que la mascotte est
  /// visible, au lieu de se jouer une fois à l'entrée.
  bool get loops => this == attente;
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
      cacheWidth: _kDecodeSize,
      cacheHeight: _kDecodeSize,
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
/// La plupart des types jouent une entrée unique (< 500 ms). [DonyMascotteType]
/// expose `loops` pour ceux qui respirent en continu ; leur animation est
/// coupée quand l'utilisateur a demandé la réduction du mouvement.
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
    Widget mascot = DonyMascotte(
      type: type,
      size: size,
      customDimension: customDimension,
      fit: fit,
    );

    if (type.loops) {
      // Une boucle infinie sans frontière de repeinture ferait ré-enregistrer
      // toute la couche parente à chaque vsync, aussi longtemps que l'écran
      // reste ouvert — précisément le cas des surfaces d'attente.
      mascot = RepaintBoundary(child: mascot);
      // `Animate.defaultDuration`, que l'app pose pour la réduction du
      // mouvement, ne s'applique pas aux durées explicites et n'arrête pas un
      // `repeat()` : le réglage doit être consulté ici.
      if (MediaQuery.disableAnimationsOf(context)) {
        return _wrapGlow(context, mascot);
      }
    }

    return _wrapGlow(context, _animate(mascot));
  }

  Widget _wrapGlow(BuildContext context, Widget mascot) {
    if (!withGlow) {
      return mascot;
    }

    final dim = customDimension ?? size.dimension;
    final cs = Theme.of(context).colorScheme;
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

  /// Entrée qui grandit — pour les moments positifs (accueil, validation).
  Widget _scaleIn(
    Widget child, {
    required double begin,
    required int fade,
    required int scale,
    Curve curve = Curves.easeOutBack,
  }) =>
      child
          .animate()
          .fadeIn(duration: fade.ms)
          .scaleXY(begin: begin, duration: scale.ms, curve: curve);

  /// Entrée qui glisse — pour les états de progression et les alertes.
  Widget _slideIn(
    Widget child, {
    required int fade,
    required int slide,
    double dy = 0,
    double dx = 0,
  }) {
    final animation = child.animate().fadeIn(duration: fade.ms);
    return dx != 0
        ? animation.slideX(begin: dx, duration: slide.ms, curve: DonyCurve.enter)
        : animation.slideY(begin: dy, duration: slide.ms, curve: DonyCurve.enter);
  }

  /// Respiration continue — pour les états qui durent.
  Widget _breathe(Widget child, {required int duration}) => child
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .scaleXY(
        begin: 0.98,
        end: 1.02,
        duration: duration.ms,
        curve: Curves.easeInOut,
      );

  Widget _animate(Widget child) => switch (type) {
        DonyMascotteType.joyeux =>
          _scaleIn(child, begin: 0.85, fade: 400, scale: 500),
        DonyMascotteType.bienvenue =>
          _scaleIn(child, begin: 0.90, fade: 350, scale: 450),
        DonyMascotteType.securise =>
          _scaleIn(child, begin: 0.88, fade: 300, scale: 480),
        DonyMascotteType.succes =>
          _scaleIn(child, begin: 0.80, fade: 300, scale: 480),
        DonyMascotteType.assis => _scaleIn(child,
            begin: 0.92, fade: 450, scale: 450, curve: DonyCurve.enter),
        DonyMascotteType.aucunResultat => _scaleIn(child,
            begin: 0.90, fade: 400, scale: 420, curve: DonyCurve.enter),
        DonyMascotteType.confiant =>
          _slideIn(child, fade: 250, slide: 350, dy: 0.06)
              .animate()
              .shimmer(duration: 600.ms, delay: 300.ms),
        DonyMascotteType.erreurLegere =>
          _slideIn(child, fade: 300, slide: 360, dy: 0.05),
        DonyMascotteType.enCourse =>
          _slideIn(child, fade: 250, slide: 400, dx: -0.1),
        DonyMascotteType.erreur =>
          _slideIn(child, fade: 300, slide: 320, dx: -0.03),
        DonyMascotteType.attente => _breathe(child, duration: 1200),
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
