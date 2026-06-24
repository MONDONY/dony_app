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
    final ratings = summary.ratings;

    return CustomScrollView(
      slivers: [
        // ── Hero éditorial — gros score + distribution ────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.base,
            ),
            child: _HeaderSummary(summary: summary),
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
              DonySpacing.lg,
              DonySpacing.lg,
              0,
            ),
            child: Text(
              'AVIS REÇUS',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
        ),

        // ── Liste éditoriale (divisée, sans cartes) ───────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            0,
            DonySpacing.lg,
            DonySpacing.huge,
          ),
          sliver: SliverList.builder(
            itemCount: ratings.length,
            itemBuilder: (context, i) {
              return Column(
                children: [
                  Divider(height: 1, color: cs.outline),
                  _ReviewItem(item: ratings[i], index: i),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Hero éditorial ───────────────────────────────────────────────────────────

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rounded = summary.averageRating.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score géant (display) — calme, couleur encre.
        Text(
          summary.averageRating.toStringAsFixed(1),
          style: tt.displayLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 60,
            height: 1,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: DonyIcon(
                'star',
                size: 18,
                color: i < rounded ? DonyColors.warning500 : cs.outline,
              ),
            );
          }),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Sur ${summary.ratingCount} avis reçus',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.lg),
        // Distribution — barres bleu marque sur track soft.
        ...List.generate(5, (i) {
          final star = 5 - i;
          final count = summary.distribution[star] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.sm),
            child: _RatingBar(
              stars: star,
              count: count,
              total: summary.ratingCount,
            ),
          );
        }),
      ],
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
        SizedBox(
          width: 26,
          child: Text(
            '$stars★',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.full),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: DonyColors.primarySoft,
              color: cs.primary,
              minHeight: 7,
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Review item (éditorial) ──────────────────────────────────────────────────

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.item, required this.index});

  final RatingItem item;
  final int index;

  /// Corridor « VILLE → VILLE » si les deux villes sont connues, sinon null.
  String? get _corridor {
    final dep = item.departureCity?.trim();
    final arr = item.arrivalCity?.trim();
    if (dep == null || dep.isEmpty || arr == null || arr.isEmpty) return null;
    return '${dep.toUpperCase()} → ${arr.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateStr =
        DateFormat('d MMM yyyy', 'fr').format(item.createdAt).toUpperCase();
    final name = (item.authorName?.trim().isNotEmpty ?? false)
        ? item.authorName!.trim()
        : 'Utilisateur dony';
    final corridor = _corridor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : avatar + nom/corridor + étoiles
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DonyAvatar(
                name: name,
                imageUrl: item.authorAvatarUrl,
                size: DonyAvatarSize.md,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (corridor != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        corridor,
                        style: tt.labelMedium?.copyWith(
                          color: cs.secondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return DonyIcon(
                    'star',
                    size: 15,
                    color: i < item.stars
                        ? DonyColors.warning500
                        : cs.outline,
                  );
                }),
              ),
            ],
          ),
          // Commentaire
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.md),
            Text(
              '« ${item.comment!} »',
              style: tt.bodyLarge?.copyWith(color: cs.onSurface, height: 1.5),
            ),
          ],
          // Date
          const SizedBox(height: DonySpacing.sm),
          Text(
            dateStr,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          // Avis exclu
          if (item.excluded) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Avis exclu du calcul',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 70).ms, duration: 300.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

