import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Carte carousel near-me pour une demande d'expéditeur.
///
/// Design Option A : photo hero en haut (responsive via [LayoutBuilder]),
/// gradient overlay corridor + prix, section info 2 lignes compactes.
/// S'inscrit dans la hauteur du carousel `(screenH * 0.37).clamp(310, 400)`.
class PackageRequestCarouselCard extends StatelessWidget {
  const PackageRequestCarouselCard({
    super.key,
    required this.item,
    required this.index,
    this.distanceLabel,
    this.isOwnRequest = false,
    this.onTap,
  });

  final PackageRequestSearchItem item;
  final int index;
  final String? distanceLabel;
  final bool isOwnRequest;
  final VoidCallback? onTap;

  static const double _photoRatio = 0.44;

  String get _sizeLabel {
    switch (item.parcelSize) {
      case ParcelSize.small:
        return 'S';
      case ParcelSize.medium:
        return 'M';
      case ParcelSize.large:
        return 'L';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final photoHeight = (constraints.maxWidth * _photoRatio).clamp(
            110.0,
            180.0,
          );
          return Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Photo hero ──────────────────────────────────────────
                    _PhotoHero(
                      item: item,
                      height: photoHeight,
                      distanceLabel: isOwnRequest ? null : distanceLabel,
                      isOwnRequest: isOwnRequest,
                      cs: cs,
                      tt: tt,
                    ),
                    // ── Info section ────────────────────────────────────────
                    Expanded(
                      child: _InfoSection(
                        item: item,
                        cs: cs,
                        tt: tt,
                        sizeLabel: _sizeLabel,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 60 * index),
                duration: 250.ms,
              )
              .slideY(begin: 0.06, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

// ── Photo hero with gradient overlay ────────────────────────────────────────

class _PhotoHero extends StatelessWidget {
  const _PhotoHero({
    required this.item,
    required this.height,
    required this.distanceLabel,
    required this.isOwnRequest,
    required this.cs,
    required this.tt,
  });

  final PackageRequestSearchItem item;
  final double height;
  final String? distanceLabel;
  final bool isOwnRequest;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo ou placeholder emoji
          if (item.photoUrl != null)
            DonyImage(
              url: item.photoUrl!,
              fit: BoxFit.cover,
              placeholder: (_) => _PhotoPlaceholder(
                emoji: emojiForLabel(item.primaryCategory),
                cs: cs,
              ),
              errorWidget: (_) => _PhotoPlaceholder(
                emoji: emojiForLabel(item.primaryCategory),
                cs: cs,
              ),
            )
          else
            _PhotoPlaceholder(
              emoji: emojiForLabel(item.primaryCategory),
              cs: cs,
            ),

          // Gradient en bas → corridor + prix
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.departureCity} → ${item.arrivalCity}',
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.targetPriceEur != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      formatPriceIn(item.targetPriceEur!, item.currency),
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 6),
                    Text(
                      'Libre',
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Badge distance (top-left) OU chip "Ma demande"
          if (isOwnRequest)
            Positioned(
              top: 8,
              left: 8,
              child: _OwnRequestBadge(cs: cs, tt: tt),
            )
          else if (distanceLabel != null &&
              distanceLabel!.isNotEmpty &&
              distanceLabel != '-')
            Positioned(
              top: 8,
              left: 8,
              child: _DistanceBadge(label: distanceLabel!, cs: cs, tt: tt),
            ),
        ],
      ),
    );
  }
}

// ── Photo placeholder ────────────────────────────────────────────────────────

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.emoji, required this.cs});
  final String emoji;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
    );
  }
}

// ── Own request badge ────────────────────────────────────────────────────────

class _OwnRequestBadge extends StatelessWidget {
  const _OwnRequestBadge({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DonyIcon('user', size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            'Ma demande',
            style: tt.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Distance badge ───────────────────────────────────────────────────────────

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({
    required this.label,
    required this.cs,
    required this.tt,
  });

  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DonyIcon('map-pin', size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info section ─────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.item,
    required this.cs,
    required this.tt,
    required this.sizeLabel,
  });

  final PackageRequestSearchItem item;
  final ColorScheme cs;
  final TextTheme tt;
  final String sizeLabel;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM', 'fr').format(item.desiredDate);
    final toleranceStr = item.dateToleranceDays > 0
        ? ' ±${item.dateToleranceDays}j'
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ligne 1 : expéditeur · note · taille · poids
          Row(
            children: [
              Expanded(
                child: Text(
                  item.sender.displayName,
                  style: tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DonyIcon('star', size: 12, color: cs.warning),
              const SizedBox(width: 2),
              Text(
                item.sender.averageRating.toStringAsFixed(1),
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 6),
              _SizeBadge(label: sizeLabel, cs: cs, tt: tt),
              const SizedBox(width: 4),
              Text(
                '${item.weightKg.toStringAsFixed(0)} kg',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Ligne 2 : date · catégorie
          Row(
            children: [
              DonyIcon('calendar', size: 11, color: cs.onSurfaceVariant),
              const SizedBox(width: 3),
              Text(
                '$dateStr$toleranceStr',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              if (item.primaryCategory != null) ...[
                Text(
                  emojiForLabel(item.primaryCategory),
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    item.primaryCategory!,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SizeBadge extends StatelessWidget {
  const _SizeBadge({required this.label, required this.cs, required this.tt});
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: cs.primary,
          fontSize: 10,
        ),
      ),
    );
  }
}
