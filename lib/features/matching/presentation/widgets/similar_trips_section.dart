import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/similar_announcement.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Bloc « Autres annonces sur ce trajet » de la recherche de trajets : les
/// trajets proches qui ne remplissent pas tous les critères, sous la liste
/// exacte. Chaque carte est construite par [cardBuilder], pour qu'elle se
/// comporte exactement comme une carte de la liste exacte (ouverture, favori,
/// offre déjà déposée).
///
/// Sliver : se pose directement dans un `CustomScrollView`. Rien n'est rendu
/// quand [items] est vide (back antérieur, ou aucun trajet proche).
///
/// Sans trajet exact, c'est le sous-titre de l'en-tête de la feuille qui dit
/// « aucun trajet ne correspond exactement » (`homeListSubtitle`) : le bloc ne
/// répète pas la phrase juste en dessous.
class SimilarTripsSection extends StatelessWidget {
  const SimilarTripsSection({
    super.key,
    required this.items,
    required this.cardBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: DonySpacing.base),
    this.onClearFilters,
  });

  final List<SimilarAnnouncement> items;
  final Widget Function(SimilarAnnouncement item, int index) cardBuilder;

  /// Marges du bloc entier (en-tête et cartes).
  final EdgeInsetsGeometry padding;

  /// Action « Effacer les filtres » sous le sous-titre, quand le bloc remplace
  /// l'état vide de la liste exacte et que des filtres sont actifs. Absente si
  /// null.
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final header = Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.similarTripsTitle,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            l.similarTripsSubtitle,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (onClearFilters != null)
            TextButton(
              key: const Key('similar-trips-clear-filters'),
              onPressed: onClearFilters,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
                alignment: Alignment.centerLeft,
              ),
              child: Text(l.commonClearFilters),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms, curve: Curves.easeOutCubic);

    return SliverPadding(
      key: const Key('similar-trips-section'),
      padding: padding,
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
            itemBuilder: (_, i) => cardBuilder(items[i], i),
          ),
        ],
      ),
    );
  }
}
