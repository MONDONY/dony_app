import 'package:flutter/material.dart';

/// Rect d'ancrage pour la popover de partage iOS (obligatoire sur iOS —
/// sans lui, `Share.share`/`shareXFiles` plante avec
/// `sharePositionOrigin: argument must be set`).
///
/// À appeler avec le [context] du widget déclencheur (ex. celui du
/// `onPressed`), pour ancrer la popover près du bouton pressé.
Rect? sharePositionOriginFor(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
