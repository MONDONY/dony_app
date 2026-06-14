import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Card affichée dans le panel bas du Home (mode TRAVELER, tab Demandes).
/// Style hero photo + CTA proéminent — symétrique de TravelerCard mais
/// orienté demandes d'expéditeurs.
class PackageRequestCard extends StatelessWidget {
  const PackageRequestCard({
    super.key,
    required this.item,
    required this.index,
  });

  final PackageRequestSearchItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateStr = DateFormat('EEE d MMM', 'fr').format(item.desiredDate);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero (photo OR fallback gradient with corridor) ────────────────
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: item.photoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
                    errorWidget: (_, __, ___) => _gradientFallback(cs),
                  )
                else
                  _gradientFallback(cs),
                // Dark gradient overlay for text readability
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, DonyColors.scrimDark],
                    ),
                  ),
                ),
                Positioned(
                  left: DonySpacing.base,
                  right: DonySpacing.base,
                  bottom: DonySpacing.base,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.departureCity}  →  ${item.arrivalCity}',
                          style: tt.headlineMedium?.copyWith(
                            color: DonyColors.neutral0,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: DonyColors.shadowDark,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.sm,
                            vertical: DonySpacing.xs),
                        decoration: BoxDecoration(
                          color: DonyColors.neutral0.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(DonyRadius.full),
                          border: Border.all(
                              color:
                                  DonyColors.neutral0.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          item.parcelSize.name.toUpperCase(),
                          style: tt.labelMedium?.copyWith(
                            color: DonyColors.neutral0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: DonySpacing.base,
                  runSpacing: DonySpacing.xs,
                  children: [
                    _Pill(
                      icon: Icons.calendar_today_rounded,
                      label:
                          '$dateStr  ±${item.dateToleranceDays}j',
                    ),
                    _Pill(
                      icon: Icons.scale_rounded,
                      label: '${item.weightKg.toStringAsFixed(item.weightKg.truncateToDouble() == item.weightKg ? 0 : 1)} kg',
                    ),
                    if (item.targetPriceEur != null)
                      _Pill(
                        icon: Icons.payments_rounded,
                        label:
                            '${item.targetPriceEur!.toStringAsFixed(0)} €',
                        accent: true,
                      ),
                    _Pill(
                      icon: Icons.label_outline_rounded,
                      label: item.contentCategory.label,
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.md),
                Divider(height: 1, color: cs.outline),
                const SizedBox(height: DonySpacing.md),

                // ── Sender mini-profile ─────────────────────────────────────
                Row(
                  children: [
                    DonyAvatar(
                      name: item.sender.displayName,
                      imageUrl: item.sender.avatarUrl,
                      size: DonyAvatarSize.sm,
                      verified: item.sender.kycVerified,
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.sender.displayName,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.sender.totalRatings > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 13, color: cs.warning),
                                const SizedBox(width: 2),
                                Text(
                                  '${item.sender.averageRating.toStringAsFixed(1)} · ${item.sender.totalRatings} avis',
                                  style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: DonySpacing.md),
                Builder(
                  builder: (context) {
                    final isFirm =
                        !item.negotiable && item.targetPriceEur != null;
                    return DonyButton(
                      label: isFirm
                          ? 'Prendre à ${PriceDisplay.eur(item.targetPriceEur!)}'
                          : 'Faire une offre',
                      onPressed: () => MakeOfferBottomSheet.show(
                        context,
                        packageRequestId: item.id,
                        targetPriceEur: item.targetPriceEur,
                        weightKg: item.weightKg,
                        departureCity: item.departureCity,
                        arrivalCity: item.arrivalCity,
                        isFirmPrice: isFirm,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, delay: (60 * index).ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _gradientFallback(ColorScheme cs) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.secondary,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          size: 56,
          color: DonyColors.neutral0.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.accent = false});
  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = accent ? cs.primary : cs.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: accent ? cs.primary : cs.onSurfaceVariant,
            fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
