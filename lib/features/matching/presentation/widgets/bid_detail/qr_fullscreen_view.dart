import 'dart:async';
import 'dart:typed_data';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// QR du colis en plein écran, sur fond blanc, aussi grand que l'écran le
/// permet : le transporteur le lit de loin ou en plein soleil.
///
/// Ouvert au-dessus de [QrSheet] (dialogue plein écran, comme les autres
/// visionneuses de l'app). La luminosité est poussée au maximum ; la feuille
/// la rétablit à sa propre fermeture.
abstract final class QrFullscreenView {
  static Future<void> show(BuildContext context, Uint8List imageBytes) {
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.bidQrFullscreenOpened,
      ),
    );
    unawaited(
      ScreenBrightness.instance
          .setApplicationScreenBrightness(1.0)
          .catchError((_) {}),
    );
    return showDialog<void>(
      context: context,
      useSafeArea: false,
      barrierColor: DonyColors.neutral0,
      builder: (ctx) => _QrFullscreen(
        imageBytes: imageBytes,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

class _QrFullscreen extends StatelessWidget {
  const _QrFullscreen({required this.imageBytes, required this.onClose});

  final Uint8List imageBytes;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    // Fond blanc quel que soit le thème : un QR se lit en noir sur blanc.
    const ink = DonyColors.ink900;
    return Material(
      key: const Key('qr-fullscreen'),
      color: DonyColors.neutral0,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.xs),
                child: IconButton(
                  key: const Key('qr-fullscreen-close'),
                  tooltip: l.commonClose,
                  onPressed: onClose,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const DonyIcon('x', color: ink),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side =
                      (constraints.biggest.shortestSide - 2 * DonySpacing.base)
                          .clamp(0.0, double.infinity);
                  return Center(
                    child: Semantics(
                      image: true,
                      label: l.bidDetailQrSheetTitle,
                      child: Image.memory(
                        imageBytes,
                        key: const Key('qr-fullscreen-image'),
                        width: side,
                        height: side,
                        fit: BoxFit.contain,
                        // Modules nets : pas de lissage entre les pixels.
                        filterQuality: FilterQuality.none,
                        gaplessPlayback: true,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                DonySpacing.sm,
                DonySpacing.base,
                DonySpacing.base,
              ),
              child: Text(
                l.bidDetailQrFullscreenHint,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
