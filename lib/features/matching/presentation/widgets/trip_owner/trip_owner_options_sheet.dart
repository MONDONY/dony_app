import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_edit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_actions.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_reschedule_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_series/trip_series_sheets.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Entrée du menu ⋮ de l'écran du trajet vu par son voyageur, dans l'ordre
/// du menu.
enum TripMenuEntry {
  edit,
  reschedule,
  unpublish,
  sharePoster,
  arrivalInstructions,
  makeRecurring,
  saveTemplate,
  cancelTrip,
  delete,
}

/// Statuts d'un trajet qu'on peut répéter ou garder comme modèle.
const _reusableStatuses = {'ACTIVE', 'COMPLETED'};

/// Entrées du menu ⋮ de [trip], dans l'ordre du menu. Fonction pure : une
/// entrée n'apparaît que si son action est possible, plutôt que grisée avec
/// un message qui ne s'applique pas (seul « Reporter » reste affiché
/// verrouillé, avec la vraie raison, [tripRescheduleBlockFor]).
///
/// - `edit` : trajet modifiable ([canEditTrip]) ;
/// - `reschedule` : trajet reportable ([tripCanReschedule]) ;
/// - `unpublish` : ACTIVE sans demande ;
/// - `sharePoster` : ACTIVE ([canShareTripPoster]) ;
/// - `arrivalInstructions` : instructions de retrait ou colis arrivé (la
///   tuile `arrival` de « Votre trajet », [tripTilesFor]) ;
/// - `makeRecurring` : trajet direct (sans étapes, le back refuse
///   `series-multi-leg-trip`) ACTIVE ou COMPLETED ;
/// - `saveTemplate` : ACTIVE ou COMPLETED ;
/// - `cancelTrip` : ACTIVE avec des demandes (jamais FULL : le back n'annule
///   qu'un trajet ACTIVE) ;
/// - `delete` : trajet modifiable, ou annulé.
///
/// [bids] : colis chargés par l'écran, `null` tant que la liste n'a pas
/// répondu (les compteurs du modèle servent alors, [tripHasBids]).
/// [isOwner] faux : aucune entrée.
List<TripMenuEntry> tripMenuEntriesFor({
  required AnnouncementModel trip,
  required List<BidModel>? bids,
  required bool isOwner,
}) {
  if (!isOwner) return const [];
  final hasBids = tripHasBids(trip, bids);
  final canEdit = canEditTrip(trip, hasBids);
  final active = trip.status == 'ACTIVE';
  final reusable = _reusableStatuses.contains(trip.status);
  return [
    if (canEdit) TripMenuEntry.edit,
    if (tripCanReschedule(trip, hasBids)) TripMenuEntry.reschedule,
    if (active && !hasBids) TripMenuEntry.unpublish,
    if (canShareTripPoster(trip)) TripMenuEntry.sharePoster,
    if (tripTilesFor(
      trip: trip,
      bids: bids,
      isOwner: true,
    ).contains(TripTile.arrival))
      TripMenuEntry.arrivalInstructions,
    if (reusable && trip.tripGroupId == null) TripMenuEntry.makeRecurring,
    if (reusable) TripMenuEntry.saveTemplate,
    if (active && hasBids) TripMenuEntry.cancelTrip,
    if (canEdit || trip.status == 'CANCELLED') TripMenuEntry.delete,
  ];
}

/// Bouton ⋮ de la barre d'application de l'écran du trajet : ouvre
/// [showTripOwnerOptionsSheet]. Absent quand le menu n'aurait aucune entrée
/// (trajet retiré par l'équipe sans instructions, visiteur). À placer dans
/// les `actions` de `DonyAppBar`, qui ajoute le scarabée après lui. Cible de
/// 48 px (`IconButton`), nom accessible par son `tooltip`.
class TripOwnerOptionsButton extends StatelessWidget {
  const TripOwnerOptionsButton({
    super.key,
    required this.trip,
    required this.bids,
    required this.isOwner,
  });

