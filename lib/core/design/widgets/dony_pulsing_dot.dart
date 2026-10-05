import 'package:flutter/material.dart';

/// Voyant qui clignote doucement pour signaler qu'une action attend
/// l'utilisateur (FLUTTER-BY : « Discussions de prix » quand c'est à lui de
/// répondre ou de payer).
///
/// Jamais porteur d'information à lui seul : l'appelant affiche aussi un
/// compteur ou un texte, et [semanticLabel] le nomme au lecteur d'écran.
/// Point fixe quand le système demande de réduire les animations
/// (`MediaQuery.disableAnimations`).
///
/// `AnimationController` manuel plutôt que `flutter_animate`, pour la même
/// raison que [DonyShimmer] : `.animate()` programme son premier `_play()`
/// via `Future.delayed`, un `Timer` réel qui reste en attente dans tout test
/// ne faisant qu'un `pump()` sur un écran qui affiche le voyant.
class DonyPulsingDot extends StatefulWidget {
  const DonyPulsingDot({
    super.key,
    required this.semanticLabel,
    this.color,
    this.size = 10,
  });

  /// Nom de l'état signalé (« Action requise »).
  final String semanticLabel;

  /// Couleur du voyant, `colorScheme.error` par défaut.
  final Color? color;
  final double size;

  @override
  State<DonyPulsingDot> createState() => _DonyPulsingDotState();
}

class _DonyPulsingDotState extends State<DonyPulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.3,
  ).animate(_curve);
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 0.8,
  ).animate(_curve);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? Theme.of(context).colorScheme.error;
    final size = widget.size;
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: size * 0.8),
        ],
      ),
    );

    return Semantics(
      label: widget.semanticLabel,
      child: MediaQuery.disableAnimationsOf(context)
          ? dot
          : RepaintBoundary(
              child: FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(scale: _scale, child: dot),
              ),
            ),
    );
  }
}
