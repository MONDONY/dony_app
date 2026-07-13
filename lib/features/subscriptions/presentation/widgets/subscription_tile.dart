import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter/material.dart';

class SubscriptionTile extends StatelessWidget {
  const SubscriptionTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleBell,
  });
  final SubscriptionItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleBell;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final subtitle = item.lastAnnouncement != null && item.hasNew
        ? '${item.lastAnnouncement!.departureCity} → ${item.lastAnnouncement!.arrivalCity}'
        : (item.ongoingTripsCount > 0
            ? '⭐ ${item.averageRating?.toStringAsFixed(1) ?? '-'} · ${item.ongoingTripsCount} trajet(s) en cours'
            : '⭐ ${item.averageRating?.toStringAsFixed(1) ?? '-'} · aucun trajet en cours');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base, vertical: DonySpacing.md),
        child: Row(
          children: [
            DonyAvatar(name: item.travelerName),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(item.travelerName, style: tt.titleSmall, overflow: TextOverflow.ellipsis)),
                    if (item.hasNew) ...[
                      const SizedBox(width: DonySpacing.xs),
                      const DonyBadge(label: 'Nouveau', type: DonyBadgeType.error),
                    ],
                  ]),
                  Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggleBell,
              icon: DonyIcon(item.pushEnabled ? 'bell' : 'bell-off',
                  color: item.pushEnabled ? cs.primary : cs.onSurfaceVariant),
            ),
            DonyIcon('chevron-right', color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
