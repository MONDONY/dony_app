import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_status_chip.dart';
import 'package:dony/features/package_request/presentation/widgets/sender_public_profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Carte « demande d'envoi » — identité COLIS-FIRST (variante Ⓒ Ticket) :
/// bande latérale ambre + micro-label, photo colis + compteur, titre colis,
/// trajet en méta (drapeaux), budget, chip statut, expéditeur.
class PackageRequestListCard extends StatelessWidget {
  const PackageRequestListCard({
    super.key,
    required this.item,
    this.onTap,
    this.onMakeOffer,
    this.isOwnRequest = false,
    this.status = PackageRequestStatus.open,
    this.index = 0,
    this.showFavorite = false,
  });

  final PackageRequestSearchItem item;
  final VoidCallback? onTap;
  final VoidCallback? onMakeOffer;
  final bool isOwnRequest;

  /// Statut réel (le feed n'expose que OPEN ; les vues propriétaires passent le vrai).
  final PackageRequestStatus status;
  final int index;

  /// When true, renders a heart button in the micro-label row (pushed right).
  /// Requires a [FavoriteIdsCubit] in the tree; silently omitted if absent.
  ///
  /// Caller is responsible for NOT passing true on items owned by the current
  /// user. The in-card heart has no owner guard; the backend returns 422 on an
  /// own-request add, but the optimistic UI would flash before the error arrives.
  final bool showFavorite;

  String get _sizeLabel => switch (item.parcelSize) {
    ParcelSize.small => 'S',
    ParcelSize.medium => 'M',
    ParcelSize.large => 'L',
  };

