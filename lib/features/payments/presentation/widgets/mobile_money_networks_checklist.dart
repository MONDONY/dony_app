import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Liste à cocher des réseaux d'un catalogue, précédée de « Tous les
/// réseaux » (tout, rien, partiel). L'état vit chez l'appelant dans un
/// `ValueNotifier<Set<String>>` : aucun `setState`.
class MobileMoneyNetworksChecklist extends StatelessWidget {
  const MobileMoneyNetworksChecklist({
    super.key,
    required this.catalog,
    required this.selection,
    required this.onChanged,
  });

  final MobileMoneyProviderCatalog catalog;
  final ValueListenable<Set<String>> selection;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final all = catalog.providers.map((p) => p.code).toSet();
    return ValueListenableBuilder<Set<String>>(
      valueListenable: selection,
      builder: (context, selected, _) {
        final allSelected = all.isNotEmpty && selected.containsAll(all);
        return DonyCard(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
          child: Column(
            children: [
              DonyOperatorTile(
                key: const Key('network-all'),
                title: 'Tous les réseaux',
                control: DonyOperatorControl.checkbox,
                selected: allSelected,
                indeterminate: !allSelected && selected.isNotEmpty,
                onChanged: (_) => onChanged(allSelected ? {} : all),
              ),
              for (var i = 0; i < catalog.providers.length; i++)
                DonyOperatorTile(
                  key: Key('network-${catalog.providers[i].code}'),
                  brand: catalog.providers[i].brand,
                  title: catalog.providers[i].label,
                  subtitle: catalog.providers[i].detected
                      ? 'Détecté pour ce numéro'
                      : null,
                  control: DonyOperatorControl.checkbox,
                  selected: selected.contains(catalog.providers[i].code),
                  showDivider: i < catalog.providers.length - 1,
                  onChanged: (v) {
                    final next = {...selected};
                    if (v) {
                      next.add(catalog.providers[i].code);
                    } else {
                      next.remove(catalog.providers[i].code);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Trois lignes grises le temps du catalogue.
class MobileMoneyNetworksSkeleton extends StatelessWidget {
  const MobileMoneyNetworksSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    return DonyCard(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm + 2),
              decoration: i < 2
                  ? BoxDecoration(
                      border: Border(bottom: BorderSide(color: cs.outline)),
                    )
                  : null,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(120, 12),
                        const SizedBox(height: 6),
                        bar(80, 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  bar(24, 24),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
