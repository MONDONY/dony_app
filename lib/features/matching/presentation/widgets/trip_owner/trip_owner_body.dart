import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_detail_section.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_action_tile.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_audience_section.dart';
import 'package:dony/features/matching/presentation/widgets/trip_legs_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_header.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_requests_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_status_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart';
import 'package:dony/features/matching/presentation/widgets/trip_summary_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Corps de l'écran du trajet vu par son voyageur, en sections, comme le
/// corps de la fiche colis (`TravelerDetailBody`).
///
/// Ordre : tête ([TripOwnerHeader] : billet, ligne surplus, pastilles kilos
/// et prix, jauge des valises) ; carte de statut ([TripStatusCard], si l'état
/// en a une) ; « À traiter » (seulement s'il y a une tuile,
/// [tripTodoTilesFor], chacune ouvrant son bottom sheet) ; cartes
/// d'information sans titre (étapes du voyage [TripLegsCard], audience
/// [TripAudienceSection]) ; cartes directes Demandes ([TripRequestsCard]),
/// Colis ([TripParcelsSection]) et Gain ([TripSummaryCard]) ; grille « Votre
/// trajet » ([tripTilesFor], chacune ouvrant son bottom sheet). Le pied
/// collant et le menu ⋮ sont posés par l'écran, hors du défilement.
///
/// Tant que la propriété n'est pas tranchée ([isOwner] faux : démarrage à
/// froid par un lien, visiteur sur le point d'être renvoyé vers la feuille
/// expéditeur), seuls la tête et la carte de statut s'affichent : rien du
/// voyageur ne fuit (colis, demandes, audience).
///
/// Toutes les sections lisent les mêmes données que les sheets et le pied
/// ([TripTodoLive] : dernier trajet relu, derniers colis chargés, compte de
/// paiement, départ confirmé) : un rechargement garde l'affichage, une tuile
/// et son sheet ne divergent jamais.
///
/// Chaque section porte une clé (`KeyedSubtree`) : l'apparition ou la
/// disparition d'une section ne remonte pas les autres.
///
/// Les sheets s'ouvrent avec le contexte de ce `State` (stable), jamais celui
/// d'une tuile qui disparaît dès que la demande est traitée.
///
/// Requiert les blocs de la route du trajet : `AnnouncementBloc`, `BidBloc`,
/// `TripAudienceCubit`, `TripGroupCubit` (facultatif), `StripeAccountBloc`
/// (global) et le `TripDepartCubit` fourni par l'écran.
class TripOwnerBody extends StatefulWidget {
  const TripOwnerBody({
    super.key,
    required this.trip,
    required this.isOwner,
    this.bottomPadding = 0,
  });

  /// Dernier trajet connu de l'écran (détail relu, à défaut l'`extra`).
  final AnnouncementModel trip;
  final bool isOwner;

  /// Marge basse en plus du défilement (zone sûre de l'écran).
  final double bottomPadding;

  @override
  State<TripOwnerBody> createState() => _TripOwnerBodyState();
}

