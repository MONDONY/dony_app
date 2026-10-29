import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/live_bid.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_todo_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// D'où s'ouvre le sheet d'une tuile « À traiter » du voyageur : propriété
/// `source` de `bid_detail_tile_opened`.
enum TravelerTodoSource {
  /// Tuile touchée dans la grille.
  tile,

  /// Lien d'une notification (`?action=supplement`) : le sheet s'ouvre de
  /// lui-même à l'affichage de la fiche.
  link,
}

/// Ouvre le bottom sheet de la tuile « À traiter » [tile] pour [bid] (fiche
/// colis, vue voyageur) et compte l'ouverture (`bid_detail_tile_opened`, avec
/// [source]).
///
/// Comme `openTravelerTileSheet` : le sheet s'ouvre sur le navigateur racine,
/// le `BidBloc` de l'écran y est reposé par le `wrapper` (suivre le colis,
/// le relire après une action), contenu et pied suivent le colis courant
/// ([LiveBid]). Les boutons vivent dans le `stickyBottom`.
///
/// Supplément : `SupplementCommissionCubit` et `SupplementActionCubit` sont
/// créés dans le `wrapper` (fermés au démontage de la route, après
/// l'animation de sortie), sans mesure d'affichage : `bid_supplement_viewed`
/// part à l'affichage de la tuile ([travelerTodoViewed]). [authorize] remplace
/// `requirePaymentAuth` dans les tests.
///
/// Le sheet se ferme seul une fois la demande traitée : au succès de l'action
/// (frais validés, demande retirée), ou dès que le colis rechargé ne justifie
/// plus [tile] ([travelerTodoTilesFor]). L'écran affiche alors la
/// confirmation, sans sheet par-dessus. Une erreur s'affiche par-dessus le
/// sheet, qui reste ouvert pour réessayer. Une confirmation ouverte au-dessus
/// du sheet n'est jamais refermée à sa place.
Future<void> openTravelerTodoSheet(
  BuildContext context,
  BidModel bid,
  TravelerTodoTile tile, {
  TravelerTodoSource source = TravelerTodoSource.tile,
  SupplementRequestAuthorizer? authorize,
}) {
  unawaited(
    getItSafe<AnalyticsService>()?.logEvent(
      AnalyticsEvents.bidDetailTileOpened,
      properties: {
        'tile': tile.name,
        'role': 'traveler',
        'source': source.name,
      },
    ),
  );

  BidBloc? bidBloc;
  try {
    bidBloc = context.read<BidBloc>();
  } on ProviderNotFoundException {
    bidBloc = null;
  }
  final screenBidBloc = bidBloc;
  final live = screenBidBloc != null;

  return DonyBottomSheet.show<void>(
    context,
    title: travelerTodoTitle(context.l10n, tile),
    analyticsName: 'bid-detail/traveler-todo-${tile.name}',
    wrapper: (content) => MultiBlocProvider(
      providers: [
        if (screenBidBloc != null)
          BlocProvider<BidBloc>.value(value: screenBidBloc),
        ...switch (tile) {
          TravelerTodoTile.supplement => [
            BlocProvider<SupplementCommissionCubit>(
              create: (_) => getIt<SupplementCommissionCubit>(),
            ),
            BlocProvider<SupplementActionCubit>(
              create: (_) => getIt<SupplementActionCubit>(),
            ),
          ],
        },
      ],
      child: content,
    ),
    stickyBottom: switch (tile) {
      // Les deux boutons tant que les frais attendent le voyageur ; rien dès
      // que le colis relu ne les attend plus (le sheet se ferme alors).
      TravelerTodoTile.supplement => LiveBid(
        bid: bid,
        live: live,
        builder: (_, current) => SupplementTravelerCard.needsReply(current)
            ? SupplementCommissionButtons(
                bid: current,
                supplement: current.supplement!,
                authorize: authorize,
              )
            : const SizedBox.shrink(),
      ),
    },
    child: _TravelerTodoSheetContent(bid: bid, tile: tile, live: live),
  );
}

/// Contenu du sheet : la carte sans cadre, sur le colis courant, et les
/// écouteurs des actions du pied.
class _TravelerTodoSheetContent extends StatelessWidget {
  const _TravelerTodoSheetContent({
    required this.bid,
    required this.tile,
    required this.live,
  });

  final BidModel bid;
  final TravelerTodoTile tile;
  final bool live;

