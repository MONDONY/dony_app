import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_state.dart';
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

    // Trigger data loads
    final profileState = context.read<ProfilePublicBloc>().state;
    if (profileState is ProfilePublicInitial) {
      context
          .read<ProfilePublicBloc>()
          .add(ProfilePublicRequested(widget.travelerId));
    }

    final hubState = context.read<TravelerHubBloc>().state;
    if (hubState.status == TravelerHubStatus.initial) {
      context
          .read<TravelerHubBloc>()
          .add(LoadTravelerHub(widget.travelerId));
    }
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
                  expandedHeight: 200,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    onPressed: () => context.pop(),
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
            cs.successLight,
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
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.base,
          DonySpacing.md,
          DonySpacing.base,
          DonySpacing.md,
        ),
        child: Row(
          children: [
            // Avatar avec bordure blanche et ombre verte
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: cs.success.withValues(alpha: 0.30),
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
                      color: cs.onSurface,
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
                        _ProfileBadge(
                          icon: Icons.star_rounded,
                          label: 'Compte PRO',
                          iconColor: cs.warning,
                        ),
                      if (profile.isKiloPro)
                        _ProfileBadge(
                          icon: Icons.local_shipping_rounded,
                          label: 'Kilo Pro',
                          iconColor: cs.warning,
                        ),
                      if (profile.kycVerified)
                        _ProfileBadge(
                          icon: Icons.verified_rounded,
                          label: 'Identité vérifiée',
                          iconColor: cs.primary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: iconColor),
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
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
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
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: iconColor),
          Text(
            value,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatsAndTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _StatsAndTabBar({required this.controller});

  final TabController controller;

  // stats (96px) + TabBar (48px)
  @override
  Size get preferredSize => const Size.fromHeight(144);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRect(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Stats row (96px) ──────────────────────────────────────────────
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
                          icon: Icons.star_rounded,
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
                          icon: Icons.inventory_2_rounded,
                          iconColor: cs.primary,
                          value: '${profile.completedBidsCount}',
                          label: 'Livraisons',
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.timer_rounded,
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
            child: state.subscribed
                ? _SubscribedRow(pushEnabled: state.pushEnabled)
                : DonyButton(
                    label: "S'abonner",
                    onPressed: () => context
                        .read<TravelerHubBloc>()
                        .add(const HubSubscribePressed()),
                  ),
          ),
        );
      },
    );
  }
}

class _SubscribedRow extends StatelessWidget {
  const _SubscribedRow({required this.pushEnabled});

  final bool pushEnabled;

  Future<void> _confirmUnsubscribe(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Se désabonner ?',
      message:
          'Vous ne recevrez plus les notifications de ce voyageur.',
      confirmLabel: 'Se désabonner',
      variant: DonyDialogVariant.destructive,
      icon: Icons.notifications_off_rounded,
    );
    if ((confirmed ?? false) && context.mounted) {
      context
          .read<TravelerHubBloc>()
          .add(const HubUnsubscribePressed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DonyButton(
            label: 'Abonné ✓',
            variant: DonyButtonVariant.secondary,
            fullWidth: false,
            onPressed: () => _confirmUnsubscribe(context),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        IconButton(
          tooltip: pushEnabled
              ? 'Désactiver les notifications'
              : 'Activer les notifications',
          icon: Icon(
            pushEnabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => context
              .read<TravelerHubBloc>()
              .add(HubTogglePush(!pushEnabled)),
        ),
      ],
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
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == TravelerHubStatus.error) {
          return DonyEmptyState(
            type: DonyEmptyStateType.error,
            mascotte: DonyMascotteType.assis,
            icon: Icons.error_outline_rounded,
            title: 'Erreur de chargement',
            description: state.error ?? 'Une erreur est survenue.',
            actionLabel: 'Réessayer',
            onAction: () {},
          );
        }

        final announcements = state.announcements;

        if (announcements.isEmpty) {
          return const DonyEmptyState(
            mascotte: DonyMascotteType.assis,
            icon: Icons.flight_takeoff_rounded,
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
              onReserve: () =>
                  context.push('/traveler/${announcement.id}'),
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
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ProfilePublicError) {
          return DonyEmptyState(
            type: DonyEmptyStateType.error,
            mascotte: DonyMascotteType.assis,
            icon: Icons.error_outline_rounded,
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
        icon: Icons.star_border_rounded,
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
              const Icon(Icons.star_rounded, color: DonyColors.warning500, size: 28),
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
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
