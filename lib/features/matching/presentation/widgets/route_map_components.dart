import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class RouteMapCard extends StatelessWidget {
  final String departureCode;
  final String arrivalCode;
  final String departureCity;
  final String arrivalCity;

  const RouteMapCard({
    super.key,
    required this.departureCode,
    required this.arrivalCode,
    required this.departureCity,
    required this.arrivalCity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.neutral200),
      ),
      child: Row(
        children: [
          CityChip(cityCode: departureCity, airportCode: departureCode),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
              child: CustomPaint(
                size: const Size(double.infinity, 24),
                painter: DashedRoutePainter(),
              ),
            ),
          ),
          CityChip(cityCode: arrivalCity, airportCode: arrivalCode),
        ],
      ),
    );
  }
}

class CityChip extends StatelessWidget {
  final String cityCode;
  final String airportCode;

  const CityChip({
    super.key,
    required this.cityCode,
    required this.airportCode,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: DonyColors.neutral100,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        '$cityCode · $airportCode',
        style: tt.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: DonyColors.ink900,
        ),
      ),
    );
  }
}

class DashedRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DonyColors.terra500
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double x = 0;
    final y = size.height / 2;

    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashWidth).clamp(0, size.width), y),
        paint,
      );
      x += dashWidth + dashSpace;
    }

    final dotPaint = Paint()
      ..color = DonyColors.terra500
      ..style = PaintingStyle.fill;

    for (final fraction in [0.25, 0.5, 0.75]) {
      canvas.drawCircle(Offset(size.width * fraction, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
