import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_brand_mark.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Contrôle dessiné à droite d'une [DonyOperatorTile].
enum DonyOperatorControl { checkbox, radio }

/// Ligne d'un réseau mobile money : pastille de marque, nom, sous-titre
/// facultatif et contrôle de sélection à droite (case pour une sélection
/// multiple, bouton radio pour un choix exclusif). Toute la ligne est
/// tappable ; l'état vit chez l'appelant ([selected], [onChanged]), jamais
/// ici. Sans [brand], la ligne sert d'en-tête (« Tous les réseaux »).
class DonyOperatorTile extends StatelessWidget {
  const DonyOperatorTile({
    super.key,
    this.brand,
    required this.title,
    this.subtitle,
    required this.control,
    required this.selected,
    this.indeterminate = false,
    this.onChanged,
    this.showDivider = true,
    this.enabled = true,
  });

  final String? brand;
  final String title;
  final String? subtitle;
  final DonyOperatorControl control;
  final bool selected;

  /// Case « partiellement cochée » (certains réseaux seulement) : dessine un
  /// tiret. Ignoré pour un bouton radio.
  final bool indeterminate;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isCheckbox = control == DonyOperatorControl.checkbox;
    return Semantics(
      container: true,
      enabled: enabled,
      checked: isCheckbox ? selected : null,
      mixed: isCheckbox ? indeterminate : null,
      selected: isCheckbox ? null : selected,
      inMutuallyExclusiveGroup: !isCheckbox,
      // Pas de `label:` ici : les Text (titre + sous-titre) descendants ne
      // sont pas exclus de la sémantique (contrairement à la pastille et au
      // contrôle), donc Flutter les fusionne dans ce nœud. Un `label`
      // explicite s'ajouterait à ce texte fusionné au lieu de le remplacer,
      // dupliquant le titre ("Orange Money\nOrange Money\n...").
      child: InkWell(
        onTap: enabled && onChanged != null
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!selected);
              }
            : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm + 2),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(bottom: BorderSide(color: cs.outline)),
                )
              : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Row(
              children: [
                if (brand != null) ...[
                  ExcludeSemantics(child: DonyBrandMark(brand: brand!)),
                  const SizedBox(width: DonySpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: brand == null
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: DonySpacing.xxs),
                        Text(
                          subtitle!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                ExcludeSemantics(
                  child: isCheckbox
                      ? _CheckBox(
                          selected: selected,
                          indeterminate: indeterminate,
                        )
                      : _RadioDot(selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Case 24 px : fond primaire et coche (ou tiret) quand elle est cochée,
/// contour `outline` sinon. Même dessin que le `Checkbox` de `DonyCheckbox`.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.selected, required this.indeterminate});

  final bool selected;
  final bool indeterminate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filled = selected || indeterminate;
    return Container(
      key: Key(
        selected ? 'operator-control-selected' : 'operator-control-unselected',
      ),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: filled ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.xs),
        border: filled ? null : Border.all(color: cs.outline, width: 1.5),
      ),
      child: filled
          ? Center(
              child: DonyIcon(
                selected ? 'check' : 'minus',
                size: 16,
                color: cs.onPrimary,
              ),
            )
          : null,
    );
  }
}

/// Bouton radio 20 px : disque primaire à point blanc quand il est retenu,
/// cercle `onSurfaceVariant` sinon (même dessin que `DonyRadioGroup`).
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: Key(
        selected ? 'operator-control-selected' : 'operator-control-unselected',
      ),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: cs.onSurfaceVariant, width: 1.5),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
