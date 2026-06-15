import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HeaderPill
// ─────────────────────────────────────────────────────────────────────────────

/// Style visuel d'une pill de header.
enum HeaderPillStyle {
  /// Fond primary bleu — action principale.
  primary,

  /// Fond warm sable + accent terracotta — section communautaire.
  warm,

  /// Fond primarySoft bleu pâle + texte primary — action secondaire.
  soft,
}

/// Pill d'action compacte placée dans les headers de section ou d'écran.
///
/// Design : pill stadium avec ink ripple au tap, icône optionnelle alignée
/// au texte avec gap xs. 3 variants de couleur via [HeaderPillStyle].
class HeaderPill extends StatelessWidget {
  const HeaderPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconAsset,
    this.style = HeaderPillStyle.primary,
  });

  final String label;
  final IconData? icon;
  final String? iconAsset;
  final HeaderPillStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (Color bg, Color fg, Color? borderColor) = switch (style) {
      HeaderPillStyle.primary => (cs.primary, cs.onPrimary, null),
      HeaderPillStyle.warm => (
          cs.surfaceWarm,
          DonyColors.terra600,
          DonyColors.sand200,
        ),
      HeaderPillStyle.soft => (
          DonyColors.primarySoft,
          DonyColors.primaryHover,
          DonyColors.blue100,
        ),
    };

    return Material(
      color: bg,
      shape: StadiumBorder(
        side: borderColor != null
            ? BorderSide(color: borderColor)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconAsset != null) ...[
                DonyIcon(iconAsset!, size: 15, color: fg),
                const SizedBox(width: DonySpacing.xs + 1),
              ] else if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: DonySpacing.xs + 1),
              ],
              Text(
                label,
                style: tt.labelLarge?.copyWith(
                  color: fg,
                  fontSize: 12.5,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TripsStatsStrip
// ─────────────────────────────────────────────────────────────────────────────

/// Bandeau horizontal de 3 tuiles statistiques pour le voyageur.
///
/// Design : 3 tuiles égales, surface + bordure fine outline, value en
/// headlineSmall poids 800, label en bodySmall muted. Animation staggerée
/// en entrée (fadeIn + slideY).
class TripsStatsStrip extends StatelessWidget {
  const TripsStatsStrip({super.key, required this.summary});

  final TripsSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: '${summary.activeTrips}',
            label: 'Trajets actifs',
            valueColor: cs.primary,
            index: 0,
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: _StatTile(
            value: '${_compact(summary.kgSoldThisMonth)} kg',
            label: 'Vendus ce mois',
            index: 1,
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: _StatTile(
            value: '${_compact(summary.revenueThisMonth)} €',
            label: 'Revenus',
            valueColor: cs.secondary,
            index: 2,
          ),
        ),
      ],
    );
  }

  /// Format compact : arrondi à l'entier (suffisant pour les stats header).
  String _compact(double v) => v.round().toString();
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.index,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: DonySpacing.md,
        horizontal: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor ?? cs.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              fontSize: 10,
              color: cs.onSurfaceVariant,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
        .animate(delay: (index * 60).ms)
        .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusChipsRow
// ─────────────────────────────────────────────────────────────────────────────

/// Données d'une chip de filtre statut.
class StatusChipData<T> {
  const StatusChipData({
    required this.label,
    required this.value,
    this.count,
    this.dotColor,
  });

  final String label;
  final T value;

  /// Compteur optionnel affiché après le label (ex: "Tous · 34").
  final int? count;

  /// Pastille colorée optionnelle à gauche du label (ex: vert = actif).
  final Color? dotColor;
}

/// Rangée horizontale scrollable de chips de filtre statut.
///
/// Pattern Airbnb : chip active fond `ink800` + texte blanc, chips inactives
/// fond surface + bordure outline. Animation d'état via `AnimatedContainer`.
///
/// [equals] : comparateur optionnel pour les types sans `==` naturel (ex: `Set`).
/// Pour les `Set<X>`, passer `setEquals` depuis `package:flutter/foundation.dart`.
class StatusChipsRow<T> extends StatelessWidget {
  const StatusChipsRow({
    super.key,
    required this.chips,
    required this.selected,
    required this.onSelected,
    this.equals,
    this.trailing,
  });

  final List<StatusChipData<T>> chips;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Comparateur d'égalité optionnel (ex: `setEquals` pour des `Set<X>`).
  final bool Function(T a, T b)? equals;

  /// Widget optionnel en fin de rangée (ex. bouton filtre période).
  final Widget? trailing;

  bool _isActive(T value) => equals?.call(value, selected) ?? (value == selected);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: DonySpacing.xs + 3),
              child: _ChipItem<T>(
                data: chip,
                active: _isActive(chip.value),
                onTap: () => onSelected(chip.value),
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ChipItem<T> extends StatelessWidget {
  const _ChipItem({
    required this.data,
    required this.active,
    required this.onTap,
  });

  final StatusChipData<T> data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final label =
        data.count != null ? '${data.label} · ${data.count}' : data.label;

    // Active : fond ink800 (quasi-noir texturé), texte blanc pour contraste max.
    // Inactive : fond surface, bordure outline standard.
    final bgColor = active ? DonyColors.ink800 : cs.surface;
    final borderColor = active ? DonyColors.ink800 : cs.outline;
    final textColor = active ? DonyColors.neutral0 : cs.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.sm - 1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: data.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs + 1),
              ],
              Text(
                label,
                style: tt.titleSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ActivitySearchField
// ─────────────────────────────────────────────────────────────────────────────

/// Champ de recherche pill compact pour les headers d'activité.
///
/// Design : pill (radius full), fond surface, bordure outline → focus primary,
/// icône loupe muted à gauche. Dense pour s'insérer dans les headers sans
/// prendre trop de hauteur.
class ActivitySearchField extends StatelessWidget {
  const ActivitySearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          borderSide: BorderSide(color: color),
        );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        prefixIcon: DonyIcon(
          'search',
          size: 18,
          color: cs.onSurfaceVariant,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: DonySpacing.md - 2,
        ),
        filled: true,
        fillColor: cs.surface,
        border: border(cs.outline),
        enabledBorder: border(cs.outline),
        focusedBorder: border(cs.primary),
      ),
    );
  }
}
