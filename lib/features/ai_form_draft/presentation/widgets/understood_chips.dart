import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_draft_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Encart « Déjà compris » : une puce par information comprise, une puce
/// « ? » par information requise manquante, et le compteur « 7 / 9 ».
class UnderstoodChips extends StatelessWidget {
  const UnderstoodChips({
    super.key,
    required this.kind,
    required this.understood,
    required this.missing,
    required this.draft,
  });

  final AiFormKind kind;
  final List<String> understood;
  final List<String> missing;
  final Map<String, Object?> draft;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final known = [
      for (final key in understood) ?aiUnderstoodChipLabel(l, kind, key, draft),
    ];
    final unknown = aiMissingChipLabels(l, missing);
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.aiFormDraftUnderstoodTitle,
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${known.length} / ${known.length + unknown.length}',
                key: const Key('ai-understood-count'),
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: [
              for (final label in known) _Chip(label: label),
              for (final label in unknown) _Chip(label: label, missing: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.missing = false});

  final String label;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      // Clé sur un descendant, pas sur le frère du Wrap : plusieurs puces
      // manquantes peuvent la porter sans doublon de clé.
      key: missing ? const Key('ai-chip-missing') : null,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: missing ? cs.surface : cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: missing ? cs.outline : cs.primary),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: missing ? cs.onSurfaceVariant : cs.onPrimaryContainer,
        ),
      ),
    );
  }
}
