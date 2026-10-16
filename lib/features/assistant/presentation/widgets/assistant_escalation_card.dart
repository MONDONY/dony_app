import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Carte « Écrire à l'équipe » : l'assistant ne sait pas, a atteint son quota
/// ou est indisponible. Le bouton crée un ticket support avec l'échange.
class AssistantEscalationCard extends StatelessWidget {
  const AssistantEscalationCard({
    super.key,
    required this.status,
    required this.onEscalate,
  });

  final AssistantEscalationStatus status;
  final VoidCallback onEscalate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return DecoratedBox(
      key: const Key('assistant-escalation-card'),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.assistantEscalationTitle,
              style: tt.titleLarge,
              // Titre court sur une à deux lignes : équilibrer les lignes
              // évite un dernier mot orphelin.
              textWidthBasis: TextWidthBasis.longestLine,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              l.assistantEscalationBody,
              style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('assistant-escalate'),
              label: l.assistantEscalate,
              icon: Icons.support_agent_rounded,
              isLoading: status == AssistantEscalationStatus.sending,
              onPressed: onEscalate,
            ),
          ],
        ),
      ),
    );
  }
}
