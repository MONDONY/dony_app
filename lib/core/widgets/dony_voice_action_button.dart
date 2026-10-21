import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Ce que fait le bouton à droite d'un champ de saisie vocale.
enum DonyVoiceAction { mic, send, stop }

/// Bouton rond de 48 pt à droite d'un champ de saisie : un seul à la fois.
///
/// - rien de saisi : le micro ;
/// - du texte saisi : l'envoi (le micro revient si on efface tout) ;
/// - pendant la dictée : l'arrêt, en rouge, qui envoie ce qui a été dit.
///
/// Sans micro disponible (permission refusée, reconnaissance absente), il ne
/// reste que l'envoi, grisé tant que le champ est vide. Remplace le gros micro
/// de 68 pt qui occupait une bande entière au-dessus de la saisie.
class DonyVoiceActionButton extends StatelessWidget {
  const DonyVoiceActionButton({
    super.key,
    required this.hasText,
    required this.listening,
    required this.micAvailable,
    required this.enabled,
    required this.onMic,
    required this.onSend,
    required this.micTooltip,
    required this.stopTooltip,
    required this.sendTooltip,
    this.micKey,
    this.stopKey,
    this.sendKey,
  });

  /// Diamètre : au-dessus de la cible tactile minimale de 44 pt.
  static const double size = 48;

  final bool hasText;
  final bool listening;
  final bool micAvailable;

  /// Faux pendant qu'une réponse arrive : micro et envoi sont grisés, l'arrêt
  /// d'une dictée reste possible.
  final bool enabled;

  /// Démarre la dictée, ou l'arrête quand elle est en cours.
  final VoidCallback onMic;
  final VoidCallback onSend;
  final String micTooltip;
  final String stopTooltip;
  final String sendTooltip;
  final Key? micKey;
  final Key? stopKey;
  final Key? sendKey;

  DonyVoiceAction get action {
    if (listening) return DonyVoiceAction.stop;
    if (hasText || !micAvailable) return DonyVoiceAction.send;
    return DonyVoiceAction.mic;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final current = action;

    final (
      IconData icon,
      String tooltip,
      Key? key,
      VoidCallback? onPressed,
    ) = switch (current) {
      DonyVoiceAction.stop => (Icons.stop_rounded, stopTooltip, stopKey, onMic),
      DonyVoiceAction.send => (
        Icons.send_rounded,
        sendTooltip,
        sendKey,
        enabled && hasText ? onSend : null,
      ),
      DonyVoiceAction.mic => (
        Icons.mic_rounded,
        micTooltip,
        micKey,
        enabled ? onMic : null,
      ),
    };
    final stopping = current == DonyVoiceAction.stop;

    return IconButton.filled(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        backgroundColor: stopping ? cs.error : cs.primary,
        foregroundColor: stopping ? cs.onError : cs.onPrimary,
        disabledBackgroundColor: cs.surfaceContainerHighest,
        disabledForegroundColor: cs.onSurfaceVariant,
      ),
      icon: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : DonyDuration.micro,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: Icon(icon, key: ValueKey(current), size: 22),
      ),
    );
  }
}