  /// Ferme le sheet s'il est au premier plan : une confirmation ouverte
  /// par-dessus (retrait de la demande) n'est jamais refermée à sa place.
  static void _closeIfOnTop(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = LiveBid(
      bid: bid,
      live: live,
      builder: (_, current) => switch (tile) {
        // Le colis relu peut perdre la demande en attente pendant l'animation
        // de sortie : la carte garde alors la dernière connue.
        TravelerTodoTile.supplement => SupplementTravelerCard(
          bid: SupplementTravelerCard.needsReply(current) ? current : bid,
          framed: false,
        ),
      },
    );

    if (live) {
      content = _CloseWhenResolved(bid: bid, tile: tile, child: content);
    }

    return switch (tile) {
      TravelerTodoTile.supplement => MultiBlocListener(
        listeners: [
          BlocListener<
            SupplementCommissionCubit,
            SupplementCommissionResumeState
          >(
            listenWhen: (prev, curr) => prev.status != curr.status,
            listener: _onCommission,
          ),
          BlocListener<SupplementActionCubit, SupplementActionState>(
            listenWhen: (prev, curr) => prev.status != curr.status,
            listener: _onWithdraw,
          ),
        ],
        child: content,
      ),
    };
  }

  /// « Valider le paiement » : frais prélevés (la demande part chez
  /// l'expéditeur) ou débit en cours de traitement par Stripe (le webhook
  /// tranchera) : le colis est relu, le sheet se ferme, puis la confirmation
  /// s'affiche sur l'écran. 3DS abandonnée : message par-dessus le sheet, qui
  /// reste ouvert pour réessayer. Carte refusée ou réseau : erreur par-dessus
  /// le sheet et colis relu (le sheet se ferme alors si la demande a été
  /// annulée).
  void _onCommission(
    BuildContext context,
    SupplementCommissionResumeState state,
  ) {
    final l = context.l10n;
    switch (state.status) {
      case SupplementCommissionResumeStatus.proposed:
        _reload(context);
        _closeIfOnTop(context);
        DonySnackbar.show(
          context,
          message: l.supplementCommissionConfirmedSnackbar,
          type: DonySnackbarType.success,
        );
      case SupplementCommissionResumeStatus.pending:
        _reload(context);
        _closeIfOnTop(context);
        DonySnackbar.show(context, message: l.supplementCommissionProcessing);
      case SupplementCommissionResumeStatus.failure:
        if (state.error == null) {
          DonySnackbar.show(
            context,
            message: l.supplementCommissionAuthInterrupted,
            type: DonySnackbarType.error,
          );
        } else {
          unawaited(ErrorPresenter.show(context, state.error));
          _reload(context);
        }
      case SupplementCommissionResumeStatus.idle ||
          SupplementCommissionResumeStatus.authorizing ||
          SupplementCommissionResumeStatus.busy:
        break;
    }
  }

  /// « Retirer la demande » : au succès, le colis est relu, le sheet se
  /// ferme, puis « Demande retirée » s'affiche sur l'écran. En échec (demande
  /// déjà traitée ou expirée), l'erreur s'affiche par-dessus le sheet et le
  /// colis relu montre le vrai état.
  void _onWithdraw(BuildContext context, SupplementActionState state) {
    switch (state.status) {
      case SupplementActionStatus.done:
        _reload(context);
        _closeIfOnTop(context);
        DonySnackbar.show(
          context,
          message: context.l10n.supplementWithdrawn,
          type: DonySnackbarType.success,
        );
      case SupplementActionStatus.failure:
        unawaited(ErrorPresenter.show(context, state.error));
        _reload(context);
      case SupplementActionStatus.idle || SupplementActionStatus.busy:
        break;
    }
  }

  void _reload(BuildContext context) {
    if (live) context.read<BidBloc>().add(BidDetailRequested(bid.id));
  }
}

/// Ferme le sheet dès que le colis courant ne justifie plus [tile]
/// ([travelerTodoTilesFor]) et que le sheet est au premier plan.
///
/// Reconstruit à chaque colis relu et à chaque retour du sheet au premier
/// plan (`ModalRoute.isCurrentOf`) : un rechargement arrivé pendant qu'une
/// confirmation ou une erreur couvrait le sheet le referme dès qu'elle se
/// ferme, sans jamais la refermer à sa place. Même règle que le sheet des
/// tuiles « À traiter » de l'expéditeur.
class _CloseWhenResolved extends StatelessWidget {
  const _CloseWhenResolved({
    required this.bid,
    required this.tile,
    required this.child,
  });

  final BidModel bid;
  final TravelerTodoTile tile;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onTop = ModalRoute.isCurrentOf(context) ?? false;
    final state = context.watch<BidBloc>().state;
    if (onTop &&
        state is BidDetailLoaded &&
        state.bid.id == bid.id &&
        !travelerTodoTilesFor(state.bid).contains(tile)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _TravelerTodoSheetContent._closeIfOnTop(context);
        }
      });
    }
    return child;
  }
}
