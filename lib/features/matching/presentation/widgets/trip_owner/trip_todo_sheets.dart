import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_depart_action.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_edit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_consent_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ouvre le bottom sheet de la tuile « À traiter » [tile] du trajet [trip]
/// (écran du trajet, vue du voyageur propriétaire) et compte l'ouverture
/// (`bid_detail_tile_opened`, `role: trip_owner`, `source: tile`).
///
/// Comme `openTravelerTodoSheet` de la fiche colis : le sheet s'ouvre sur le
/// navigateur racine, les blocs de l'écran y sont reposés par le `wrapper`
/// (`BlocProvider.value`) quand [context] les fournit ([TripTodoBlocs]) :
/// `AnnouncementBloc` (trajet relu), `BidBloc` (colis du trajet),
/// `StripeAccountBloc` (compte de paiement par carte) et `TripDepartCubit`
/// (« Je pars »). La tuile [TripTodoTile.depart] exige le `TripDepartCubit`
/// de l'écran, celui dont la section « À traiter » lit `departed` : le sheet
/// n'en crée jamais (un cubit propre au sheet serait fermé au glissement du
/// sheet, réponse du départ encore en vol).
///
/// Titre, contenu et pied suivent les mêmes données que la section
/// ([TripTodoLive]) ; [bids] : derniers colis connus de la section, repris
/// si le `BidBloc` est en plein rechargement à l'ouverture. Le bouton vit
/// dans le `stickyBottom`.
///
/// Tuiles concernées : [TripTodoTile.depart] et [TripTodoTile.card], rendues
/// en lignes par `TripTodoRows`. [TripTodoTile.requests] n'y passe jamais
/// (carte de réponse directe `TripDirectRequestCard`, sheet d'activité
/// `openTripActivitySheet`).
///
/// Le sheet se ferme seul dès que les données relues ne justifient plus
/// [tile] ([tripTodoTilesFor]) : départ confirmé, carte ajoutée. Une confirmation ou une erreur ouverte par-dessus n'est
/// jamais refermée à sa place.
///
/// Les boutons qui mènent à un autre écran ferment d'abord le sheet, puis
/// poussent la route depuis [context] (l'écran, jamais la tuile qui peut
/// disparaître) et relisent l'écran au retour.
Future<void> openTripTodoSheet(
  BuildContext context,
  AnnouncementModel trip,
  TripTodoTile tile, {
  List<BidModel>? bids,
}) {
  // Les demandes à traiter ne passent jamais par ce sheet : la carte de
  // réponse directe et le sheet d'activité « Demandes » les portent.
  assert(
    tile != TripTodoTile.requests,
    'requests: TripDirectRequestCard / openTripActivitySheet',
  );
  final blocs = TripTodoBlocs.of(context);
  // La tuile « Je pars » se calcule avec le TripDepartCubit de l'écran : il
  // doit être fourni au-dessus de [context].
  assert(
    tile != TripTodoTile.depart || blocs.depart != null,
    'TripDepartCubit missing above context',
  );
  logBidDetailTileOpened(
    tile: tile.name,
    role: 'trip_owner',
    source: TodoSource.tile.name,
  );

  Widget follow(Widget Function(BuildContext, TripTodoLiveData) builder) =>
      TripTodoLive(
        trip: trip,
        blocs: blocs,
        initialBids: bids,
        builder: builder,
      );

  return DonyBottomSheet.show<void>(
    context,
    // Le titre de la tuile « carte » change avec le compte de paiement : il
    // suit les données comme le corps et le bouton.
    titleWidget: follow(
      (sheetContext, live) => Text(
        tripTodoTitle(sheetContext.l10n, tile, cardReady: live.cardReady),
      ),
    ),
    analyticsName: 'trip-owner/todo-${tile.name}',
    wrapper: (content) {
      final providers = [
        if (blocs.announcement case final b?)
          BlocProvider<AnnouncementBloc>.value(value: b),
        if (blocs.bids case final b?) BlocProvider<BidBloc>.value(value: b),
        if (blocs.stripe case final b?)
          BlocProvider<StripeAccountBloc>.value(value: b),
        if (blocs.depart case final b?)
          BlocProvider<TripDepartCubit>.value(value: b),
      ];
      return providers.isEmpty
          ? content
          : MultiBlocProvider(providers: providers, child: content);
    },
    stickyBottom: follow(
      (sheetContext, live) =>
          _TripTodoFooter(tile: tile, live: live, screenContext: context),
    ),
    child: follow(
      (sheetContext, live) => CloseTripSheetWhenGone(
        gone: !live.tiles.contains(tile),
        child: _TripTodoContent(tile: tile, live: live),
      ),
    ),
  );
}

