import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_errors_shown_above.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_pay_button.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/live_bid.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/recipient_change_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_todo_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre le bottom sheet de la tuile « À traiter » [tile] pour [bid] (fiche
/// colis, vue expéditeur) et compte l'ouverture (`bid_detail_tile_opened`,
/// avec [source]).
///
/// Comme [openSenderTileSheet] : le sheet s'ouvre sur le navigateur racine, les
/// BLoCs de l'écran y sont reposés par le `wrapper` (`BidBloc` pour suivre le
/// colis, `CancellationBloc` pour répondre au report), contenu et pied suivent
/// le colis courant ([LiveBid]). Les boutons vivent dans le `stickyBottom`.
///
/// Le sheet se ferme seul une fois la demande traitée : dès que le colis
/// rechargé ne justifie plus [tile] ([senderTodoTilesFor]), ou au succès de
/// l'action (report gardé ou retiré). L'écran affiche alors sa confirmation,
/// sans sheet par-dessus. Une confirmation ouverte au-dessus du sheet n'est
/// jamais refermée à sa place.
///
/// Points d'extension pour une nouvelle tuile : son contenu sans cadre dans
/// [_SenderTodoSheetContent], son pied dans [_stickyBottomFor], ses BLoCs ou
/// cubits d'action dans le `wrapper` (un cubit créé par `BlocProvider(create:)`
/// y est fermé au démontage de la route, après l'animation de sortie), et sa
/// fermeture au succès dans [_SenderTodoSheetContent] si l'action ne recharge
/// pas le colis.
///
/// Modification : `AmendmentActionCubit` est créé dans le `wrapper`, sans
/// mesure d'affichage (`bid_amendment_viewed` part à l'affichage de la tuile,
/// [senderTodoViewed]) ; « Payer » ferme le sheet avant de pousser l'écran
/// d'attente.
Future<void> openSenderTodoSheet(
  BuildContext context,
  BidModel bid,
  SenderTodoTile tile, {
  TodoSource source = TodoSource.tile,
}) {
  unawaited(
    getItSafe<AnalyticsService>()?.logEvent(
      AnalyticsEvents.bidDetailTileOpened,
      properties: {'tile': tile.name, 'role': 'sender', 'source': source.name},
    ),
  );

  final bidBloc = _maybeRead<BidBloc>(context);
  final cancellationBloc = _maybeRead<CancellationBloc>(context);
  final live = bidBloc != null;
  final amendment = tile == SenderTodoTile.amendment;

  return DonyBottomSheet.show<void>(
    context,
    title: senderTodoTitle(context.l10n, tile),
    analyticsName: 'bid-detail/todo-${tile.name}',
    wrapper: (bidBloc == null && cancellationBloc == null && !amendment)
        ? null
        : (content) => MultiBlocProvider(
            providers: [
              if (bidBloc != null) BlocProvider<BidBloc>.value(value: bidBloc),
              if (cancellationBloc != null)
                BlocProvider<CancellationBloc>.value(value: cancellationBloc),
              if (amendment)
                BlocProvider<AmendmentActionCubit>(
                  create: (_) => getIt<AmendmentActionCubit>(),
                ),
            ],
            child: content,
          ),
    stickyBottom: _stickyBottomFor(
      tile,
      context,
      bid,
      live: live,
      canDecide: cancellationBloc != null,
    ),
    child: _SenderTodoSheetContent(
      bid: bid,
      tile: tile,
      live: live,
      closesOnDecision: cancellationBloc != null,
    ),
  );
}

T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Pied du sheet de [tile] : les boutons de la carte, qui suivent le colis
/// courant et disparaissent quand la demande ne réclame plus de réponse.
/// `null` quand l'action est impossible faute de BLoC à l'écran.
Widget? _stickyBottomFor(
  SenderTodoTile tile,
  BuildContext screenContext,
  BidModel bid, {
  required bool live,
  required bool canDecide,
}) {
  final l = screenContext.l10n;
  return switch (tile) {
    // Un bouton à la fois, selon l'état de la demande : « Annuler ma
    // demande » tant que le montant n'est pas acquis, « Payer » une fois
    // acceptée en mobile money, rien pendant la commission du voyageur.
    SenderTodoTile.amendment => LiveBid(
      bid: bid,
      live: live,
      builder: (sheetContext, current) {
        final open = AmendmentSenderCard.openRequest(current);
        if (open != null && AmendmentSenderCancelButton.canCancel(open)) {
          return AmendmentSenderCancelButton(bid: current, amendment: open);
        }
        if (AmendmentPayButton.canPay(current)) {
          // Pousse un écran : ferme d'abord ce sheet, puis paie avec le
          // contexte de l'écran (le colis y est relu au retour).
          return AmendmentPayButton(
            bid: current,
            launcher: (pay) => closeTileSheetThen(
              sheetContext,
              screenContext,
              () => unawaited(pay(screenContext)),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    ),
    // Bouton simple : ferme ce sheet, puis ouvre « Modifier le destinataire »
    // avec le contexte de l'écran (rechargement et confirmation y vivent).
    SenderTodoTile.recipient => LiveBid(
      bid: bid,
      live: live,
      builder: (sheetContext, current) => current.canChangeRecipient
          ? DonyButton(
              key: const Key('recipient-declined-change'),
              // Sans icône : « Désigner un autre destinataire » rétrécissait
              // en français à 360 dp et grand texte (× 1,3).
              label: l.recipientDeclinedSenderButton,
              onPressed: () => closeTileSheetThen(
                sheetContext,
                screenContext,
                () =>
                    unawaited(openRecipientChangeSheet(screenContext, current)),
              ),
            )
          : const SizedBox.shrink(),
    ),
    SenderTodoTile.reschedule =>
      canDecide
          ? LiveBid(
              bid: bid,
              live: live,
              builder: (_, current) => TripRescheduleCard.needsReply(current)
                  ? TripRescheduleDecisionButtons(bid: current)
                  : const SizedBox.shrink(),
            )
          : null,
  };
}

/// Contenu du sheet : la carte sans cadre, sur le colis courant, et les
/// écouteurs qui referment le sheet une fois la demande traitée.
class _SenderTodoSheetContent extends StatelessWidget {
  const _SenderTodoSheetContent({
    required this.bid,
    required this.tile,
    required this.live,
    required this.closesOnDecision,
  });

  final BidModel bid;
  final SenderTodoTile tile;
  final bool live;

  /// Le `CancellationBloc` de l'écran est là : le report gardé ou retiré
  /// referme le sheet sans attendre le rechargement du colis.
  final bool closesOnDecision;

  @override
  Widget build(BuildContext context) {
    Widget content = LiveBid(
      bid: bid,
      live: live,
      builder: (_, current) => switch (tile) {
        // Comme le report : le colis rechargé peut perdre sa demande ouverte
        // pendant l'animation de sortie, la carte garde la dernière connue.
        SenderTodoTile.amendment => AmendmentSenderCard(
          bid: AmendmentSenderCard.needsReply(current) ? current : bid,
          framed: false,
        ),
        SenderTodoTile.recipient => RecipientDeclinedBody(bid: current),
        // Le colis rechargé peut perdre son report pendant l'animation de
        // sortie : la carte garde alors le dernier report connu.
        SenderTodoTile.reschedule => TripRescheduleCard(
          bid: TripRescheduleCard.shouldShow(current) ? current : bid,
          isSender: true,
          framed: false,
        ),
      },
    );

    if (live) {
      // Une confirmation ouverte par-dessus (retrait du report) n'est jamais
      // refermée à sa place.
      content = CloseSheetWhenResolved(
        bidId: bid.id,
        stillNeeded: (current) => senderTodoTilesFor(current).contains(tile),
        child: content,
      );
    }

    if (tile == SenderTodoTile.amendment) {
      // Pendant l'annulation, le retour système et le toucher du fond ne
      // ferment pas le sheet (la réponse y est attendue) ; les fermetures
      // forcées (glissement, succès) restent possibles, le bouton relit
      // alors le colis à la réponse.
      final inner = content;
      content = BlocConsumer<AmendmentActionCubit, AmendmentActionState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: _onAmendmentAction,
        buildWhen: (prev, curr) => prev.isBusy != curr.isBusy,
        builder: (_, action) => PopScope(canPop: !action.isBusy, child: inner),
      );
    }

    if (tile == SenderTodoTile.reschedule && closesOnDecision) {
      content = BlocListener<CancellationBloc, CancellationState>(
        listenWhen: (_, state) =>
            state is RescheduleKept ||
            state is RescheduleWithdrawn ||
            state is CancellationError,
        listener: (context, state) {
          if (state is CancellationError) {
            // Échéance passée, réseau : le sheet la montre par-dessus lui et
            // reste ouvert, boutons actifs, pour réessayer ; il le déclare
            // (CancellationErrorsShownAbove), l'écran dessous se tait.
            unawaited(ErrorPresenter.show(context, state.error));
          } else {
            closeSheetIfOnTop(context);
          }
        },
        child: CancellationErrorsShownAbove(
          bloc: context.read<CancellationBloc>(),
          child: content,
        ),
      );
    }

    return content;
  }

  /// Annulation de la modification : au succès, le sheet se ferme, puis la
  /// confirmation s'affiche sur l'écran (le sheet n'est plus la route active)
  /// et le colis est relu ; la tuile disparaît. En échec (demande déjà
  /// traitée ou expirée), l'erreur s'affiche au-dessus du sheet et le colis
  /// relu montre le vrai état (le sheet se ferme alors si la demande n'est
  /// plus ouverte).
  void _onAmendmentAction(BuildContext context, AmendmentActionState state) {
    switch (state.status) {
      case AmendmentActionStatus.done:
        _reload(context);
        closeSheetIfOnTop(context);
        DonySnackbar.show(
          context,
          message: context.l10n.amendmentCancelledSnackbar,
          type: DonySnackbarType.success,
        );
      case AmendmentActionStatus.failure:
        unawaited(ErrorPresenter.show(context, state.error));
        _reload(context);
      case AmendmentActionStatus.idle || AmendmentActionStatus.busy:
        break;
    }
  }

  void _reload(BuildContext context) {
    if (live) context.read<BidBloc>().add(BidDetailRequested(bid.id));
  }
}
