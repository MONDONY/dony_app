import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter/material.dart';

/// Carte d'une alerte corridor : corridor, badge matchCount, toggle actif/pause.
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
