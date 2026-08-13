import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:flutter/material.dart';

/// Sélecteur de mode de la recherche : deux états exclusifs, un toujours actif.
///
/// Premier élément de la rangée de chips, qui défile avec elle. Le compteur
/// [otherModeCount] renseigne sur l'autre mode sans occuper de surface propre ;
/// l'appelant ne le passe que lorsqu'il porte une information, c'est-à-dire
/// quand un filtre commun est posé.
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(DonyRadius.full),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Segment(
                key: const Key('search_mode_segment_trips'),
                label: 'Trajets',
                emoji: '✈️',
                isActive: mode.isTrips,
                badge: mode.isTrips ? null : otherModeCount,
                onTap: () => mode.isTrips ? null : onChanged(SearchMode.trips),
              ),
              _Segment(
                key: const Key('search_mode_segment_colis'),
                label: 'Colis',
                emoji: '📦',
                isActive: mode.isParcels,
                badge: mode.isParcels ? null : otherModeCount,
                onTap: () =>
                    mode.isParcels ? null : onChanged(SearchMode.parcels),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.emoji,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String emoji;
  final bool isActive;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final showBadge = badge != null && badge! > 0;
    return Semantics(
      button: true,
      selected: isActive,
      label: '$label${showBadge ? ', $badge résultats' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isActive ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: DonySpacing.xs),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showBadge) ...[
                const SizedBox(width: DonySpacing.xs),
                Container(
                  // Le badge, et lui seul, porte cette clé : un seul segment
                  // (l'inactif) peut l'afficher à la fois. Vérifier son absence
                  // vérifie bien l'absence du compteur, pas celle du sélecteur.
                  key: const Key('mode-other-count'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    '$badge',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
