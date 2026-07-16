import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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
    final isFull = announcement.availableKg <= 0;

    return DonyCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre d'accent dégradée — signature visuelle "boarding pass"
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, DonyColors.accent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(DonyRadius.card),
                  bottomLeft: Radius.circular(DonyRadius.card),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
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
                              const DonyEmoji.planeTakeoff(),
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
                    SizedBox(
                      height: 8,
                      child: CustomPaint(
                        painter: _DashedLinePainter(color: cs.outline),
                        size: const Size(double.infinity, 1),
                      ),
                    ),
                    const SizedBox(height: DonySpacing.base),

                    // Zone 2 — Footer grille 2×2
                    Column(
                      children: [
                        // Ligne 1 : date (gauche) · kg dispo / Complet (droite)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DonyIcon(
                                    'calendar',
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
                              isFull
                                  ? 'Complet'
                                  : '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                              style: tt.bodySmall?.copyWith(
                                color: isFull ? cs.error : cs.onSurfaceVariant,
                                fontWeight: isFull ? FontWeight.w700 : FontWeight.w400,
                              ),
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
                              onPressed: isFull ? null : onReserve,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Séparateur pointillé horizontal — signature visuelle "boarding pass".
/// Pas de nouvelle dépendance pub : simple CustomPainter.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashGap = 3.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
