import 'package:dony/core/design/design_system.dart';
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
                  expandedHeight: 200,
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

    // Même teinte que l'en-tête chargé : sans elle, l'écran passerait du
    // sombre au clair entre le squelette et le profil.
    final fond = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.06),
      Theme.of(context).scaffoldBackgroundColor,
    );

    return Container(
      color: fond,
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      // Teinte de marque très pâle au lieu du dégradé nuit : elle accueille
      // sans assombrir la photo de profil ni forcer des pastilles
      // translucides pour rester lisibles par-dessus.
      color: Color.alphaBlend(
        cs.primary.withValues(alpha: 0.06),
        Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.base,
            0,
            DonySpacing.base,
            DonySpacing.base,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DonyAvatar(
                    name: profile.displayName,
                    imageUrl: profile.avatarUrl,
                    size: DonyAvatarSize.lg,
                    verified: profile.kycVerified,
                    pro: profile.isProAccount,
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profile.displayName,
                          style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: DonySpacing.xxs),
                        _TrustMarks(profile: profile),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.md),
              _StatSentence(profile: profile),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marques de confiance, en texte plutôt qu'en pastilles.
///
/// Trois pastilles translucides sur un fond sombre demandaient au lecteur de
/// déchiffrer un contraste faible pour une information qui tient en deux mots.
class _TrustMarks extends StatelessWidget {
  const _TrustMarks({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final style = tt.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    final marques = <Widget>[
      if (profile.isProAccount)
        _Mark(icon: 'star', label: 'Compte PRO', color: cs.primary, bold: true),
      if (profile.isKiloPro)
        _Mark(icon: 'package', label: 'Kilo Pro', color: cs.onSurfaceVariant),
      if (profile.kycVerified)
        _Mark(
          icon: 'badge-check',
          label: 'Identité vérifiée',
          color: cs.onSurfaceVariant,
        ),
    ];
    if (marques.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < marques.length; i++) ...[
          if (i > 0) Text('·', style: style),
          marques[i],
        ],
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.icon,
    required this.label,
    required this.color,
    this.bold = false,
  });

  final String icon;
  final String label;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyIcon(icon, size: 13, color: color),
        const SizedBox(width: DonySpacing.xxs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Réputation en une phrase, à la place de trois cartes de même taille.
///
/// Une carte est une promesse de contenu : « Réponse – » en affichait une vide.
/// Ici, une donnée absente ne s'écrit pas, et un profil sans historique le dit.
class _StatSentence extends StatelessWidget {
  const _StatSentence({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final style = tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final fort = style?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final morceaux = <InlineSpan>[];
    void ajouter(List<InlineSpan> spans) {
      if (morceaux.isNotEmpty) {
        morceaux.add(TextSpan(text: '  ·  ', style: style));
      }
      morceaux.addAll(spans);
    }

    if (profile.averageRating > 0) {
      ajouter([
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: DonySpacing.xxs),
            child: DonyIcon('star', size: 13, color: cs.warning),
          ),
        ),
        TextSpan(
          text: profile.averageRating.toStringAsFixed(1).replaceAll('.', ','),
          style: fort,
        ),
        TextSpan(text: ' de note', style: style),
      ]);
    }

    final livraisons = profile.completedBidsCount;
    ajouter([
      TextSpan(text: '$livraisons', style: fort),
      TextSpan(
        text: livraisons > 1 ? ' livraisons' : ' livraison',
        style: style,
      ),
    ]);

    final delai = profile.responseDelayHours;
    if (delai != null) {
      ajouter([
        TextSpan(text: 'répond en ', style: style),
        TextSpan(text: '$delai h', style: fort),
      ]);
    }

    // Aucun historique : le dire franchement vaut mieux qu'aligner des zéros.
    if (profile.averageRating <= 0 && livraisons == 0) {
      return Text('Nouveau sur Yadony', style: style);
    }

    return Text.rich(TextSpan(children: morceaux));
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DonySpacing.base,
          0,
          DonySpacing.base,
          DonySpacing.base,
        ),
        child: DonyShimmer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DonySkeletonCircle(diameter: 56),
                  SizedBox(width: DonySpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DonySkeletonBox(width: 150, height: 22),
                      SizedBox(height: DonySpacing.xs),
                      DonySkeletonBox(width: 190, height: 13),
                    ],
                  ),
                ],
              ),
              SizedBox(height: DonySpacing.md),
              DonySkeletonBox(width: 230, height: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsAndTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _StatsAndTabBar({required this.controller});

  final TabController controller;

  /// Les trois cartes de statistiques ont rejoint l'en-tête sous forme de
  /// phrase : il ne reste que la barre d'onglets.
  static const double height = 48;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
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
              onSubscribe: () => context.read<TravelerHubBloc>().add(
                const HubSubscribePressed(),
              ),
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
