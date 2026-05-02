import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dony/core/design/design_system.dart';

class MarkerBitmapFactory {
  MarkerBitmapFactory._();

  static const double _markerSize = 96; // logical px before pixel ratio
  static const double _clusterSize = 110;

  static Future<BitmapDescriptor> luggagePickup() =>
      _renderLuggage(DonyColors.primary);

  static Future<BitmapDescriptor> luggageDelivery() =>
      _renderLuggage(DonyColors.warning);

  static Future<BitmapDescriptor> clusterBadge(int count) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = _clusterSize;
    const center = Offset(size / 2, size / 2);

    // Outer halo
    final halo = Paint()
      ..color = DonyColors.primary.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2, halo);

    // Solid primary circle
    final fill = Paint()
      ..color = DonyColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2 - 14, fill);

    // White number
    final label = count > 99 ? '99+' : '$count';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: count > 99 ? 26 : 32,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _renderLuggage(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = _markerSize;
    const center = Offset(size / 2, size / 2);

    // Pin teardrop (circle + triangle pointing down)
    final pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const pinRadius = size / 2 - 8;
    canvas.drawCircle(Offset(center.dx, pinRadius + 4), pinRadius, pinPaint);

    final tail = Path()
      ..moveTo(center.dx - 12, pinRadius * 1.5)
      ..lineTo(center.dx, size - 4)
      ..lineTo(center.dx + 12, pinRadius * 1.5)
      ..close();
    canvas.drawPath(tail, pinPaint);

    // White inner circle for icon contrast
    final innerCircle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, pinRadius + 4), pinRadius * 0.6, innerCircle);

    // Luggage icon (using TextPainter on the Material icon glyph)
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.luggage_rounded.codePoint),
        style: TextStyle(
          fontFamily: Icons.luggage_rounded.fontFamily,
          package: Icons.luggage_rounded.fontPackage,
          fontSize: pinRadius * 0.9,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, pinRadius + 4 - tp.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
