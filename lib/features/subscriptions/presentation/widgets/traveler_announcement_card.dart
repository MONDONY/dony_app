import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone 1 — Route
          Row(
            children: [
              Expanded(
                child: Text(
                  announcement.departureCity,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 1.5,
                      color: cs.primary.withValues(alpha: 0.3),
                    ),
                    const DonyEmoji.planeTakeoff(size: 16),
                    Container(
                      width: 28,
                      height: 1.5,
                      color: cs.primary.withValues(alpha: 0.3),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cs.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  announcement.arrivalCity,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        Flexible(
                          child: Text(
                            DateFormat('dd MMM yyyy', 'fr')
                                .format(announcement.departureDate),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
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
                children: [
                  Flexible(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            '${formatKgPrice(netToSenderPrice(announcement.pricePerKg))} €',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xxs),
                        Text(
                          '/kg',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: onReserve,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                      ),
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Réserver'),
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
