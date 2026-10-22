import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Corridor d'une demande d'envoi : ville de départ à gauche, d'arrivée à
/// droite, flèche pointillée entre les deux. Les drapeaux se déduisent des
/// villes ([cityFlag]) ; sans drapeau connu, seul le libellé « Départ » /
/// « Arrivée » s'affiche.
///
/// Partagé par le détail d'une demande (carte héros) et par la feuille « Faire
/// une offre » (rappel de la demande, [compact] pour le résumé).
class RequestCorridor extends StatelessWidget {
  const RequestCorridor({
    required this.departureCity,
    required this.arrivalCity,
    this.compact = false,
    super.key,
  });

  final String departureCity;
  final String arrivalCity;

  /// Variante resserrée : villes plus petites, flèche plus courte. Pour les
  /// lignes d'un résumé où la place manque.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final depFlag = cityFlag(departureCity);
    final arrFlag = cityFlag(arrivalCity);
    final cityStyle = tt.headlineMedium?.copyWith(
      fontSize: compact ? 16 : 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: cs.onSurface,
    );
    final subStyle = (compact ? tt.labelSmall : tt.labelMedium)?.copyWith(
      color: cs.onSurfaceVariant,
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                departureCity,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: cityStyle,
              ),
              const SizedBox(height: 2),
              Text(
                '${depFlag != null ? '$depFlag ' : ''}'
                '${l.requestPublicFromLabel}',
                style: subStyle,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
          child: _CorridorArrow(compact: compact),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                arrivalCity,
                maxLines: 2,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: cityStyle,
              ),
              const SizedBox(height: 2),
              Text(
                '${l.requestPublicToLabel}'
                '${arrFlag != null ? ' $arrFlag' : ''}',
                textAlign: TextAlign.end,
                style: subStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Flèche du corridor : ligne pointillée qui part d'un point (départ), avion
/// dans une pastille au milieu, pointe de flèche à l'arrivée. Couleurs unies.
class _CorridorArrow extends StatelessWidget {
  const _CorridorArrow({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final badge = compact ? 20.0 : 24.0;
    return ExcludeSemantics(
      child: SizedBox(
        width: compact ? 56 : 76,
        height: compact ? 22 : 28,
        child: CustomPaint(
          painter: _CorridorArrowPainter(
            line: cs.outline,
            dot: cs.primary,
            head: cs.warning,
            surface: cs.surface,
          ),
          child: Center(
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: RotatedBox(
                quarterTurns: 1,
                child: Icon(
                  Icons.flight_rounded,
                  size: compact ? 12 : 14,
                  color: cs.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CorridorArrowPainter extends CustomPainter {
  const _CorridorArrowPainter({
    required this.line,
    required this.dot,
    required this.head,
    required this.surface,
  });

  final Color line;
  final Color dot;
  final Color head;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const dotR = 3.5;
    const headLen = 6.0;
    final dash = Paint()
      ..color = line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // Pointillé de la pastille de départ jusqu'à la pointe.
    var x = dotR * 2 + 2;
    final endX = size.width - headLen - 2;
    while (x < endX) {
      canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, endX), y), dash);
      x += 8;
    }
    canvas
      ..drawCircle(Offset(dotR, y), dotR, Paint()..color = surface)
      ..drawCircle(
        Offset(dotR, y),
        dotR - 1,
        Paint()
          ..color = dot
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    final arrow = Paint()
      ..color = head
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width - headLen - 1, y - 5)
        ..lineTo(size.width - 1, y)
        ..lineTo(size.width - headLen - 1, y + 5),
      arrow,
    );
  }

  @override
  bool shouldRepaint(_CorridorArrowPainter old) =>
      old.line != line ||
      old.dot != dot ||
      old.head != head ||
      old.surface != surface;
}
