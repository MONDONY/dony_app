import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_availability_cubit.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Carte « Dites-le, on remplit pour vous » en haut de l'étape 1.
class AiEntryCard extends StatelessWidget {
  const AiEntryCard({super.key, required this.kind, required this.onPressed});

  final AiFormKind kind;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DonyIcon('sparkles', size: 20, color: cs.primary),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  l.aiFormDraftEntryTitle,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            kind == AiFormKind.trip
                ? l.aiFormDraftEntryBodyTrip
                : l.aiFormDraftEntryBodyPackage,
            style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('ai-entry-cta'),
            label: l.aiFormDraftEntryCta,
            iconAsset: 'sparkles',
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

/// N'affiche [child] que si `/assistant/status` dit `formDraftEnabled: true`.
class AiEntryGate extends StatelessWidget {
  const AiEntryGate({
    super.key,
    required this.availability,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final AiFormDraftAvailabilityCubit availability;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AiFormDraftAvailabilityCubit, bool>(
        bloc: availability,
        builder: (context, enabled) => enabled
            ? Padding(padding: padding, child: child)
            : const SizedBox.shrink(),
      );
}
