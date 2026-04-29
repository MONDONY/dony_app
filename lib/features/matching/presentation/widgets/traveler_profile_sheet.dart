import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';

/// Ouvre un modal sheet (90 % écran) affichant le profil complet d'un voyageur.
void showTravelerProfileSheet(BuildContext context, TravelerProfile traveler) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => _TravelerProfileSheet(
        traveler: traveler,
        scrollController: controller,
      ),
    ),
  );
}

// ─── Sheet content ────────────────────────────────────────────────────────────

class _TravelerProfileSheet extends StatelessWidget {
  const _TravelerProfileSheet({
    required this.traveler,
    required this.scrollController,
  });

  final TravelerProfile traveler;
  final ScrollController scrollController;

  String get _abbreviatedName {
    final name = traveler.resolvedName;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0]} ${parts[1][0]}.';
    }
    return parts[0];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: DonyColors.bgApp,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          const SizedBox(height: DonySpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
          ),
          const SizedBox(height: DonySpacing.xl),

          // ── Scrollable body ────────────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg, 0, DonySpacing.lg, DonySpacing.huge,
              ),
              children: [
                // Avatar + name + phone
                Center(
                  child: Column(
                    children: [
                      DonyAvatar(
                        name: traveler.resolvedName,
                        size: DonyAvatarSize.xl,
                        verified: true,
                      ),
                      const SizedBox(height: DonySpacing.md),
                      Text(
                        _abbreviatedName,
                        style: tt.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (traveler.phoneNumber != null) ...[
                        const SizedBox(height: DonySpacing.xs),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 13,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              traveler.phoneNumber!,
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: DonySpacing.sm),
                      // Badges
                      Wrap(
                        spacing: DonySpacing.sm,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          if (traveler.kiloPro)
                            const _SheetBadge(
                              icon: Icons.star_rounded,
                              label: 'Kilo Pro',
                              iconColor: DonyColors.amberDark,
                              bgColor: DonyColors.amberLight,
                              textColor: DonyColors.amberDark,
                            ),
                          _SheetBadge(
                            icon: Icons.verified_rounded,
                            label: 'Identité vérifiée',
                            iconColor: cs.primary,
                            bgColor: cs.primaryContainer,
                            textColor: cs.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DonySpacing.xl),

                // ── Stats ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: DonySpacing.base,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SheetStat(
                        value: traveler.averageRating != null
                            ? traveler.averageRating!.toStringAsFixed(1)
                            : '–',
                        label: 'Note',
                        icon: Icons.star_rounded,
                        iconColor: DonyColors.warning,
                      ),
                      Container(width: 1, height: 36, color: cs.outline),
                      _SheetStat(
                        value: traveler.totalTrips != null
                            ? '${traveler.totalTrips}'
                            : '–',
                        label: 'Trajets',
                        icon: Icons.flight_takeoff_rounded,
                        iconColor: cs.primary,
                      ),
                      Container(width: 1, height: 36, color: cs.outline),
                      const _SheetStat(
                        value: '–',
                        label: 'Livraison',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: DonyColors.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DonySpacing.xl),

                // ── Avis récents ───────────────────────────────────────────
                Text(
                  'Avis récents',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                _ReviewsBlock(traveler: traveler),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────

class _SheetBadge extends StatelessWidget {
  const _SheetBadge({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat item ────────────────────────────────────────────────────────────────

class _SheetStat extends StatelessWidget {
  const _SheetStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(height: DonySpacing.xs),
        Text(
          value,
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─── Reviews ──────────────────────────────────────────────────────────────────

class _ReviewsBlock extends StatelessWidget {
  const _ReviewsBlock({required this.traveler});

  final TravelerProfile traveler;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final firstName = traveler.resolvedName.split(' ').first;

    final reviews = [
      _ReviewData(
        authorName: 'Aminata F.',
        stars: 5,
        comment:
            '$firstName a livré mon colis en main propre chez ma mère avec photo. Je recommande à 100 %.',
        daysAgo: 12,
      ),
      const _ReviewData(
        authorName: 'Cheikh N.',
        stars: 5,
        comment:
            'Très sérieux, ponctuel et de très bon contact. Le colis est arrivé en parfait état.',
        daysAgo: 28,
      ),
      const _ReviewData(
        authorName: 'Marième D.',
        stars: 4,
        comment:
            'Bonne communication tout au long du trajet. Je re-ferai appel sans hésiter.',
        daysAgo: 45,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          for (int i = 0; i < reviews.length; i++) ...[
            _ReviewTile(review: reviews[i]),
            if (i < reviews.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Divider(height: 1, color: cs.outline),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewData {
  const _ReviewData({
    required this.authorName,
    required this.stars,
    required this.comment,
    required this.daysAgo,
  });

  final String authorName;
  final int stars;
  final String comment;
  final int daysAgo;
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final _ReviewData review;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final String timeLabel;
    if (review.daysAgo < 7) {
      timeLabel = 'Il y a ${review.daysAgo} j.';
    } else if (review.daysAgo < 30) {
      timeLabel = 'Il y a ${(review.daysAgo / 7).floor()} sem.';
    } else {
      timeLabel = 'Il y a ${(review.daysAgo / 30).floor()} mois';
    }

    return Padding(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyAvatar(name: review.authorName, size: DonyAvatarSize.sm),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      review.authorName,
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeLabel,
                      style: tt.labelSmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.xs),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.stars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 13,
                      color: DonyColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  review.comment,
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