class _TripOwnerBodyState extends State<TripOwnerBody> {
  /// Mesure d'affichage des tuiles « À traiter », une fois par tuile et par
  /// statut du trajet (et par nombre de demandes pour `requests`) pour cet
  /// écran ([tripTodoShown]).
  final _todoViews = TodoTileViewLog();

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final Widget column;
    if (!widget.isOwner) {
      column = _column([
        ('header', TripOwnerHeader(a: widget.trip)),
        if (tripStatusCardKindFor(widget.trip.status) case final kind?)
          ('status', TripStatusCard(kind: kind)),
      ]);
    } else {
      column = TripTodoLive(
        trip: widget.trip,
        blocs: TripTodoBlocs.of(context),
        builder: (context, live) => _column(_ownerSections(live)),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.md,
        h,
        DonySpacing.lg + widget.bottomPadding,
      ),
      child: DonyLayout.constrained(context, column),
    );
  }

  Widget _column(List<(String, Widget)> sections) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (name, child) in sections)
        KeyedSubtree(
          key: ValueKey(name),
          // Les cartes qui peuvent ne rien rendre (étapes, audience) posent
          // leur marge elles-mêmes, seulement quand elles s'affichent.
          child: _selfSpaced.contains(name)
              ? child
              : Padding(
                  padding: const EdgeInsets.only(bottom: DonySpacing.base),
                  child: child,
                ),
        ),
    ],
  );

  static const _selfSpaced = {'legs', 'audience'};

  List<(String, Widget)> _ownerSections(TripTodoLiveData live) {
    final l = context.l10n;
    final trip = live.trip;
    final bids = live.bids;

    final todoTiles = live.tiles;
    _todoViews.logAll(context, trip.id, [
      for (final tile in todoTiles)
        tripTodoShown(tile, trip, pendingCount: live.pendingCount),
    ]);
    final tiles = tripTilesFor(trip: trip, bids: bids, isOwner: true);
    const spacing = EdgeInsets.only(bottom: DonySpacing.base);

    return [
      ('header', TripOwnerHeader(a: trip)),
      if (tripStatusCardKindFor(trip.status) case final kind?)
        ('status', TripStatusCard(kind: kind)),
      if (todoTiles.isNotEmpty)
        (
          'todo',
          BidDetailSection(
            title: l.bidDetailSectionTodo,
            children: [
              DonyActionTileGrid(
                tiles: [for (final tile in todoTiles) _todoTile(live, tile)],
              ),
            ],
          ),
        ),
      // Voyage à plusieurs étapes (FLUTTER-4D), puis audience : cartes
      // d'information sans titre.
      (
        'legs',
        TripLegsCard(
          announcementId: trip.id,
          padding: spacing,
          onOpenLeg: (leg) =>
              unawaited(context.push<void>('/announcements/${leg.id}/trip')),
        ),
      ),
      if (TripAudienceSection.shownFor(trip.status))
        (
          'audience',
          TripAudienceSection(announcementId: trip.id, padding: spacing),
        ),
      if (TripRequestsCard.shownFor(trip, bids))
        ('requests', TripRequestsCard(trip: trip, bids: bids)),
      // Un brouillon n'a pas encore de colis ; un trajet retiré par l'équipe
      // n'en montre plus.
      if (!_noParcelsCard.contains(trip.status))
        ('parcels', TripParcelsSection(announcementId: trip.id)),
      if (TripSummaryCard.shownFor(isOwner: true, trip: trip))
        ('gain', TripSummaryCard(summary: trip.parcelsSummary!)),
      if (tiles.isNotEmpty)
        (
          'tiles',
          BidDetailSection(
            title: l.tripSectionYourTrip,
            spacing: DonySpacing.md,
            children: [
              DonyActionTileGrid(
                tiles: [for (final tile in tiles) _tripTile(live, tile)],
              ),
            ],
          ),
        ),
    ];
  }

  static const _noParcelsCard = {'DRAFT', 'REMOVED_BY_ADMIN'};

  /// Tuile « À traiter » : pastille « Réponse attendue », résumé de ce qui
  /// est attendu ; le sheet part des colis de la tuile ([TripTodoLiveData]).
  Widget _todoTile(TripTodoLiveData live, TripTodoTile tile) {
    final l = context.l10n;
    return todoActionTile(
      context,
      role: 'trip_owner',
      tile: tile.name,
      iconName: tripTodoIcon(tile),
      label: tripTodoTitle(l, tile, cardReady: live.cardReady),
      subtitle: tripTodoSummary(
        l,
        tile,
        pendingCount: live.pendingCount,
        cardReady: live.cardReady,
      ),
      badge: l.todoTileBadgeReplyNeeded,
      onTap: () => unawaited(
        openTripTodoSheet(context, live.trip, tile, bids: live.bids),
      ),
    );
  }

  /// Tuile « Votre trajet » : ouvre la feuille de lecture, avec son bouton
  /// « Modifier » quand le trajet est modifiable.
  Widget _tripTile(TripTodoLiveData live, TripTile tile) {
    final l = context.l10n;
    return DonyActionTile(
      key: Key('trip-tile-${tile.name}'),
      iconName: tripTileIcon(tile),
      label: tripTileTitle(l, tile),
      subtitle: tripTileSubtitle(l, tile, live.trip),
      color: Theme.of(context).colorScheme.primary,
      onTap: () => unawaited(
        openTripTileSheet(context, live.trip, tile, bids: live.bids),
      ),
    );
  }
}
