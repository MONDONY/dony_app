// Ligne compacte du mode de transport, au-dessus des étapes du formulaire
// « Publier un trajet » quand l'étape Mode n'est pas affichée (mode fixé, ou
// rappel du mode choisi). Widget sans état : le mode vit dans un
// ValueNotifier que possède le formulaire.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Libellé « Mode de transport » et une puce par mode.
///
/// Un mode courant absent de [modes] (trajet BOAT existant alors que la
/// création du bateau n'est pas ouverte) est ajouté en tête et affiché
/// sélectionné : le voyageur voit toujours le mode réel de son trajet.
class TransportModeRow extends StatelessWidget {
  const TransportModeRow({
    super.key,
    required this.modes,
    required this.notifier,
    this.readOnly = false,
  });

  /// Modes proposés, dans l'ordre d'affichage.
  final List<TransportMode> modes;

  /// Mode courant ; `null` vaut avion (anciennes données).
  final ValueNotifier<TransportMode?> notifier;

  /// Mode figé (modification, demande dédiée) : les taps ne font rien.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.tripPublishModeSectionLabel,
          style: tt.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        ValueListenableBuilder<TransportMode?>(
          valueListenable: notifier,
          builder: (context, value, _) {
            final current = transportModeOrPlane(value).displayGroup;
            final shown = [
              if (!modes.any((m) => m.displayGroup == current)) current,
              ...modes,
            ];
            return Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.xs,
              children: [
                for (final mode in shown)
                  _ModeChip(
                    mode: mode,
                    selected: mode.displayGroup == current,
                    enabled: !readOnly,
                    onTap: () => notifier.value = mode,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Puce icône + nom, du même style que `DonyChip`, avec une icône SVG.
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TransportMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.primary : cs.onSurfaceVariant;
    // Lecture seule : la puce du mode réel reste pleinement lisible, les
    // autres s'estompent.
    final dimmed = !enabled && !selected;
    return Semantics(
      key: Key('mode-chip-${mode.displayGroup.name}'),
      button: true,
      enabled: enabled,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Opacity(
              opacity: dimmed ? 0.5 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: DonySpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: selected ? cs.primaryContainer : cs.surface,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                  border: Border.all(
                    color: selected ? cs.primary : cs.outline,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DonyIcon(mode.iconAsset, size: 14, color: fg),
                    const SizedBox(width: DonySpacing.xs),
                    Flexible(
                      child: Text(
                        mode.label(context.l10n),
                        style: tt.labelMedium?.copyWith(
                          color: fg,
                          letterSpacing: 0,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
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
