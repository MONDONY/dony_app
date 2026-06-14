import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/profile/presentation/widgets/all_reviews_bottom_sheet.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

// ─── Route args ───────────────────────────────────────────────────────────────

class ProfilePublicArgs {
  final String? userId;
  final bool showSubscribe;

  const ProfilePublicArgs({this.userId, this.showSubscribe = false});
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProfilePublicScreen extends StatefulWidget {
  const ProfilePublicScreen({
    super.key,
    this.userId,
    this.showSubscribe = false,
  });

  final String? userId;
  final bool showSubscribe;

  @override
  State<ProfilePublicScreen> createState() => _ProfilePublicScreenState();
}

class _ProfilePublicScreenState extends State<ProfilePublicScreen> {
  String get _effectiveUserId => widget.userId?.isNotEmpty == true
      ? widget.userId!
      : FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<ProfilePublicBloc>();
      if (bloc.state is ProfilePublicInitial) {
        bloc.add(ProfilePublicRequested(_effectiveUserId));
      }
      // Load subscribe status only if we should show the button
      if (widget.showSubscribe && _effectiveUserId.isNotEmpty) {
        context
            .read<TravelerSubscribeBloc>()
            .add(LoadSubscribeStatus(_effectiveUserId));
      }
    });
  }

  /// Returns the current user's id from AuthBloc, or null.
  /// Returns null gracefully if AuthBloc is not in scope.
  String? _currentUserId(BuildContext context) {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) return authState.user.id;
      if (authState is AuthProfileUpdated) return authState.user.id;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId(context);
    final viewedUserId = _effectiveUserId;
    final isOwnProfile =
        currentUserId != null && currentUserId == viewedUserId;
    final showButton = widget.showSubscribe && !isOwnProfile;

    return BlocBuilder<ProfilePublicBloc, ProfilePublicState>(
      builder: (context, state) {
        Widget body;
        if (state is ProfilePublicLoading || state is ProfilePublicInitial) {
          body = const Center(child: CircularProgressIndicator());
        } else if (state is ProfilePublicError) {
          body = _ErrorView(
            message: state.message,
            onRetry: () => context
                .read<ProfilePublicBloc>()
                .add(ProfilePublicRequested(viewedUserId)),
          );
        } else if (state is ProfilePublicLoaded) {
          body = _LoadedView(
            userId: viewedUserId,
            profile: state.profile,
            recentRatings: state.recentRatings,
          );
        } else {
          body = const SizedBox.shrink();
        }

        return DonyPageScaffold(
          title: 'Ce que les autres voient',
          scrollable: false,
          stickyBottom: showButton ? const _SubscribeButton() : null,
          body: body,
        );
      },
    );
  }
}

// ─── Subscribe sticky button ─────────────────────────────────────────────────

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TravelerSubscribeBloc, TravelerSubscribeState>(
      builder: (context, state) {
        final isLoading = state.status == TravelerSubscribeStatus.loading ||
            state.status == TravelerSubscribeStatus.initial;

        if (state.subscribed) {
          return DonyButton(
            label: 'Abonné',
            icon: Icons.check_rounded,
            variant: DonyButtonVariant.secondary,
            isLoading: isLoading,
            onPressed: isLoading
                ? null
                : () => context
                    .read<TravelerSubscribeBloc>()
                    .add(const UnsubscribePressed()),
          );
        }

        return DonyButton(
          label: "S'abonner à ce voyageur",
          icon: Icons.notifications_active_rounded,
          variant: DonyButtonVariant.primary,
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : () => context
                  .read<TravelerSubscribeBloc>()
                  .add(const SubscribePressed()),
        );
      },
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
    required this.userId,
    required this.profile,
    required this.recentRatings,
  });

  final String userId;
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

        // À propos card
        if (profile.bio != null && profile.bio!.trim().isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                0,
              ),
              child: _AboutCard(bio: profile.bio!),
            ).animate().fadeIn(delay: 60.ms, duration: 300.ms),
          ),

        // Stats row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.base,
              DonySpacing.lg,
              0,
            ),
            child: _StatsRow(profile: profile),
          ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
        ),

        // Langues / Transport card
        if (profile.languages.isNotEmpty || profile.transportMode != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                0,
              ),
              child: _TravelerInfoCard(
                languages: profile.languages,
                transportMode: profile.transportMode,
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
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

        // Contact info chips
        if (profile.contactMode != null || profile.responseDelayHours != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.xl,
                DonySpacing.lg,
                0,
              ),
              child: _ContactInfoSection(profile: profile),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
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

        // "Voir tous les avis" — inline link button at bottom of reviews card
        if (recentRatings.ratingCount > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                DonySpacing.huge,
              ),
              child: DonyButton(
                label: 'Voir tous les avis (${recentRatings.ratingCount})',
                variant: DonyButtonVariant.secondary,
                onPressed: () => AllReviewsBottomSheet.show(
                  context,
                  userId: userId,
                  initialSummary: recentRatings,
                ),
              ),
            ).animate().fadeIn(delay: 320.ms, duration: 300.ms),
          ),

        // Bottom safe-area padding (when no sticky button, give generous bottom)
        const SliverToBoxAdapter(child: SizedBox(height: DonySpacing.xl)),
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

    // Formatted memberSince meta: "⭐ 4.8 · 12 avis · Membre depuis mars 2025"
    final ratingStr = profile.averageRating > 0
        ? profile.averageRating.toStringAsFixed(1)
        : '—';
    final metaLine =
        '⭐ $ratingStr · ${profile.ratingCount} avis · Membre depuis ${profile.memberSince}';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
        boxShadow: DonyShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blue gradient cover strip
          Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary,
                  cs.primary.withOpacity(0.7),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.xl,
              0,
              DonySpacing.xl,
              DonySpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar overlapping the gradient strip
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: DonyAvatar(
                    name: profile.displayName,
                    imageUrl: profile.avatarUrl,
                    size: DonyAvatarSize.xl,
                    verified: profile.kycVerified,
                    pro: profile.isProAccount,
                  ),
                ),

                // Name (pull up to compensate translated avatar space)
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Text(
                    profile.displayName,
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),

                // Status pills
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: Wrap(
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
                        const _StatusChip(
                          label: 'PRO',
                          color: DonyColors.warning700,
                          bgColor: DonyColors.amberLight,
                        ),
                      if (profile.isKiloPro)
                        const _StatusChip(
                          label: 'Kilo Pro',
                          color: DonyColors.violet,
                          bgColor: DonyColors.violetLight,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: DonySpacing.sm),

                // Meta line: ⭐ rating · N avis · Membre depuis XXX
                Text(
                  metaLine,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
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

// ─── Stats row — 3 equal columns ─────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Response delay label
    final delayLabel = profile.responseDelayHours != null
        ? '~${profile.responseDelayHours}h'
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
        boxShadow: DonyShadows.card,
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
                value: delayLabel,
                label: 'Répond en',
                icon: Icons.timer_rounded,
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
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── À propos card ───────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.bio});

  final String bio;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'À PROPOS',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            bio,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Langues / Transport card ─────────────────────────────────────────────────

