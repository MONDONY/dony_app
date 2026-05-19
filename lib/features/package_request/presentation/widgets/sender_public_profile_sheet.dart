import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_list_item.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre un modal sheet (90 %) affichant le profil public d'un expéditeur.
void showSenderPublicProfileSheet(
  BuildContext context,
  SenderPublicProfile sender,
) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => getIt<ProfilePublicBloc>()
        ..add(ProfilePublicRequested(sender.id)),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => _SenderProfileSheet(
          sender: sender,
          scrollController: controller,
        ),
      ),
    ),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _SenderProfileSheet extends StatelessWidget {
  const _SenderProfileSheet({
    required this.sender,
    required this.scrollController,
  });

  final SenderPublicProfile sender;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────────
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

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<ProfilePublicBloc, ProfilePublicState>(
              builder: (context, state) {
                if (state is ProfilePublicError) {
                  return _ErrorBody(
                    onRetry: () => context
                        .read<ProfilePublicBloc>()
                        .add(ProfilePublicRequested(sender.id)),
                  );
                }

                final profile =
                    state is ProfilePublicLoaded ? state.profile : null;
                final ratings =
                    state is ProfilePublicLoaded ? state.recentRatings : null;
                final isLoading = state is ProfilePublicLoading ||
                    state is ProfilePublicInitial;

                return ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    0,
                    DonySpacing.lg,
                    DonySpacing.xl +
                        MediaQuery.of(context).viewPadding.bottom,
                  ),
                  children: [
                    // ── Avatar + nom ─────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          DonyAvatar(
                            name: sender.displayName,
                            size: DonyAvatarSize.xl,
                            verified: profile?.kycVerified ?? sender.kycVerified,
                            pro: profile?.isProAccount ?? false,
                          ),
                          const SizedBox(height: DonySpacing.md),
                          Text(
                            sender.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                  letterSpacing: -0.3,
                                ),
                          ),
                          if (profile?.memberSince != null) ...[
                            const SizedBox(height: DonySpacing.xs),
                            Text(
                              'Membre depuis ${profile!.memberSince}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                          const SizedBox(height: DonySpacing.sm),

                          // Badges
                          Wrap(
                            spacing: DonySpacing.sm,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              if (profile?.isProAccount == true)
                                _Badge(
                                  icon: Icons.workspace_premium_rounded,
                                  label: 'Compte PRO',
                                  iconColor: cs.warning,
                                  bgColor: cs.warningLight,
                                  textColor: cs.warning,
                                ),
                              if (profile?.isKiloPro == true)
                                const _Badge(
                                  icon: Icons.scale_rounded,
                                  label: 'Kilo Pro',
                                  iconColor: DonyColors.amberDark,
                                  bgColor: DonyColors.amberLight,
                                  textColor: DonyColors.amberDark,
                                ),
                              if (profile?.kycVerified == true ||
                                  sender.kycVerified)
                                _Badge(
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

                    // ── Stats ────────────────────────────────────────────
                    _StatsCard(
                      averageRating: profile?.averageRating ??
                          (sender.averageRating > 0
                              ? sender.averageRating
                              : null),
                      totalRatings:
                          profile?.ratingCount ?? sender.totalRatings,
                      completedBids: profile?.completedBidsCount,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: DonySpacing.xl),

                    // ── Évaluations ──────────────────────────────────────
                    Text(
                      'Évaluations',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: DonySpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (ratings != null)
                      _RatingsSection(summary: ratings)
                    else
                      Text(
                        'Aucune évaluation pour l\'instant.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats card ──────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.averageRating,
    required this.totalRatings,
    required this.completedBids,
    required this.isLoading,
  });

  final double? averageRating;
  final int totalRatings;
  final int? completedBids;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final noteStr = averageRating != null && averageRating! > 0
        ? averageRating!.toStringAsFixed(1)
        : '–';
    final avisStr = totalRatings > 0 ? '$totalRatings' : '–';
    final envoiStr =
        completedBids != null ? '$completedBids' : (isLoading ? '…' : '–');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SheetStat(
            value: noteStr,
            label: 'Note',
            icon: Icons.star_rounded,
            iconColor: cs.warning,
          ),
          Container(width: 1, height: 36, color: cs.outline),
          _SheetStat(
            value: avisStr,
            label: 'Avis',
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: cs.primary,
          ),
          Container(width: 1, height: 36, color: cs.outline),
          _SheetStat(
            value: envoiStr,
            label: 'Envois',
            icon: Icons.inventory_2_rounded,
            iconColor: cs.success,
          ),
        ],
      ),
    );
  }
}

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

// ─── Ratings section ──────────────────────────────────────────────────────────

class _RatingsSection extends StatelessWidget {
  const _RatingsSection({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (summary.ratingCount == 0) {
      return Text(
        'Aucune évaluation pour l\'instant.',
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RatingSummaryCard(
          averageRating: summary.averageRating,
          ratingCount: summary.ratingCount,
          distribution: summary.distribution,
        ),
        const SizedBox(height: DonySpacing.base),
        ...summary.ratings.map((r) => RatingListItem(item: r)),
      ],
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
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

// ─── Error body ──────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: DonySpacing.md),
            Text(
              'Impossible de charger le profil',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.base),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
