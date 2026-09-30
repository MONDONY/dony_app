import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bouton « Copier le code » qui confirme la copie **sur place** : son libellé
/// passe à [copiedLabel] avec une coche pendant [feedbackDuration].
///
/// Les codes de retrait et de retour s'affichent dans une feuille : un
/// snackbar partait sur l'écran du dessous, caché par la feuille, et le
/// testeur ne voyait jamais que la copie avait marché (FLUTTER-4P).
class CopyCodeButton extends StatefulWidget {
  const CopyCodeButton({
    super.key,
    required this.code,
    required this.label,
    required this.copiedLabel,
    this.feedbackDuration = const Duration(seconds: 2),
  });

  final String code;
  final String label;
  final String copiedLabel;
  final Duration feedbackDuration;

  @override
  State<CopyCodeButton> createState() => _CopyCodeButtonState();
}

class _CopyCodeButtonState extends State<CopyCodeButton> {
  /// État d'affichage seul, jamais métier : un notifier plutôt qu'un
  /// `setState`, pour ne redessiner que le contenu du bouton.
  final _copied = ValueNotifier<bool>(false);
  Timer? _reset;

  void _copy() {
    unawaited(Clipboard.setData(ClipboardData(text: widget.code)));
    unawaited(HapticFeedback.lightImpact());
    _copied.value = true;
    _reset?.cancel();
    _reset = Timer(widget.feedbackDuration, () {
      if (mounted) _copied.value = false;
    });
  }

  @override
  void dispose() {
    _reset?.cancel();
    _copied.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<bool>(
      valueListenable: _copied,
      builder: (context, copied, _) {
        final color = copied ? cs.success : cs.primary;
        return Semantics(
          button: true,
          liveRegion: true,
          label: copied ? widget.copiedLabel : widget.label,
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('copy-code-button'),
            onTap: _copy,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 44,
              decoration: BoxDecoration(
                color: copied ? cs.success.withValues(alpha: 0.1) : null,
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Row(
                  key: ValueKey(copied),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DonyIcon(copied ? 'check' : 'copy', size: 16, color: color),
                    const SizedBox(width: DonySpacing.sm),
                    Text(
                      copied ? widget.copiedLabel : widget.label,
                      style: tt.titleSmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