  final AnnouncementModel trip;

  /// Colis chargés par l'écran, `null` tant que la liste n'a pas répondu.
  final List<BidModel>? bids;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    if (tripMenuEntriesFor(trip: trip, bids: bids, isOwner: isOwner).isEmpty) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('trip-owner-menu-button'),
      tooltip: context.l10n.tripOwnerMenuTooltip,
      icon: DonyIcon(
        'ellipsis-vertical',
        color: Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: () =>
          unawaited(showTripOwnerOptionsSheet(context, trip: trip, bids: bids)),
    );
  }
}

/// Ouvre le menu ⋮ du trajet [trip] ([tripMenuEntriesFor]) pour son
/// voyageur. Le menu ne fait que choisir : chaque entrée le ferme, puis agit
/// depuis [context], le contexte de l'écran, qui porte ses blocs et en écoute
/// les suites :
/// - Modifier : [openTripEdit] ; Reporter : `TripRescheduleBottomSheet` ;
///   Dépublier, Supprimer : [confirmTripUnpublish], [confirmTripDelete]
///   (confirmation, étapes suivantes d'un voyage) ; Annuler le voyage :
///   [openTripCancellation] (colis déjà remis annoncés) ; Partager
///   l'affiche : [openTripPoster] ;
/// - Instructions de retrait : le sheet de la tuile `arrival`
///   ([openTripTileSheet], `source: menu`, qui émet `bid_detail_tile_opened`) ;
/// - Rendre ce trajet récurrent, Enregistrer en modèle : un `TripSeriesCubit`
///   pour ce trajet (calendrier puis modèle, ou modèle seul), fermé à la fin
///   du parcours (`trip_series_opened`, `trip_series_created`,
///   `trip_series_template_saved` émis par le cubit).
///
/// Le menu lui-même n'émet rien, comme celui de la fiche colis.
Future<void> showTripOwnerOptionsSheet(
  BuildContext context, {
  required AnnouncementModel trip,
  required List<BidModel>? bids,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  // Jusqu'à sept entrées : la feuille prend la hauteur dont elle a besoin,
  // le contenu défile au-delà (petit téléphone, grand texte).
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) =>
      _TripOwnerOptionsSheet(trip: trip, bids: bids, screenContext: context),
);

class _TripOwnerOptionsSheet extends StatelessWidget {
  const _TripOwnerOptionsSheet({
    required this.trip,
    required this.bids,
    required this.screenContext,
  });

