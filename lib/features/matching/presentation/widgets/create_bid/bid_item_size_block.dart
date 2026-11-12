import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/presentation/widgets/item_size_selector.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Taille du colis à la réservation, sur un trajet qui porte une taille
/// maximum ([maxSize]).
///
/// Seules les tailles qui tiennent dans le maximum du trajet sont proposées :
/// l'expéditeur ne peut pas choisir une taille que le voyageur refuse. Le
/// choix est facultatif (un second tap retire la taille) et ne bloque jamais
/// l'envoi ; le back reste le dernier juge (422 `parcel-too-big`).
class BidItemSizeBlock extends StatelessWidget {
  const BidItemSizeBlock({
    super.key,
    required this.maxSize,
    required this.selected,
    required this.onChanged,
  });

  final ItemSize maxSize;
  final ItemSize? selected;
  final ValueChanged<ItemSize?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final sizes = [
      for (final size in ItemSize.values)
        if (size.fitsWithin(maxSize)) size,
    ];
    return Column(
      key: const Key('bid-item-size-block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.bidCreateItemSizeLabel,
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
        ItemSizeSelector(
          sizes: sizes,
          selected: selected,
          onChanged: onChanged,
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DonyIcon('info', size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Text(
                l.bidCreateItemSizeHelp(maxSize.code),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
