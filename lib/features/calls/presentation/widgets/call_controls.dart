import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Les trois commandes d'un appel audio. Cibles de 64 px, libellé lu par les
/// lecteurs d'écran ; raccrocher en rouge.
class CallControls extends StatelessWidget {
  const CallControls({
    super.key,
    required this.muted,
    required this.speakerOn,
    required this.enabled,
    required this.onMute,
    required this.onSpeaker,
    required this.onHangUp,
  });

  final bool muted;
  final bool speakerOn;
  final bool enabled;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          label: muted ? l.callUnmute : l.callMute,
          icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          selected: muted,
          onTap: enabled ? onMute : null,
        ),
        _RoundButton(
          label: l.callHangUp,
          icon: Icons.call_end_rounded,
          background: cs.error,
          foreground: cs.onError,
          onTap: onHangUp,
        ),
        _RoundButton(
          label: l.callSpeaker,
          icon: Icons.volume_up_rounded,
          selected: speakerOn,
          onTap: enabled ? onSpeaker : null,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg =
        background ?? (selected ? cs.onSurface : cs.surfaceContainerHighest);
    final fg = foreground ?? (selected ? cs.surface : cs.onSurface);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: fg, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
