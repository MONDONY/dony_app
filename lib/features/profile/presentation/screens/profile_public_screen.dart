import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
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
import 'package:go_router/go_router.dart';
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
        context.read<TravelerSubscribeBloc>().add(
          LoadSubscribeStatus(_effectiveUserId),
        );
      }
    });
  }

  /// Returns the current user's id from AuthBloc, or null.
  /// Returns null gracefully if AuthBloc is not in scope.
  String? _currentUserId(BuildContext context) {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        return authState.user.id;
      }
      if (authState is AuthProfileUpdated) {
        return authState.user.id;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId(context);
    final viewedUserId = _effectiveUserId;
    final isOwnProfile = currentUserId != null && currentUserId == viewedUserId;
    final showButton = widget.showSubscribe && !isOwnProfile;

    return BlocBuilder<ProfilePublicBloc, ProfilePublicState>(
      builder: (context, state) {
        // ── Contextual app bar title ──────────────────────────────────────────
        // Own profile → "Ce que les autres voient"
        // Other user, loaded → their displayName (or "Profil" as fallback)
        // Other user, loading/error → "Profil"
        final String appBarTitle;
        if (isOwnProfile) {
          appBarTitle = 'Ce que les autres voient';
        } else if (state is ProfilePublicLoaded &&
            state.profile.displayName.isNotEmpty) {
          appBarTitle = state.profile.displayName;
        } else {
          appBarTitle = 'Profil';
        }

        Widget body;
        if (state is ProfilePublicLoading || state is ProfilePublicInitial) {
          body = const Center(child: CircularProgressIndicator());
        } else if (state is ProfilePublicError) {
          body = _ErrorView(
            message: state.message,
            onRetry: () => context.read<ProfilePublicBloc>().add(
              ProfilePublicRequested(viewedUserId),
            ),
          );
        } else if (state is ProfilePublicLoaded) {
          body = _LoadedView(
            userId: viewedUserId,
            profile: state.profile,
            recentRatings: state.recentRatings,
            showSubscribeButton: showButton,
          );
        } else {
          body = const SizedBox.shrink();
        }

        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DonyAppBar(
            title: appBarTitle,
            actions: isOwnProfile
                ? null
                : [
                    IconButton(
                      tooltip: 'Signaler',
                      icon: DonyIcon('flag', color: cs.onSurfaceVariant),
                      onPressed: () => context.push(
                        '/settings/report-incident',
                        extra: {
                          'targetType': IncidentTargetType.user,
                          'targetId': viewedUserId,
                        },
                      ),
                    ),
                  ],
          ),
          body: body,
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
      mascotte: DonyMascotteType.erreurLegere,
      iconAsset: 'circle-alert',
      title: 'Impossible de charger le profil',
      description: message,
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

// ─── Loaded view (flat / editorial layout) ────────────────────────────────────

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.userId,
    required this.profile,
    required this.recentRatings,
    required this.showSubscribeButton,
  });

  final String userId;
  final ProfilePublicModel profile;
  final RatingSummary recentRatings;
  final bool showSubscribeButton;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Hero — flat, centered ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child:
              _ProfileHero(
                    profile: profile,
                    subscribeAction: showSubscribeButton
                        ? const _SubscribeAction()
                        : null,
                  )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),

        // ── Stats section ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _FlatSection(
            topBorder: false,
            child: _StatsRow(profile: profile),
          ).animate().fadeIn(delay: 60.ms, duration: 300.ms),
        ),

        // ── À propos section ──────────────────────────────────────────────────
        if (profile.bio != null && profile.bio!.trim().isNotEmpty)
          SliverToBoxAdapter(
            child: _FlatSection(
              child: _AboutSection(bio: profile.bio!),
            ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
          ),

        // ── Langues / Transport section ───────────────────────────────────────
        if (profile.languages.isNotEmpty || profile.transportMode != null)
          SliverToBoxAdapter(
            child: _FlatSection(
              child: _TravelerInfoSection(
                languages: profile.languages,
                transportMode: profile.transportMode,
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
          ),

        // ── Badges section ────────────────────────────────────────────────────
        if (profile.badges.isNotEmpty)
          SliverToBoxAdapter(
            child: _FlatSection(
              child: _BadgesSection(badges: profile.badges),
            ).animate().fadeIn(delay: 160.ms, duration: 300.ms),
          ),

        // ── Contact / Availability section ────────────────────────────────────
        if (profile.contactMode != null || profile.responseDelayHours != null)
          SliverToBoxAdapter(
            child: _FlatSection(
              child: _ContactInfoSection(profile: profile),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
          ),

        // ── Avis récents section ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _FlatSection(
            child: _RecentReviewsSection(
              summary: recentRatings,
              userId: userId,
            ),
          ).animate().fadeIn(delay: 240.ms, duration: 300.ms),
        ),

        // Bottom safe-area padding
        const SliverToBoxAdapter(child: SizedBox(height: DonySpacing.xxl)),
      ],
    );
  }
}

