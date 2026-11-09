import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_availability_cubit.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Carte « Dites-le, on remplit pour vous » en haut de l'étape 1 : une seule
/// ligne (icône, titre, courte phrase, bouton compact) pour ne pas pousser le
/// formulaire hors de l'écran.
class AiEntryCard extends StatelessWidget {
  const AiEntryCard({super.key, required this.kind, required this.onPressed});

  /// Conservé pour les appelants : la carte compacte a le même texte pour le
  /// trajet et la demande d'envoi.
  final AiFormKind kind;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Texte agrandi : le bouton passe sous le titre plutôt que de rétrécir
    // une police ou de déborder.
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 16;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.aiFormDraftEntryTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onPrimaryContainer,
          ),
        ),
        Text(
          l.aiFormDraftEntrySubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
        ),
      ],
    );
    final cta = _CompactCta(
      key: const Key('ai-entry-cta'),
      label: l.aiFormDraftEntryCta,
      onPressed: onPressed,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DonyIcon('sparkles', size: 20, color: cs.primary),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(child: texts),
                  ],
                ),
                const SizedBox(height: DonySpacing.sm),
                Align(alignment: Alignment.centerRight, child: cta),
              ],
            )
          : Row(
              children: [
                DonyIcon('sparkles', size: 20, color: cs.primary),
                const SizedBox(width: DonySpacing.sm),
                Expanded(child: texts),
                const SizedBox(width: DonySpacing.sm),
                cta,
              ],
            ),
    );
  }
}

/// Bouton plein compact (36 dp), aplat uni : `DonyButton` n'a pas de taille
/// réduite (52 dp minimum). Libellé sur une ligne, à la taille du thème.
class _CompactCta extends StatelessWidget {
  const _CompactCta({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.lg),
        ),
      ),
      child: Text(label, maxLines: 1, softWrap: false),
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
