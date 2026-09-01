import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_state.dart';
import 'package:dony/features/subscriptions/presentation/widgets/subscribe_bar.dart';
import 'package:dony/features/subscriptions/presentation/widgets/traveler_announcement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TravelerProfileHubScreen extends StatefulWidget {
  const TravelerProfileHubScreen({super.key, required this.travelerId});

  final String travelerId;

  @override
  State<TravelerProfileHubScreen> createState() =>
      _TravelerProfileHubScreenState();
}

class _TravelerProfileHubScreenState extends State<TravelerProfileHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Events are dispatched by the router's BlocProvider create callbacks.
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 280,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: const Padding(
                    padding: EdgeInsets.only(left: DonySpacing.base),
                    child: DonyAppBarBackButton(),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _ProfileHeader(travelerId: widget.travelerId),
                  ),
                  bottom: _StatsAndTabBar(controller: _tabController),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [_TripsTab(), _ReviewsTab()],
              ),
            ),
          ),
          _SubscriptionBar(),
        ],
      ),
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.travelerId});

  final String travelerId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DonyColors.proBg2,
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: BlocBuilder<ProfilePublicBloc, ProfilePublicState>(
        builder: (context, state) {
          if (state is ProfilePublicLoaded) {
            return _LoadedProfileHeader(profile: state.profile);
          }
          if (state is ProfilePublicError) {
            return Center(
              child: Text(
                'Impossible de charger le profil',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            );
          }
          return const _HeaderSkeleton();
        },
      ),
    );
  }
}