// ─── Flat section wrapper — hairline top border, horizontal padding ───────────

class _FlatSection extends StatelessWidget {
  const _FlatSection({required this.child, this.topBorder = true});

  final Widget child;
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: topBorder
            ? Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.6)))
            : const Border(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.lg,
        ),
        child: child,
      ),
    );
  }
}

// ─── Profile hero — flat background, centered ────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, this.subscribeAction});

  final ProfilePublicModel profile;
  final Widget? subscribeAction;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final ratingStr = profile.averageRating > 0
        ? profile.averageRating.toStringAsFixed(1)
        : '-';
    final metaLine =
        '⭐ $ratingStr · ${profile.ratingCount} avis · ${profile.memberSince}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
        DonySpacing.sm,
      ),
      child: Column(
        children: [
          _HeroAvatar(
            name: profile.displayName,
            imageUrl: profile.avatarUrl,
            verified: profile.kycVerified,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            profile.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (profile.kycVerified ||
              profile.isProAccount ||
              profile.isKiloPro) ...[
            const SizedBox(height: DonySpacing.xs),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: DonySpacing.xs,
              runSpacing: DonySpacing.xs,
              children: [
                if (profile.kycVerified) const _HeroPill(label: '✓ Vérifié'),
                if (profile.isProAccount) const _HeroPill(label: 'PRO'),
                if (profile.isKiloPro) const _HeroPill(label: 'Kilo Pro'),
              ],
            ),
          ],
          const SizedBox(height: DonySpacing.xs),
          Text(
            metaLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (subscribeAction != null) ...[
            const SizedBox(height: DonySpacing.base),
            subscribeAction!,
          ],
        ],
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({
    required this.name,
    required this.verified,
    this.imageUrl,
  });

  final String name;
  final bool verified;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const size = 64.0;
    final initials = _initials(name);

    Widget avatar;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = ClipOval(
        child: DonyImage(
          url: imageUrl!,
          width: size,
          height: size,
          placeholder: (_) => _initialsCircle(initials, size),
          errorWidget: (_) => _initialsCircle(initials, size),
        ),
      );
    } else {
      avatar = _initialsCircle(initials, size);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size + 4,
          height: size + 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: ClipOval(child: avatar),
          ),
        ),
        if (verified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: DonyColors.warning500,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
              alignment: Alignment.center,
              child: const Text(
                '✓',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _initialsCircle(String initials, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DonyColors.terra400, DonyColors.terra600],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── Stats row — 2 equal columns, no box ─────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              value: profile.averageRating > 0
                  ? profile.averageRating.toStringAsFixed(1)
                  : '-',
              label: 'Note',
              iconAsset: 'star',
              iconColor: DonyColors.warning500,
            ),
          ),
          VerticalDivider(
            color: cs.outline.withValues(alpha: 0.6),
            width: 1,
            thickness: 1,
          ),
          Expanded(
            child: _StatItem(
              value: '${profile.completedBidsCount}',
              label: 'Livraisons',
              iconAsset: 'package',
              iconColor: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.iconAsset,
    required this.iconColor,
  });

  final String value;
  final String label;
  final String iconAsset;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconAsset == 'package'
              ? const DonyEmoji.parcel(size: 18)
              : DonyIcon(iconAsset, size: 18, color: iconColor),
          const SizedBox(height: DonySpacing.xs),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: cs.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Section label helper ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      text,
      style: tt.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.7,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ─── À propos section ─────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.bio});
  final String bio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('À PROPOS'),
        const SizedBox(height: DonySpacing.sm),
        Text(
          bio,
          style: tt.bodyMedium?.copyWith(color: cs.onSurface, height: 1.55),
        ),
      ],
    );
  }
}

// ─── Langues / Transport section ──────────────────────────────────────────────

