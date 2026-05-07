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

  static const double _clusterSize = 64;
  static const double _iconSize = 22;

  static final Map<_MarkerKey, BitmapDescriptor> _cache = {};
  static final Map<_PricePillKey, BitmapDescriptor> _pillCache = {};

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
    _pillCache.clear();
  }

  // ─── Price pill marker (style Cocolis) ────────────────────────────────────

  static Future<BitmapDescriptor> pricePill({
    required double pricePerKg,
    bool isHighlighted = false,
  }) async {
    final key = _PricePillKey(
      priceCents: (pricePerKg * 100).round(),
      isHighlighted: isHighlighted,
    );
    final cached = _pillCache[key];
    if (cached != null) return cached;
    final bitmap = await _renderPricePill(pricePerKg: pricePerKg, isHighlighted: isHighlighted);
    _pillCache[key] = bitmap;
    return bitmap;
  }

  static Future<BitmapDescriptor> _renderPricePill({
    required double pricePerKg,
    required bool isHighlighted,
  }) async {
    final label = pricePerKg == pricePerKg.roundToDouble()
        ? '${pricePerKg.toInt()}€/kg'
        : '${pricePerKg.toStringAsFixed(1)}€/kg';

    const fontSize = 13.0;
    const paddingH = 12.0;
    const paddingV = 7.0;

    final textColor = isHighlighted ? Colors.white : const Color(0xFF061833);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pillW = tp.width + paddingH * 2;
    final pillH = tp.height + paddingV * 2;
    // Extra space for shadow
    const shadowSpread = 4.0;
    const shadowOffY = 2.0;
    final canvasW = pillW + shadowSpread * 2;
    final canvasH = pillH + shadowSpread * 2 + shadowOffY;
    final offsetX = shadowSpread;
    final offsetY = shadowSpread;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offsetX, offsetY, pillW, pillH),
      Radius.circular(pillH / 2),
    );

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offsetX, offsetY + shadowOffY, pillW, pillH),
        Radius.circular(pillH / 2),
      ),
      Paint()
        ..color = const Color(0x30000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Background
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = isHighlighted ? DonyColors.primary : Colors.white
        ..style = PaintingStyle.fill,
    );

    // Border (white pill only)
    if (!isHighlighted) {
      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = const Color(0xFFE8E5DF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Text
    tp.paint(canvas, Offset(offsetX + paddingH, offsetY + paddingV));

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasW.ceil(), canvasH.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
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

class _PricePillKey {
  const _PricePillKey({required this.priceCents, required this.isHighlighted});

  final int priceCents;
  final bool isHighlighted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PricePillKey &&
          priceCents == other.priceCents &&
          isHighlighted == other.isHighlighted;

  @override
  int get hashCode => Object.hash(priceCents, isHighlighted);
}
