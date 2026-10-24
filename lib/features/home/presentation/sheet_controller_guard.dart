import 'package:dony/core/services/app_log.dart';
import 'package:flutter/widgets.dart';

/// Nombre de frames pendant lesquelles un geste sur une feuille détachée
/// attend le rattachement du défilant avant d'être abandonné.
const kSheetAttachRetryFrames = 5;

/// Amène la feuille à [size] sans jamais appeler le contrôleur détaché
/// (`animateTo` lève une assertion, Sentry 155532570).
///
/// Détachée, la feuille n'est pas touchée et aucune taille en cache n'est
/// écrite : `_onSheetSizeChanged` reste la seule source du cache. Le geste est
/// réessayé aux [kSheetAttachRetryFrames] frames suivantes, puis abandonné
/// (avec un `AppLog.warn`).
void moveSheetWhenAttached(
  DraggableScrollableController controller,
  double size, {
  required bool Function() isMounted,
  required Duration duration,
}) {
  _move(controller, size, isMounted, duration, kSheetAttachRetryFrames);
}

void _move(
  DraggableScrollableController controller,
  double size,
  bool Function() isMounted,
  Duration duration,
  int retriesLeft,
) {
  if (controller.isAttached) {
    controller.animateTo(size, duration: duration, curve: Curves.easeOutCubic);
    return;
  }
  if (retriesLeft <= 0) {
    AppLog.warn(
      'home.sheet_gesture_dropped',
      data: {'target_size': size},
    );
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!isMounted()) return;
    _move(controller, size, isMounted, duration, retriesLeft - 1);
  });
  // Un écran au repos ne produit pas de frame : sans cela, la reprise ne part pas.
  WidgetsBinding.instance.ensureVisualUpdate();
}
