// Champs de filtre partagés par l'écran de composition de recherche
// (`SearchComposerScreen`) et, pour les deux sélecteurs modaux (prix,
// transport), par son ancêtre `search_form_bottom_sheet.dart`.
//
// Le corridor (villes de départ/arrivée) n'est PAS partagé depuis ce fichier :
// `SearchComposerScreen` construit son propre `CityCorridorFields` (clés
// `composer-departure-city`/`composer-arrival-city`, sous deux étiquettes
// distinctes OÙ/QUAND) plutôt que de réutiliser un bloc commun — voir
// `SearchComposerScreen._clearDeparture`/`_clearArrival`, qui duplique
// intentionnellement cette petite logique plutôt que de dépendre d'ici.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Presets de date (Aujourd'hui / Cette semaine / Ce mois) + date précise,
/// sans corridor ni en-tête propre : `SearchComposerScreen` le place sous sa
/// propre étiquette « QUAND », distincte de « OÙ ».
class DatePresetsField extends StatelessWidget {
  const DatePresetsField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final HomeSearchFilters value;
  final ValueChanged<HomeSearchFilters> onChanged;

  static const _presets = <(DonyDatePreset, String)>[
    (DonyDatePreset.today, "Aujourd'hui"),
    (DonyDatePreset.thisWeek, 'Cette semaine'),
    (DonyDatePreset.thisMonth, 'Ce mois'),
  ];

  void _togglePreset(DonyDatePreset preset) {
    final active = value.datePreset == preset;
    onChanged(
      value.copyWith(
        datePreset: active ? DonyDatePreset.none : preset,
        clearCustomDate: true,
      ),
    );
  }

  void _onCustomDate(DateTime? date) {
    if (date == null) {
      onChanged(
        value.copyWith(datePreset: DonyDatePreset.none, clearCustomDate: true),
      );
      return;
    }
    onChanged(
      value.copyWith(datePreset: DonyDatePreset.custom, customDate: date),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customDate = value.datePreset == DonyDatePreset.custom
        ? value.customDate
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final (preset, label) in _presets)
              QuickChip(
                label: label,
                active: value.datePreset == preset,
                onChanged: (_) => _togglePreset(preset),
              ),
          ],
        ),
        const SizedBox(height: DonySpacing.md),
        Row(
          children: [
            Expanded(
              child: DateField(
                label: 'DATE PRÉCISE',
                date: customDate,
                onChanged: _onCustomDate,
              ),
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}

// ── Sous-composants partagés ──────────────────────────────────────────────────

class SimpleSheet extends StatelessWidget {
  const SimpleSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        bottomPad + DonySpacing.base,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            title,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.base),
          child,
        ],
      ),
    );
  }
}

class PriceField extends StatelessWidget {
  const PriceField({super.key, required this.maxPrice, required this.onTap});

