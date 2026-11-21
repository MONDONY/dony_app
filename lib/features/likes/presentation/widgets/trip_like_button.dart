import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/likes/bloc/trip_likes_cubit.dart';
import 'package:dony/features/likes/data/models/trip_like_status.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Pouce « j'aime » public d'un trajet, lu dans [TripLikesCubit].
///
/// - Sélectionné : pouce plein au primaire du thème (`colorScheme.primary`,
///   qui suit le mode sombre et le contraste élevé) ; sinon contour neutre.
/// - Compteur caché tant que l'utilisateur n'a pas aimé : un non-aimant ne
///   voit que le pouce. Une fois aimé, il montre le TOTAL (le sien compris,
///   d'abord optimiste puis celui du serveur), abrégé au-delà de 1 000
///   (« 1,3 k ») ; retirer son j'aime le cache de nouveau. Jamais de 0.
/// - Lecture seule ([readOnly], le voyageur sur son propre trajet) : pouce au
///   contour neutre sans geste et compteur dès 1 j'aime, rien à 0. Un trajet
///   que le back refuse d'aimer ([canLike] faux) sans j'aime de
///   l'utilisateur : même pouce neutre, sans geste et sans nombre. Un j'aime
///   déjà posé sur un trajet devenu non aimable reste actif pour pouvoir être
///   retiré.
/// - Lecteur d'écran : libellé constant « J'aime », l'état passe par
///   `toggled` ; la valeur (« N personnes aiment ce trajet ») suit la règle
///   du compteur visuel, jamais lue quand le nombre est caché. Seule
///   l'infobulle visuelle dit « Je n'aime plus ».
/// - Visiteur sans compte ([FirebaseSessionProbe.hasRealSession] faux) : le
///   toucher ouvre l'invitation à se connecter ([AuthRequiredSheet]), sans
///   rien changer.
/// - Une bascule refusée revient à l'état d'avant (cubit) et montre un
///   message d'erreur, comme le signet.
///
/// Sans [TripLikesCubit] au-dessus (tests, aperçus) : rien n'est rendu.
///
/// L'icône est posée au début de sa zone de toucher, qui s'étend vers la
/// fin : alignée sur le texte de la carte, cible de 44 px entière.
class TripLikeButton extends StatelessWidget {
  const TripLikeButton({
    super.key,
    required this.announcement,
    this.readOnly = false,
  });

  final AnnouncementModel announcement;
  final bool readOnly;

  /// Taille des icônes de la ligne d'actions (pouce, partage, signet).
  static const double iconSize = 24;

  /// Le back accepte-t-il un j'aime sur [trip] ? Même règle que
  /// `TripLikeService.requireLikeable` : trajet ACTIVE ou FULL, non caché.
  /// Ailleurs (en cours, brouillon, retiré…), chaque toucher finirait en 404
  /// puis « Action impossible » : le pouce y reste en lecture seule.
  static bool canLike(AnnouncementModel trip) =>
      (trip.status == 'ACTIVE' || trip.isFull) && !trip.hidden;

  @override
  Widget build(BuildContext context) {
    final cubit = maybeRead<TripLikesCubit>(context);
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<TripLikesCubit, TripLikesState>(
      bloc: cubit,
      buildWhen: (prev, curr) =>
          prev.byTrip[announcement.id] != curr.byTrip[announcement.id],
      builder: (context, _) {
        final status = cubit.statusOf(announcement);
        // Un j'aime déjà posé reste retirable même quand le trajet n'est
        // plus aimable (le back accepte le retrait, jamais un nouveau
        // j'aime) : une fois retiré, le pouce retombe en lecture seule.
        final locked =
            readOnly || (!canLike(announcement) && !status.likedByMe);
        if (locked) {
          // Seul le voyageur voit le nombre sur son trajet, dès 1 ; sans
          // rien à lui montrer, il n'a pas de pouce. Un autre utilisateur
          // garde un pouce neutre sans nombre : il n'a pas aimé.
          if (readOnly) {
            return status.likeCount > 0
                ? _ReadOnlyLikes(count: status.likeCount)
                : const SizedBox.shrink();
          }
          return const _ReadOnlyLikes(count: 0);
        }
        return _LikeToggle(status: status, onTap: () => _onTap(context, cubit));
      },
    );
  }

