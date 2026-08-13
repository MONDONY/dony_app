import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Ligne plate (style liste WhatsApp) d'une alerte corridor : avatar cloche,
/// corridor, résumé des filtres et toggle actif/pause. Pas de bordure ni de
/// carte — séparateurs fins gérés par la liste parente.
///
/// La direction (colis ↔ trajets) n'est plus affichée ici : chaque écran
/// d'alertes est mono-direction (filtré en amont).
class CorridorAlertTile extends StatelessWidget {
  const CorridorAlertTile({
    super.key,
    required this.alert,
    required this.onTap,
    required this.onToggle,
  });

  final CorridorAlertModel alert;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  /// Builds a compact filter summary, e.g. "20–30 juin · ≥ 3 kg · Documents, Vêtements".
  /// For senderWantsTrips, only the date window is meaningful.
  /// Returns a neutral fallback when no filter is set.
  static String buildFilterSummary(CorridorAlertModel alert) {
    final parts = <String>[];

    // ── Date ──────────────────────────────────────────────────────────────
    if (alert.dateFrom != null && alert.dateTo != null) {
      parts.add(
        '${_compactDate(alert.dateFrom!)}–${_compactDate(alert.dateTo!)}',
      );
    } else if (alert.dateFrom != null) {
      parts.add('À partir du ${_compactDate(alert.dateFrom!)}');
    } else if (alert.dateTo != null) {
      parts.add("Jusqu'au ${_compactDate(alert.dateTo!)}");
    }

    // For trajets direction, only date is meaningful — skip weight & categories.
    if (alert.direction == AlertDirection.senderWantsTrips) {
      return parts.isEmpty ? 'Toute date' : parts.join(' · ');
    }

    // ── Weight ────────────────────────────────────────────────────────────
    if (alert.minWeightKg != null) {
      final kg = alert.minWeightKg!;
      final display = kg == kg.truncateToDouble()
          ? '${kg.toInt()} kg'
          : '$kg kg';
      parts.add('≥ $display');
    }

    // ── Categories ────────────────────────────────────────────────────────
    if (alert.contentCategories.isNotEmpty) {
      parts.add(alert.contentCategories.join(', '));
    }

    if (parts.isEmpty) {
      return 'Toute date · tout poids';
    }
    return parts.join(' · ');
  }

  static String _compactDate(DateTime d) => DateFormat('d MMM', 'fr').format(d);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final active = alert.active;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            // ── Avatar cloche ────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? cs.primaryContainer
                    : cs.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: DonyIcon(
                  'bell',
                  size: 20,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            // ── Corridor + résumé filtres ────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${alert.departureCity} → ${alert.arrivalCity}',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: active ? cs.onSurface : cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (alert.matchCount > 0) ...[
                        const SizedBox(width: DonySpacing.xs),
                        DonyBadge(
                          label: '${alert.matchCount}',
                          type: DonyBadgeType.success,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    buildFilterSummary(alert),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (alert.hasPickupZone) ...[
                    const SizedBox(height: 4),
                    _ZoneChip(
                      radiusKm: alert.radiusKm!,
                      label: alert.centerLabel,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            // ── Toggle actif/pause ───────────────────────────────────────
            Switch(
              value: active,
              onChanged: onToggle,
              activeThumbColor: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit chip « 📍 ≤ R km · Lieu » affiché quand l'alerte porte une zone de remise.
class _ZoneChip extends StatelessWidget {
  const _ZoneChip({required this.radiusKm, this.label});

  final int radiusKm;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final text = label != null ? '≤ $radiusKm km · $label' : '≤ $radiusKm km';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.xs + 2,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('map-pin', size: 11, color: cs.onPrimaryContainer),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                text,
                style: tt.labelSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
