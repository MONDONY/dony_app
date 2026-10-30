import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/owner_action_grid.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_detail_sections.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_edit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre le bottom sheet de la tuile « Votre trajet » [tile] du trajet [trip]
/// (écran du trajet, vue du voyageur propriétaire) et compte l'ouverture
/// (`bid_detail_tile_opened`, `role: trip_owner`, [source] : `tile` pour la
/// tuile de la grille, `menu` pour une entrée du menu ⋮ qui ouvre la même
/// feuille).
///
/// Comme `openTravelerTileSheet` de la fiche colis : le sheet s'ouvre sur le
/// navigateur racine, les blocs de l'écran trouvés sous [context] y sont
/// reposés par le `wrapper` (`BlocProvider.value`) : `AnnouncementBloc`
/// (trajet relu), `BidBloc` (colis du trajet), `StripeAccountBloc` (renvoi
/// vers « À traiter » d'un trajet en espèces seules). Le contenu suit le
/// trajet et les colis relus ; il se ferme seul quand [tripTilesFor] ne
/// contient plus [tile] (trajet complet pour l'affiche, par exemple), jamais
/// par-dessus une confirmation.
///
/// Le bouton, quand le sheet en a un, vit dans le `stickyBottom` ; le pied
/// n'existe que si l'action vaut à l'ouverture, et le bouton disparaît si
/// elle ne vaut plus :
/// - `itinerary`, `conditions` : « Modifier » si le trajet est modifiable
///   ([canEditTrip]) ;
/// - `payments` : aucun (l'action « carte » est dans « À traiter ») ;
/// - `poster` : « Partager l'affiche » ([openTripPoster]) ;
/// - `arrival` : « Modifier les instructions » dès qu'un colis est
///   arrivé ([tripHasArrivedParcel], ce que le back exige pour les modifier)
///   et que l'écran fournit son `AnnouncementBloc`.
///
/// Les boutons ferment d'abord le sheet, puis agissent depuis [context]
/// (l'écran, jamais la tuile qui peut disparaître).
Future<void> openTripTileSheet(
  BuildContext context,
  AnnouncementModel trip,
  TripTile tile, {
  TravelerTileSource source = TravelerTileSource.tile,
}) {
  logBidDetailTileOpened(
    tile: tile.name,
    role: 'trip_owner',
    source: source.name,
  );

  final blocs = _TripTileBlocs(
    announcement: maybeRead<AnnouncementBloc>(context),
    bids: maybeRead<BidBloc>(context),
    stripe: maybeRead<StripeAccountBloc>(context),
  );
  final opening = _TripTileLiveData(
    trip: switch (blocs.announcement?.state) {
      final AnnouncementState s => tripAnnouncementIn(s, trip.id) ?? trip,
      null => trip,
    },
    bids: switch (blocs.bids?.state) {
      BidListLoaded(:final bids) => bids,
      _ => null,
    },
    stripe: blocs.stripe?.state ?? const StripeAccountInitial(),
    canUpdateInstructions: blocs.announcement != null,
  );

  return DonyBottomSheet.show<void>(
    context,
    title: tripTileTitle(context.l10n, tile),
    analyticsName: 'trip-owner/${tile.name}',
    wrapper: (content) {
      final providers = [
        if (blocs.announcement case final b?)
          BlocProvider<AnnouncementBloc>.value(value: b),
        if (blocs.bids case final b?) BlocProvider<BidBloc>.value(value: b),
        if (blocs.stripe case final b?)
          BlocProvider<StripeAccountBloc>.value(value: b),
      ];
      return providers.isEmpty
          ? content
          : MultiBlocProvider(providers: providers, child: content);
    },
    stickyBottom: opening.hasAction(tile)
        ? _LiveTripTile(
            opening: opening,
            blocs: blocs,
            builder: (sheetContext, live) =>
                _TripTileFooter(tile: tile, live: live, screenContext: context),
          )
        : null,
    child: _LiveTripTile(
      opening: opening,
      blocs: blocs,
      builder: (sheetContext, live) => CloseTripSheetWhenGone(
        gone: !tripTilesFor(trip: live.trip, bids: live.bids).contains(tile),
        child: _TripTileContent(tile: tile, live: live),
      ),
    ),
  );
}

