import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/likes/bloc/trip_likes_cubit.dart';
import 'package:dony/features/likes/presentation/widgets/trip_like_button.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/trip_moment_corridor.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ligne d'icônes en pied de carte trajet (recherche, carte, favoris), sous
/// un filet comme les autres sections de la carte, sans barre ni cadre :
/// ♡ et son compteur puis partage à gauche, signet (favori privé) à droite.
///
/// - Partage : ouvre l'affiche du trajet ([openTripPoster], la même que la
///   feuille du trajet), masqué quand [canShareTripPoster] est faux. Action
///   sans état : primaire seulement pendant l'appui.
/// - [isOwn] (le voyageur sur son propre trajet) : compteur en lecture seule
///   et partage, ni ♡ actif ni signet. Sans rien à montrer (trajet complet
///   sans j'aime), la ligne et son filet disparaissent.
/// - [showBookmark] : signet affiché, par défaut sur le trajet d'un autre.
///   Les favoris le gardent sur son propre trajet, pour pouvoir le retirer.
///
/// La carte qui la pose réduit sa marge du bas à [cardBottomPadding] : la
/// zone de toucher de 44 px porte déjà son propre blanc.
class TripCardActions extends StatelessWidget {
  const TripCardActions({
    super.key,
    required this.announcement,
    required this.isOwn,
    bool? showBookmark,
    this.gap = DonySpacing.md,
  }) : showBookmark = showBookmark ?? !isOwn;

  final AnnouncementModel announcement;
  final bool isOwn;
  final bool showBookmark;

  /// Espace au-dessus du filet, celui des autres sections de la carte.
  final double gap;

  /// Marge du bas de la carte sous la ligne d'icônes.
  static const double cardBottomPadding = DonySpacing.sm;

  @override
  Widget build(BuildContext context) {
    final canShare = canShareTripPoster(announcement);
    // Seul le compteur peut encore remplir la ligne : elle attend qu'il y
    // ait au moins un j'aime.
    if (isOwn && !canShare && !showBookmark) {
      final likes = maybeRead<TripLikesCubit>(context);
      if (likes == null) return const SizedBox.shrink();
      return BlocBuilder<TripLikesCubit, TripLikesState>(
        bloc: likes,
        buildWhen: (prev, curr) =>
            prev.byTrip[announcement.id] != curr.byTrip[announcement.id],
        builder: (context, _) => likes.statusOf(announcement).likeCount > 0
            ? _row(context, canShare: canShare)
            : const SizedBox.shrink(),
      );
    }
    return _row(context, canShare: canShare);
  }

  Widget _row(BuildContext context, {required bool canShare}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: gap),
        Divider(height: 1, thickness: 1, color: cs.outline),
        const SizedBox(height: DonySpacing.xs),
        Row(
          key: const Key('trip-card-actions'),
          children: [
            TripLikeButton(announcement: announcement, readOnly: isOwn),
            if (canShare) _ShareButton(announcement: announcement),
            const Spacer(),
            if (showBookmark)
              TripBookmarkButton(
                trip: announcement,
                size: TripLikeButton.iconSize,
                alignment: AlignmentDirectional.centerEnd,
              ),
          ],
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      key: const Key('trip-card-share-button'),
      tooltip: context.l10n.tripPosterShareButton,
      visualDensity: VisualDensity.standard,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: kDonyMinTapTarget,
        minHeight: kDonyMinTapTarget,
      ),
      style: ButtonStyle(
        iconColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? DonyColors.primary
              : cs.onSurfaceVariant,
        ),
      ),
      onPressed: () {
        maybeRead<TripLikesCubit>(context)?.trackShareTapped();
        openTripPoster(context, announcement);
      },
      // DonyIcon ne lit pas IconTheme : la couleur résolue par le bouton
      // (appuyé ou non) lui est passée.
      icon: Builder(
        // Taille par défaut de DonyIcon : TripLikeButton.iconSize.
        builder: (context) =>
            DonyIcon('share-curved', color: IconTheme.of(context).color),
      ),
    );
  }
}

/// Signet (favori privé) d'un trajet, lu dans [FavoriteIdsCubit]. Rien
/// n'est rendu sans cubit au-dessus (la carte ne plante jamais). Un échec
/// de bascule revient en arrière (cubit) et montre un message d'erreur.
class TripBookmarkButton extends StatelessWidget {
  const TripBookmarkButton({
    super.key,
    required this.trip,
    this.size = 26,
    this.alignment = Alignment.center,
  });

  final AnnouncementModel trip;
  final double size;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final cubit = maybeRead<FavoriteIdsCubit>(context);
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<FavoriteIdsCubit, FavoriteIdsState>(
      bloc: cubit,
      builder: (ctx, _) => FavoriteHeartButton(
        isFavorite: cubit.isTripFav(trip.id),
        size: size,
        alignment: alignment,
        onToggle: () async {
          try {
            await cubit.toggleTrip(trip.id, corridor: tripMomentCorridor(trip));
          } catch (_) {
            if (ctx.mounted) {
              DonySnackbar.show(
                ctx,
                message: ctx.l10n.listingRetryActionMessage,
                type: DonySnackbarType.error,
              );
            }
          }
        },
      ),
    );
  }
}
