import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// « 👁 12 vues » : combien de personnes ont vu un trajet ou une demande, sur la
/// carte de son seul propriétaire dans le fil Rechercher.
///
/// Le back ne sert le chiffre qu'au propriétaire ; [isOwner] double la garde
/// côté client. Rien n'est affiché avant la première vue, ni sur un back qui
/// ne fournit pas encore le champ ([count] nul).
class OwnerViewsLabel extends StatelessWidget {
  const OwnerViewsLabel({
    super.key,
    required this.count,
    required this.isOwner,
  });

  final int? count;
  final bool isOwner;

  static bool isVisible({required int? count, required bool isOwner}) =>
      isOwner && (count ?? 0) >= 1;

  @override
  Widget build(BuildContext context) {
    if (!isVisible(count: count, isOwner: isOwner)) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      key: const Key('owner-views-label'),
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyIcon('eye', size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xxs),
        Text(
          context.l10n.searchCardViews(count!),
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
