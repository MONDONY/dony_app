import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/bloc/my_reviews_event.dart';
import 'package:dony/features/ratings/bloc/my_reviews_state.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MyReviewsBloc>().add(const MyReviewsRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return DonyPageScaffold(
      title: 'Mes avis reçus',
      scrollable: false,
      body: BlocBuilder<MyReviewsBloc, MyReviewsState>(
        builder: (context, state) {
          if (state is MyReviewsLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (state is MyReviewsError) {
            return _ErrorView(message: state.message);
          }
          if (state is MyReviewsLoaded) {
            if (state.summary.ratingCount == 0) {
              return const _EmptyView();
            }
            return _LoadedView(summary: state.summary);
          }
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const DonyEmptyState(
      mascotte: DonyMascotteType.assis,
      title: "Tu n'as pas encore reçu d'avis",
      description:
          'Les notes et commentaires laissés par les voyageurs apparaîtront ici.',
    );
  }
}

// ─── Error state ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DonyEmptyState(
      mascotte: DonyMascotteType.assis,
      type: DonyEmptyStateType.error,
      iconAsset: 'circle-alert',
      title: 'Impossible de charger les avis',
      description: message,
      actionLabel: 'Réessayer',
      onAction: () =>
          context.read<MyReviewsBloc>().add(const MyReviewsRequested()),
    );
  }
}

// ─── Loaded state ─────────────────────────────────────────────────────────────

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // Header card — score moyen
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.base,
            ),
            child: _HeaderCard(summary: summary),
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),

        // Section label
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.base,
              DonySpacing.lg,
              DonySpacing.sm,
            ),
            child: Text(
              'AVIS REÇUS',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
        ),

        // Liste des avis
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            0,
            DonySpacing.lg,
            DonySpacing.huge,
          ),
          sliver: SliverList.builder(
            itemCount: summary.ratings.length,
            itemBuilder: (context, i) {
              return _ReviewItem(
                item: summary.ratings[i],
                index: i,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Header card ─────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.summary});

  final RatingSummary summary;

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
          // Score moyen
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                summary.averageRating.toStringAsFixed(1),
                style: tt.displayLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < summary.averageRating.round();
                  return DonyIcon(
                    'star',
                    size: 14,
                    color: filled
                        ? DonyColors.warning500
                        : cs.onSurfaceVariant,
                  );
                }),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                '${summary.ratingCount} avis',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),

          const SizedBox(width: DonySpacing.xl),

          // Barres de distribution
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = summary.distribution[star] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: DonySpacing.xs),
                  child: _RatingBar(
                    stars: star,
                    count: count,
                    total: summary.ratingCount,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rating bar ──────────────────────────────────────────────────────────────

class _RatingBar extends StatelessWidget {
  const _RatingBar({
    required this.stars,
    required this.count,
    required this.total,
  });

  final int stars;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ratio = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        Text(
          '$stars★',
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.full),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: cs.outline,
              color: DonyColors.warning500,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ─── Review item ─────────────────────────────────────────────────────────────

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.item, required this.index});

  final RatingItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateStr = DateFormat('dd/MM/yyyy').format(item.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Container(
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
                // Étoiles
                ...List.generate(5, (i) {
                  return DonyIcon(
                    'star',
                    size: 16,
                    color: i < item.stars
                        ? DonyColors.warning500
                        : cs.onSurfaceVariant,
                  );
                }),
                const Spacer(),
                Text(
                  dateStr,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            if (item.comment != null && item.comment!.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                item.comment!,
                style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              ),
            ],
            if (item.excluded) ...[
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Avis exclu du calcul',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 80).ms, duration: 300.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

