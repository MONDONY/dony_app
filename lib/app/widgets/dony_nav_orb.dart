import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Glint cyan décoratif (bas-droite de la sphère) — accent glossy, non sémantique.
const Color _kOrbGlint = Color(0xFF5AFFD2);

/// Bouton central « orb » de la bottom nav flottante — onglet Suivi / scan QR.
///
/// Sphère glossy bleue en relief avec une icône scanner blanche. Le halo
/// s'intensifie à l'état [active]. Les couleurs du halo dérivent du
/// [ColorScheme] pour rester cohérentes en thème clair comme sombre ; le dégradé
/// de la sphère reste un bleu de marque (primitive) sur les deux thèmes.
class DonyNavOrb extends StatelessWidget {
  const DonyNavOrb({
    super.key,
    required this.active,
    required this.onTap,
    this.size = 58,
  });

  final bool active;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: active,
      label: 'Suivi',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.35, -0.45),
              radius: 1.05,
              colors: [
                DonyColors.blue300,
                DonyColors.blue500,
                DonyColors.blue800,
              ],
              stops: [0.0, 0.52, 1.0],
            ),
            boxShadow: [
              // Halo coloré (s'intensifie quand actif)
              BoxShadow(
                color: cs.primary.withValues(alpha: active ? 0.60 : 0.42),
                blurRadius: active ? 28 : 20,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
              // Ombre portée neutre
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              // Anneau diffus
              BoxShadow(
                color: cs.primary.withValues(alpha: active ? 0.22 : 0.12),
                spreadRadius: active ? 6 : 4,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Reflet spéculaire (haut-gauche)
              Positioned(
                top: size * 0.15,
                left: size * 0.17,
                child: Container(
                  width: size * 0.36,
                  height: size * 0.28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Glint cyan (bas-droite)
              Positioned(
                bottom: size * 0.12,
                right: size * 0.13,
                child: Container(
                  width: size * 0.32,
                  height: size * 0.32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _kOrbGlint.withValues(alpha: 0.45),
                        _kOrbGlint.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              DonyIcon(
                'scan-line',
                size: size * 0.42,
                color: Colors.white,
                semanticLabel: 'Scanner',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
