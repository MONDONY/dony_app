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

/// ♡ public d'un trajet et son compteur, lus dans [TripLikesCubit].
///
/// - Sélectionné : cœur plein en [DonyColors.primary] ; sinon contour neutre.
/// - Compteur masqué à 0, affiché dès 1 (abrégé au-delà de 1 000 : « 1,3 k »).
/// - [readOnly] (le voyageur sur son propre trajet) : compteur seul, sans
///   geste, rien du tout à 0.
/// - Visiteur sans compte ([FirebaseSessionProbe.hasRealSession] faux) : le
///   toucher ouvre l'invitation à se connecter ([AuthRequiredSheet]), sans
///   rien changer au compteur.
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

  /// Taille des icônes de la ligne d'actions (♡, partage, signet).
  static const double iconSize = 24;

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
        if (readOnly) {
          return status.likeCount > 0
              ? _ReadOnlyLikes(count: status.likeCount)
              : const SizedBox.shrink();
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
    final count = status.likeCount;
    final color = liked ? DonyColors.primary : cs.onSurfaceVariant;
    final tooltip = liked ? l.tripUnlikeTooltip : l.tripLikeTooltip;
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      key: const Key('trip-like-button'),
      container: true,
      button: true,
      toggled: liked,
      label: tooltip,
      value: count > 0 ? l.tripLikeCountSemantics(count) : null,
      // `excludeSemantics` retire l'action de l'InkWell : sans ce rappel, le
      // ♡ restait inactivable au lecteur d'écran (TalkBack, Switch Access,
      // Voice Access).
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: _LikeLayout(
            count: count,
            countColor: color,
            // Pop court du cœur, coupé avec « réduire les animations ».
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
                liked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(liked),
                size: TripLikeButton.iconSize,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compteur du voyageur sur son propre trajet : il voit qui aime, sans
/// pouvoir aimer.
class _ReadOnlyLikes extends StatelessWidget {
  const _ReadOnlyLikes({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('trip-like-count-readonly'),
      container: true,
      label: context.l10n.tripLikeCountSemantics(count),
      excludeSemantics: true,
      child: _LikeLayout(
        count: count,
        countColor: cs.onSurfaceVariant,
        icon: const Icon(
          Icons.favorite,
          size: TripLikeButton.iconSize,
          color: DonyColors.primary,
        ),
      ),
    );
  }
}

/// Cœur au début d'une zone d'au moins 44 × 44, compteur à sa suite.
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
