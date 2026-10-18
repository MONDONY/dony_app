import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Gros bouton micro rond de l'assistant, centré juste au-dessus de la barre
/// de saisie, à portée de pouce (FLUTTER-RE).
///
/// Au repos : micro sur fond plein. Pendant la dictée : carré « arrêter » et
/// halo qui respire doucement ; un toucher arrête et envoie à tout moment.
/// Le halo reste fixe quand l'utilisateur a réduit les animations.
class AssistantMicButton extends StatefulWidget {
  const AssistantMicButton({
    super.key,
    required this.listening,
    required this.enabled,
    required this.onTap,
  });

  /// Diamètre du bouton, au-dessus de la cible minimale de 44 pt.
  static const double size = 68;

  final bool listening;

  /// Faux pendant qu'une réponse arrive : le bouton reste visible, grisé.
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<AssistantMicButton> createState() => _AssistantMicButtonState();
}

class _AssistantMicButtonState extends State<AssistantMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncHalo();
  }

  @override
  void didUpdateWidget(covariant AssistantMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listening != widget.listening) _syncHalo();
  }

  /// Démarre ou arrête le halo selon l'écoute ; repart de sa position
  /// courante, jamais d'un saut (animation interruptible).
  void _syncHalo() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.listening && !reduceMotion) {
      if (!_halo.isAnimating) _halo.repeat(reverse: true);
    } else {
      _halo.animateBack(
        0,
        duration: reduceMotion ? Duration.zero : DonyDuration.micro,
        curve: DonyCurve.exit,
      );
    }
  }

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final listening = widget.listening;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final label = listening
        ? l.assistantMicTooltipStop
        : l.assistantMicTooltipStart;
    final button = Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: label,
        excludeSemantics: true,
        child: DonyPressable(
          onTap: widget.enabled ? widget.onTap : () {},
          enableHaptic: widget.enabled,
          child: SizedBox.square(
            dimension: AssistantMicButton.size + 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Halo : visible seulement pendant l'écoute.
                AnimatedBuilder(
                  animation: _halo,
                  builder: (context, _) {
                    final t = Curves.easeInOut.transform(_halo.value);
                    return AnimatedOpacity(
                      opacity: listening ? 1 : 0,
                      duration: reduceMotion
                          ? Duration.zero
                          : DonyDuration.micro,
                      child: Container(
                        width: AssistantMicButton.size + 6 + 14 * t,
                        height: AssistantMicButton.size + 6 + 14 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary.withValues(alpha: 0.16),
                        ),
                      ),
                    );
                  },
                ),
                AnimatedContainer(
                  key: const Key('assistant-mic-disc'),
                  duration: reduceMotion ? Duration.zero : DonyDuration.base,
                  curve: DonyCurve.enter,
                  width: AssistantMicButton.size,
                  height: AssistantMicButton.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.enabled
                        ? (listening ? cs.error : cs.primary)
                        : cs.surfaceContainerHighest,
                    boxShadow: widget.enabled ? DonyShadow.md : null,
                  ),
                  child: AnimatedSwitcher(
                    duration: reduceMotion ? Duration.zero : DonyDuration.micro,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Icon(
                      listening ? Icons.stop_rounded : Icons.mic_rounded,
                      key: ValueKey(listening),
                      size: 32,
                      color: widget.enabled
                          ? (listening ? cs.onError : cs.onPrimary)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyedSubtree(key: const Key('assistant-mic'), child: button),
        Text(
          listening ? l.assistantMicListening : l.assistantMicStart,
          key: const Key('assistant-mic-caption'),
          textAlign: TextAlign.center,
          style: tt.labelMedium?.copyWith(
            color: listening ? cs.error : cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
