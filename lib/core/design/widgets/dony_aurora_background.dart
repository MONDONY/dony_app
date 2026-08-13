import 'dart:ui';

import 'package:flutter/material.dart';

/// 6 variantes d'aurora pour fonds glassmorphism.
enum DonyAurora {
  /// Rose → violet → bleu. Marketplace, listing voyageurs.
  pink,

  /// Pêche → corail → rouge. Wizard création, formulaires.
  peach,

  /// Bleu → cyan → violet. Thread négo, comm structurée.
  blue,

  /// Vert → turquoise → bleu. Hub Envoyer (sender), envois.
  green,

  /// Violet → rose → corail. Cards demandes, package_request.
  violet,

  /// Cyan → bleu → lavande. Carousel near-me, géolocalisation.
  cyan,
}

/// Fond aurora (gradient linéaire + 2 blobs flouts) à mettre derrière
/// des surfaces en verre (`DonyGlassCard`, `DonyGlassDarkFloating`, etc.).
///
/// Wrap toute la page :
/// ```dart
/// Scaffold(
///   body: DonyAuroraBackground(
///     variant: DonyAurora.green,
///     child: YourContent(),
///   ),
/// )
/// ```
class DonyAuroraBackground extends StatelessWidget {
  const DonyAuroraBackground({
    super.key,
    required this.variant,
    required this.child,
  });

  final DonyAurora variant;
  final Widget child;

  _AuroraSpec get _spec => switch (variant) {
    DonyAurora.pink => const _AuroraSpec(
      gradient: [Color(0xFFFFD0E7), Color(0xFFC5A6FF), Color(0xFF7DA5FF)],
      blobAColor: Color(0xFFFF6FB5),
      blobBColor: Color(0xFF7B5BFF),
    ),
    DonyAurora.peach => const _AuroraSpec(
      gradient: [Color(0xFFFFE3B5), Color(0xFFFF9678), Color(0xFFE64C7E)],
      blobAColor: Color(0xFFFFB37A),
      blobBColor: Color(0xFFFF4D8A),
    ),
    DonyAurora.blue => const _AuroraSpec(
      gradient: [Color(0xFFBCE8FF), Color(0xFF7CB0FF), Color(0xFF7460FF)],
      blobAColor: Color(0xFF5EE0FF),
      blobBColor: Color(0xFF5B6AFF),
    ),
    DonyAurora.green => const _AuroraSpec(
      gradient: [Color(0xFFC5F3D5), Color(0xFF7DE0B8), Color(0xFF5EBED4)],
      blobAColor: Color(0xFF5EE5A0),
      blobBColor: Color(0xFF5EB8FF),
    ),
    DonyAurora.violet => const _AuroraSpec(
      gradient: [Color(0xFFE4C5FF), Color(0xFFFFA5D8), Color(0xFFFF8775)],
      blobAColor: Color(0xFFC77DFF),
      blobBColor: Color(0xFFFF5B85),
    ),
    DonyAurora.cyan => const _AuroraSpec(
      gradient: [Color(0xFFB5F0FF), Color(0xFF82C5FF), Color(0xFFA899FF)],
      blobAColor: Color(0xFF5EE0FF),
      blobBColor: Color(0xFF7B85FF),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return RepaintBoundary(
      child: Stack(
        children: [
          // Base gradient (toujours visible)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: spec.gradient,
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          // Blob A — top-left, donne du chaud
          Positioned(
            top: -60,
            left: -60,
            child: _Blob(color: spec.blobAColor, size: 280, opacity: 0.55),
          ),
          // Blob B — bottom-right, donne de la profondeur
          Positioned(
            bottom: -80,
            right: -80,
            child: _Blob(color: spec.blobBColor, size: 320, opacity: 0.5),
          ),
          // Contenu au-dessus
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class _AuroraSpec {
  const _AuroraSpec({
    required this.gradient,
    required this.blobAColor,
    required this.blobBColor,
  });

  final List<Color> gradient;
  final Color blobAColor;
  final Color blobBColor;
}
