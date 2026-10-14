import 'dart:math' as math;

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
              child: _notch(notchColor, cs.outline, left: true),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Transform.translate(
              offset: const Offset(8, 0),
              child: _notch(notchColor, cs.outline, left: false),
            ),
          ),
        ],
      ),
    );
  }

  // L'encoche est remplie du fond derrière le billet, puis cerclée côté
  // intérieur seulement : sur une carte blanche posée sur le fond clair de
  // l'app, une encoche sans trait ne se voyait pas (FLUTTER-Q1).
  Widget _notch(Color fill, Color stroke, {required bool left}) => SizedBox(
    width: 16,
    height: 16,
    child: CustomPaint(
      painter: _NotchPainter(fill: fill, stroke: stroke, left: left),
    ),
  );
}

class _NotchPainter extends CustomPainter {
  _NotchPainter({required this.fill, required this.stroke, required this.left});

  final Color fill;
  final Color stroke;

  /// Encoche du bord gauche : son demi-cercle intérieur est à droite.
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(rect, Paint()..color = fill);
    canvas.drawArc(
      rect.deflate(0.5),
      left ? -math.pi / 2 : math.pi / 2,
      math.pi,
      false,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_NotchPainter old) =>
      old.fill != fill || old.stroke != stroke || old.left != left;
}
