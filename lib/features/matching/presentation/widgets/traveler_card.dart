import 'package:dony/core/design/design_system.dart';
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
  });

  final AnnouncementModel announcement;
  final VoidCallback? onTap;
  final int index;
  final bool isOwnAnnouncement;
  final String? distanceBadge;

  static const int _maxVisibleChips = 3;

  String get _displayName => announcement.traveler?.resolvedName ?? 'Voyageur';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final totalTrips = traveler?.totalTrips;
    final isKiloPro = traveler?.kiloPro ?? false;
    final isProAccount = traveler?.isProAccount ?? false;
    final dateStr = DateFormat('EEE d', 'fr').format(announcement.departureDate);
    final categories = announcement.acceptedContentTypes ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DonyColors.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.borderDefault),
        ),
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (distanceBadge != null) ...[
              _DistanceBadge(label: distanceBadge!),
              const SizedBox(height: DonySpacing.sm),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyAvatar(name: _displayName, size: DonyAvatarSize.md),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName, style: tt.titleLarge, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: DonySpacing.xxs),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: DonyColors.warning),
                          const SizedBox(width: DonySpacing.xxs),
                          Text(rating != null ? rating.toStringAsFixed(1) : '—', style: tt.titleSmall),
                          const SizedBox(width: DonySpacing.xxs),
                          Text(
                            '· ${totalTrips ?? 0} trajet${(totalTrips ?? 0) > 1 ? 's' : ''}',
                            style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
                          ),
                          if (isKiloPro) ...[
                            const SizedBox(width: DonySpacing.xs),
                            const _KycBadge(),
                          ],
                          if (isProAccount) ...[
                            const SizedBox(width: DonySpacing.xs),
                            const _ProBadge(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  '${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                  style: tt.titleLarge?.copyWith(color: DonyColors.success, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 13, color: DonyColors.textSubtle),
                const SizedBox(width: DonySpacing.xxs),
                Text(dateStr, style: tt.bodySmall?.copyWith(color: DonyColors.textMuted)),
                const SizedBox(width: DonySpacing.md),
                const Icon(Icons.inventory_2_outlined, size: 13, color: DonyColors.textSubtle),
                const SizedBox(width: DonySpacing.xxs),
                Text(
                  '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                  style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
                ),
              ],
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.sm),
              _CategoryChips(categories: categories, maxVisible: _maxVisibleChips),
            ],
            if (isOwnAnnouncement) ...[
              const SizedBox(height: DonySpacing.sm),
              Text('Votre trajet', style: tt.labelMedium?.copyWith(color: DonyColors.textMuted)),
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

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: DonyColors.ink900,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded, size: 11, color: Colors.white),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
      decoration: BoxDecoration(
        color: DonyColors.warning50,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: DonyColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 10, color: DonyColors.warning),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'PRO',
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: DonyColors.warning,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
      decoration: BoxDecoration(
        color: DonyColors.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: DonyColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: DonySpacing.xxs),
          Text('KYC', style: tt.labelSmall?.copyWith(color: DonyColors.success, fontWeight: FontWeight.w600)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
      decoration: BoxDecoration(
        color: DonyColors.bgApp,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: DonyColors.borderDefault),
      ),
      child: Text(label, style: tt.labelSmall?.copyWith(color: DonyColors.textMuted)),
    );
  }
}
