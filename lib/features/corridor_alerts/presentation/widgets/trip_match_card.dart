import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/data/models/trip_match_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Carte « trajet disponible » pour l'alerte corridor direction
/// senderWantsTrips. Mirror visuel de MatchingRequestCard (layout B) mais
/// adapté aux champs voyageur : avatar/initiales, corridor, date, kg dispo,
/// prix/kg, note.
class TripMatchCard extends StatelessWidget {
  const TripMatchCard({
    super.key,
    required this.match,
    required this.index,
    this.onTap,
  });

  final TripMatchModel match;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = cs.primary;

    final dateStr = DateFormat(
      'd MMM',
      'fr',
    ).format(match.departureDate).toLowerCase();

    return Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(DonyRadius.card),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bande latérale bleue — identité « trajet »
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [accent, accent.withValues(alpha: 0.55)],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(DonySpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Micro-label Trajet ─────────────────────────────
                            Row(
                              children: [
                                DonyIcon('plane', size: 13, color: accent),
                                const SizedBox(width: DonySpacing.xxs),
                                Expanded(
                                  child: Text(
                                    'Trajet disponible',
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: DonySpacing.sm),

                            // ── Thumbnail + infos corridor ─────────────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TripThumbnail(match: match, cs: cs),
                                const SizedBox(width: DonySpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Corridor + date
                                      Text(
                                        '${match.departureCity} → ${match.arrivalCity}',
                                        style: tt.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          color: cs.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: DonySpacing.xs),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.flight_rounded,
                                            size: 13,
                                            color: cs.onSurfaceVariant,
                                          ),
                                          const SizedBox(
                                            width: DonySpacing.xxs,
                                          ),
                                          Text(
                                            dateStr,
                                            style: tt.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: DonySpacing.xs),
                                      // Kg dispo
                                      Text(
                                        '${match.availableKg.toStringAsFixed(0)} kg dispo',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: DonySpacing.xs),
                                      // Prix/kg
                                      match.pricePerKg != null
                                          ? Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.baseline,
                                              textBaseline:
                                                  TextBaseline.alphabetic,
                                              children: [
                                                Text(
                                                  'Prix ',
                                                  style: tt.bodySmall?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                                Text(
                                                  '${formatPriceIn(match.pricePerKg!, match.currency)}/kg',
                                                  style: tt.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color: cs.primary,
                                                    letterSpacing: -0.3,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              'Prix libre',
                                              style: tt.bodySmall?.copyWith(
                                                color: cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Divider(height: 1, color: cs.outlineVariant),
                            const SizedBox(height: DonySpacing.xs),
                            // ── Voyageur row ────────────────────────────────────
                            Row(
                              children: [
                                DonyAvatar(
                                  name: match.travelerName,
                                  size: DonyAvatarSize.sm,
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        match.travelerName,
                                        style: tt.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          DonyIcon(
                                            'star',
                                            size: 12,
                                            color: cs.warning,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            match.travelerRating
                                                .toStringAsFixed(1),
                                            style: tt.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurface,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DonyIcon(
                                  'chevron-right',
                                  size: 16,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
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
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 60 * index),
          duration: 280.ms,
        )
        .slideY(
          begin: 0.04,
          delay: Duration(milliseconds: 60 * index),
          curve: Curves.easeOutCubic,
        );
  }
}

// ── Miniature photo voyageur ─────────────────────────────────────────────────

class _TripThumbnail extends StatelessWidget {
  const _TripThumbnail({required this.match, required this.cs});
  final TripMatchModel match;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final url = match.photoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: SizedBox(
        width: 76,
        height: 76,
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                cacheKey: DonyImage.stableCacheKey(url),
                fit: BoxFit.cover,
                placeholder: (_, _) => _placeholder(cs),
                errorWidget: (_, _, _) => _placeholder(cs),
              )
            : _placeholder(cs),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
    color: cs.primaryContainer.withValues(alpha: 0.45),
    child: const Center(child: Text('✈️', style: TextStyle(fontSize: 30))),
  );
}
