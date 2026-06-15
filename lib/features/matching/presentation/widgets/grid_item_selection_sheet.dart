import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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
  }) async {
    final quantitiesNotifier = ValueNotifier<Map<String, int>>(
      Map<String, int>.from(initialQuantities),
    );
    Map<String, int>? result;

    await DonyBottomSheet.show(
      context,
      title: 'Articles disponibles',
      stickyBottom: ValueListenableBuilder<Map<String, int>>(
        valueListenable: quantitiesNotifier,
        builder: (ctx, quantities, _) {
          final hasItems = quantities.values.any((q) => q > 0);
          final totalSelected =
              quantities.values.fold<int>(0, (sum, q) => sum + q);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                  child: Text(
                    '$totalSelected article${totalSelected > 1 ? 's' : ''} sélectionné${totalSelected > 1 ? 's' : ''}',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
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
        corridor: corridor,
        quantitiesNotifier: quantitiesNotifier,
      ),
    ).whenComplete(quantitiesNotifier.dispose);

    return result;
  }
}

class _GridItemSelectionContent extends StatelessWidget {
  const _GridItemSelectionContent({
    required this.items,
    required this.corridor,
    required this.quantitiesNotifier,
  });

  final List<AnnouncementGridItemModel> items;
  final String corridor;
  final ValueNotifier<Map<String, int>> quantitiesNotifier;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          corridor,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ).animate().fadeIn(duration: 200.ms),
        const SizedBox(height: DonySpacing.md),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return ValueListenableBuilder<Map<String, int>>(
            valueListenable: quantitiesNotifier,
            builder: (context, quantities, _) {
              final qty = quantities[item.id] ?? 0;
              return _GridItemRow(
                item: item,
                quantity: qty,
                onIncrement: () {
                  quantitiesNotifier.value = {
                    ...quantitiesNotifier.value,
                    item.id: qty + 1,
                  };
                },
                onDecrement: qty > 0
                    ? () {
                        final updated =
                            Map<String, int>.from(quantitiesNotifier.value);
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
  });

  final AnnouncementGridItemModel item;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isActive = quantity > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: DonySpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(
          color: isActive ? cs.success : cs.outline,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: tt.titleSmall),
                Text(
                  '${item.unitPriceDisplay.toStringAsFixed(2)} € / unité',
                  style: tt.bodySmall?.copyWith(
                    color: isActive ? cs.success : cs.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _StepBtn(
                key: Key('grid-item-remove-${item.id}'),
                iconAsset: 'minus',
                active: quantity > 0,
                onTap: onDecrement,
              ),
              SizedBox(
                width: 28,
                child: Center(
                  child: Text('$quantity', style: tt.titleSmall),
                ),
              ),
              _StepBtn(
                key: Key('grid-item-add-${item.id}'),
                iconAsset: 'plus',
                active: true,
                onTap: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    super.key,
    required this.iconAsset,
    required this.active,
    this.onTap,
  });

  final String iconAsset;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = active ? cs.primary : cs.surfaceContainerLow;
    final iconColor = active ? cs.onPrimary : cs.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap != null ? 1.0 : 0.4,
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
    );
  }
}
