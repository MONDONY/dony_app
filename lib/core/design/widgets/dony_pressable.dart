import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wrapper tactile « scale on press ».
///
/// Applique le retour visuel de pression standard Yadony (réduction à [scale],
/// 100 ms `easeOutCubic`) + un retour haptique léger au toucher, à n'importe
/// quel [child] tappable qui n'est PAS un bouton (cards, chips, tuiles,
/// actions rapides). Pour les boutons pleins, utiliser [DonyButton] qui gère
/// en plus ses états de dégradé/ombre.
///
/// Factorise le motif `GestureDetector(onTapDown/Up/Cancel) + AnimatedScale`
/// auparavant réimplémenté localement dans plusieurs écrans.
class DonyPressable extends StatefulWidget {
  const DonyPressable({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.96,
    this.enableHaptic = true,
  });

  /// Action déclenchée au tap.
  final VoidCallback onTap;

  /// Contenu tappable (sa propre décoration/padding restent à sa charge).
  final Widget child;

  /// Facteur d'échelle pendant la pression (0.96 par défaut — ne jamais
  /// descendre sous 0.95, le feedback paraît alors exagéré).
  final double scale;

  /// Retour haptique léger au toucher (`selectionClick`). Désactivable.
  final bool enableHaptic;

  @override
  State<DonyPressable> createState() => _DonyPressableState();
}

class _DonyPressableState extends State<DonyPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _setPressed(true);
        if (widget.enableHaptic) HapticFeedback.selectionClick();
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
