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
  static const double _pinWidth = 64;
  static const double _pinHeight = 72;
  static const double _pinHeadRadius = 22;
  static const double _pinHeadCenterY = 24;
  static const double _innerCircleRadius = 13;
  static const double _iconSize = 22;
  static const double _badgeWidth = 28;
  static const double _badgeHeight = 16;

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

    final sideColor = side == MarkerSide.pickup
        ? DonyColors.primary
        : DonyColors.warning;

    // Pin head + tail
    final pinPaint = Paint()
      ..color = sideColor
      ..style = PaintingStyle.fill;
    final headCenter = Offset(_pinWidth / 2, _pinHeadCenterY);
    canvas.drawCircle(headCenter, _pinHeadRadius, pinPaint);
    final tail = Path()
      ..moveTo(headCenter.dx - 10, headCenter.dy + _pinHeadRadius - 4)
      ..lineTo(_pinWidth / 2, _pinHeight)
      ..lineTo(headCenter.dx + 10, headCenter.dy + _pinHeadRadius - 4)
      ..close();
    canvas.drawPath(tail, pinPaint);

    // White inner circle
    canvas.drawCircle(
      headCenter,
      _innerCircleRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Transport icon at center (color = side color)
    final iconData = (mode ?? TransportMode.other).icon;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          fontSize: _iconSize,
          color: sideColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(headCenter.dx - iconPainter.width / 2,
          headCenter.dy - iconPainter.height / 2),
    );

    // Rating badge (top-right)
    _drawRatingBadge(canvas, rating);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_pinWidth.toInt(), _pinHeight.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static void _drawRatingBadge(Canvas canvas, double? rating) {
    final left = _pinWidth - _badgeWidth;
    const top = 2.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, _badgeWidth, _badgeHeight),
      const Radius.circular(8),
    );

    // Subtle drop shadow
    canvas.drawRRect(
      rect.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0x1A000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    if (rating == null) {
      // "Nouveau" terracotta variant
      canvas.drawRRect(rect, Paint()..color = DonyColors.accent);
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Nouveau',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(left + (_badgeWidth - tp.width) / 2,
            top + (_badgeHeight - tp.height) / 2),
      );
      return;
    }

    // Rated variant: white bg + primary star + score
    canvas.drawRRect(rect, Paint()..color = Colors.white);

    const starIcon = Icons.star_rounded;
    final starPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(starIcon.codePoint),
        style: TextStyle(
          fontFamily: starIcon.fontFamily,
          package: starIcon.fontPackage,
          fontSize: 10,
          color: DonyColors.primary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final score = rating.toStringAsFixed(1);
    final scorePainter = TextPainter(
      text: TextSpan(
        text: score,
        style: const TextStyle(
          color: DonyColors.primary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final totalWidth = starPainter.width + 2 + scorePainter.width;
    final startX = left + (_badgeWidth - totalWidth) / 2;
    final centerY = top + _badgeHeight / 2;
    starPainter.paint(canvas, Offset(startX, centerY - starPainter.height / 2));
    scorePainter.paint(
      canvas,
      Offset(startX + starPainter.width + 2, centerY - scorePainter.height / 2),
    );
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
