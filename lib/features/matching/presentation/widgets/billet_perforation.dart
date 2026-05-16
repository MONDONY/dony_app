import 'package:flutter/material.dart';

/// Ligne de perforation d'un billet : pointillés + deux encoches latérales.
/// [notchColor] doit être la couleur du fond derrière le billet.
///
/// Les deux encoches utilisent [Transform.translate] pour déborder de 8 px
/// hors des limites du widget (à gauche et à droite), ce qui est intentionnel :
/// elles "mordent" dans les bords de la carte pour simuler une vraie
/// perforation physique. Par conséquent, **le parent ne doit pas clipper les
/// bords où les encoches se trouvent** (pas de `ClipRRect`, `ClipPath`, ou
/// `overflow: Clip.hardEdge` autour du billet à cet endroit), sinon les
/// encoches seront coupées et l'effet visuel sera rompu.
class BilletPerforation extends StatelessWidget {
  final Color notchColor;
  const BilletPerforation({super.key, required this.notchColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(
              40,
              (i) => Expanded(
                child: Container(
                  height: 1.5,
                  color: i.isEven ? cs.outline : Colors.transparent,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(-8, 0),
              child: _notch(notchColor),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Transform.translate(
              offset: const Offset(8, 0),
              child: _notch(notchColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notch(Color c) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