  final AnnouncementModel trip;
  final List<BidModel>? bids;
  final BuildContext screenContext;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final h = DonyLayout.hPadding(context);
    final entries = tripMenuEntriesFor(trip: trip, bids: bids, isOwner: true);
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          h,
          0,
          h,
          MediaQuery.of(context).padding.bottom + DonySpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(l.bidDetailOptionsTitle, style: tt.headlineMedium),
            const SizedBox(height: DonySpacing.base),
            for (final entry in entries) ...[
              _entryTile(context, entry),
              const SizedBox(height: DonySpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _entryTile(BuildContext context, TripMenuEntry entry) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final danger =
        entry == TripMenuEntry.cancelTrip || entry == TripMenuEntry.delete;
    final block = entry == TripMenuEntry.reschedule
        ? tripRescheduleBlockFor(trip, bids)
        : null;
    final (icon, label, subtitle) = switch (entry) {
      TripMenuEntry.edit => (
        'square-pen',
        l.commonEdit,
        l.tripMenuEditSubtitle,
      ),
      TripMenuEntry.reschedule => (
        'calendar-sync',
        l.tripRescheduleTile,
        block == null
            ? l.tripRescheduleSubtitle
            : tripRescheduleBlockMessage(l, block),
      ),
      TripMenuEntry.unpublish => (
        'eye-off',
        l.tripOwnerUnpublishTile,
        l.tripOwnerUnpublishDialogMessage,
      ),
      TripMenuEntry.sharePoster => (
        'share-2',
        l.tripPosterShareButton,
        l.tripTilePosterSubtitle,
      ),
      // Le sheet ne propose de modifier les instructions qu'après l'arrivée
      // (un colis ARRIVED, règle du back) : avant, ou sur un trajet terminé
      // ou annulé, il se lit seulement, le sous-titre n'annonce pas de
      // saisie.
      TripMenuEntry.arrivalInstructions => (
        'flag',
        l.tripOwnerArrivalEditingTitle,
        tripHasArrivedParcel(bids)
            ? l.tripOwnerArrivalSubtitle
            : l.tripMenuArrivalReadSubtitle,
      ),
      TripMenuEntry.makeRecurring => (
        'calendar',
        l.tripSeriesCardCta,
        l.tripMenuRecurringSubtitle,
      ),
      TripMenuEntry.saveTemplate => (
        'bookmark',
        l.tripMenuSaveTemplate,
        l.tripMenuSaveTemplateSubtitle,
      ),
      TripMenuEntry.cancelTrip => (
        'circle-x',
        l.tripOwnerCancelTripButton,
        l.cancellationIrreversibleSubtitle,
      ),
      TripMenuEntry.delete => (
        'trash-2',
        l.commonDelete,
        l.tripMenuDeleteSubtitle,
      ),
    };
    return _OptionTile(
      key: Key('trip-menu-${entry.name}'),
      iconAsset: icon,
      iconColor: danger ? cs.error : cs.primary,
      iconBg: danger ? cs.errorLight : cs.primaryContainer,
      label: label,
      subtitle: subtitle,
      onTap: block != null
          ? null
          : () {
              Navigator.of(context).pop();
              _act(entry);
            },
    );
  }

  void _act(TripMenuEntry entry) {
    final ctx = screenContext;
    if (!ctx.mounted) return;
    switch (entry) {
      case TripMenuEntry.edit:
        unawaited(openTripEdit(ctx, trip));
      case TripMenuEntry.reschedule:
        unawaited(TripRescheduleBottomSheet.show(ctx, announcement: trip));
      case TripMenuEntry.unpublish:
        unawaited(confirmTripUnpublish(ctx, trip));
      case TripMenuEntry.sharePoster:
        openTripPoster(ctx, trip);
      case TripMenuEntry.arrivalInstructions:
        unawaited(
          openTripTileSheet(
            ctx,
            trip,
            TripTile.arrival,
            source: TileSource.menu,
            bids: bids,
          ),
        );
      case TripMenuEntry.makeRecurring:
        unawaited(_withSeriesCubit(ctx, TripSeriesFlow.start));
      case TripMenuEntry.saveTemplate:
        unawaited(_withSeriesCubit(ctx, TripSeriesFlow.saveTemplate));
      case TripMenuEntry.cancelTrip:
        unawaited(openTripCancellation(ctx, trip, bids));
      case TripMenuEntry.delete:
        unawaited(confirmTripDelete(ctx, trip));
    }
  }

  /// Parcours du trajet récurrent ou du modèle sur un cubit propre à ce
  /// trajet, fermé à la fin.
  ///
  /// Le menu n'a pas, comme la carte de l'écran de succès, de surface qui
  /// survit au parcours et en garde le résultat : une feuille fermée d'un
  /// geste pendant l'envoi ne doit ni perdre la réponse du serveur (le cubit
  /// fermé trop tôt n'émettrait pas `trip_series_created`, le voyageur
  /// recommencerait et recevrait `series-date-taken`), ni laisser le
  /// voyageur sans trace des trajets créés. Le cubit n'est donc fermé
  /// qu'une fois l'envoi en cours terminé, et l'écran confirme ensuite
  /// ([_confirmSeriesOutcome]).
  Future<void> _withSeriesCubit(
    BuildContext ctx,
    Future<void> Function(BuildContext, TripSeriesCubit) flow,
  ) async {
    final cubit = getIt<TripSeriesCubit>(param1: trip);
    try {
      await flow(ctx, cubit);
      final pendingSeries = cubit.state.status == TripSeriesStatus.submitting;
      final pendingTemplate =
          cubit.state.templateStatus == TripSeriesTemplateStatus.saving;
      final settled = pendingSeries || pendingTemplate
          ? await cubit.stream.firstWhere(
              (s) =>
                  s.status != TripSeriesStatus.submitting &&
                  s.templateStatus != TripSeriesTemplateStatus.saving,
            )
          : cubit.state;
      if (ctx.mounted) {
        _confirmSeriesOutcome(
          ctx,
          settled,
          seriesShown: !pendingSeries,
          templateConfirmed: !pendingTemplate,
        );
      }
    } finally {
      await cubit.close();
    }
  }

  /// Confirmation laissée sur l'écran une fois le parcours refermé :
  /// - modèle enregistré alors que sa feuille était déjà fermée : « Modèle
  ///   enregistré » ([templateConfirmed] faux : la feuille ne l'a pas dit) ;
  /// - trajets créés sans modèle enregistré (« Non merci », feuille du modèle
  ///   fermée d'un geste, calendrier fermé pendant l'envoi) : « N trajets
  ///   publiés » ou « N brouillons créés ». Avec un modèle enregistré, la
  ///   feuille du modèle a déjà montré les deux ;
  /// - série refusée alors que le calendrier était déjà fermé
  ///   ([seriesShown] faux : la feuille n'a pas pu afficher le refus) : le
  ///   motif, en erreur.
  void _confirmSeriesOutcome(
    BuildContext ctx,
    TripSeriesState state, {
    required bool seriesShown,
    required bool templateConfirmed,
  }) {
    final l = ctx.l10n;
    if (!seriesShown && state.status == TripSeriesStatus.failed) {
      DonySnackbar.show(
        ctx,
        message: tripSeriesErrorText(ctx, state.errorCode),
        type: DonySnackbarType.error,
      );
      return;
    }
    final templateSaved =
        state.templateStatus == TripSeriesTemplateStatus.saved;
    if (templateSaved) {
      if (!templateConfirmed) {
        DonySnackbar.show(
          ctx,
          message: l.tripTemplateSaved,
          type: DonySnackbarType.success,
        );
      }
      return;
    }
    final created = state.result?.created.length ?? 0;
    if (state.status != TripSeriesStatus.done || created == 0) return;
    DonySnackbar.show(
      ctx,
      message: state.draft
          ? l.tripSeriesBadgeDrafts(created)
          : l.tripSeriesBadgePublished(created),
      type: DonySnackbarType.success,
    );
  }
}

/// Entrée du menu : icône, libellé, sous-titre, chevron. Sans [onTap], elle
/// est verrouillée : annoncée désactivée, icône et libellé estompés
/// (`opacity` 0,4), mais le sous-titre, qui dit pourquoi, garde son
/// contraste normal (WCAG 1.4.3). Le lecteur d'écran lit l'entrée d'un
/// trait (`MergeSemantics`) : libellé puis raison.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.iconAsset,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String iconAsset;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final dim = enabled ? 1.0 : 0.4;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.lg),
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                Opacity(
                  opacity: dim,
                  child: Container(
                    padding: const EdgeInsets.all(DonySpacing.sm),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                    ),
                    // Décorative : le libellé dit l'entrée.
                    child: ExcludeSemantics(
                      child: DonyIcon(iconAsset, color: iconColor, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(
                        opacity: dim,
                        child: Text(
                          label,
                          style: tt.titleSmall?.copyWith(color: cs.onSurface),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  ExcludeSemantics(
                    child: DonyIcon(
                      'chevron-right',
                      color: cs.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
