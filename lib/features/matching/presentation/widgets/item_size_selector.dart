import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Quatre tuiles égales (S, M, L, XL) : le code en gras, son exemple dessous
/// (« Sac », « Carton », « Valise, chaise », « Meuble »).
///
/// Widget sans état : la taille choisie vit chez l'appelant. La taille est
/// facultative, donc un second tap sur la tuile choisie la désélectionne
/// ([allowDeselect]) et [onChanged] reçoit `null`. Hors désélection, la
/// tuile choisie est repérée par une bordure `primary` unie, jamais par un
/// dégradé.
class ItemSizeSelector extends StatelessWidget {
  const ItemSizeSelector({
    super.key,
    required this.sizes,
    required this.selected,
    required this.onChanged,
    this.allowDeselect = true,
  });

  /// Tailles proposées, dans l'ordre d'affichage.
  final List<ItemSize> sizes;

  /// Taille choisie, `null` quand aucune.
  final ItemSize? selected;

  final ValueChanged<ItemSize?> onChanged;

  /// Un second tap sur la tuile choisie la désélectionne (taille facultative).
  final bool allowDeselect;

  @override
  Widget build(BuildContext context) {
    // Tuiles de même hauteur, que la description tienne sur une ou deux lignes.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sizes.length; i++) ...[
            if (i > 0) const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: _SizeTile(
                size: sizes[i],
                selected: sizes[i] == selected,
                onTap: () {
                  if (sizes[i] == selected) {
                    if (allowDeselect) {
                      onChanged(null);
                    }
                  } else {
                    onChanged(sizes[i]);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SizeTile extends StatelessWidget {
  const _SizeTile({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final ItemSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Semantics(
      key: Key('item-size-${size.code}'),
      button: true,
      selected: selected,
      label: '${size.code}, ${size.description(l)}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.xs,
              vertical: DonySpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? cs.primaryContainer : cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(
                color: selected ? cs.primary : cs.outline,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  size.code,
                  maxLines: 1,
                  style: tt.titleMedium?.copyWith(
                    color: selected ? cs.primary : cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  size.description(l),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
