import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/user_reviews_cubit.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

/// Bottom sheet that shows the full (paginated) list of reviews for [userId].
///
/// Usage:
/// ```dart
/// AllReviewsBottomSheet.show(
///   context,
///   userId: profile.userId,
///   initialSummary: state.recentRatings,
/// );
/// ```
abstract final class AllReviewsBottomSheet {
  static Future<void> show(
    BuildContext context, {
    required String userId,
    RatingSummary? initialSummary,
  }) {
    final cubit = GetIt.instance<UserReviewsCubit>();
    return DonyBottomSheet.show<void>(
      context,
      title: 'Avis',
      wrapper: (child) => BlocProvider<UserReviewsCubit>.value(
        value: cubit,
        child: child,
      ),
      child: _AllReviewsSheetBody(
        userId: userId,
        initialSummary: initialSummary,
      ),
    ).whenComplete(cubit.close);
  }
}

// ─── Sheet body ───────────────────────────────────────────────────────────────

class _AllReviewsSheetBody extends StatefulWidget {
  const _AllReviewsSheetBody({
    required this.userId,
    this.initialSummary,
  });

  final String userId;
  final RatingSummary? initialSummary;

  @override
  State<_AllReviewsSheetBody> createState() => _AllReviewsSheetBodyState();
}

class _AllReviewsSheetBodyState extends State<_AllReviewsSheetBody> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Seed with initial data or fetch page 0.
    context
        .read<UserReviewsCubit>()
        .load(widget.userId, seed: widget.initialSummary);

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      context.read<UserReviewsCubit>().loadNextPage(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserReviewsCubit, UserReviewsState>(
      builder: (context, state) {
        if (state is UserReviewsLoading) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is UserReviewsError) {
          return _ErrorBody(
            message: state.message,
            onRetry: () => context
                .read<UserReviewsCubit>()
                .load(widget.userId, seed: widget.initialSummary),
          );
        }

        if (state is UserReviewsLoaded) {
          return _LoadedBody(
            state: state,
            scrollController: _scrollController,
          );
        }

        // Initial — should not normally render; show nothing.
        return const SizedBox.shrink();
      },
    );
  }
}

// ─── Loaded body ──────────────────────────────────────────────────────────────

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.state, required this.scrollController});

  final UserReviewsLoaded state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    final items = state.allRatings;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Summary card ────────────────────────────────────────────────────
        RatingSummaryCard(
          averageRating: summary.averageRating,
          ratingCount: summary.ratingCount,
          distribution: summary.distribution,
        ),
        const SizedBox(height: DonySpacing.base),

        // ── Review list ─────────────────────────────────────────────────────
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
            child: Text(
              'Aucun avis pour le moment.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ListView.separated(
            controller: scrollController,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length + (state.isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) =>
                const SizedBox(height: DonySpacing.sm),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: DonySpacing.base),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _ReviewRow(item: items[index]);
            },
          ),
      ],
    );
  }
}

// ─── Review row ───────────────────────────────────────────────────────────────

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item});

  final RatingItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateStr =
        DateFormat('d MMM yyyy', 'fr_FR').format(item.createdAt.toLocal());
    final authorName = item.authorName?.isNotEmpty == true
        ? item.authorName!
        : 'Utilisateur';

    // Build initials for avatar fallback.
    final parts = authorName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : authorName.substring(0, authorName.length.clamp(0, 2)).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: avatar + name + date ─────────────────────────────────
          Row(
            children: [
              // Avatar
              _AuthorAvatar(
                avatarUrl: item.authorAvatarUrl,
                initials: initials,
              ),
              const SizedBox(width: DonySpacing.sm),
              // Name + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => DonyIcon(
                    'star',
                    size: 14,
                    color: i < item.stars
                        ? DonyColors.starGold
                        : DonyColors.starGold.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),

          // ── Comment ────────────────────────────────────────────────────
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.sm),
            Text(
              item.comment!,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            ),
          ],

          // ── Corridor chip ─────────────────────────────────────────────
          if (item.departureCity != null && item.arrivalCity != null) ...[
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

// ─── Author avatar ────────────────────────────────────────────────────────────

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({this.avatarUrl, required this.initials});

  final String? avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const size = 36.0;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _InitialsCircle(
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
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ─── Corridor chip ────────────────────────────────────────────────────────────

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
          const DonyEmoji.planeTakeoff(size: 12),
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

// ─── Error body ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('circle-alert', size: 40, color: cs.error),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Impossible de charger les avis',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            message,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.base),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