/// Blocs de l'écran trouvés à l'ouverture du sheet, à reposer dans le sheet.
class _TripTileBlocs {
  const _TripTileBlocs({
    required this.announcement,
    required this.bids,
    required this.stripe,
  });

  final AnnouncementBloc? announcement;
  final BidBloc? bids;
  final StripeAccountBloc? stripe;
}

/// Données courantes d'un sheet « Votre trajet ».
class _TripTileLiveData {
  const _TripTileLiveData({
    required this.trip,
    required this.bids,
    required this.stripe,
    required this.canUpdateInstructions,
  });

  /// Dernier trajet relu par l'écran, à défaut celui de l'ouverture.
  final AnnouncementModel trip;

  /// Derniers colis chargés (`BidListLoaded`), `null` tant que la liste n'a
  /// pas répondu.
  final List<BidModel>? bids;
  final StripeAccountState stripe;

  /// L'écran fournit son `AnnouncementBloc`, que la feuille d'édition des
  /// instructions de retrait lit.
  final bool canUpdateInstructions;

  bool get canEdit => canEditTrip(trip, tripHasBids(trip, bids));

  /// Trajet en espèces seules où la carte reste possible : la tuile « carte »
  /// de « À traiter » porte l'action, le sheet Paiements y renvoie.
  bool get cardTodoShown => tripTodoTilesFor(
    trip: trip,
    bids: bids,
    isOwner: true,
    departed: false,
    stripe: stripe,
  ).contains(TripTodoTile.card);

  /// Le sheet de [tile] a-t-il une action, donc un bouton dans son pied ?
  bool hasAction(TripTile tile) => switch (tile) {
    TripTile.itinerary || TripTile.conditions => canEdit,
    TripTile.payments => false,
    TripTile.poster => canShareTripPoster(trip),
    TripTile.arrival => canUpdateInstructions && tripHasArrivedParcel(bids),
  };

  _TripTileLiveData copyWith({
    AnnouncementModel? trip,
    List<BidModel>? bids,
    StripeAccountState? stripe,
  }) => _TripTileLiveData(
    trip: trip ?? this.trip,
    bids: bids ?? this.bids,
    stripe: stripe ?? this.stripe,
    canUpdateInstructions: canUpdateInstructions,
  );
}

/// Rend [builder] avec les données courantes : chaque bloc présent est suivi
/// (seuls ses états porteurs de données reconstruisent : un chargement garde
/// les dernières connues), un bloc absent laisse la valeur de l'ouverture.
class _LiveTripTile extends StatelessWidget {
  const _LiveTripTile({
    required this.opening,
    required this.blocs,
    required this.builder,
  });

  final _TripTileLiveData opening;
  final _TripTileBlocs blocs;
  final Widget Function(BuildContext context, _TripTileLiveData live) builder;

  @override
  Widget build(BuildContext context) {
    return followBloc<AnnouncementBloc, AnnouncementState, AnnouncementModel>(
      present: blocs.announcement != null,
      select: (s) => tripAnnouncementIn(s, opening.trip.id),
      builder: (context, trip) => followBloc<BidBloc, BidState, List<BidModel>>(
        present: blocs.bids != null,
        select: (s) => s is BidListLoaded ? s.bids : null,
        builder: (context, bids) =>
            followBloc<
              StripeAccountBloc,
              StripeAccountState,
              StripeAccountState
            >(
              present: blocs.stripe != null,
              select: (s) => s,
              builder: (context, stripe) => builder(
                context,
                opening.copyWith(trip: trip, bids: bids, stripe: stripe),
              ),
            ),
      ),
    );
  }
}

