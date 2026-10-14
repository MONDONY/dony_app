import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/presentation/widgets/airline_logo.dart';
import 'package:flutter/material.dart';

/// Couleur de l'étiquette « billet ».
enum FlightPriceTicketTone {
  /// Prix trouvé sous le seuil : vert.
  hit,

  /// Meilleur prix vu, encore au-dessus du seuil : gris.
  neutral,

  /// Pas encore d'alerte : bleu, l'étiquette devient un bouton « Créer ».
  create,
}

/// Contour d'un billet : coins arrondis et une encoche en demi-cercle au
/// milieu de chaque côté, comme les billets de Yadony. Dessiné, jamais une
/// image : il suit la taille du contenu, le thème et le sens de lecture.
class FlightTicketBorder extends ShapeBorder {
  const FlightTicketBorder({
    this.radius = 9,
    this.notchRadius = 4,
    this.side = BorderSide.none,
  });

  final double radius;
  final double notchRadius;

  /// Contour, encoches comprises. Le ton neutre en a besoin : son gris pâle
  /// sur la rangée blanche ne se détachait pas (FLUTTER-Q1).
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final notches = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.left, rect.center.dy),
          radius: notchRadius,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.right, rect.center.dy),
          radius: notchRadius,
        ),
      );
    return Path.combine(PathOperation.difference, body, notches);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.width / 2), textDirection: textDirection),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) => FlightTicketBorder(
    radius: radius * t,
    notchRadius: notchRadius * t,
    side: side.scale(t),
  );

  @override
  bool operator ==(Object other) =>
      other is FlightTicketBorder &&
      other.radius == radius &&
      other.notchRadius == notchRadius &&
      other.side == side;

  @override
  int get hashCode => Object.hash(radius, notchRadius, side);
}

/// Étiquette de prix en forme de billet, à droite de la ligne « Alertes
/// prix vols » : le prix en gras et une petite ligne dessous (« −61 € sous
/// votre prix », « meilleur prix vu »), ou « Créer » seul.
class FlightPriceTicket extends StatelessWidget {
  const FlightPriceTicket({
    super.key,
    required this.tone,
    required this.label,
    this.caption,
  });

  final FlightPriceTicketTone tone;

  /// Prix (« 389 € ») ou « Créer ».
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (background, foreground) = switch (tone) {
      FlightPriceTicketTone.hit => (cs.successLight, cs.success),
      FlightPriceTicketTone.neutral => (
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
      ),
      FlightPriceTicketTone.create => (cs.primaryContainer, cs.primary),
    };
    final create = tone == FlightPriceTicketTone.create;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: FlightTicketBorder(
          side: tone == FlightPriceTicketTone.neutral
              ? BorderSide(color: cs.outline)
              : BorderSide.none,
        ),
      ),
      child: CustomPaint(
        painter: _TicketPerforation(color: foreground.withValues(alpha: 0.35)),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DonySpacing.md + DonySpacing.xxs,
            DonySpacing.xs + DonySpacing.xxs,
            DonySpacing.sm,
            DonySpacing.xs + DonySpacing.xxs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                maxLines: 1,
                style: tt.headlineSmall?.copyWith(
                  fontSize: create ? 13 : 15,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: foreground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  caption!,
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  // Petite ligne du billet, à la taille des libellés de la
                  // barre d'onglets : le billet doit laisser la place au
                  // trajet sur un écran de 360 points.
                  style: tt.labelSmall?.copyWith(
                    height: 1.1,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                    color: foreground.withValues(alpha: 0.9),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pointillé vertical près de l'encoche gauche, comme une perforation.
class _TicketPerforation extends CustomPainter {
  const _TicketPerforation({required this.color});

  final Color color;

  static const _inset = 5.0;
  static const _vertical = 6.0;
  static const _dash = 3.0;
  static const _gap = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    var y = _vertical;
    while (y < size.height - _vertical) {
      final end = (y + _dash).clamp(0.0, size.height - _vertical);
      canvas.drawLine(Offset(_inset, y), Offset(_inset, end), paint);
      y += _dash + _gap;
    }
  }

  @override
  bool shouldRepaint(_TicketPerforation oldDelegate) =>
      oldDelegate.color != color;
}

/// Pile de logos de compagnies (trois au plus), qui se chevauchent : les
/// compagnies des vols trouvés par une alerte.
class AirlineLogoStack extends StatelessWidget {
  const AirlineLogoStack({
    super.key,
    required this.codes,
    this.size = defaultSize,
  });

  final List<String> codes;
  final double size;

  static const defaultSize = 18.0;

  /// Chevauchement d'un logo sur le précédent : un sixième du diamètre, le
  /// code de chaque compagnie reste lisible en entier.
  static double overlapFor(double size) => size / 6;

  /// Largeur occupée par [count] logos de [size].
  static double widthFor(int count, {double size = defaultSize}) =>
      count <= 0 ? 0 : size + (count - 1) * (size - overlapFor(size));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = codes.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      key: const Key('airline-logo-stack'),
      width: widthFor(shown.length, size: size),
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, code) in shown.indexed)
            PositionedDirectional(
              start: i * (size - overlapFor(size)),
              // Liseré de la couleur de la carte, tracé à l'extérieur : il
              // détache chaque logo de celui qu'il recouvre.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.surface,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                child: AirlineLogo(code: code, size: size),
              ),
            ),
        ],
      ),
    );
  }
}
