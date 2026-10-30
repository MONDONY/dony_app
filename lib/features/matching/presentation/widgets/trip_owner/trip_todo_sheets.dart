import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_depart_button.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_edit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
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
/// Le sheet se ferme seul dès que les données relues ne justifient plus
/// [tile] ([tripTodoTilesFor]) : départ confirmé, dernière demande traitée,
/// carte ajoutée. Une confirmation ou une erreur ouverte par-dessus n'est
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
    final cs = Theme.of(context).colorScheme;
    final muted = tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: switch (tile) {
        TripTodoTile.requests => Column(
          key: const Key('trip-todo-requests-content'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Liste pas encore chargée : le nombre servi par la liste des
            // trajets, sans les lignes.
            if (live.bids case final bids?)
              for (final bid in bids.where(isPendingBid)) ...[
                _RequestRow(bid: bid),
                const SizedBox(height: DonySpacing.sm),
              ]
            else ...[
              Text(
                l.tripTodoRequestsSummary(live.pendingCount),
                style: tt.bodyMedium,
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            Text(l.tripTodoRequestsHint, style: muted),
          ],
        ),
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

/// Une demande à traiter : contenu, expéditeur · poids, net du voyageur
/// ([travelerNetAmount], même montant que la liste des demandes).
class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Catégories, sinon description, sinon « Colis » : une valeur vide du
    // back ne laisse jamais la ligne sans titre.
    final category = bid.contentCategory;
    final categories = category == null
        ? ''
        : contentCategoriesDisplayName(l, category);
    final description = bid.description?.trim() ?? '';
    final content = categories.isNotEmpty
        ? categories
        : description.isNotEmpty
        ? description
        : l.tripOwnerParcelsDefaultContent;
    final sender = bid.senderDisplayName(l);
    final w = bid.displayWeightKg;
    final weight = w == null
        ? null
        : '${w.toStringAsFixed(w % 1 == 0 ? 0 : 1)} kg';
    final net = travelerNetAmount(bid);
    return Container(
      key: Key('trip-todo-request-${bid.id}'),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  weight != null ? '$sender · $weight' : sender,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (net != null) ...[
            const SizedBox(width: DonySpacing.sm),
            Text(
              formatPriceIn(net, bid.currency),
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
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
      TripTodoTile.requests => DonyButton(
        key: const Key('trip-todo-requests-button'),
        label: l.listingSeeRequestsButton(live.pendingCount),
        onPressed: () => unawaited(_openRequests(context)),
      ),
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

  /// Activité › Demandes « À traiter » de ce trajet, relu au retour
  /// ([openTripRequests]).
  Future<void> _openRequests(BuildContext sheetContext) async {
    closeSheetIfOnTop(sheetContext);
    if (!screenContext.mounted) return;
    await openTripRequests(screenContext, live.trip.id);
  }

  /// Compte de paiement prêt : l'édition du trajet propose la carte, puis le
  /// trajet est relu pour que la tuile disparaisse (Sentry FLUTTER-DH), comme
  /// l'encart du corps du trajet ([openTripEdit]).
  Future<void> _openEditToEnableCard(BuildContext sheetContext) async {
    closeSheetIfOnTop(sheetContext);
    if (!screenContext.mounted) return;
    await openTripEdit(screenContext, live.trip);
  }

  /// Activation des paiements par carte. Le `StripeAccountBloc` est partagé
  /// par toute l'app et relu par le parcours d'activation lui-même : rien à
  /// recharger au retour.
  Future<void> _openCardOnboarding(BuildContext sheetContext) async {
    closeSheetIfOnTop(sheetContext);
    if (!screenContext.mounted) return;
    await screenContext.push<void>('/connect/onboarding/intro');
  }
}
