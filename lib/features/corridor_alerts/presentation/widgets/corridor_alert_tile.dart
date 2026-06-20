import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte d'une alerte corridor : corridor, badge matchCount, toggle actif/pause,
/// et résumé des filtres (date · poids · catégories).
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
      parts.add('${_compactDate(alert.dateFrom!)}–${_compactDate(alert.dateTo!)}');
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

  static String _compactDate(DateTime d) =>
      DateFormat('d MMM', 'fr').format(d);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: alert.active
                ? cs.primary.withValues(alpha: 0.35)
                : cs.outline,
          ),
        ),
        child: Row(
          children: [
            DonyIcon('bell',
                size: 20,
                color: alert.active ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DirectionPill(
                        direction: alert.direction,
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      Flexible(
                        child: Text(
                          '${alert.departureCity} → ${alert.arrivalCity}',
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
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
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    alert.active ? 'Active' : 'En pause',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: alert.active,
              onChanged: onToggle,
              activeThumbColor: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill showing direction: « Colis » (traveler wants packages) or « Trajets » (sender wants trips).
class _DirectionPill extends StatelessWidget {
  const _DirectionPill({required this.direction});

  final AlertDirection direction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTrip = direction == AlertDirection.senderWantsTrips;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isTrip
            ? cs.secondaryContainer
            : cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTrip ? Icons.flight_rounded : Icons.inventory_2_rounded,
            size: 11,
            color: isTrip
                ? cs.onSecondaryContainer
                : cs.onPrimaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            isTrip ? 'Trajets' : 'Colis',
            style: tt.labelSmall?.copyWith(
              color: isTrip
                  ? cs.onSecondaryContainer
                  : cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
