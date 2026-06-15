import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/block_user_action.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_list_item.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_summary_card.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre un modal sheet (90 % écran) affichant le profil complet d'un voyageur.
void showTravelerProfileSheet(BuildContext context, TravelerProfile traveler) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<RatingBloc>()
            ..add(UserRatingsLoadRequested(userId: traveler.id)),
        ),
        BlocProvider(
          create: (_) => getIt<TravelerSubscribeBloc>()
            ..add(LoadSubscribeStatus(traveler.id)),
        ),
      ],
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => _TravelerProfileSheet(
          traveler: traveler,
          scrollController: controller,
        ),
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
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          // ── Handle + menu ⋯ ──────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                ),
                Positioned(
                  right: DonySpacing.sm,
                  child: IconButton(
                    icon: DonyIcon(
                      'ellipsis',
                      color: cs.onSurfaceVariant,
                    ),
                    tooltip: 'Plus d\'options',
                    onPressed: () => showBlockMenu(
                      context,
                      userId: traveler.id,
                      displayName: _abbreviatedName,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── En-tête tintée ────────────────────────────────────────────────
          _ProfileHeader(
            traveler: traveler,
            abbreviatedName: _abbreviatedName,
          ),

          Divider(height: 1, thickness: 1, color: cs.outline),

          // ── 3 stat cards ──────────────────────────────────────────────────
          BlocBuilder<RatingBloc, RatingState>(
            buildWhen: (p, c) =>
                c is UserRatingsLoaded || c is RatingInitial || c is RatingLoading || c is RatingError,
            builder: (context, state) {
              final loaded = state is UserRatingsLoaded ? state : null;
              final noteValue = traveler.averageRating != null
                  ? traveler.averageRating!.toStringAsFixed(1)
                  : (loaded != null && loaded.ratingCount > 0
                      ? loaded.averageRating.toStringAsFixed(1)
                      : '–');
              final tripsValue = traveler.totalTrips != null
                  ? '${traveler.totalTrips}'
                  : '–';
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.sm,
                  DonySpacing.lg,
                  DonySpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: noteValue,
                        label: 'Note',
                        iconAsset: 'star',
                        iconColor: cs.warning,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: _StatCard(
                        value: tripsValue,
                        label: 'Trajets',
                        iconAsset: 'plane-takeoff',
                        iconColor: cs.primary,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: _StatCard(
                        value: '–',
                        label: 'Livraison',
                        iconAsset: 'circle-check',
                        iconColor: cs.success,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Divider(height: 1, thickness: 1, color: cs.outline),

          // ── Évaluations (scrollable) ────────────────────────────────────
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.md,
                DonySpacing.lg,
                DonySpacing.xl,
              ),
              children: [
                Text(
                  'Évaluations',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                BlocBuilder<RatingBloc, RatingState>(
                  builder: (context, state) {
                    if (state is UserRatingsLoaded) {
                      if (state.ratingCount == 0) {
                        return Text(
                          'Aucune évaluation pour l\'instant.',
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RatingSummaryCard(
                            averageRating: state.averageRating,
                            ratingCount: state.ratingCount,
                            distribution: state.distribution,
                          ),
                          const SizedBox(height: DonySpacing.base),
                          ...state.ratings.map((r) => RatingListItem(item: r)),
                          if (state.page < state.totalPages - 1)
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    context.read<RatingBloc>().add(
                                          UserRatingsLoadRequested(
                                            userId: traveler.id,
                                            page: state.page + 1,
                                          ),
                                        ),
                                child: const Text('Voir plus'),
                              ),
                            ),
                        ],
                      );
                    }
                    if (state is RatingError) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              context.read<RatingBloc>().add(
                                    UserRatingsLoadRequested(
                                        userId: traveler.id),
                                  ),
                          icon: const DonyIcon('refresh-cw'),
                          label: const Text('Réessayer'),
                        ),
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(
                  begin: 0.04,
                  curve: Curves.easeOutCubic,
                ),
          ),

          // ── Barre d'abonnement (sticky) ───────────────────────────────
          const _SubscribeBar(),
        ],
      ),
    );
  }
}

// ─── Profile header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.traveler,
    required this.abbreviatedName,
  });

  final TravelerProfile traveler;
  final String abbreviatedName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        DonySpacing.lg,
      ),
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
      child: Row(
        children: [
          // Avatar avec bordure blanche + ombre verte
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
              name: traveler.resolvedName,
              size: DonyAvatarSize.lg,
              verified: traveler.kycVerified,
              pro: traveler.isProAccount,
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          // Nom, téléphone, badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  abbreviatedName,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                if (traveler.phoneNumber != null)
                  Row(
                    children: [
                      DonyIcon('phone',
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        traveler.phoneNumber!,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  )
                else
                  Text(
                    'Numéro révélé après acceptation',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: DonySpacing.xs),
                Wrap(
                  spacing: DonySpacing.xs,
                  runSpacing: DonySpacing.xs,
                  children: [
                    if (traveler.isProAccount)
                      _ProfileBadge(
                        iconAsset: 'star',
                        label: 'Compte PRO',
                        iconColor: cs.warning,
                      ),
                    if (traveler.kiloPro)
                      _ProfileBadge(
                        iconAsset: 'package',
                        label: 'Kilo Pro',
                        iconColor: cs.warning,
                      ),
                    if (traveler.kycVerified)
                      _ProfileBadge(
                        iconAsset: 'badge-check',
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
    );
  }
}

// ─── Profile badge ────────────────────────────────────────────────────────────

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    required this.iconAsset,
    required this.label,
    required this.iconColor,
  });

  final String iconAsset;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: 3, // spec-defined pixel value — no exact DonySpacing token
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon(iconAsset, size: 11, color: iconColor),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), // spec-defined pixel values — no exact DonySpacing token
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon(iconAsset, size: 18, color: iconColor),
          const SizedBox(height: DonySpacing.xs),
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 3), // spec-defined pixel value — no exact DonySpacing token
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─── Subscribe bar ────────────────────────────────────────────────────────────

class _SubscribeBar extends StatelessWidget {
  const _SubscribeBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<TravelerSubscribeBloc, TravelerSubscribeState>(
      builder: (context, state) {
        if (state.status != TravelerSubscribeStatus.ready) {
          return const SizedBox.shrink();
        }
        return Material(
          color: cs.surface,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.sm,
                DonySpacing.lg,
                DonySpacing.sm,
              ),
              child: state.subscribed
                  ? _SubscribedRow(pushEnabled: state.pushEnabled)
                  : DonyButton(
                      label: "S'abonner à ce voyageur",
                      iconAsset: 'bell',
                      onPressed: () => context
                          .read<TravelerSubscribeBloc>()
                          .add(const SubscribePressed()),
                    ),
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
          icon: DonyIcon(
            pushEnabled ? 'bell' : 'bell-off',
            color: cs.primary,
          ),
          onPressed: () => context
              .read<TravelerSubscribeBloc>()
              .add(TogglePushPressed(!pushEnabled)),
        ),
      ],
    );
  }
}