  /// Builds a favorite heart for a package request — defensive (never crashes
  /// if no [FavoriteIdsCubit] is present in the tree).
  Widget _buildRequestFavoriteHeart(BuildContext context) {
    FavoriteIdsCubit? cubit;
    try {
      cubit = context.read<FavoriteIdsCubit>();
    } catch (_) {
      return const SizedBox.shrink();
    }
    final c = cubit;
    return BlocBuilder<FavoriteIdsCubit, FavoriteIdsState>(
      bloc: c,
      builder: (ctx, _) => FavoriteHeartButton(
        isFavorite: c.isRequestFav(item.id),
        onToggle: () async {
          try {
            await c.toggleRequest(item.id);
          } catch (_) {
            if (ctx.mounted) {
              DonySnackbar.show(
                ctx,
                message: 'Action impossible, réessaie',
                type: DonySnackbarType.error,
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = cs.warning;

    return Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isOwnRequest
                      ? cs.primary.withValues(alpha: 0.35)
                      : cs.outlineVariant,
                  width: isOwnRequest ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(DonyRadius.card),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bande latérale ambre — identité « demande »
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [accent, accent.withValues(alpha: 0.55)],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(DonySpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Micro-label + chip statut/own + optional heart ──
                            Row(
                              children: [
                                DonyIcon('package', size: 13, color: accent),
                                const SizedBox(width: DonySpacing.xxs),
                                Expanded(
                                  child: Text(
                                    'Demande d\'envoi',
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                if (isOwnRequest)
                                  _OwnRequestChip(cs: cs, tt: tt)
                                else
                                  packageStatusChip(context, status),
                                if (item.isUrgent) ...[
                                  const SizedBox(width: DonySpacing.xs),
                                  const DonyUrgentBadge(),
                                ],
                                if (showFavorite) ...[
                                  const SizedBox(width: DonySpacing.xs),
                                  _buildRequestFavoriteHeart(context),
                                ],
                              ],
                            ),
                            // ── Score de compatibilité (filtre « Pour mes
                            //    trajets ») : présent uniquement quand le
                            //    serveur a renvoyé un score.
                            if (item.hasMatchScore) ...[
                              const SizedBox(height: DonySpacing.xs),
                              _MatchScoreRow(item: item, cs: cs, tt: tt),
                            ],
                            const SizedBox(height: DonySpacing.sm),

                            // ── Photo colis + infos colis ─────────────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Thumbnail(item: item, cs: cs),
                                const SizedBox(width: DonySpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Titre colis-first
                                      Text(
                                        '${item.weightKg.toStringAsFixed(0)} kg · '
                                        '${item.categories.isNotEmpty ? '${item.categories.first} · ' : ''}$_sizeLabel',
                                        style: tt.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          color: cs.onSurface,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: DonySpacing.xs),
                                      _RouteMeta(item: item, cs: cs, tt: tt),
                                      const SizedBox(height: DonySpacing.xs),
                                      _Budget(item: item, cs: cs, tt: tt),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Divider(height: 1, color: cs.outlineVariant),
                            const SizedBox(height: DonySpacing.xs),
                            _SenderRow(item: item, cs: cs, tt: tt),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 60 * index),
          duration: 280.ms,
        )
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ── Score de compatibilité avec les trajets de l'utilisateur ─────────────────

/// Ligne « 94 % · Ton trajet du 12 juil. » affichée sur les résultats d'une
/// recherche filtrée « Pour mes trajets ». Le score vient du serveur, la carte
/// ne le recalcule jamais. Absente dès que [PackageRequestSearchItem.matchScore]
/// est nul : les autres feeds de demandes gardent leur rendu d'origine.
class _MatchScoreRow extends StatelessWidget {
  const _MatchScoreRow({
    required this.item,
    required this.cs,
    required this.tt,
  });

  final PackageRequestSearchItem item;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final depart = item.matchedTripDepartureDate;
    return Row(
      children: [
        Container(
          key: const Key('match-score-badge'),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.sm,
            vertical: DonySpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon('sparkles', size: 12, color: cs.primary),
              const SizedBox(width: DonySpacing.xs),
              Text(
                '${item.matchScore} %',
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        if (depart != null) ...[
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Ton trajet du ${DateFormat('d MMM', 'fr').format(depart)}',
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Route meta (drapeaux + date) ─────────────────────────────────────────────

class _RouteMeta extends StatelessWidget {
  const _RouteMeta({required this.item, required this.cs, required this.tt});
  final PackageRequestSearchItem item;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final depFlag = cityFlag(item.departureCity);
    final arrFlag = cityFlag(item.arrivalCity);
    final dateStr = DateFormat(
      'd MMM',
      'fr',
    ).format(item.desiredDate).toLowerCase();
    final tol = item.dateToleranceDays > 0
        ? ' ±${item.dateToleranceDays}j'
        : '';
    final parts = <String>[
      ?depFlag,
      item.departureCity,
      '→',
      item.arrivalCity,
      ?arrFlag,
    ];
    return Row(
      children: [
        Icon(Icons.flight_rounded, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xxs),
        Expanded(
          child: Text(
            '${parts.join(' ')} · $dateStr$tol',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Budget ───────────────────────────────────────────────────────────────────

class _Budget extends StatelessWidget {
  const _Budget({required this.item, required this.cs, required this.tt});
  final PackageRequestSearchItem item;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (item.targetPriceEur == null) {
      return Text(
        'Budget libre',
        style: tt.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'Budget ',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Text(
          '${item.targetPriceEur!.toStringAsFixed(0)} €',
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.primary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ── Thumbnail + compteur photos ──────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, required this.cs});
  final PackageRequestSearchItem item;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final url = item.photoUrls.isNotEmpty
        ? item.photoUrls.first
        : item.photoUrl;
    final count = item.photoUrls.length;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: SizedBox(
              width: 76,
              height: 76,
              child: url != null && url.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: url,
                      cacheKey: DonyImage.stableCacheKey(url),
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          _PlaceholderBox(item: item, cs: cs),
                      errorWidget: (_, _, _) =>
                          _PlaceholderBox(item: item, cs: cs),
                    )
                  : _PlaceholderBox(item: item, cs: cs),
            ),
          ),
          if (count > 1)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                child: Text(
                  '📷 $count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({required this.item, required this.cs});
  final PackageRequestSearchItem item;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.primaryContainer.withValues(alpha: 0.45),
      child: Center(
        child: Text(
          emojiForLabel(
            item.categories.isEmpty ? null : item.categories.first,
          ),
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }
}

// ── Sender row ───────────────────────────────────────────────────────────────

class _SenderRow extends StatelessWidget {
  const _SenderRow({required this.item, required this.cs, required this.tt});
  final PackageRequestSearchItem item;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showSenderPublicProfileSheet(context, item.sender),
      borderRadius: BorderRadius.circular(DonyRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
        child: Row(
          children: [
            DonyAvatar(
              name: item.sender.displayName,
              imageUrl: item.sender.avatarUrl,
              size: DonyAvatarSize.sm,
              verified: item.sender.kycVerified,
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sender.displayName,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      DonyIcon('star', size: 12, color: cs.warning),
                      const SizedBox(width: 2),
                      Text(
                        item.sender.averageRating.toStringAsFixed(1),
                        style: tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        ' · ${item.sender.totalRatings} avis',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            DonyIcon(
              'chevron-right',
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip "Ma demande" ────────────────────────────────────────────────────────

class _OwnRequestChip extends StatelessWidget {
  const _OwnRequestChip({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('user', size: 12, color: cs.primary),
          const SizedBox(width: DonySpacing.xs),
          Text(
            'Ma demande',
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte matching scoré (layout B — « Colis sur mes trajets ») ──────────────

/// Carte unifiée d'un colis matchant un trajet : badge de score, poids,
/// corridor du trajet + date, expéditeur (initiales/note), budget/kg, photo.
class MatchingRequestCard extends StatelessWidget {
  const MatchingRequestCard({
    super.key,
    required this.match,
    required this.index,
    this.onTap,
  });

  final MatchingRequestModel match;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = cs.warning;
    final depDate = match.tripDepartureDate;
    final dateStr = depDate != null
        ? DateFormat('d MMM', 'fr').format(depDate).toLowerCase()
        : '';

    return Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(DonyRadius.card),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [accent, accent.withValues(alpha: 0.55)],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(DonySpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _ScoreBadge(score: match.matchScore),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: Text(
                                    match.tripCorridor != null && dateStr.isNotEmpty
                                        ? '${match.tripCorridor} · $dateStr'
                                        : match.tripCorridor ?? dateStr,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MatchThumbnail(match: match, cs: cs),
                                const SizedBox(width: DonySpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${match.weightKg.toStringAsFixed(0)} kg'
                                        '${match.contentType != null ? ' · ${match.contentType}' : ''}',
                                        style: tt.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          color: cs.onSurface,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: DonySpacing.xs),
                                      Text(
                                        match.budgetPerKg != null
                                            ? 'Budget ${match.budgetPerKg!.toStringAsFixed(0)} €/kg'
                                            : 'Budget libre',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Divider(height: 1, color: cs.outlineVariant),
                            const SizedBox(height: DonySpacing.xs),
                            Row(
                              children: [
                                DonyAvatar(
                                  name: match.senderName,
                                  size: DonyAvatarSize.sm,
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        match.senderName,
                                        style: tt.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          DonyIcon('star',
                                              size: 12, color: cs.warning),
                                          const SizedBox(width: 2),
                                          Text(
                                            match.senderRating
                                                .toStringAsFixed(1),
                                            style: tt.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurface,
                                            ),
                                          ),
                                          Text(
                                            ' · ${match.senderTotalSent} envois',
                                            style: tt.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DonyIcon('chevron-right',
                                    size: 16,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 60 * index), duration: 280.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('sparkles', size: 12, color: cs.primary),
          const SizedBox(width: DonySpacing.xs),
          Text(
            '$score',
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchThumbnail extends StatelessWidget {
  const _MatchThumbnail({required this.match, required this.cs});
  final MatchingRequestModel match;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final url = match.packagePhotoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: SizedBox(
        width: 76,
        height: 76,
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                cacheKey: DonyImage.stableCacheKey(url),
                fit: BoxFit.cover,
                placeholder: (_, _) => _matchPlaceholder(cs),
                errorWidget: (_, _, _) => _matchPlaceholder(cs),
              )
            : _matchPlaceholder(cs),
      ),
    );
  }

  Widget _matchPlaceholder(ColorScheme cs) => Container(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        child: const Center(child: Text('📦', style: TextStyle(fontSize: 30))),
      );
}