class _TravelerInfoCard extends StatelessWidget {
  const _TravelerInfoCard({
    required this.languages,
    required this.transportMode,
  });

  final List<String> languages;
  final String? transportMode;

  static String _transportLabel(String mode) {
    switch (mode) {
      case 'AVION':
        return '✈️ Avion';
      case 'VOITURE':
        return '🚗 Voiture';
      case 'TRAIN':
        return '🚆 Train';
      default:
        return mode;
    }
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (languages.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LANGUES',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  Wrap(
                    spacing: DonySpacing.xs,
                    runSpacing: DonySpacing.xs,
                    children: languages
                        .map(
                          (lang) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DonySpacing.sm,
                              vertical: DonySpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(DonyRadius.full),
                            ),
                            child: Text(
                              lang,
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
              ),
            ),
          if (languages.isNotEmpty && transportMode != null)
            const SizedBox(width: DonySpacing.base),
          if (transportMode != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRANSPORT',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  Text(
                    _transportLabel(transportMode!),
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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

  /// Returns initials from a name (max 2 chars), e.g. "Fatou Diallo" → "FD".
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final authorName = item.authorName?.isNotEmpty == true
        ? item.authorName!
        : 'Utilisateur';
    final hasCorridor = item.departureCity != null && item.arrivalCity != null;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
        boxShadow: DonyShadows.card,
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row: avatar + name (left) + date (right)
          Row(
            children: [
              // Author avatar
              _AuthorAvatar(
                name: authorName,
                imageUrl: item.authorAvatarUrl,
                initials: _initials(authorName),
              ),
              const SizedBox(width: DonySpacing.sm),
              // Author name
              Expanded(
                child: Text(
                  authorName,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Date (tabular numbers)
              Text(
                DateFormat('dd/MM/yyyy').format(item.createdAt),
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: DonySpacing.sm),

          // Stars row
          Row(
            children: List.generate(5, (i) {
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
          ),

          // Comment
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              item.comment!,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.5,
              ),
            ),
          ],

          // Corridor chip
          if (hasCorridor) ...[
            const SizedBox(height: DonySpacing.sm),
            _CorridorChip(
              departure: item.departureCity!,
              arrival: item.arrivalCity!,
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.name,
    required this.initials,
    this.imageUrl,
  });

  final String name;
  final String initials;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const size = 36.0;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _InitialsCircle(
            initials: initials,
            size: size,
            cs: cs,
          ),
        ),
      );
    }

    return _InitialsCircle(initials: initials, size: size, cs: cs);
  }
}

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({
    required this.initials,
    required this.size,
    required this.cs,
  });

  final String initials;
  final double size;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: cs.primary,
        ),
      ),
    );
  }
}

class _CorridorChip extends StatelessWidget {
  const _CorridorChip({required this.departure, required this.arrival});

  final String departure;
  final String arrival;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flight_takeoff_rounded, size: 12, color: cs.primary),
          const SizedBox(width: DonySpacing.xs),
          Text(
            '$departure → $arrival',
            style: tt.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contact info section ─────────────────────────────────────────────────────

class _ContactInfoSection extends StatelessWidget {
  const _ContactInfoSection({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    String? contactLabel;
    IconData? contactIcon;
    switch (profile.contactMode) {
      case 'call':
        contactLabel = 'Joignable par appel';
        contactIcon = Icons.phone_rounded;
      case 'message':
        contactLabel = 'Joignable par message';
        contactIcon = Icons.message_rounded;
      case 'both':
        contactLabel = 'Appel & message';
        contactIcon = Icons.forum_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISPONIBILITÉ',
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            if (contactLabel != null)
              _InfoChip(icon: contactIcon!, label: contactLabel, cs: cs),
            if (profile.responseDelayHours != null)
              _InfoChip(
                icon: Icons.timer_rounded,
                label: 'Répond en < ${profile.responseDelayHours}h',
                cs: cs,
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.cs});

  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
