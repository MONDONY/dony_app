import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TravelerAnnouncementCard extends StatelessWidget {
  const TravelerAnnouncementCard({
    super.key,
    required this.announcement,
    required this.onReserve,
  });

  final TravelerAnnouncement announcement;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      padding: const EdgeInsets.fromLTRB(DonySpacing.base, DonySpacing.base, DonySpacing.base - 2, DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone 1 — Route
          Row(
            children: [
              Flexible(
                flex: 1,
                child: Text(
                  announcement.departureCity,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 1,
                      color: cs.primary.withValues(alpha: 0.3),
                    ),
                    Icon(Icons.flight_takeoff_rounded, size: 14, color: cs.primary),
                    Container(
                      width: 24,
                      height: 1,
                      color: cs.primary.withValues(alpha: 0.3),
                    ),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cs.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                flex: 1,
                child: Text(
                  announcement.arrivalCity,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),

          const SizedBox(height: DonySpacing.base),
          Container(height: 1, color: cs.outline),
          const SizedBox(height: DonySpacing.base),

          // Zone 2 — Footer grille 2×2
          Column(
            children: [
              // Ligne 1 : date (gauche) · kg dispo (droite)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        DateFormat('dd MMM yyyy', 'fr')
                            .format(announcement.departureDate),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),

              const SizedBox(height: DonySpacing.sm),

              // Ligne 2 : prix (gauche) · bouton Réserver (droite)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${announcement.pricePerKg.toStringAsFixed(0)} €',
                          style: tt.titleLarge?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '/kg',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  FilledButton(
                    onPressed: onReserve,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: DonySpacing.xs,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Réserver', style: tt.labelLarge),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
