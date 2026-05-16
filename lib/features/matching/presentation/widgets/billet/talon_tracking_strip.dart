import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Bande « n° de suivi » en pied de talon : code-barres décoratif,
/// numéro, et actions Copier / Partager.
class TalonTrackingStrip extends StatelessWidget {
  final String trackingNumber;
  const TalonTrackingStrip({super.key, required this.trackingNumber});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.only(top: DonySpacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          const _BarcodeGlyph(),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'N° DE SUIVI',
                  style: tt.bodySmall?.copyWith(
                    // bodySmall (12px) — plancher HIG ≥ 12px
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  trackingNumber,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('talon-copy-button'),
            icon: Icon(Icons.copy_rounded, color: cs.primary, size: 20),
            tooltip: 'Copier',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: trackingNumber));
              DonySnackbar.show(
                context,
                message: 'Numéro copié',
                type: DonySnackbarType.success,
              );
            },
          ),
          IconButton(
            key: const Key('talon-share-button'),
            icon: Icon(
              Platform.isIOS ? Icons.ios_share_rounded : Icons.share_rounded,
              color: cs.primary,
              size: 20,
            ),
            tooltip: 'Partager',
            onPressed: () =>
                Share.share('Suivez mon colis dony #$trackingNumber'),
          ),
        ],
      ),
    );
  }
}

class _BarcodeGlyph extends StatelessWidget {
  const _BarcodeGlyph();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        border: Border.all(color: cs.outline),
      ),
      child: CustomPaint(painter: _BarcodePainter(cs.onSurface)),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final Color color;
  _BarcodePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const widths = [2.0, 1.0, 3.0, 1.0, 2.0, 1.0, 1.0, 3.0, 2.0, 1.0];
    double x = 4;
    for (final w in widths) {
      canvas.drawRect(Rect.fromLTWH(x, 6, w, size.height - 12), p);
      x += w + 2;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.color != color;
}