  final double? maxPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final active = maxPrice != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: active ? cs.primary : cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRIX MAX',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                DonyIcon('euro', size: 14, color: cs.primary),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  active ? '≤ ${formatPriceActive(maxPrice!)}/kg' : 'Tous',
                  style: tt.titleSmall?.copyWith(
                    color: active ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TransportModeField extends StatelessWidget {
  const TransportModeField({
    super.key,
    required this.mode,
    required this.onTap,
  });

  final TransportMode? mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final active = mode != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: active ? cs.primary : cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRANSPORT',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                active
                    ? Icon(mode!.icon, size: 14, color: cs.primary)
                    : DonyIcon('route', size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    active ? mode!.label : 'Tous',
                    style: tt.titleSmall?.copyWith(
                      color: active ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DonyIcon('chevron-right', size: 16, color: cs.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ContentTypeChip extends StatelessWidget {
  const ContentTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.emoji,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 180.ms,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: selected ? cs.primary : cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: selected ? cs.primary : cs.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickChip extends StatelessWidget {
  const QuickChip({
    super.key,
    required this.label,
    required this.active,
    required this.onChanged,
    this.iconAsset,
  });

  final String label;
  final bool active;
  final ValueChanged<bool> onChanged;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: AnimatedContainer(
        duration: 180.ms,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: active ? cs.primary : cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconAsset != null) ...[
              DonyIcon(
                iconAsset!,
                size: 14,
                color: active ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: DonySpacing.xs),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: active ? cs.primary : cs.onSurface,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastilles « urgence du départ » (trajets uniquement).
class UrgencyFilterChips extends StatelessWidget {
  const UrgencyFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final UrgencyFilter? selected;
  final ValueChanged<UrgencyFilter?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: UrgencyFilter.values.map((f) {
        final isSelected = selected == f;
        return GestureDetector(
          onTap: () => onChanged(isSelected ? null : f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? f.color.withValues(alpha: 0.12)
                  : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(DonyRadius.full),
              border: Border.all(
                color: isSelected ? f.color : cs.outline,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: f.color,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: f.color.withValues(alpha: 0.45),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  f.label,
                  style: tt.labelSmall?.copyWith(
                    color: isSelected ? f.color : cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.date,
    required this.onChanged,
    this.label = 'DATE',
  });

  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  /// Libellé du champ. Le bloc commun affiche « DATE PRÉCISE » pour le
  /// distinguer des presets qui le précèdent.
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (c, child) => Theme(
            data: Theme.of(
              c,
            ).copyWith(colorScheme: ColorScheme.light(primary: cs.primary)),
            child: child!,
          ),
        );
        onChanged(d);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: date != null ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: date != null ? cs.primary : cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                DonyIcon('calendar', size: 14, color: cs.primary),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  date != null
                      ? DateFormat('d MMM', 'fr').format(date!)
                      : 'Choisir',
                  style: tt.titleSmall?.copyWith(
                    color: date != null ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: date != null
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weight field ──────────────────────────────────────────────────────────────

class WeightField extends StatelessWidget {
  const WeightField({
    super.key,
    required this.weightKg,
    required this.onChanged,
  });

  final double weightKg;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final active = weightKg != 6;
    return GestureDetector(
      onTap: () => _showWeightPicker(context),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: active ? cs.primary : cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POIDS MIN',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                DonyIcon('scale', size: 14, color: cs.primary),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  '${weightKg.toStringAsFixed(0)} kg',
                  style: tt.titleSmall?.copyWith(
                    color: active ? cs.primary : cs.onSurface,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWeightPicker(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    double local = weightKg;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SimpleSheet(
          title: 'Poids minimum du trajet',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      local.toStringAsFixed(0),
                      style: tt.displayLarge?.copyWith(color: cs.primary),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(top: DonySpacing.md),
                      child: Text(
                        'kg',
                        style: tt.headlineMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.outline,
                  thumbColor: cs.primary,
                  trackHeight: 4,
                ),
                child: Slider(
                  value: local,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (v) => setS(() => local = v),
                ),
              ),
              const SizedBox(height: DonySpacing.md),
              DonyButton(
                label: 'Confirmer',
                onPressed: () {
                  onChanged(local);
                  // Navigator plutôt que `ctx.pop()` (go_router) : la feuille
                  // est un route modale imperative, et Navigator ne suppose
                  // aucun GoRouter au-dessus.
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sélecteurs modaux partagés ────────────────────────────────────────────────
//
// Déplacés à l'identique depuis `search_filter_sheet.dart` et
// `search_form_bottom_sheet.dart`, où ils existaient en double. Les deux
// feuilles consomment désormais cette seule implémentation : leurs conventions
// implicites (un prix égal au maximum vaut « pas de filtre ») ne peuvent plus
// diverger.

/// Sélecteur de prix maximum par kilo.
///
/// [maxPrice] est le prix courant, `null` si aucun filtre. [onApply] reçoit
/// `null` quand l'utilisateur pousse le curseur au maximum : la convention
/// « curseur au max = tous les prix » est celle des deux feuilles d'origine.
///
/// Bornes en devise ACTIVE ([priceFilterBoundsActive]) : la valeur est
/// interprétée par le backend dans la devise du lecteur, des bornes figées
/// 3–25 n'avaient de sens qu'en euro.
Future<void> showPricePicker(
  BuildContext context, {
  required double? maxPrice,
  required ValueChanged<double?> onApply,
}) async {
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;
  final bounds = priceFilterBoundsActive();
  final double kMin = bounds.min;
  final double kMax = bounds.max;
  // Un filtre mémorisé dans une autre devise (changement de devise entre deux
  // ouvertures) sortirait des bornes et ferait planter le Slider : on le borne.
  double local = (maxPrice ?? kMax).clamp(kMin, kMax);
  bool localEnabled = maxPrice != null && local < kMax;

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => SimpleSheet(
        title: 'Prix maximum',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                localEnabled
                    ? '≤ ${formatPriceActive(local)}/kg'
                    : 'Tous les prix',
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: localEnabled ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.sm),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: cs.primary,
                thumbColor: cs.primary,
                overlayColor: cs.primaryContainer,
                inactiveTrackColor: cs.outline,
              ),
              child: Slider(
                value: local,
                min: kMin,
                max: kMax,
                divisions: ((kMax - kMin) / bounds.step).round(),
                onChanged: (v) => setS(() {
                  local = v;
                  localEnabled = v < kMax;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${formatPriceActive(kMin)}/kg',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    '${formatPriceActive(kMax)}/kg',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DonySpacing.lg),
            DonyButton(
              label: 'Appliquer',
              onPressed: () {
                onApply(localEnabled ? local : null);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Sélecteur de mode de transport. [onApply] reçoit `null` quand aucun mode
/// n'est retenu (tap sur le mode déjà sélectionné = désélection).
Future<void> showTransportPicker(
  BuildContext context, {
  required TransportMode? mode,
  required ValueChanged<TransportMode?> onApply,
}) async {
  TransportMode? local = mode;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final tt = Theme.of(ctx).textTheme;
        final cs = Theme.of(ctx).colorScheme;
        return SimpleSheet(
          title: 'Mode de transport',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...TransportMode.values.map((m) {
                final selected = local == m;
                return GestureDetector(
                  onTap: () => setS(() => local = selected ? null : m),
                  child: AnimatedContainer(
                    duration: 180.ms,
                    margin: const EdgeInsets.only(bottom: DonySpacing.xs),
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.primaryContainer
                          : Theme.of(ctx).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DonyRadius.card),
                      border: Border.all(
                        color: selected ? cs.primary : cs.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          m.icon,
                          size: 18,
                          color: selected ? cs.primary : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: DonySpacing.md),
                        Expanded(
                          child: Text(
                            m.label,
                            style: tt.bodyMedium?.copyWith(
                              color: selected ? cs.primary : cs.onSurface,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (selected)
                          DonyIcon('circle-check', size: 18, color: cs.primary),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: DonySpacing.md),
              DonyButton(
                label: 'Appliquer',
                onPressed: () {
                  onApply(local);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