class _TravelerInfoSection extends StatelessWidget {
  const _TravelerInfoSection({
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (languages.isNotEmpty)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('LANGUES'),
                const SizedBox(height: DonySpacing.sm),
                Wrap(
                  spacing: DonySpacing.xs,
                  runSpacing: DonySpacing.xs,
                  children: languages
                      .map(
                        (lang) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              DonyRadius.full,
                            ),
                          ),
                          child: Text(
                            lang,
                            style: tt.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
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
          const SizedBox(width: DonySpacing.xl),
        if (transportMode != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('TRANSPORT'),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  _transportLabel(transportMode!),
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Badges section ───────────────────────────────────────────────────────────

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
        const _SectionLabel('BADGES'),
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

// ─── Contact / availability section ──────────────────────────────────────────

class _ContactInfoSection extends StatelessWidget {
  const _ContactInfoSection({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String? contactLabel;
    String? contactIcon;
    switch (profile.contactMode) {
      case 'call':
        contactLabel = 'Joignable par appel';
        contactIcon = 'phone';
      case 'message':
        contactLabel = 'Joignable par message';
        contactIcon = 'message-circle';
      case 'both':
        contactLabel = 'Appel & message';
        contactIcon = 'messages-square';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('DISPONIBILITÉ'),
        const SizedBox(height: DonySpacing.sm),
        Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            if (contactLabel != null)
              _InfoChip(iconAsset: contactIcon!, label: contactLabel, cs: cs),
            if (profile.responseDelayHours != null)
              _InfoChip(
                iconAsset: 'timer',
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
  const _InfoChip({
    required this.iconAsset,
    required this.label,
    required this.cs,
  });

  final String iconAsset;
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
          DonyIcon(iconAsset, size: 14, color: cs.primary),
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

// ─── Avis récents section — flat rows with hairline dividers ─────────────────

class _RecentReviewsSection extends StatelessWidget {
  const _RecentReviewsSection({required this.summary, required this.userId});

  final RatingSummary summary;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final recentItems = summary.ratings.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('AVIS RÉCENTS'),
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
          ...List.generate(recentItems.length, (i) {
            final item = recentItems[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.outline.withValues(alpha: 0.5),
                  ),
                _FlatReviewRow(item: item),
              ],
            );
          }),

        // "Voir tous les avis" — inline text link, not a boxed button
        if (summary.ratingCount > 0) ...[
          const SizedBox(height: DonySpacing.base),
          GestureDetector(
            onTap: () => AllReviewsBottomSheet.show(
              context,
              userId: userId,
              initialSummary: summary,
            ),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              // Ensure min 44pt touch area
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
              child: Text(
                'Voir tous les avis (${summary.ratingCount}) ›',
                style: tt.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FlatReviewRow extends StatelessWidget {
  const _FlatReviewRow({required this.item});

  final RatingItem item;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
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
    final initials = _initials(authorName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author avatar
          _ReviewAvatar(
            name: authorName,
            imageUrl: item.authorAvatarUrl,
            initials: initials,
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author + date row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        authorName,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      DateFormat('dd/MM/yyyy').format(item.createdAt),
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Stars
                Row(
                  children: List.generate(5, (i) {
                    return DonyIcon(
                      'star',
                      size: 13,
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
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                // Corridor
                if (hasCorridor) ...[
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    '${item.departureCity} → ${item.arrivalCity}',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewAvatar extends StatelessWidget {
  const _ReviewAvatar({
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
        child: DonyImage(
          url: imageUrl!,
          width: size,
          height: size,
          placeholder: (_) =>
              _InitialsCircle(initials: initials, size: size, cs: cs),
          errorWidget: (_) =>
              _InitialsCircle(initials: initials, size: size, cs: cs),
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

// ─── Subscribe action — compact button + interactive bell (in-hero) ──────────

class _SubscribeAction extends StatelessWidget {
  const _SubscribeAction();

  Future<void> _confirmUnsubscribe(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Se désabonner ?',
      message: 'Vous ne recevrez plus les notifications de ce voyageur.',
      confirmLabel: 'Se désabonner',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'bell-off',
    );
    if ((confirmed ?? false) && context.mounted) {
      context.read<TravelerSubscribeBloc>().add(const UnsubscribePressed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<TravelerSubscribeBloc, TravelerSubscribeState>(
      builder: (context, state) {
        final isLoading =
            state.status == TravelerSubscribeStatus.loading ||
            state.status == TravelerSubscribeStatus.initial;

        if (state.subscribed) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyButton(
                label: 'Abonné ✓',
                variant: DonyButtonVariant.secondary,
                fullWidth: false,
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : () => _confirmUnsubscribe(context),
              ),
              const SizedBox(width: DonySpacing.sm),
              IconButton(
                tooltip: state.pushEnabled
                    ? 'Désactiver les notifications'
                    : 'Activer les notifications',
                icon: DonyIcon(
                  state.pushEnabled ? 'bell' : 'bell-off',
                  color: cs.primary,
                ),
                onPressed: isLoading
                    ? null
                    : () => context.read<TravelerSubscribeBloc>().add(
                        TogglePushPressed(!state.pushEnabled),
                      ),
              ),
            ],
          );
        }

        return DonyButton(
          label: "S'abonner",
          iconAsset: 'plus',
          fullWidth: false,
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : () => context.read<TravelerSubscribeBloc>().add(
                  const SubscribePressed(),
                ),
        );
      },
    );
  }
}