/// Contenu du sheet, sur les données courantes.
class _TripTodoContent extends StatelessWidget {
  const _TripTodoContent({required this.tile, required this.live});

  final TripTodoTile tile;
  final TripTodoLiveData live;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: switch (tile) {
        // Jamais ouvert ici : les demandes ont leur carte de réponse directe
        // et leur sheet d'activité (`openTripActivitySheet`).
        TripTodoTile.requests => const SizedBox.shrink(),
        TripTodoTile.depart => Column(
          key: const Key('trip-todo-depart-content'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.tripTodoDepartIntro, style: tt.bodyMedium),
            const SizedBox(height: DonySpacing.md),
            const TrackingConsentExplainer(),
          ],
        ),
        TripTodoTile.card => Text(
          live.cardReady
              ? l.listingCashOnlyCardReadyMessage
              : l.listingCashOnlyNudgeMessage,
          key: const Key('trip-todo-card-content'),
          style: tt.bodyMedium,
        ),
      },
    );
  }
}

/// Bouton du pied, sur les données courantes. [screenContext] : contexte de
/// l'écran qui a ouvert le sheet, pour pousser une route une fois le sheet
/// fermé.
class _TripTodoFooter extends StatelessWidget {
  const _TripTodoFooter({
    required this.tile,
    required this.live,
    required this.screenContext,
  });

  final TripTodoTile tile;
  final TripTodoLiveData live;
  final BuildContext screenContext;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return switch (tile) {
      TripTodoTile.requests => const SizedBox.shrink(),
      TripTodoTile.depart => const TripDepartAction(),
      TripTodoTile.card =>
        live.cardReady
            ? DonyButton(
                key: const Key('enable-card-on-trip-cta'),
                label: l.listingEnableCardOnTripButton,
                onPressed: () => unawaited(_openEditToEnableCard(context)),
              )
            : DonyButton(
                key: const Key('activate-card-payments-cta'),
                label: l.listingActivateCardPaymentsButton,
                onPressed: () => unawaited(_openCardOnboarding(context)),
              ),
    };
  }

  /// Compte de paiement prêt : l'édition du trajet propose la carte, puis le
  /// trajet est relu pour que la tuile disparaisse (Sentry FLUTTER-DH)
  /// ([openTripEdit]).
  Future<void> _openEditToEnableCard(BuildContext sheetContext) async {
    if (!_closeForAction(sheetContext)) return;
    await openTripEdit(screenContext, live.trip);
  }

  /// Activation des paiements par carte. Le `StripeAccountBloc` est partagé
  /// par toute l'app et relu par le parcours d'activation lui-même : rien à
  /// recharger au retour.
  Future<void> _openCardOnboarding(BuildContext sheetContext) async {
    if (!_closeForAction(sheetContext)) return;
    await screenContext.push<void>('/connect/onboarding/intro');
  }

  /// Ferme le sheet avant d'agir. Faux quand il n'est plus au premier plan
  /// (second appui pendant l'animation de sortie, confirmation par-dessus)
  /// ou que l'écran n'est plus monté : l'action n'est pas rejouée.
  bool _closeForAction(BuildContext sheetContext) =>
      closeSheetIfOnTop(sheetContext) && screenContext.mounted;
}
