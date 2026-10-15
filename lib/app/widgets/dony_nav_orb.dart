import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Bouton central « orb » de la bottom nav flottante — onglet Suivi / scan QR.
///
/// Disque uni `cs.primary` avec une icône scanner `cs.onPrimary`. Couleur
/// unie, sans dégradé, reflet ni halo flou (demande du propriétaire) ;
/// l'anneau plein s'élargit à l'état [active].
class DonyNavOrb extends StatelessWidget {
  const DonyNavOrb({
    super.key,
    required this.active,
    required this.onTap,
    this.size = defaultSize,
  });

  final bool active;
  final VoidCallback onTap;

  /// Diamètre par défaut — exposé pour que le parent (bottom nav) puisse
  /// calculer la géométrie de l'encoche sans instancier le widget.
  static const double defaultSize = 58;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: active,
      label: context.l10n.shellOrbTracking,
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
            color: cs.primary,
            boxShadow: [
              // Ombre portée neutre
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              // Anneau plein, plus large quand actif
              BoxShadow(
                color: cs.primary.withValues(alpha: active ? 0.22 : 0.12),
                spreadRadius: active ? 6 : 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: DonyIcon(
            'scan-line',
            size: size * 0.42,
            color: cs.onPrimary,
            semanticLabel: context.l10n.shellOrbQrScanner,
          ),
        ),
      ),
    );
  }
}
