import 'dart:ui' as ui;

import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dony/core/design/design_system.dart';

/// Side of a trip a marker represents.
enum MarkerSide { pickup, delivery }

class MarkerBitmapFactory {
  MarkerBitmapFactory._();

  // Bitmap canvases — kept small so markers are visually compact AND
  // accurate (the pin tip aligns with the bottom-centre, which is the
  // default Marker anchor → lat/lng exact).
  static const double _clusterSize = 64;

  // ─── New pin rendering (Phase B) ──────────────────────────────────────────
  static const double _iconSize = 22;

  static final Map<_MarkerKey, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> pin({
    required TransportMode? mode,
    required MarkerSide side,
    double? rating,
  }) async {
    final key = _MarkerKey(
      mode: mode,
      side: side,
      ratingTenths: rating == null ? null : (rating * 10).round(),
    );
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    final bitmap = await _renderPin(mode: mode, side: side, rating: rating);
    _cache[key] = bitmap;
    return bitmap;
  }

  @visibleForTesting
  static void clearCache() {
    _cache.clear();
  }

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

  static Future<BitmapDescriptor> _renderPin({
    required TransportMode? mode,
    required MarkerSide side,
    double? rating,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const size = 48.0;
    const center = Offset(size / 2, size / 2);
    const radius = size / 2 - 2; // Small inset for clarity

    // Solid blue circle background
    final bgPaint = Paint()
      ..color = DonyColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Optional: subtle white border for contrast
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // Transport icon centered (white color)
    final iconData = (mode ?? TransportMode.other).icon;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          fontSize: _iconSize,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(center.dx - iconPainter.width / 2,
          center.dy - iconPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

}

class _MarkerKey {
  const _MarkerKey({
    required this.mode,
    required this.side,
    required this.ratingTenths,
  });

  final TransportMode? mode;
  final MarkerSide side;
  final int? ratingTenths;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MarkerKey &&
          mode == other.mode &&
          side == other.side &&
          ratingTenths == other.ratingTenths;

  @override
  int get hashCode => Object.hash(mode, side, ratingTenths);
}
