import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Sélecteur de note, de 1 à 5 étoiles.
///
/// Existait en double, à l'identique, dans `rating_screen.dart` et
/// `rating_bottom_sheet.dart`. Réuni ici pour que les annotations
/// d'accessibilité ne puissent pas diverger entre les deux : sans elles, noter
/// est impossible sans voir l'écran, les étoiles n'étant que des zones
/// tappables muettes.
class StarSelector extends StatelessWidget {
  const StarSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.padding = EdgeInsets.zero,
  });

  /// Note actuellement choisie, de 0 (aucune) à 5.
  final int selected;
  final ValueChanged<int> onSelect;

  /// Marge autour de la rangée. Le sheet en met, l'écran non.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final index = i + 1;
            final filled = index <= selected;
            return Semantics(
              button: true,
              // Une note parmi cinq, pas cinq bascules indépendantes.
              inMutuallyExclusiveGroup: true,
              // La note choisie, pas « toutes les étoiles jusqu'à elle » :
              // c'est la valeur qui est sélectionnée, pas le remplissage.
              selected: index == selected,
              label: 'Noter $index sur 5',
              container: true,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onSelect(index),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Builder(
                      builder: (context) => DonyIcon(
                        'star',
                        key: ValueKey(filled),
                        size: 44,
                        color: filled
                            ? DonyColors.starGold
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
