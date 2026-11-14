// Étape « Mode » du formulaire « Publier un trajet » : le voyageur choisit
// comment il voyage. Elle n'existe que s'il a un vrai choix
// (`showModeStepFor`). Widget sans état : le choix vit dans un ValueNotifier
// que possède le formulaire.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Une carte par mode proposé : icône, titre, sous-titre, deux étiquettes, et
/// une coche sur la carte choisie.
class ModeStep extends StatelessWidget {
  const ModeStep({super.key, required this.modes, required this.notifier});

  /// Modes proposés, dans l'ordre d'affichage.
  final List<TransportMode> modes;

  /// Mode choisi ; `null` tant que le voyageur n'a pas choisi.
  final ValueNotifier<TransportMode?> notifier;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.tripPublishModeQuestion,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.tripPublishModeHint,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.lg),
        ValueListenableBuilder<TransportMode?>(
          valueListenable: notifier,
          builder: (context, selected, _) => Column(
            children: [
              for (final mode in modes)
                Padding(
                  padding: const EdgeInsets.only(bottom: DonySpacing.md),
                  child: _ModeCard(
                    mode: mode,
                    selected: selected?.displayGroup == mode.displayGroup,
                    onTap: () => notifier.value = mode,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Textes d'une carte : le titre, le sous-titre et deux étiquettes. Un mode
/// sans texte dédié (bateau, pas proposé à la publication avant le lot 3)
/// n'affiche que son nom.
({String title, String? subtitle, List<String> tags}) _copy(
  TransportMode mode,
  AppLocalizations l,
) => switch (mode.displayGroup) {
  TransportMode.plane => (
    title: l.tripPublishModeAirTitle,
    subtitle: l.tripPublishModeAirSubtitle,
    tags: [l.tripPublishModeAirTagDuration, l.tripPublishModeAirTagCapacity],
  ),
  TransportMode.car => (
    title: l.tripPublishModeRoadTitle,
    subtitle: l.tripPublishModeRoadSubtitle,
    tags: [l.tripPublishModeRoadTagScope, l.tripPublishModeRoadTagCapacity],
  ),
  _ => (title: mode.label(l), subtitle: null, tags: const <String>[]),
};

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TransportMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final copy = _copy(mode, context.l10n);
    final radius = BorderRadius.circular(DonyRadius.card);
    // Couleurs unies : seule la bordure (et la coche) porte la sélection.
    // Même épaisseur des deux côtés pour que la carte ne bouge pas.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: DecoratedBox(
          key: Key('mode-card-${mode.displayGroup.name}'),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: radius,
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: 2,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: DonySpacing.icon + DonySpacing.xs,
                      height: DonySpacing.icon + DonySpacing.xs,
                      decoration: BoxDecoration(
                        color: selected ? cs.primary : cs.primaryContainer,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: DonyIcon(
                        mode.iconAsset,
                        size: DonySpacing.lg,
                        color: selected ? cs.onPrimary : cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.title,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (copy.subtitle != null) ...[
                            const SizedBox(height: DonySpacing.xxs),
                            Text(
                              copy.subtitle!,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (copy.tags.isNotEmpty) ...[
                            const SizedBox(height: DonySpacing.sm),
                            Wrap(
                              spacing: DonySpacing.xs,
                              runSpacing: DonySpacing.xs,
                              children: [
                                for (final tag in copy.tags) _Tag(label: tag),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: DonySpacing.sm),
                      Container(
                        key: Key('mode-check-${mode.displayGroup.name}'),
                        width: DonySpacing.lg + DonySpacing.xs,
                        height: DonySpacing.lg + DonySpacing.xs,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: DonyIcon(
                          'check',
                          size: DonySpacing.base - DonySpacing.xs,
                          color: cs.onPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}
