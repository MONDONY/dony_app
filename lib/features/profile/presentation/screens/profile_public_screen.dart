import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProfilePublicScreen extends StatelessWidget {
  const ProfilePublicScreen({super.key, this.userId});

  final String? userId;

  String get _effectiveUserId =>
      userId?.isNotEmpty == true
          ? userId!
          : FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    // Dispatch event if bloc hasn't started yet
    final state = context.read<ProfilePublicBloc>().state;
    if (state is ProfilePublicInitial) {
      context
          .read<ProfilePublicBloc>()
          .add(ProfilePublicRequested(_effectiveUserId));
    }

    return DonyPageScaffold(
      title: 'Ce que les autres voient',
      scrollable: false,
      body: BlocBuilder<ProfilePublicBloc, ProfilePublicState>(
        builder: (context, state) {
          if (state is ProfilePublicLoading || state is ProfilePublicInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ProfilePublicError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context
                  .read<ProfilePublicBloc>()
                  .add(ProfilePublicRequested(_effectiveUserId)),
            );
          }
          if (state is ProfilePublicLoaded) {
            return _LoadedView(
              profile: state.profile,
              recentRatings: state.recentRatings,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─── Error state ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DonyEmptyState(
      type: DonyEmptyStateType.error,
      mascotte: DonyMascotteType.assis,
      icon: Icons.error_outline_rounded,
      title: 'Impossible de charger le profil',
      description: message,
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

// ─── Loaded view ─────────────────────────────────────────────────────────────

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.profile,
    required this.recentRatings,
  });

  final ProfilePublicModel profile;
  final RatingSummary recentRatings;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Hero card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.base,
            ),
            child: _HeroCard(profile: profile),
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),

        // Stats row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
            child: _StatsRow(profile: profile),
          ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
        ),

        // Badges section
        if (profile.badges.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.xl,
                DonySpacing.lg,
                0,
              ),
              child: _BadgesSection(badges: profile.badges),
            ).animate().fadeIn(delay: 160.ms, duration: 300.ms),
          ),

        // Recent reviews section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              0,
            ),
            child: _RecentReviewsSection(summary: recentRatings),
          ).animate().fadeIn(delay: 240.ms, duration: 300.ms),
        ),

        // "Voir tous mes avis" button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.base,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            child: DonyButton(
              label: 'Voir tous mes avis',
              variant: DonyButtonVariant.secondary,
              onPressed: () => context.push('/profile/reviews'),
            ),
          ).animate().fadeIn(delay: 320.ms, duration: 300.ms),
        ),
      ],
    );
  }
}

// ─── Hero card ───────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
        boxShadow: DonyShadows.card,
      ),
      padding: const EdgeInsets.all(DonySpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DonyAvatar(
            name: profile.displayName,
            imageUrl: profile.avatarUrl,
            size: DonyAvatarSize.xl,
            verified: profile.kycVerified,
            pro: profile.isProAccount,
          ),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.displayName,
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Wrap(
                  spacing: DonySpacing.xs,
                  runSpacing: DonySpacing.xs,
                  children: [
                    if (profile.kycVerified)
                      _StatusChip(
                        label: '✓ Vérifié',
                        color: cs.success,
                        bgColor: cs.successLight,
                      ),
                    if (profile.isProAccount)
                      _StatusChip(
                        label: 'PRO',
                        color: DonyColors.warning700,
                        bgColor: DonyColors.amberLight,
                      ),
                    if (profile.isKiloPro)
                      _StatusChip(
                        label: 'Kilo Pro',
                        color: DonyColors.violet,
                        bgColor: DonyColors.violetLight,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final Color color;
  final Color bgColor;

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
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Stats row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: DonySpacing.base,
        horizontal: DonySpacing.sm,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                value: profile.averageRating > 0
                    ? profile.averageRating.toStringAsFixed(1)
                    : '—',
                label: 'Note',
                icon: Icons.star_rounded,
                iconColor: DonyColors.warning500,
              ),
            ),
            VerticalDivider(color: cs.outline, width: 1),
            Expanded(
              child: _StatItem(
                value: '${profile.completedBidsCount}',
                label: 'Livraisons',
                icon: Icons.inventory_2_rounded,
                iconColor: cs.primary,
              ),
            ),
            VerticalDivider(color: cs.outline, width: 1),
            Expanded(
              child: _StatItem(
                value: profile.memberSince,
                label: 'Membre depuis',
                icon: Icons.calendar_today_rounded,
                iconColor: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: DonySpacing.xs),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Badges section ──────────────────────────────────────────────────────────

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({required this.badges});

  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BADGES',
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: badges
              .map(
                (b) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: DonySpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    b,
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─── Recent reviews section ──────────────────────────────────────────────────

class _RecentReviewsSection extends StatelessWidget {
  const _RecentReviewsSection({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final recentItems = summary.ratings.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVIS RÉCENTS',
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        if (recentItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
            child: Text(
              'Aucun avis pour le moment.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
        else
          ...recentItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm),
              child: _MiniReviewCard(item: item),
            ),
          ),
      ],
    );
  }
}

class _MiniReviewCard extends StatelessWidget {
  const _MiniReviewCard({required this.item});

  final RatingItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  i < item.stars
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 14,
                  color: i < item.stars
                      ? DonyColors.warning500
                      : cs.onSurfaceVariant,
                );
              }),
              const Spacer(),
              Text(
                DateFormat('dd/MM/yyyy').format(item.createdAt),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              item.comment!,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
