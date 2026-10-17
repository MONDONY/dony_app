import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// « Rempli par l'IA. Vérifiez chaque champ avant de publier. » + « Reparler ».
class AiFilledBanner extends StatelessWidget {
  const AiFilledBanner({super.key, required this.onTalkAgain});

  final VoidCallback onTalkAgain;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('ai-filled-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        children: [
          DonyIcon('sparkles', size: 18, color: cs.onSecondaryContainer),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              l.aiFormDraftFilledBanner,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
          TextButton(
            key: const Key('ai-talk-again'),
            onPressed: onTalkAgain,
            child: Text(l.aiFormDraftTalkAgain),
          ),
        ],
      ),
    );
  }
}