/// Contenu du sheet, sur les données courantes : les sections du trajet
/// reprises telles quelles du corps de détail.
class _TripTileContent extends StatelessWidget {
  const _TripTileContent({required this.tile, required this.live});

  final TripTile tile;
  final _TripTileLiveData live;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final trip = live.trip;
    return Column(
      key: Key('trip-tile-${tile.name}-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (tile) {
        TripTile.itinerary => [TripPlacesSection(trip: trip)],
        TripTile.payments => [
          TripPaymentsSection(trip: trip),
          TripMobileMoneyNetworksSection(trip: trip),
          if (live.cardTodoShown)
            Text(
              l.tripTilePaymentsCashOnlyNote,
              key: const Key('trip-tile-payments-cash-note'),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
        ],
        TripTile.conditions => [TripConditionsSection(trip: trip)],
        TripTile.poster => [Text(l.tripTilePosterIntro, style: tt.bodyMedium)],
        TripTile.arrival => [
          if (ArrivalInstructionsCard.hasText(trip.arrivalInstructions))
            ArrivalInstructionsCard(instructions: trip.arrivalInstructions!)
          else
            Text(
              l.tripTileArrivalEmpty,
              key: const Key('trip-tile-arrival-empty'),
              style: tt.bodyMedium,
            ),
        ],
      },
    );
  }
}

/// Bouton du pied, sur les données courantes ; rien quand l'action ne vaut
/// plus. [screenContext] : contexte de l'écran qui a ouvert le sheet, pour
/// agir une fois le sheet fermé.
class _TripTileFooter extends StatelessWidget {
  const _TripTileFooter({
    required this.tile,
    required this.live,
    required this.screenContext,
  });

  final TripTile tile;
  final _TripTileLiveData live;
  final BuildContext screenContext;

  @override
  Widget build(BuildContext context) {
    if (!live.hasAction(tile)) return const SizedBox.shrink();
    final l = context.l10n;
    return switch (tile) {
      TripTile.itinerary || TripTile.conditions => DonyButton(
        key: const Key('trip-tile-edit-button'),
        label: l.commonEdit,
        onPressed: () => unawaited(_edit(context)),
      ),
      TripTile.poster => DonyButton(
        key: const Key('trip-tile-poster-button'),
        label: l.tripPosterShareButton,
        onPressed: () => _sharePoster(context),
      ),
      TripTile.arrival => DonyButton(
        key: const Key('trip-tile-arrival-edit-button'),
        label: l.tripTileArrivalEditButton,
        onPressed: () => unawaited(_editInstructions(context)),
      ),
      TripTile.payments => const SizedBox.shrink(),
    };
  }

  /// Édition du trajet, relu au retour s'il a été enregistré.
  Future<void> _edit(BuildContext sheetContext) async {
    closeSheetIfOnTop(sheetContext);
    if (!screenContext.mounted) return;
    await openTripEdit(screenContext, live.trip);
  }

  /// Affiche partageable du trajet. Elle ne modifie rien : pas de relecture.
  void _sharePoster(BuildContext sheetContext) {
    closeSheetIfOnTop(sheetContext);
    if (!screenContext.mounted) return;
    openTripPoster(screenContext, live.trip);
  }

  /// Feuille d'édition des instructions de retrait, sur l'`AnnouncementBloc`
  /// de l'écran : la relecture du trajet et des colis passe par l'écran
  /// (`AnnouncementArrivalInstructionsUpdated`), comme avec l'ancien bouton.
  Future<void> _editInstructions(BuildContext sheetContext) async {
    closeSheetIfOnTop(sheetContext);
    if (!screenContext.mounted) return;
    await ArrivalInstructionsBottomSheet.show(
      screenContext,
      announcementId: live.trip.id,
      initialInstructions: live.trip.arrivalInstructions,
      isEditing: true,
    );
  }
}
