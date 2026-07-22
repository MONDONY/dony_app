// Rangée de chips de l'écran Rechercher.
//
// Fusionne les trois classes privées d'avant (`_HomeFilterChipsRow`,
// `_PackageRequestFilterChipsRow`, `_SmallChip`) en une seule rangée pilotée
// par le mode. Deux rangées jumelles se sont révélées être le vrai vecteur de
// divergence : la date, commune aux deux modes, y était rendue par deux
// widgets différents et effacée par deux chemins différents.
//
// Ordre imposé : le sélecteur de mode d'abord, puis les chips COMMUNS (urgent,
// date) à `key` stable, puis ceux du mode courant. Les clés stables évitent
// qu'un chip commun soit détruit/reconstruit à la bascule, ce qui perdrait son
// animation et, plus grave, ferait clignoter un état identique.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/search_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeFilterChipsRow extends StatelessWidget {
  const HomeFilterChipsRow({
    super.key,
    required this.mode,
    required this.filters,
    required this.onModeChanged,
    required this.onUrgentToggle,
    required this.onDateTap,
    required this.onDateClear,
    required this.onRatingTap,
    required this.onRatingClear,
    required this.onCapacityTap,
    required this.onCapacityClear,
    required this.onPriceTap,
    required this.onPriceClear,
    required this.onKiloProToggle,
    required this.onMaxWeightTap,
    required this.onMaxWeightClear,
    required this.onParcelSizeTap,
    required this.onParcelSizeClear,
    this.otherModeCount,
  });

  final SearchMode mode;
  final HomeSearchFilters filters;
  final ValueChanged<SearchMode> onModeChanged;

  /// Nombre de résultats de l'autre mode. `null` quand il n'est pas informatif
  /// (aucun filtre géographique ni temporel posé) : le segment inactif n'est
  /// alors pas badgé du tout.
  final int? otherModeCount;

  // Communs
  final VoidCallback onUrgentToggle;
  final VoidCallback onDateTap;
  final VoidCallback onDateClear;

  // Trajets
  final VoidCallback onRatingTap;
  final VoidCallback onRatingClear;
  final VoidCallback onCapacityTap;
  final VoidCallback onCapacityClear;
  final VoidCallback onPriceTap;
  final VoidCallback onPriceClear;
  final VoidCallback onKiloProToggle;

  // Colis
  final VoidCallback onMaxWeightTap;
  final VoidCallback onMaxWeightClear;
  final VoidCallback onParcelSizeTap;
  final VoidCallback onParcelSizeClear;

  String get _dateLabel {
    switch (filters.datePreset) {
      case DonyDatePreset.today:
        return 'Aujourd\'hui';
      case DonyDatePreset.thisWeek:
        return 'Cette semaine';
      case DonyDatePreset.thisMonth:
        return 'Ce mois-ci';
      case DonyDatePreset.custom:
        return filters.customDate != null
            ? DateFormat('d MMM', 'fr').format(filters.customDate!)
            : 'Date';
      case DonyDatePreset.none:
        return 'Toutes dates';
    }
  }

  String get _ratingLabel => filters.minRating != null
      ? '★ ${filters.minRating!.toStringAsFixed(1)}+'
      : 'Note';

  String get _capacityLabel {
    final min = filters.weightMin;
    final max = filters.weightMax;
    if (min != null && max != null) {
      return '${min.toInt()}–${max.toInt()} kg';
    }
    if (min != null) {
      return '≥ ${min.toInt()} kg';
    }
    if (max != null) {
      return '≤ ${max.toInt()} kg';
    }
    return 'Kilos';
  }

  String get _priceLabel => filters.maxPricePerKg != null
      ? '≤ ${filters.maxPricePerKg!.toStringAsFixed(0)} €/kg'
      : 'Prix';

  String get _maxWeightLabel =>
      filters.maxWeight != null ? '≤ ${filters.maxWeight!.toInt()} kg' : 'Kilos';

  String get _parcelSizeLabel =>
      filters.parcelSize != null ? filters.parcelSize!.wireName : 'Taille';

  @override
  Widget build(BuildContext context) {
    final hasDate = filters.datePreset != DonyDatePreset.none;
    final hasCapacity = filters.weightMin != null || filters.weightMax != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Clé STABLE : elle ne doit pas encoder la présence du compteur,
          // sinon l'arrivée du nombre démonte le sélecteur et emporte
          // l'animation de 200 ms du segment actif. La clé du badge vit dans
          // `SearchModeSelector`, sur le badge lui-même.
          SearchModeSelector(
            key: const Key('search-mode-selector'),
            mode: mode,
            onChanged: onModeChanged,
            otherModeCount: otherModeCount,
          ),
          const SizedBox(width: DonySpacing.sm),

          // ── Communs ─────────────────────────────────────────────────────────
          HomeSmallChip(
            key: const Key('chip-urgent'),
            label: '🔥 Urgent',
            isActive: filters.urgentOnly,
            onTap: onUrgentToggle,
          ),
          const SizedBox(width: DonySpacing.xs),
          HomeSmallChip(
            key: const Key('chip-date'),
            label: _dateLabel,
            isActive: hasDate,
            iconAsset: 'calendar',
            onTap: hasDate ? onDateClear : onDateTap,
          ),
          const SizedBox(width: DonySpacing.xs),

          // ── Spécifiques au mode ─────────────────────────────────────────────
          if (mode.isTrips) ...[
            HomeSmallChip(
              label: _ratingLabel,
              isActive: filters.minRating != null,
              iconAsset: 'star',
              onTap: filters.minRating != null ? onRatingClear : onRatingTap,
            ),
            const SizedBox(width: DonySpacing.xs),
            HomeSmallChip(
              label: _capacityLabel,
              isActive: hasCapacity,
              iconAsset: 'dumbbell',
              onTap: hasCapacity ? onCapacityClear : onCapacityTap,
            ),
            const SizedBox(width: DonySpacing.xs),
            HomeSmallChip(
              label: _priceLabel,
              isActive: filters.maxPricePerKg != null,
              iconAsset: 'euro',
              onTap: filters.maxPricePerKg != null ? onPriceClear : onPriceTap,
            ),
            const SizedBox(width: DonySpacing.xs),
            HomeSmallChip(
              label: 'Kilo Pro',
              isActive: filters.kiloProOnly,
              onTap: onKiloProToggle,
            ),
          ] else ...[
            HomeSmallChip(
              label: _maxWeightLabel,
              isActive: filters.maxWeight != null,
              iconAsset: 'dumbbell',
              onTap:
                  filters.maxWeight != null ? onMaxWeightClear : onMaxWeightTap,
            ),
            const SizedBox(width: DonySpacing.xs),
            HomeSmallChip(
              label: _parcelSizeLabel,
              isActive: filters.parcelSize != null,
              iconAsset: 'package',
              onTap: filters.parcelSize != null
                  ? onParcelSizeClear
                  : onParcelSizeTap,
            ),
          ],
        ],
      ),
    );
  }
}

/// Pastille de filtre de l'écran Rechercher. Ex-`_SmallChip` de `home_screen`,
/// remontée ici avec la rangée qui l'utilise.
class HomeSmallChip extends StatelessWidget {
  const HomeSmallChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.iconAsset,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isActive ? 0.20 : 0.08),
              blurRadius: isActive ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconAsset != null) ...[
              DonyIcon(
                iconAsset!,
                size: 15,
                color: isActive ? Colors.white : cs.onSurfaceVariant,
              ),
              const SizedBox(width: DonySpacing.xxs),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isActive ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
