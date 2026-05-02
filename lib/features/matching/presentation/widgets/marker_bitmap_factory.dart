import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dony/core/design/design_system.dart';

class MarkerBitmapFactory {
  MarkerBitmapFactory._();

  // Bitmap canvases — kept small so markers are visually compact AND
  // accurate (the pin tip aligns with the bottom-centre, which is the
  // default Marker anchor → lat/lng exact).
  static const double _markerSize = 56;
  static const double _clusterSize = 64;

  static Future<BitmapDescriptor> luggagePickup() =>
      _renderLuggage(DonyColors.primary);

  static Future<BitmapDescriptor> luggageDelivery() =>
      _renderLuggage(DonyColors.warning);

  static Future<BitmapDescriptor> clusterBadge(int count) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = _clusterSize;
    const center = Offset(size / 2, size / 2);

    final halo = Paint()
      ..color = DonyColors.primary.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2, halo);

    final fill = Paint()
      ..color = DonyColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2 - 8, fill);

    final label = count > 99 ? '99+' : '$count';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: count > 99 ? 16 : 20,
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

    // Pin geometry: head circle on top, tail tip at the very bottom
    // (y = size) so the default anchor (0.5, 1.0) lands exactly on the
    // real lat/lng coordinate.
    const headRadius = 18.0;
    const headCenter = Offset(size / 2, headRadius + 2);

    final pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(headCenter, headRadius, pinPaint);

    final tail = Path()
      ..moveTo(headCenter.dx - 8, headCenter.dy + headRadius - 4)
      ..lineTo(size / 2, size) // tip exactly at bottom-centre
      ..lineTo(headCenter.dx + 8, headCenter.dy + headRadius - 4)
      ..close();
    canvas.drawPath(tail, pinPaint);

    final innerCircle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(headCenter, headRadius * 0.62, innerCircle);

    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.luggage_rounded.codePoint),
        style: TextStyle(
          fontFamily: Icons.luggage_rounded.fontFamily,
          package: Icons.luggage_rounded.fontPackage,
          fontSize: headRadius * 0.95,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(headCenter.dx - tp.width / 2, headCenter.dy - tp.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