class _LoadedProfileHeader extends StatelessWidget {
  const _LoadedProfileHeader({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Stack(
      children: [
        // Fond nuit fixe (choix de marque assumé, non theme-aware — voir spec
        // section "Dark mode" : ce hero reste identique en light/dark mode).
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.6, -0.9),
                radius: 1.4,
                colors: [
                  DonyColors.proBg3,
                  DonyColors.proBg1,
                  DonyColors.proBg2,
                ],
              ),
            ),
          ),
        ),
        // Halo diffus terracotta, haut-droit
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, -0.7),
                radius: 0.9,
                colors: [
                  DonyColors.accent.withValues(alpha: 0.30),
                  DonyColors.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base,
              0,
              DonySpacing.base,
              _StatsAndTabBar.height + DonySpacing.md,
            ),
            child: Row(
              children: [
                // Avatar avec bordure blanche et ombre accent
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: DonyColors.accent.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: DonyAvatar(
                    name: profile.displayName,
                    imageUrl: profile.avatarUrl,
                    size: DonyAvatarSize.lg,
                    verified: profile.kycVerified,
                    pro: profile.isProAccount,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                // Infos à droite
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.displayName,
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: DonySpacing.xs),
                      Wrap(
                        spacing: DonySpacing.xs,
                        runSpacing: DonySpacing.xs,
                        children: [
                          if (profile.isProAccount)
                            const _ProfileBadge(
                              lucideIcon: 'star',
                              label: 'Compte PRO',
                              iconColor: DonyColors.kycBadgeGold,
                            ),
                          if (profile.isKiloPro)
                            const _ProfileBadge(
                              iconAsset: 'package',
                              label: 'Kilo Pro',
                              iconColor: DonyColors.kycBadgeGold,
                            ),
                          if (profile.kycVerified)
                            const _ProfileBadge(
                              lucideIcon: 'badge-check',
                              label: 'Identité vérifiée',
                              iconColor: DonyColors.kycBadgeBlue,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    this.lucideIcon,
    this.iconAsset,
    required this.label,
    required this.iconColor,
  });

  final String? lucideIcon;
  final String? iconAsset;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconAsset != null
              ? const DonyEmoji.parcel(size: 11)
              : DonyIcon(lucideIcon!, size: 11, color: iconColor),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    this.lucideIcon,
    this.iconAsset,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final String? lucideIcon;
  final String? iconAsset;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconAsset != null
              ? const DonyEmoji.parcel(size: 14)
              : DonyIcon(lucideIcon!, size: 14, color: iconColor),
          Text(
            value,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
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

/// Skeleton du header, calqué sur [_LoadedProfileHeader] — même avatar +
/// hauteur de contenu, en blanc translucide : le fond reste le dégradé nuit
/// (marque assumée, non theme-aware) même pendant le chargement.
class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    const boxColor = Color.fromRGBO(255, 255, 255, 0.18);

    return const Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.6, -0.9),
                radius: 1.4,
                colors: [
                  DonyColors.proBg3,
                  DonyColors.proBg1,
                  DonyColors.proBg2,
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.base,
              0,
              DonySpacing.base,
              _StatsAndTabBar.height + DonySpacing.md,
            ),
            child: DonyShimmer(
              color: Color.fromRGBO(255, 255, 255, 0.35),
              child: Row(
                children: [
                  DonySkeletonCircle(diameter: 56, color: boxColor),
                  SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DonySkeletonBox(
                          width: 160,
                          height: 20,
                          color: boxColor,
                        ),
                        SizedBox(height: DonySpacing.xs),
                        DonySkeletonBox(
                          width: 100,
                          height: 14,
                          color: boxColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsAndTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _StatsAndTabBar({required this.controller});

  final TabController controller;

  // 96px (stats) + 48px (TabBar) = 144px
  static const double height = 144;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRect(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Stats row ───────────────────────────────────────────────────
          BlocBuilder<ProfilePublicBloc, ProfilePublicState>(
            buildWhen: (p, c) =>
                c is ProfilePublicLoaded ||
                c is ProfilePublicLoading ||
                c is ProfilePublicInitial,
            builder: (context, state) {
              if (state is! ProfilePublicLoaded) {
                return SizedBox(
                  height: 96,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              final profile = state.profile;
              return SizedBox(
                height: 96,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.base,
                    DonySpacing.sm,
                    DonySpacing.base,
                    DonySpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          lucideIcon: 'star',
                          iconColor: cs.warning,
                          value: profile.averageRating > 0
                              ? profile.averageRating.toStringAsFixed(1)
                              : '–',
                          label: 'Note',
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: _StatCard(
                          iconAsset: 'package',
                          iconColor: cs.primary,
                          value: '${profile.completedBidsCount}',
                          label: 'Livraisons',
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: _StatCard(
                          lucideIcon: 'timer',
                          iconColor: cs.success,
                          value: profile.responseDelayHours != null
                              ? '<${profile.responseDelayHours}h'
                              : '–',
                          label: 'Réponse',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // ── TabBar (48px) ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outline)),
            ),
            child: TabBar(
              controller: controller,
              tabs: const [
                Tab(text: 'Trajets'),
                Tab(text: 'Avis'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Subscription Bar ─────────────────────────────────────────────────────────

class _SubscriptionBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<TravelerHubBloc, TravelerHubState>(
      builder: (context, state) {
        return SafeArea(
          top: false,
          child: Container(
            color: cs.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.lg,
              vertical: DonySpacing.sm,
            ),
            child: SubscribeBar(
              subscribed: state.subscribed,
              pushEnabled: state.pushEnabled,
              onSubscribe: () =>
                  context.read<TravelerHubBloc>().add(const HubSubscribePressed()),
              onUnsubscribe: () => context.read<TravelerHubBloc>().add(
                const HubUnsubscribePressed(),
              ),
              onTogglePush: (enabled) =>
                  context.read<TravelerHubBloc>().add(HubTogglePush(enabled)),
            ),
          ),
        );
      },
    );
  }
}

// ─── Trips Tab ────────────────────────────────────────────────────────────────

class _TripsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TravelerHubBloc, TravelerHubState>(
      builder: (context, state) {
        if (state.status == TravelerHubStatus.loading ||
            state.status == TravelerHubStatus.initial) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.lg,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
            itemBuilder: (_, _) => const DonyTripCardSkeleton(),
          );
        }

        if (state.status == TravelerHubStatus.error) {
          return SingleChildScrollView(
            child: DonyEmptyState(
              type: DonyEmptyStateType.error,
              mascotte: DonyMascotteType.erreurLegere,
              iconAsset: 'circle-alert',
              title: 'Erreur de chargement',
              description:
                  'Impossible de charger les trajets. Réessayez dans un instant.',
              actionLabel: 'Réessayer',
              onAction: () => context.read<TravelerHubBloc>().add(
                LoadTravelerHub(context.read<TravelerHubBloc>().travelerId),
              ),
            ),
          );
        }

        final announcements = state.announcements;

        if (announcements.isEmpty) {
          return const DonyEmptyState(
            mascotte: DonyMascotteType.assis,
            iconAsset: 'plane-takeoff',
            title: 'Aucun trajet en cours',
            description: 'Ce voyageur n\'a pas encore publié de trajet.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.base,
            DonySpacing.lg,
            DonySpacing.huge,
          ),
          itemCount: announcements.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: DonySpacing.base),
          itemBuilder: (context, index) {
            final announcement = announcements[index];
            return TravelerAnnouncementCard(
              announcement: announcement,
              onReserve: () => context.push('/traveler/${announcement.id}'),
            );
          },
        );
      },
    );
  }
}

// ─── Reviews Tab ──────────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfilePublicBloc, ProfilePublicState>(
      builder: (context, state) {
        if (state is ProfilePublicLoading || state is ProfilePublicInitial) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.lg,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
            itemBuilder: (_, _) => const DonyUserCardSkeleton(),
          );
        }

        if (state is ProfilePublicError) {
          return DonyEmptyState(
            type: DonyEmptyStateType.error,
            mascotte: DonyMascotteType.erreur,
            iconAsset: 'circle-alert',
            title: 'Impossible de charger les avis',
            description: state.message,
          );
        }

        if (state is ProfilePublicLoaded) {
          return _ReviewsList(summary: state.recentRatings);
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _ReviewsList extends StatelessWidget {
  const _ReviewsList({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = summary.ratings;

    if (items.isEmpty) {
      return const DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        iconAsset: 'star',
        title: 'Aucun avis',
        description: 'Ce voyageur n\'a pas encore reçu d\'avis.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              DonyIcon('star', color: cs.warning, size: 28),
              const SizedBox(width: DonySpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.averageRating.toStringAsFixed(1),
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '${summary.ratingCount} avis',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        // Individual review cards
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.sm),
            child: _ReviewCard(item: item),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item});

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
                return DonyIcon(
                  'star',
                  size: 14,
                  color: i < item.stars ? cs.warning : cs.onSurfaceVariant,
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
