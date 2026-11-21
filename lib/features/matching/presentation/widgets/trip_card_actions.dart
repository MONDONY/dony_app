import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
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
/// cœur « j'aime » puis partage à gauche, signet (favori privé) à droite.
///
/// - Partage : ouvre l'affiche du trajet ([openTripPoster], la même que la
///   feuille du trajet), masqué quand [canShareTripPoster] est faux. Action
///   sans état : primaire du thème seulement pendant l'appui.
/// - Le nombre de j'aime s'affiche dès 1 pour tout le monde. [isOwn] (le
///   voyageur sur son propre trajet) : cœur actif comme les autres et
///   partage, sans signet.
/// - Trajet que le back refuse d'aimer ([TripLikeButton.canLike] faux : en
///   cours, brouillon, caché…) : aucun cœur, sauf si l'utilisateur l'avait
///   déjà aimé : le cœur reste actif (avec le nombre) pour retirer son
///   j'aime, puis disparaît. Le voyageur y garde le compteur en lecture
///   seule. Sans rien à montrer, la ligne et son filet disparaissent.
/// - [showBookmark] : signet affiché, par défaut sur le trajet d'un autre.
///   Les favoris le gardent sur son propre trajet, pour pouvoir le retirer.
///
/// La carte qui la pose réduit sa marge du bas de [cardPadding] à
/// [cardBottomPadding] : la zone de toucher de 44 px porte déjà son propre
/// blanc. Quand la ligne disparaît, elle rend la différence, et la carte
/// garde sa marge habituelle.
class TripCardActions extends StatelessWidget {
  const TripCardActions({
    super.key,
    required this.announcement,
    required this.isOwn,
    bool? showBookmark,
    this.gap = DonySpacing.md,
    this.cardPadding = DonySpacing.base,
  }) : assert(cardPadding >= cardBottomPadding),
       showBookmark = showBookmark ?? !isOwn;

  final AnnouncementModel announcement;
  final bool isOwn;
  final bool showBookmark;

  /// Espace au-dessus du filet, celui des autres sections de la carte.
  final double gap;

  /// Marge du bas de la carte quand elle n'a pas de ligne d'actions.
  final double cardPadding;

  /// Marge du bas de la carte sous la ligne d'icônes.
  static const double cardBottomPadding = DonySpacing.sm;

  @override
  Widget build(BuildContext context) {
    final canShare = canShareTripPoster(announcement);
    // Le cœur décide seul de son état (j'aime déjà posé, retirable) ;
    // ici, seul le remplissage de la ligne compte.
    final likeInert = !TripLikeButton.canLike(announcement);
    // Sans partage ni signet, seul un nombre (son trajet) ou un j'aime posé
    // (trajet plus aimable, retirable) remplit encore la ligne.
    if (likeInert && !canShare && !showBookmark) {
      final likes = maybeRead<TripLikesCubit>(context);
      if (likes == null) return _empty();
      return BlocBuilder<TripLikesCubit, TripLikesState>(
        bloc: likes,
        buildWhen: (prev, curr) =>
            prev.byTrip[announcement.id] != curr.byTrip[announcement.id],
        builder: (context, _) {
          final status = likes.statusOf(announcement);
          return (status.likedByMe || (isOwn && status.likeCount > 0))
              ? _row(context, canShare: canShare)
              : _empty();
        },
      );
    }
    return _row(context, canShare: canShare);
  }

  /// Ligne vide : le blanc que la carte a retiré de sa marge du bas.
  Widget _empty() => SizedBox(height: cardPadding - cardBottomPadding);

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
            TripLikeButton(announcement: announcement, isOwn: isOwn),
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
              ? cs.primary
              : cs.onSurfaceVariant,
        ),
      ),
      onPressed: () {
        final likes = maybeRead<TripLikesCubit>(context);
        // L'affiche n'est pas ouverte aux visiteurs : le routeur les
        // renverrait sans un mot vers la connexion. Même invitation que le cœur,
        // et le partage, qui n'a pas eu lieu, n'est pas mesuré.
        if (!(getItSafe<FirebaseSessionProbe>()?.hasRealSession ?? false)) {
          likes?.trackLoginPrompted();
          unawaited(
            AuthRequiredSheet.show(context, reason: AuthRequiredReason.share),
          );
          return;
        }
        likes?.trackShareTapped();
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
