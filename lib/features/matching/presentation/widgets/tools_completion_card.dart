import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/presentation/widgets/tool_key_presentation.dart';
import 'package:flutter/material.dart';

/// Carte de complétion des outils, en tête de la section « Outils » du hub
/// Activités (spec § 4.3). Le titre vend le bénéfice, la jauge n'est que la
/// preuve ; le compteur dit « n / 5 », jamais un pourcentage.
///
/// À 5 / 5 elle se replie en bandeau compact sans CTA : elle ne disparaît
/// jamais, les badges des tuiles non plus.
class ToolsCompletionCard extends StatelessWidget {
  const ToolsCompletionCard({
    super.key,
    required this.model,
    required this.onCtaTap,
  });

  final ToolsCompletionModel model;

  /// Reçoit la clé du prochain outil manquant ; l'écran navigue et recharge.
  final ValueChanged<ToolKey> onCtaTap;

  @override
  Widget build(BuildContext context) {
    if (model.isComplete) return const _CompleteBanner();
    return _ProgressCard(model: model, onCtaTap: onCtaTap);
  }
}

class _CompleteBanner extends StatelessWidget {
  const _CompleteBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      key: const Key('tools-completion-complete'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        children: [
          DonyIcon('circle-check', size: 22, color: cs.success),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vos outils sont prêts', style: tt.titleSmall),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  'Publiez un colis ou un trajet en 3 taps',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.model, required this.onCtaTap});

  final ToolsCompletionModel model;
  final ValueChanged<ToolKey> onCtaTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final next = model.nextMissing!;
    final isStart = model.ready == 0;

    final title = isStart
        ? 'Préparez vos outils une fois'
        : 'Publiez en 3 taps';
    final body = isStart
        ? 'Adresses, destinataires, modèles, grille de prix, alertes : '
              'remplis une fois, réutilisés à chaque publication.'
        : '${missingSentence(model.missing)} Une fois vos outils prêts, '
              'plus rien à ressaisir.';
    final cta = isStart ? 'Commencer par mes adresses' : next.ctaLabel;

    return DonyCard(
      key: const Key('tools-completion-card'),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIconContainer(
                iconAsset: 'zap',
                size: DonyIconContainerSize.sm,
                backgroundColor: cs.primary,
                iconColor: cs.onPrimary,
                borderRadius: DonyRadius.iconBtn,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(child: Text(title, style: tt.titleMedium)),
              const SizedBox(width: DonySpacing.sm),
              Text(
                '${model.ready} / ${model.total}',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          DonyOnboardingGauge(
            segments: [
              for (final tool in model.tools)
                tool.ready ? DonyGaugeSegment.done : DonyGaugeSegment.todo,
            ],
            label: 'prêts',
            showCounter: false,
            semanticsLabel: 'Préparation de vos outils',
          ),
          const SizedBox(height: DonySpacing.md),
          Text(body, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: DonySpacing.xs),
          InkWell(
            key: const Key('tools-completion-cta'),
            onTap: () => onCtaTap(next),
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
                child: Row(
                  children: [
                    DonyIcon('plus', size: 16, color: cs.primary),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Text(
                        cta,
                        style: tt.labelLarge?.copyWith(color: cs.primary),
                      ),
                    ),
                    DonyIcon('chevron-right', size: 18, color: cs.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
