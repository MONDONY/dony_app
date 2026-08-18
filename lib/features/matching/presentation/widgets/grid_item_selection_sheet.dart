import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Bottom sheet de sélection d'articles grille (mode tarification MIXED).
///
/// Retourne `Map<String, int>?` : les id→quantité sélectionnés,
/// ou `null` si l'utilisateur ferme sans confirmer.
///
/// Usage :
/// ```dart
/// final quantities = await GridItemSelectionSheet.show(
///   context,
///   items: announcement.priceGridItems,
///   initialQuantities: existingQuantities,
///   corridor: 'Paris → Dakar',
/// );
/// if (quantities != null) { /* utiliser les quantités */ }
/// ```
class GridItemSelectionSheet {
  static Future<Map<String, int>?> show(
    BuildContext context, {
    required List<AnnouncementGridItemModel> items,
    required Map<String, int> initialQuantities,
    required String corridor,
    String currency = 'EUR',
  }) async {
    final quantitiesNotifier = ValueNotifier<Map<String, int>>(
      Map<String, int>.from(initialQuantities),
    );
    Map<String, int>? result;

    await DonyBottomSheet.show(
      context,
      title: 'Articles disponibles',
      subtitle: corridor,
      stickyBottom: ValueListenableBuilder<Map<String, int>>(
        valueListenable: quantitiesNotifier,
        builder: (ctx, quantities, _) {
          final hasItems = quantities.values.any((q) => q > 0);
          final totalSelected = quantities.values.fold<int>(
            0,
            (sum, q) => sum + q,
          );
          // Total courant : sans lui, la feuille demandait de confirmer une
          // sélection sans jamais dire ce qu'elle coûte.
          final totalPrice = items.fold<double>(0, (sum, item) {
            final qty = quantities[item.id] ?? 0;
            return sum + qty * item.unitPriceDisplay;
          });

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                  child: Row(
                    children: [
                      Text(
                        '$totalSelected article${totalSelected > 1 ? 's' : ''}',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatPriceIn(totalPrice, currency),
                        key: const Key('grid-sheet-total'),
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              DonyButton(
                key: const Key('grid-sheet-confirm'),
                label: 'Confirmer la sélection',
                onPressed: hasItems
                    ? () {
                        result = Map<String, int>.from(quantities);
                        Navigator.of(ctx, rootNavigator: true).pop();
                      }
                    : null,
              ),
            ],
          );
        },
      ),
      child: _GridItemSelectionContent(
        items: items,
        quantitiesNotifier: quantitiesNotifier,
        currency: currency,
      ),
    ).whenComplete(quantitiesNotifier.dispose);

    return result;
  }
}

class _GridItemSelectionContent extends StatelessWidget {
  const _GridItemSelectionContent({
    required this.items,
    required this.quantitiesNotifier,
    this.currency = 'EUR',
  });

  final List<AnnouncementGridItemModel> items;
  final ValueNotifier<Map<String, int>> quantitiesNotifier;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          // Toutes les lignes se reconstruisent à chaque appui, alors qu'une
          // seule change. Assumé : une grille tient sous la dizaine d'articles
          // et une ligne ne déclenche ni repaint du CustomPaint ni layout
          // coûteux. Filtrer par article demanderait un notifier dérivé et un
          // StatefulWidget par ligne, pour un gain non perceptible.
          return ValueListenableBuilder<Map<String, int>>(
            valueListenable: quantitiesNotifier,
            builder: (context, quantities, _) {
              final qty = quantities[item.id] ?? 0;
              return _GridItemRow(
                item: item,
                quantity: qty,
                currency: currency,
                onIncrement: () {
                  quantitiesNotifier.value = {
                    ...quantitiesNotifier.value,
                    item.id: qty + 1,
                  };
                },
                onDecrement: qty > 0
                    ? () {
                        final updated = Map<String, int>.from(
                          quantitiesNotifier.value,
                        );
                        if (qty <= 1) {
                          updated.remove(item.id);
                        } else {
                          updated[item.id] = qty - 1;
                        }
                        quantitiesNotifier.value = updated;
                      }
                    : null,
              ).animate().fadeIn(delay: (50 * i).ms);
            },
          );
        }),
        const SizedBox(height: DonySpacing.lg),
      ],
    );
  }
}

class _GridItemRow extends StatelessWidget {
  const _GridItemRow({
    required this.item,
    required this.quantity,
    required this.onIncrement,
    this.onDecrement,
    this.currency = 'EUR',
  });

  final AnnouncementGridItemModel item;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isActive = quantity > 0;
    final unitPrice = formatPriceIn(item.unitPriceDisplay, currency);

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm + 2),
      child: DonyPriceTag(
        label: item.label,
        emoji: emojiForLabel(item.label),
        price: unitPrice,
        compact: true,
        highlighted: isActive,
        semanticLabel: isActive
            ? '${item.label}, $unitPrice l\'unité, $quantity sélectionné'
            : '${item.label}, $unitPrice l\'unité',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepBtn(
              key: Key('grid-item-remove-${item.id}'),
              iconAsset: 'minus',
              active: isActive,
              semanticLabel: 'Retirer un ${item.label}',
              onTap: onDecrement,
            ),
            SizedBox(
              width: 28,
              child: Center(
                child: Text(
                  '$quantity',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            _StepBtn(
              key: Key('grid-item-add-${item.id}'),
              iconAsset: 'plus',
              active: true,
              semanticLabel: 'Ajouter un ${item.label}',
              onTap: onIncrement,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    super.key,
    required this.iconAsset,
    required this.active,
    required this.semanticLabel,
    this.onTap,
  });

  /// Nom annoncé, distinct par article : « moins » et « plus » répétés sur
  /// chaque ligne d'une grille ne disent pas de quoi on change la quantité.
  final String semanticLabel;

  final String iconAsset;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Estompe fondue dans les couleurs plutôt qu'une couche Opacity : à
    // l'ouverture tous les boutons « moins » sont inactifs, ce qui pousserait
    // autant de couches de composition sur le thread raster.
    final dimmed = onTap == null;
    final bgColor = (active ? cs.primary : cs.surfaceContainerLow).withValues(
      alpha: dimmed ? 0.4 : 1,
    );
    final iconColor = (active ? cs.onPrimary : cs.onSurfaceVariant).withValues(
      alpha: dimmed ? 0.4 : 1,
    );
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        // Le visuel reste à 28 pt, la zone tappable monte au minimum requis.
        child: Container(
          constraints: const BoxConstraints(
            minWidth: kDonyMinTapTarget,
            minHeight: kDonyMinTapTarget,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            child: DonyIcon(iconAsset, size: 14, color: iconColor),
          ),
        ),
      ),
    );
  }
}
