import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Trajet d'un colis : ville de départ, court connecteur pointillé portant
/// l'icône du mode de transport, ville d'arrivée.
///
/// Rendu en texte enrichi : tient sur une ligne quand la place suffit, sinon
/// passe à la ligne comme un texte (noms longs, texte agrandi), sans jamais
/// déborder. Lu « De Paris à Dakar » par les lecteurs d'écran, l'icône
/// restant décorative.
class RouteLabel extends StatelessWidget {
  const RouteLabel({
    super.key,
    required this.from,
    required this.to,
    this.transportMode,
    this.style,
  });

  final String from;
  final String to;

  /// Mode du trajet quand il est connu, avion sinon.
  final TransportMode? transportMode;

  /// Style des villes, celui du texte ambiant par défaut.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style.merge(style);
    return Semantics(
      container: true,
      label: context.l10n.suiviRouteSemantics(from, to),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: from),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _RouteConnector(
                mode: transportMode ?? TransportMode.plane,
                fontSize: textStyle.fontSize ?? 14,
              ),
            ),
            TextSpan(text: to),
          ],
        ),
        style: textStyle,
      ),
    );
  }
}

/// Trait pointillé de part et d'autre de l'icône du mode de transport.
class _RouteConnector extends StatelessWidget {
  const _RouteConnector({required this.mode, required this.fontSize});

  final TransportMode mode;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconSize = (fontSize * 0.8).clamp(12.0, 20.0);
    Widget icon = Icon(mode.icon, size: iconSize, color: cs.primary);
    // L'avion pointe vers le haut : quart de tour, dans le sens du trajet.
    if (mode == TransportMode.plane) {
      icon = RotatedBox(quarterTurns: 1, child: icon);
    }
    final dotsWidth = iconSize * 0.6;
    // Pile de taille fixe plutôt qu'une ligne : dans une colonne très étroite
    // (texte agrandi), le connecteur est rogné au lieu de déborder.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: (fontSize * 0.25).clamp(3.0, 6.0),
      ),
      child: SizedBox(
        width: dotsWidth * 2 + iconSize,
        height: iconSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DotsPainter(
                  color: cs.primary.withValues(alpha: 0.45),
                  gap: iconSize,
                ),
              ),
            ),
            icon,
          ],
        ),
      ),
    );
  }
}

/// Deux points de chaque côté de l'icône, qui occupe le [gap] central.
class _DotsPainter extends CustomPainter {
  const _DotsPainter({required this.color, required this.gap});

  final Color color;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = (size.height / 16).clamp(0.9, 1.5);
    final y = size.height / 2;
    final side = (size.width - gap) / 2;
    for (final x in [
      side * 0.25,
      side * 0.75,
      side + gap + side * 0.25,
      side + gap + side * 0.75,
    ]) {
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.gap != gap;
}
