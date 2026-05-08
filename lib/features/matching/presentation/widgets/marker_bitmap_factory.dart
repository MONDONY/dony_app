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
  static final Map<_StackedPillKey, BitmapDescriptor> _stackedPillCache = {};

  static const double _kTailH = 6.0;
  static const double _kTailW = 10.0;

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
    _stackedPillCache.clear();
  }

  // ─── Price pill marker (white pill + urgency dot) ─────────────────────────

  static Future<BitmapDescriptor> pricePill({
    required double pricePerKg,
    Color dotColor = Colors.transparent,
    bool isSelected = false,
  }) async {
    final key = _PricePillKey(
      priceCents: (pricePerKg * 100).round(),
      colorValue: dotColor.value,
      isSelected: isSelected,
    );
    final cached = _pillCache[key];
    if (cached != null) return cached;
    final bitmap = await _renderPricePill(
      pricePerKg: pricePerKg,
      dotColor: dotColor,
      isSelected: isSelected,
    );
    _pillCache[key] = bitmap;
    return bitmap;
  }

  // ─── Stacked price pill (same-address cluster: ghost layer + "+N" badge) ───

  static Future<BitmapDescriptor> stackedPricePill({
    required double pricePerKg,
    required int count,
    Color dotColor = Colors.transparent,
    bool isSelected = false,
  }) async {
    final key = _StackedPillKey(
      priceCents: (pricePerKg * 100).round(),
      count: count,
      colorValue: dotColor.value,
      isSelected: isSelected,
    );
    final cached = _stackedPillCache[key];
    if (cached != null) return cached;
    final bitmap = await _renderStackedPricePill(
      pricePerKg: pricePerKg,
      count: count,
      dotColor: dotColor,
      isSelected: isSelected,
    );
    _stackedPillCache[key] = bitmap;
    return bitmap;
  }

  static Future<BitmapDescriptor> _renderStackedPricePill({
    required double pricePerKg,
    required int count,
    required Color dotColor,
    required bool isSelected,
  }) async {
    final label = pricePerKg == pricePerKg.roundToDouble()
        ? '${pricePerKg.toInt()}€'
        : '${pricePerKg.toStringAsFixed(1)}€';

    const fontSize = 12.0;
    const paddingH = 8.0;
    const paddingV = 5.0;
    const textColor = Color(0xFF061833);
    const dotR = 3.0;
    const halo1R = 4.5;
    const halo2R = 6.0;
    const dotSectionW = halo2R * 2;
    const dotGap = 5.0;
    const badgeR = 8.0;
    const ghostStep = 3.5;

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pillW = paddingH + dotSectionW + dotGap + tp.width + paddingH;
    final pillH = tp.height + paddingV * 2;

    const shadowSpread = 4.0;
    const shadowOffY = 2.0;

    // Canvas: main pill gets extra space on right for badge overflow,
    // extra space on top for badge circle sticking above the pill.
    final canvasW = pillW + shadowSpread * 2 + badgeR;
    final canvasH = shadowSpread + badgeR + pillH + _kTailH;

    // Main pill origin (shifted down by badgeR to leave room for badge above)
    final mainX = shadowSpread;
    final mainY = shadowSpread + badgeR;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ── Ghost pill (behind and offset → stacking depth cue) ──────────────
    final ghostRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(mainX + ghostStep, mainY + ghostStep, pillW, pillH),
      Radius.circular(pillH / 2),
    );
    canvas.drawRRect(
      ghostRect,
      Paint()
        ..color = const Color(0xFFD0CCC4)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      ghostRect,
      Paint()
        ..color = const Color(0xFFBBB7AF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Main pill ─────────────────────────────────────────────────────────
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(mainX, mainY, pillW, pillH),
      Radius.circular(pillH / 2),
    );

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(mainX, mainY + shadowOffY, pillW, pillH),
        Radius.circular(pillH / 2),
      ),
      Paint()
        ..color = const Color(0x30000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Selected ring
    if (isSelected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(mainX - 2.5, mainY - 2.5, pillW + 5, pillH + 5),
          Radius.circular((pillH + 5) / 2),
        ),
        Paint()
          ..color = const Color(0xFF0B5FFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // White fill
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = const Color(0xFFE8E5DF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Tail
    final tailCx = mainX + pillW / 2;
    final tailTopY = mainY + pillH;
    final tailPath = Path()
      ..moveTo(tailCx - _kTailW / 2, tailTopY)
      ..lineTo(tailCx + _kTailW / 2, tailTopY)
      ..lineTo(tailCx, canvasH)
      ..close();
    canvas.drawPath(
        tailPath, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // Urgency dot + halos
    final dotCx = mainX + paddingH + halo2R;
    final dotCy = mainY + pillH / 2;
    final dotCenter = Offset(dotCx, dotCy);
    canvas.drawCircle(
        dotCenter, halo2R, Paint()..color = dotColor.withValues(alpha: 0.15));
    canvas.drawCircle(
        dotCenter, halo1R, Paint()..color = dotColor.withValues(alpha: 0.35));
    canvas.drawCircle(dotCenter, dotR, Paint()..color = dotColor);

    // Price text
    tp.paint(canvas,
        Offset(mainX + paddingH + dotSectionW + dotGap, mainY + paddingV));

    // ── Count badge (blue circle at top-right corner of main pill) ────────
    final badgeCx = mainX + pillW;
    final badgeCy = mainY; // top edge of pill = badge center

    canvas.drawCircle(
      Offset(badgeCx, badgeCy),
      badgeR,
      Paint()..color = const Color(0xFF0B5FFF),
    );
    canvas.drawCircle(
      Offset(badgeCx, badgeCy),
      badgeR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final badgeText = count > 99 ? '99' : '$count';
    final badgeTp = TextPainter(
      text: TextSpan(
        text: badgeText,
        style: const TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgeTp.paint(
      canvas,
      Offset(badgeCx - badgeTp.width / 2, badgeCy - badgeTp.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasW.ceil(), canvasH.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _renderPricePill({
    required double pricePerKg,
    required Color dotColor,
    required bool isSelected,
  }) async {
    final label = pricePerKg == pricePerKg.roundToDouble()
        ? '${pricePerKg.toInt()}€'
        : '${pricePerKg.toStringAsFixed(1)}€';

    const fontSize = 12.0;
    const paddingH = 8.0;
    const paddingV = 5.0;
    const textColor = Color(0xFF061833);

    // Urgency dot dimensions
    const dotR = 3.0;
    const halo1R = 4.5;
    const halo2R = 6.0;
    const dotSectionW = halo2R * 2; // total width taken by dot + halos
    const dotGap = 5.0;   // gap between outer halo and text

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pillW = paddingH + dotSectionW + dotGap + tp.width + paddingH;
    final pillH = tp.height + paddingV * 2;

    const shadowSpread = 4.0;
    const shadowOffY = 2.0;
    final canvasW = pillW + shadowSpread * 2;
    final canvasH = shadowSpread + pillH + _kTailH;
    final offsetX = shadowSpread;
    final offsetY = shadowSpread;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offsetX, offsetY, pillW, pillH),
      Radius.circular(pillH / 2),
    );

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offsetX, offsetY + shadowOffY, pillW, pillH),
        Radius.circular(pillH / 2),
      ),
      Paint()
        ..color = const Color(0x30000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Selected ring (blue stroke around the pill)
    if (isSelected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(offsetX - 2.5, offsetY - 2.5, pillW + 5, pillH + 5),
          Radius.circular((pillH + 5) / 2),
        ),
        Paint()
          ..color = const Color(0xFF0B5FFF) // DonyColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // White pill background
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Pill border (neutral200)
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = const Color(0xFFE8E5DF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // White tail (bottom triangle)
    final tailCenterX = offsetX + pillW / 2;
    final tailTopY = offsetY + pillH;
    final tailPath = Path()
      ..moveTo(tailCenterX - _kTailW / 2, tailTopY)
      ..lineTo(tailCenterX + _kTailW / 2, tailTopY)
      ..lineTo(tailCenterX, canvasH)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // Urgency dot + sonar halos (left-aligned inside pill)
    final dotCx = offsetX + paddingH + halo2R;
    final dotCy = offsetY + pillH / 2;
    final dotCenter = Offset(dotCx, dotCy);

    // Outer halo (faintest)
    canvas.drawCircle(dotCenter, halo2R, Paint()..color = dotColor.withValues(alpha: 0.15));
    // Mid halo
    canvas.drawCircle(dotCenter, halo1R, Paint()..color = dotColor.withValues(alpha: 0.35));
    // Inner solid dot
    canvas.drawCircle(dotCenter, dotR, Paint()..color = dotColor);

    // Price text
    tp.paint(canvas, Offset(offsetX + paddingH + dotSectionW + dotGap, offsetY + paddingV));

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
  const _PricePillKey({
    required this.priceCents,
    required this.colorValue,
    required this.isSelected,
  });

  final int priceCents;
  final int colorValue;
  final bool isSelected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PricePillKey &&
          priceCents == other.priceCents &&
          colorValue == other.colorValue &&
          isSelected == other.isSelected;

  @override
  int get hashCode => Object.hash(priceCents, colorValue, isSelected);
}

class _StackedPillKey {
  const _StackedPillKey({
    required this.priceCents,
    required this.count,
    required this.colorValue,
    required this.isSelected,
  });

  final int priceCents;
  final int count;
  final int colorValue;
  final bool isSelected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StackedPillKey &&
          priceCents == other.priceCents &&
          count == other.count &&
          colorValue == other.colorValue &&
          isSelected == other.isSelected;

  @override
  int get hashCode => Object.hash(priceCents, count, colorValue, isSelected);
}
