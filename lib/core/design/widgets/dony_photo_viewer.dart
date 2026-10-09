import 'dart:math' as math;

import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_pressable.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Bouton de fermeture d'une visionneuse photo plein écran (FLUTTER-GR).
///
/// Une croix blanche sans fond disparaissait sur une photo claire : la pastille
/// sombre semi-opaque la garde lisible sur n'importe quelle image. Zone de tap
/// de [kDonyMinTapTarget] (44 pt), pastille visuelle de 36.
class DonyPhotoCloseButton extends StatelessWidget {
  const DonyPhotoCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.commonClose;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: DonyPressable(
          onTap: onPressed,
          child: SizedBox(
            key: const Key('dony-photo-close'),
            width: kDonyMinTapTarget,
            height: kDonyMinTapTarget,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  // Liseré clair : détache la pastille d'une photo sombre.
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const SizedBox.square(
                  dimension: 36,
                  child: Center(
                    child: DonyIcon('x', size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fermeture d'une visionneuse en glissant vers le bas (FLUTTER-GR).
///
/// Le contenu suit le doigt et le fond s'éclaircit ; au-delà de
/// [dismissDistance] ou d'un geste rapide, [onDismiss] est appelé, sinon le
/// contenu revient en place. Les gestes arrivent soit d'un
/// [DonyZoomablePhoto] (photo non zoomée, un seul doigt), soit d'une
/// [DonyPhotoDragArea] (états chargement, erreur).
class DonyPhotoDismiss extends StatefulWidget {
  const DonyPhotoDismiss({
    super.key,
    required this.onDismiss,
    required this.child,
    this.background = Colors.black,
    this.dismissDistance = 120,
  });

  final VoidCallback onDismiss;
  final Widget child;

  /// Fond plein écran, estompé à mesure que le contenu descend.
  final Color background;
  final double dismissDistance;

  static DonyPhotoDismissState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<DonyPhotoDismissState>();

  @override
  State<DonyPhotoDismiss> createState() => DonyPhotoDismissState();
}

class DonyPhotoDismissState extends State<DonyPhotoDismiss>
    with SingleTickerProviderStateMixin {
  // Décalage vertical en pixels (non borné : pas une progression 0..1).
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  bool _dismissed = false;

  /// Vitesse au-delà de laquelle un geste court ferme tout de même.
  static const double _flingVelocity = 800;

  void dragUpdate(double dy) {
    if (_dismissed) return;
    _offset.value = math.max(0, _offset.value + dy);
  }

  void dragEnd(double velocityY) {
    if (_dismissed) return;
    final offset = _offset.value;
    if (offset <= 0) return;
    if (offset >= widget.dismissDistance ||
        (velocityY >= _flingVelocity && offset > kDonyMinTapTarget / 2)) {
      _dismissed = true;
      widget.onDismiss();
      return;
    }
    _offset.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return AnimatedBuilder(
      animation: _offset,
      child: child,
      builder: (context, child) {
        final offset = _offset.value;
        final progress = (offset / (widget.dismissDistance * 2.5)).clamp(
          0.0,
          1.0,
        );
        return ColoredBox(
          color: widget.background.withValues(
            alpha: widget.background.a * (1 - progress),
          ),
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(scale: 1 - progress * 0.1, child: child),
          ),
        );
      },
    );
  }
}

/// Zone sans photo (chargement, erreur) qui relaie le glissement vertical au
/// [DonyPhotoDismiss] parent.
class DonyPhotoDragArea extends StatelessWidget {
  const DonyPhotoDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (d) =>
          DonyPhotoDismiss.maybeOf(context)?.dragUpdate(d.delta.dy),
      onVerticalDragEnd: (d) => DonyPhotoDismiss.maybeOf(
        context,
      )?.dragEnd(d.velocity.pixelsPerSecond.dy),
      child: child,
    );
  }
}

/// Photo zoomable qui, tant qu'elle n'est pas zoomée, relaie le glissement à un
/// doigt au [DonyPhotoDismiss] parent. Les gestes passent par l'
/// [InteractiveViewer] lui-même : pas de second reconnaisseur vertical qui
/// volerait le pincement.
class DonyZoomablePhoto extends StatefulWidget {
  const DonyZoomablePhoto({super.key, required this.child, this.maxScale = 5});

  final Widget child;
  final double maxScale;

  @override
  State<DonyZoomablePhoto> createState() => _DonyZoomablePhotoState();
}

class _DonyZoomablePhotoState extends State<DonyZoomablePhoto> {
  final TransformationController _transform = TransformationController();
  bool _dragging = false;

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transform,
      maxScale: widget.maxScale,
      onInteractionStart: (d) => _dragging = d.pointerCount == 1 && !_zoomed,
      onInteractionUpdate: (d) {
        if (d.pointerCount > 1) _dragging = false;
        if (_dragging) {
          DonyPhotoDismiss.maybeOf(context)?.dragUpdate(d.focalPointDelta.dy);
        }
      },
      onInteractionEnd: (d) {
        // Toujours relâcher : un pincement entamé après un début de glissement
        // ramène la photo en place.
        DonyPhotoDismiss.maybeOf(
          context,
        )?.dragEnd(_dragging ? d.velocity.pixelsPerSecond.dy : 0);
        _dragging = false;
      },
      child: widget.child,
    );
  }
}
