import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_draft_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Résumé « C'est tout bon » : ce qui sera rempli, avec les avertissements.
class DraftSummary extends StatelessWidget {
  const DraftSummary({
    super.key,
    required this.kind,
    required this.resolved,
    this.turnLimitReached = false,
    this.fallbackCurrency,
  });

  final AiFormKind kind;
  final AiResolvedDraft resolved;
  final bool turnLimitReached;

  /// Devise du formulaire, quand l'IA n'en a pas dit.
  final String? fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final route = aiRouteLabel(resolved.draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.aiFormDraftReadyTitle,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          turnLimitReached
              ? l.aiFormDraftTurnLimit
              : kind == AiFormKind.trip
              ? l.aiFormDraftReadyBodyTrip
              : l.aiFormDraftReadyBodyPackage,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.base),
        if (route != null) ...[
          Text(
            route,
            key: const Key('ai-summary-route'),
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        for (final (label, value) in aiSummaryLines(
          l,
          kind,
          resolved.draft,
          fallbackCurrency: fallbackCurrency,
        ))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Text(
                    label,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        if (kind == AiFormKind.packageRequest)
          _Notice(icon: 'info', text: l.aiFormDraftSummaryPhotoHint),
        for (final warning in resolved.warnings)
          _Notice(
            icon: 'triangle-alert',
            text: aiWarningText(l, warning),
            isWarning: true,
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.isWarning = false,
  });

  final String icon;
  final String text;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.sm),
      child: Container(
        // Clé sur un descendant : plusieurs avertissements frères sans doublon.
        key: isWarning ? const Key('ai-summary-warning') : null,
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(DonyRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DonyIcon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
