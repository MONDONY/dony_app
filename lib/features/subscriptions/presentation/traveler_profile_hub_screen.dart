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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            backgroundColor: Theme.of(context).colorScheme.surface,
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
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Trajets'),
                Tab(text: 'Avis'),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            // Subscription bar
            _SubscriptionBar(),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TripsTab(),
                  _ReviewsTab(),
                ],
              ),
            ),
          ],
        ),
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

    return BlocBuilder<ProfilePublicBloc, ProfilePublicState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary,
                cs.primary.withValues(alpha: 0.85),
                DonyColors.blue700,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: _buildHeaderContent(context, cs, state),
          ),
        );
      },
    );
  }

  Widget _buildHeaderContent(
    BuildContext context,
    ColorScheme cs,
    ProfilePublicState state,
  ) {
    if (state is ProfilePublicLoading || state is ProfilePublicInitial) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (state is ProfilePublicError) {
      return Center(
        child: Text(
          'Impossible de charger le profil',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      );
    }

    if (state is ProfilePublicLoaded) {
      return _LoadedHeader(profile: state.profile);
    }

    return const SizedBox.shrink();
  }
}

class _LoadedHeader extends StatelessWidget {
  const _LoadedHeader({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final responseLabel = profile.responseDelayHours != null
        ? '<${profile.responseDelayHours}h'
        : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.base,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          DonyAvatar(
            name: profile.displayName,
            imageUrl: profile.avatarUrl,
            size: DonyAvatarSize.xl,
            verified: profile.kycVerified,
            pro: profile.isProAccount,
          ),
          const SizedBox(height: DonySpacing.sm),
          // Name + verified check
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                profile.displayName,
                style: tt.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (profile.kycVerified) ...[
                const SizedBox(width: DonySpacing.xs),
                const Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ],
          ),
          // Badges row
          if (profile.isProAccount || profile.isKiloPro) ...[
            const SizedBox(height: DonySpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (profile.isProAccount)
                  const _HeaderBadge(label: 'PRO', color: DonyColors.warning700),
                if (profile.isProAccount && profile.isKiloPro)
                  const SizedBox(width: DonySpacing.xs),
                if (profile.isKiloPro)
                  const _HeaderBadge(label: 'Kilo Pro', color: DonyColors.violet),
              ],
            ),
          ],
          const SizedBox(height: DonySpacing.base),
          // 3 stats columns
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  value: profile.averageRating > 0
                      ? profile.averageRating.toStringAsFixed(1)
                      : '—',
                  label: 'Note',
                  icon: Icons.star_rounded,
                ),
              ),
              _VerticalDividerWhite(),
              Expanded(
                child: _StatColumn(
                  value: '${profile.completedBidsCount}',
                  label: 'Livraisons',
                  icon: Icons.inventory_2_rounded,
                ),
              ),
              _VerticalDividerWhite(),
              Expanded(
                child: _StatColumn(
                  value: responseLabel,
                  label: 'Réponse',
                  icon: Icons.timer_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(height: DonySpacing.xs),
        Text(
          value,
          style: tt.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _VerticalDividerWhite extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: Colors.white.withValues(alpha: 0.3),
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
        return Container(
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
