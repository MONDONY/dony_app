import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class TravelerCard extends StatelessWidget {
  const TravelerCard({
    super.key,
    required this.announcement,
    required this.index,
    required this.isOwnAnnouncement,
    required this.onTap,
    this.distanceBadge,
    this.existingBidStatus,
  });

  final AnnouncementModel announcement;
  final VoidCallback? onTap;
  final int index;
  final bool isOwnAnnouncement;
  final String? distanceBadge;
  /// Statut d'un bid actif (PENDING ou ACCEPTED) déjà déposé par l'expéditeur
  /// courant sur cette annonce. Si non null, la carte affiche un chip de
  /// statut + une bordure colorée pour rappeler à l'expéditeur qu'il a déjà
  /// une demande en cours sur ce trajet.
  final String? existingBidStatus;

  static const int _maxVisibleChips = 3;

  String get _displayName => announcement.traveler?.resolvedName ?? 'Voyageur';

  ({Color border, Color chipBg, Color chipFg, String label}) _bidStyle(ColorScheme cs) {
    switch (existingBidStatus) {
      case 'ACCEPTED':
        return (
          border: cs.success,
          chipBg: cs.successLight,
          chipFg: cs.success,
          label: 'Demande acceptée',
        );
      case 'PENDING':
      default:
        return (
          border: cs.warning,
          chipBg: cs.warningLight,
          chipFg: DonyColors.amberDark,
          label: 'Demande en attente',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final totalTrips = traveler?.totalTrips;
    final isKiloPro = traveler?.kiloPro ?? false;
    final isProAccount = traveler?.isProAccount ?? false;
    final dateStr = DateFormat('EEE d', 'fr').format(announcement.departureDate);
    final categories = announcement.acceptedContentTypes ?? [];
    final hasExistingBid = existingBidStatus != null;
    final bidStyle = _bidStyle(cs);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: hasExistingBid ? bidStyle.border : cs.outline,
            width: hasExistingBid ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasExistingBid) ...[
              _ExistingBidChip(
                label: bidStyle.label,
                bg: bidStyle.chipBg,
                fg: bidStyle.chipFg,
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            if (distanceBadge != null) ...[
              _DistanceBadge(label: distanceBadge!),
              const SizedBox(height: DonySpacing.sm),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyAvatar(
                  name: _displayName,
                  size: DonyAvatarSize.md,
                  verified: traveler?.kycVerified ?? false,
                  pro: isProAccount,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName, style: tt.titleLarge, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: DonySpacing.xxs),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: DonySpacing.xxs,
                        runSpacing: DonySpacing.xxs,
                        children: [
                          Icon(Icons.star_rounded, size: 13, color: cs.warning),
                          Text(rating != null ? rating.toStringAsFixed(1) : '—', style: tt.titleSmall),
                          Text(
                            '· ${totalTrips ?? 0} trajet${(totalTrips ?? 0) > 1 ? 's' : ''}',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          if (isKiloPro) const _KycBadge(),
                          if (isProAccount) const _ProBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  announcement.pricingMode == 'MIXED'
                      ? 'Grille tarifaire'
                      : '${formatKgPrice(announcement.senderPricePerKg)} €/kg',
                  style: tt.titleLarge?.copyWith(color: cs.success, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.xxs),
                Text(dateStr, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(width: DonySpacing.md),
                Icon(Icons.inventory_2_outlined, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.xxs),
                Text(
                  announcement.capacityUnit == 'KG_FREE'
                      ? 'Kg libre'
                      : '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.sm),
              _CategoryChips(categories: categories, maxVisible: _maxVisibleChips),
            ],
            if (isOwnAnnouncement) ...[
              const SizedBox(height: DonySpacing.sm),
              Text('Votre trajet', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      )
          .animate()
          .fadeIn(delay: Duration(milliseconds: 60 * index))
          .slideY(begin: 0.04, curve: Curves.easeOutCubic),
    );
  }
}

class _ExistingBidChip extends StatelessWidget {
  const _ExistingBidChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const Key('traveler-card-existing-bid-chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 13, color: fg),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.onSurface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, size: 11, color: cs.surface),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.surface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 10, color: cs.warning),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'PRO',
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.warning,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _KycBadge extends StatelessWidget {
  const _KycBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: cs.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: DonySpacing.xxs),
          Text('KYC', style: tt.labelSmall?.copyWith(color: cs.success, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.maxVisible});
  final List<String> categories;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = categories.take(maxVisible).toList();
    final overflow = categories.length - maxVisible;
    return Wrap(
      spacing: DonySpacing.xs,
      runSpacing: DonySpacing.xs,
      children: [
        for (final label in visible) _CategoryChip(label: label),
        if (overflow > 0) _CategoryChip(label: '+$overflow'),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: cs.outline),
      ),
      child: Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
    );
  }
}
