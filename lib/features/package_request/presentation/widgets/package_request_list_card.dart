import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/sender_public_profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class PackageRequestListCard extends StatelessWidget {
  const PackageRequestListCard({
    super.key,
    required this.item,
    this.onTap,
    this.onMakeOffer,
    this.isOwnRequest = false,
    this.index = 0,
  });

  final PackageRequestSearchItem item;
  final VoidCallback? onTap;
  final VoidCallback? onMakeOffer;
  final bool isOwnRequest;
  final int index;

  String get _sizeLabel => switch (item.parcelSize) {
        ParcelSize.small => 'S',
        ParcelSize.medium => 'M',
        ParcelSize.large => 'L',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isOwnRequest
                  ? cs.primary.withValues(alpha: 0.35)
                  : cs.outlineVariant,
              width: isOwnRequest ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          padding: const EdgeInsets.all(DonySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOwnRequest) ...[
                _OwnRequestChip(cs: cs, tt: tt),
                const SizedBox(height: DonySpacing.sm),
              ],
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Thumbnail(item: item, cs: cs),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: _InfoColumn(
                        item: item,
                        sizeLabel: _sizeLabel,
                        cs: cs,
                        tt: tt,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 60 * index), duration: 280.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ── Thumbnail ────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, required this.cs});
  final PackageRequestSearchItem item;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: SizedBox(
        width: 80,
        child: item.photoUrl != null && item.photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: item.photoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => _PlaceholderBox(item: item, cs: cs),
                errorWidget: (_, _, _) => _PlaceholderBox(item: item, cs: cs),
              )
            : _PlaceholderBox(item: item, cs: cs),
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({required this.item, required this.cs});
  final PackageRequestSearchItem item;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.primaryContainer.withValues(alpha: 0.45),
      child: Center(
        child: Text(
          item.contentCategory.emoji,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}

// ── Info column ──────────────────────────────────────────────────────────────

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.item,
    required this.sizeLabel,
    required this.cs,
    required this.tt,
  });

  final PackageRequestSearchItem item;
  final String sizeLabel;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('d MMM', 'fr').format(item.desiredDate).toLowerCase();
    final toleranceStr =
        item.dateToleranceDays > 0 ? ' ±${item.dateToleranceDays}j' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Corridor + prix ───────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${item.departureCity} → ${item.arrivalCity}',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: cs.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            if (item.targetPriceEur != null)
              Text(
                '${item.targetPriceEur!.toStringAsFixed(0)} €',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                  letterSpacing: -0.3,
                ),
              )
            else
              Text(
                'Libre',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),

        // ── Grille 2×2 ────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _MiniInfoTile(
                icon: Icons.scale_rounded,
                label: 'Poids',
                value: '${item.weightKg.toStringAsFixed(0)} kg',
                cs: cs,
                tt: tt,
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: _MiniInfoTile(
                icon: Icons.open_in_full_rounded,
                label: 'Taille',
                value: sizeLabel,
                cs: cs,
                tt: tt,
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        Row(
          children: [
            Expanded(
              child: _MiniInfoTile(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: '$dateStr$toleranceStr',
                cs: cs,
                tt: tt,
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: _MiniInfoTile(
                icon: item.contentCategory.icon,
                label: 'Catégorie',
                value: item.contentCategory.label,
                cs: cs,
                tt: tt,
                isUrgent: item.contentCategory.isUrgent,
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),

        // ── Expéditeur ────────────────────────────────────────────────────
        Divider(height: 1, color: cs.outlineVariant),
        const SizedBox(height: DonySpacing.xs),
        InkWell(
          onTap: () => showSenderPublicProfileSheet(context, item.sender),
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
            child: Row(
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
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12, color: cs.warning),
                          const SizedBox(width: 2),
                          Text(
                            item.sender.averageRating.toStringAsFixed(1),
                            style: tt.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            ' · ${item.sender.totalRatings} avis',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Mini info tile (grille 2×2) ──────────────────────────────────────────────

class _MiniInfoTile extends StatelessWidget {
  const _MiniInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
    this.isUrgent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final bgColor = isUrgent
        ? cs.error.withValues(alpha: 0.07)
        : cs.surfaceContainerHighest;
    final iconColor = isUrgent ? cs.error : cs.onSurfaceVariant;
    final labelColor = isUrgent
        ? cs.error.withValues(alpha: 0.75)
        : cs.onSurfaceVariant;
    final valueColor = isUrgent ? cs.error : cs.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        border: isUrgent
            ? Border.all(color: cs.error.withValues(alpha: 0.18))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: DonySpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(
                    fontSize: 9,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  value,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip "Ma demande" ────────────────────────────────────────────────────────

class _OwnRequestChip extends StatelessWidget {
  const _OwnRequestChip({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_rounded, size: 13, color: cs.primary),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Ma demande',
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
