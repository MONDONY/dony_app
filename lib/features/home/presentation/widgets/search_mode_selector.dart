import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Sélecteur de mode de la recherche : deux intentions exclusives, une
/// toujours active.
///
/// Contrôle segmenté pleine largeur, posé sous la barre de recherche et à
/// l'écart des chips de filtre. Les testeurs lisaient « Trajets » / « Colis »,
/// dessinés comme les chips voisines, comme deux filtres de plus et non comme
/// l'interrupteur qui change ce que la liste contient. Chaque segment nomme
/// donc l'intention (« J'envoie un colis », « Je voyage ») et dit en sous-titre
/// ce que la liste montrera. Le compteur [otherModeCount] s'inscrit dans le
/// sous-titre du segment inactif ; l'appelant ne le passe que lorsqu'il porte
/// une information, c'est-à-dire quand un filtre commun est posé.
class SearchModeSelector extends StatelessWidget {
  const SearchModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    this.otherModeCount,
  });

  final SearchMode mode;
  final ValueChanged<SearchMode> onChanged;
  final int? otherModeCount;

  static String tripsTitle(AppLocalizations l) => l.homeModeSelectorSending;
  static String parcelsTitle(AppLocalizations l) => l.homeModeSelectorTraveling;

  /// Ce que la liste montre dans ce mode ; sur le segment inactif, avec le
  /// nombre quand il est connu et non nul.
  String _subtitle(AppLocalizations l, SearchMode segment) {
    final n = segment == mode ? null : otherModeCount;
    final withCount = n != null && n > 0;
    return switch (segment) {
      SearchMode.trips =>
        withCount
            ? l.homeModeSelectorTravelersAvailable(n)
            : l.homeModeSelectorTravelersSubtitle,
      SearchMode.parcels =>
        withCount
            ? l.homeModeSelectorParcelsToCarry(n)
            : l.homeModeSelectorParcelsSubtitle,
    };
  }

  bool _countShown(SearchMode segment) =>
      segment != mode && (otherModeCount ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(DonyRadius.card),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(DonySpacing.xs),
          // Les deux segments prennent la même hauteur (celle du plus haut)
          // même dans un parent sans hauteur bornée, comme le bandeau
          // défilant au-dessus de la carte.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Segment(
                    key: const Key('search_mode_segment_trips'),
                    title: tripsTitle(l),
                    subtitle: _subtitle(l, SearchMode.trips),
                    countShown: _countShown(SearchMode.trips),
                    isActive: mode.isTrips,
                    onTap: () =>
                        mode.isTrips ? null : onChanged(SearchMode.trips),
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: _Segment(
                    key: const Key('search_mode_segment_colis'),
                    title: parcelsTitle(l),
                    subtitle: _subtitle(l, SearchMode.parcels),
                    countShown: _countShown(SearchMode.parcels),
                    isActive: mode.isParcels,
                    onTap: () =>
                        mode.isParcels ? null : onChanged(SearchMode.parcels),
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

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.title,
    required this.subtitle,
    required this.countShown,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final String subtitle;

  /// Vrai quand le sous-titre porte le compteur de l'autre mode.
  final bool countShown;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: isActive,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.sm,
            vertical: DonySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isActive ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tt.labelLarge?.copyWith(
                  color: isActive ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                subtitle,
                // Le compteur, et lui seul, porte cette clé : un seul segment
                // (l'inactif) peut l'afficher à la fois. Vérifier son absence
                // vérifie bien l'absence du compteur, pas celle du sélecteur.
                key: countShown ? const Key('mode-other-count') : null,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tt.labelSmall?.copyWith(
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
