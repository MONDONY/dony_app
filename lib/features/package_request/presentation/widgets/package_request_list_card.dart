import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// **L2 — Airbnb 1-col éditorial** : card de demande pour le tab "Demandes"
/// du Home côté voyageur.
///
/// Layout :
/// ```
/// ┌─────────────────────────────────────┐
/// │  HERO PHOTO 16:10                   │  ← badge URGENT top-left si médicaments
/// │  (gradient fallback si pas photo)   │  ← badge S/M/L · kg top-right
/// ├─────────────────────────────────────┤
/// │  Paris → Dakar               42 €  │
/// │  EEE d MMM · cat label             │
/// │  ─────────────────────────────────  │
/// │  👤 Marie · ★4.9  KYC   [Faire offre →] │
/// └─────────────────────────────────────┘
/// ```
class PackageRequestListCard extends StatelessWidget {
  const PackageRequestListCard({
    super.key,
    required this.item,
    this.onTap,
    this.onMakeOffer,
  });

  final PackageRequestSearchItem item;
  final VoidCallback? onTap;
  final VoidCallback? onMakeOffer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(DonyRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroPhoto(item: item),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, DonySpacing.md, 14, DonySpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CorridorRow(item: item),
                    const SizedBox(height: DonySpacing.xs),
                    _SubInfoRow(item: item),
                    const SizedBox(height: DonySpacing.md),
                    Divider(color: cs.outline, height: 1),
                    const SizedBox(height: DonySpacing.md),
                    _SenderRow(item: item, onMakeOffer: onMakeOffer),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({required this.item});
  final PackageRequestSearchItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: item.photoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: cs.surfaceContainerHighest),
              errorWidget: (_, _, _) => _fallback(context),
            )
          else
            _fallback(context),
          if (item.contentCategory.isUrgent)
            Positioned(
              top: 10,
              left: 10,
              child: _UrgentBadge(),
            ),
          Positioned(
            top: 10,
            right: 10,
            child: _SizeBadge(
              parcelSize: item.parcelSize.name.toUpperCase(),
              weightKg: item.weightKg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.18),
            cs.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          item.contentCategory.emoji,
          style: const TextStyle(fontSize: 64),
        ),
      ),
    );
  }
}

class _UrgentBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DonyColors.error,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        boxShadow: const [
          BoxShadow(
            color: DonyColors.scrimLight,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
          const SizedBox(width: DonySpacing.xs),
          Text(
            'URGENT',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeBadge extends StatelessWidget {
  const _SizeBadge({required this.parcelSize, required this.weightKg});
  final String parcelSize;
  final double weightKg;

  String get _shortSize => switch (parcelSize) {
        'SMALL' => 'S',
        'MEDIUM' => 'M',
        'LARGE' => 'L',
        _ => parcelSize.substring(0, 1),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Text(
        '$_shortSize · ${weightKg.toStringAsFixed(weightKg == weightKg.truncateToDouble() ? 0 : 1)} kg',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _CorridorRow extends StatelessWidget {
  const _CorridorRow({required this.item});
  final PackageRequestSearchItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${item.departureCity} → ${item.arrivalCity}',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        if (item.targetPriceEur != null)
          Text(
            '${item.targetPriceEur!.toStringAsFixed(0)} €',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cs.primary,
              letterSpacing: -0.3,
            ),
          )
        else
          Text(
            'Libre',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _SubInfoRow extends StatelessWidget {
  const _SubInfoRow({required this.item});
  final PackageRequestSearchItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('EEE d MMM', 'fr').format(item.desiredDate);
    return Text(
      '$dateStr · ${item.contentCategory.label}',
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

class _SenderRow extends StatelessWidget {
  const _SenderRow({required this.item, this.onMakeOffer});
  final PackageRequestSearchItem item;
  final VoidCallback? onMakeOffer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sender = item.sender;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: cs.primaryContainer,
          child: Text(
            sender.displayName.isEmpty ? '?' : sender.displayName[0],
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      sender.displayName,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (sender.kycVerified) ...[
                    const SizedBox(width: DonySpacing.xs),
                    Icon(Icons.verified_rounded,
                        color: cs.primary, size: 14),
                  ],
                ],
              ),
              if (sender.totalRatings > 0)
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        color: DonyColors.warning, size: 13),
                    const SizedBox(width: 2),
                    Text(
                      sender.averageRating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (onMakeOffer != null)
          Material(
            color: cs.primary,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              onTap: onMakeOffer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Faire offre',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimary,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    Icon(Icons.arrow_forward_rounded,
                        color: cs.onPrimary, size: 14),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