  Future<void> _onTap(BuildContext context, TripLikesCubit cubit) async {
    final real = getItSafe<FirebaseSessionProbe>()?.hasRealSession ?? false;
    if (!real) {
      // Pas de j'aime anonyme : le back refuse un visiteur (403).
      cubit.trackLoginPrompted();
      await AuthRequiredSheet.show(context, reason: AuthRequiredReason.like);
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    try {
      await cubit.toggle(announcement);
    } catch (_) {
      if (context.mounted) {
        DonySnackbar.show(
          context,
          message: context.l10n.listingRetryActionMessage,
          type: DonySnackbarType.error,
        );
      }
    }
  }
}

String _formatCount(BuildContext context, int count) =>
    NumberFormat.compact(locale: context.l10n.localeName).format(count);

class _LikeToggle extends StatelessWidget {
  const _LikeToggle({required this.status, required this.onTap});

  final TripLikeStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final liked = status.likedByMe;
    // Le nombre n'apparaît qu'après mon j'aime, jamais à 0.
    final count = liked && status.likeCount > 0 ? status.likeCount : 0;
    final color = liked ? cs.primary : cs.onSurfaceVariant;
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      key: const Key('trip-like-button'),
      container: true,
      button: true,
      toggled: liked,
      // Libellé constant : l'état est dit par « activé ». Un libellé qui
      // bascule faisait lire « Je n'aime plus, activé » à TalkBack.
      label: l.tripLikeTooltip,
      // Même règle que le nombre affiché : rien à lire s'il est caché.
      value: count > 0 ? l.tripLikeCountSemantics(count) : null,
      // `excludeSemantics` retire l'action de l'InkWell : sans ce rappel, le
      // pouce restait inactivable au lecteur d'écran (TalkBack, Switch Access,
      // Voice Access).
      onTap: onTap,
      excludeSemantics: true,
      // L'infobulle visuelle dit le geste qui suit. Le `Material` transparent
      // donne au pouce sa propre surface d'encre : le fond décoré de la carte
      // recouvrait celle de l'écran (ni éclaboussure ni focus visible), sans
      // changer la mise en page. `Tooltip(` reste à moins de 10 lignes de
      // l'`InkWell` : c'est la fenêtre où le garde a11y cherche un nom.
      child: Tooltip(
        message: liked ? l.tripUnlikeTooltip : l.tripLikeTooltip,
        excludeFromSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: _LikeLayout(
              count: count,
              countColor: color,
              // Pop court du pouce, coupé avec « réduire les animations ».
              icon: AnimatedSwitcher(
                duration: animate
                    ? const Duration(milliseconds: 220)
                    : Duration.zero,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: Icon(
                  liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  key: ValueKey(liked),
                  size: TripLikeButton.iconSize,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pouce sans geste : le voyageur sur son propre trajet voit combien
/// l'aiment ([count] > 0), sans pouvoir aimer ; sur un trajet que le back
/// refuse d'aimer, l'autre utilisateur voit le même pouce sans nombre
/// ([count] à 0, décoratif pour le lecteur d'écran). Pouce au contour
/// neutre : un pouce plein se lirait « j'ai aimé ce trajet ».
class _ReadOnlyLikes extends StatelessWidget {
  const _ReadOnlyLikes({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('trip-like-count-readonly'),
      container: true,
      label: count > 0 ? context.l10n.tripLikeCountSemantics(count) : null,
      excludeSemantics: true,
      child: _LikeLayout(
        count: count,
        countColor: cs.onSurfaceVariant,
        icon: Icon(
          Icons.thumb_up_outlined,
          size: TripLikeButton.iconSize,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Pouce au début d'une zone d'au moins 44 × 44, compteur à sa suite.
class _LikeLayout extends StatelessWidget {
  const _LikeLayout({
    required this.icon,
    required this.count,
    required this.countColor,
  });

  final Widget icon;
  final int count;
  final Color countColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: kDonyMinTapTarget,
        minHeight: kDonyMinTapTarget,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          end: count > 0 ? DonySpacing.sm : 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (count > 0) ...[
              const SizedBox(width: DonySpacing.xs),
              Text(
                _formatCount(context, count),
                key: const Key('trip-like-count'),
                maxLines: 1,
                softWrap: false,
                style: tt.labelLarge?.copyWith(
                  color: countColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
