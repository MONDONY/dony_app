import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';


/// Card de demande d'envoi — Option B (thumbnail gauche).
///
/// Layout :
/// ```
/// ┌────────────────────────────────────────────┐
/// │ ┌──────┐  Paris → Dakar           100 €   │
/// │ │      │  [M] · 10 kg · Vêtements         │
/// │ │ 📦  │  📅 15 juin ±2j                  │
/// │ │photo │  👤 Aminata D.  ⭐4.8  ✓         │
/// │ └──────┘                                   │
/// │              [  →  Faire une offre  →  ]   │
/// └────────────────────────────────────────────┘
/// ```
///
/// Quand [isOwnRequest] est `true` (l'expéditeur consulte sa propre demande),
/// le bouton "Faire une offre" est masqué et un chip "Ma demande" s'affiche.
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
              color: isOwnRequest ? cs.primary.withValues(alpha: 0.35) : cs.outlineVariant,
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
              // ── Ligne principale : thumbnail + infos ────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
              // ── CTA ─────────────────────────────────────────────────
              if (!isOwnRequest && onMakeOffer != null) ...[
                const SizedBox(height: DonySpacing.md),
                _MakeOfferButton(onTap: onMakeOffer!, cs: cs, tt: tt),
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 60 * index), duration: 280.ms)
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
        height: 80,
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
    final dateStr = DateFormat('EEE d MMM', 'fr').format(item.desiredDate);
    final toleranceStr =
        item.dateToleranceDays > 0 ? ' ±${item.dateToleranceDays}j' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Corridor + prix
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
        const SizedBox(height: DonySpacing.xs),
        // Taille · poids · catégorie
        Wrap(
          spacing: DonySpacing.xs,
          runSpacing: DonySpacing.xxs,
          children: [
            _InfoChip(label: sizeLabel, cs: cs, tt: tt, isPrimary: true),
            _InfoChip(
              label: '${item.weightKg.toStringAsFixed(0)} kg',
              cs: cs,
              tt: tt,
            ),
            _InfoChip(label: item.contentCategory.label, cs: cs, tt: tt),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        // Date
        Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 12, color: cs.onSurfaceVariant),
            const SizedBox(width: 3),
            Text(
              '$dateStr$toleranceStr',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        Divider(height: 1, color: cs.outlineVariant),
        const SizedBox(height: DonySpacing.sm),
        // Expéditeur — style TravelerCard
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DonyAvatar(
              name: item.sender.displayName,
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
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: DonySpacing.xxs,
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: cs.warning),
                      Text(
                        item.sender.averageRating.toStringAsFixed(1),
                        style: tt.titleSmall,
                      ),
                      Text(
                        '· ${item.sender.totalRatings} avis',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Chips utilitaires ────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.cs,
    required this.tt,
    this.isPrimary = false,
  });

  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isPrimary
            ? cs.primaryContainer
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: isPrimary ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Bouton CTA ───────────────────────────────────────────────────────────────

class _MakeOfferButton extends StatelessWidget {
  const _MakeOfferButton({
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_shipping_rounded,
                  color: Colors.white, size: 16),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Faire une offre',
                style: tt.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip "Ma demande" ─────────────────────────────────────────────────────────

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
